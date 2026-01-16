package queue

import (
	"context"
	"testing"
	"time"

	"gatekeep/internal/config"
	redisclient "gatekeep/internal/redis"
)

func setupTestManager(t *testing.T) (*Manager, func()) {
	cfg := &config.Config{
		Port:          8080,
		RedisAddr:     "localhost:6379",
		RedisPassword: "",
		TokenSecret:   "this-is-a-very-long-secret-key-that-is-at-least-32-characters",
		AdminAPIKey:   "admin-key",
		LogLevel:      "info",
		MetricsPort:   9090,
	}

	redisClient, err := redisclient.NewClient(cfg)
	if err != nil {
		t.Skipf("Skipping test: Redis not available: %v", err)
		return nil, nil
	}

	manager := NewManager(redisClient)

	// Cleanup function
	cleanup := func() {
		ctx := context.Background()
		client := redisClient.GetClient()

		// Clean up test keys
		keys := []string{
			"queue:*",
		}
		for _, pattern := range keys {
			iter := client.Scan(ctx, 0, pattern, 100).Iterator()
			for iter.Next(ctx) {
				client.Del(ctx, iter.Val())
			}
		}
	}

	return manager, cleanup
}

func TestJoinQueue_SuccessfulJoin(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	req := JoinQueueRequest{
		EventID:        "test-event-1",
		DeviceID:       "device-1",
		UserID:         "user-1",
		PriorityBucket: "normal",
	}

	entry, err := manager.JoinQueue(req)
	if err != nil {
		t.Fatalf("JoinQueue() failed: %v", err)
	}

	if entry == nil {
		t.Fatal("JoinQueue() returned nil entry")
	}

	if entry.QueueID == "" {
		t.Error("QueueID is empty")
	}
	if entry.EventID != req.EventID {
		t.Errorf("EventID mismatch: expected %s, got %s", req.EventID, entry.EventID)
	}
	if entry.DeviceID != req.DeviceID {
		t.Errorf("DeviceID mismatch: expected %s, got %s", req.DeviceID, entry.DeviceID)
	}
	if entry.UserID != req.UserID {
		t.Errorf("UserID mismatch: expected %s, got %s", req.UserID, entry.UserID)
	}
	if entry.PriorityBucket != req.PriorityBucket {
		t.Errorf("PriorityBucket mismatch: expected %s, got %s", req.PriorityBucket, entry.PriorityBucket)
	}
	if entry.Position <= 0 {
		t.Errorf("Position should be > 0, got %d", entry.Position)
	}
}

func TestJoinQueue_IdempotentJoin(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	req := JoinQueueRequest{
		EventID:        "test-event-2",
		DeviceID:       "device-2",
		UserID:         "user-2",
		PriorityBucket: "normal",
	}

	// First join
	entry1, err := manager.JoinQueue(req)
	if err != nil {
		t.Fatalf("First JoinQueue() failed: %v", err)
	}

	// Second join with same device+event (should return same entry)
	entry2, err := manager.JoinQueue(req)
	if err != nil {
		t.Fatalf("Second JoinQueue() failed: %v", err)
	}

	if entry1.QueueID != entry2.QueueID {
		t.Errorf("Idempotency failed: QueueID changed from %s to %s", entry1.QueueID, entry2.QueueID)
	}
}

func TestJoinQueue_QueueDisabled(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	eventID := "test-event-disabled"

	// Set event config to disabled
	config := &EventConfig{
		EventID:     eventID,
		Enabled:     false,
		MaxSize:     1000,
		ReleaseRate: 10,
	}
	if err := manager.SetEventConfig(config); err != nil {
		t.Fatalf("SetEventConfig() failed: %v", err)
	}

	req := JoinQueueRequest{
		EventID:        eventID,
		DeviceID:       "device-3",
		UserID:         "user-3",
		PriorityBucket: "normal",
	}

	_, err := manager.JoinQueue(req)
	if err == nil {
		t.Error("JoinQueue() expected error for disabled queue, got nil")
		return
	}

	if err.Error() == "" {
		t.Error("Error message is empty")
	}
}

func TestJoinQueue_MaxSizeLimit(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	eventID := "test-event-maxsize"

	// Set event config with small max size
	config := &EventConfig{
		EventID:     eventID,
		Enabled:     true,
		MaxSize:     2, // Very small limit
		ReleaseRate: 10,
	}
	if err := manager.SetEventConfig(config); err != nil {
		t.Fatalf("SetEventConfig() failed: %v", err)
	}

	// Join first user
	req1 := JoinQueueRequest{
		EventID:        eventID,
		DeviceID:       "device-4",
		UserID:         "user-4",
		PriorityBucket: "normal",
	}
	_, err := manager.JoinQueue(req1)
	if err != nil {
		t.Fatalf("First JoinQueue() failed: %v", err)
	}

	// Join second user
	req2 := JoinQueueRequest{
		EventID:        eventID,
		DeviceID:       "device-5",
		UserID:         "user-5",
		PriorityBucket: "normal",
	}
	_, err = manager.JoinQueue(req2)
	if err != nil {
		t.Fatalf("Second JoinQueue() failed: %v", err)
	}

	// Third user should fail
	req3 := JoinQueueRequest{
		EventID:        eventID,
		DeviceID:       "device-6",
		UserID:         "user-6",
		PriorityBucket: "normal",
	}
	_, err = manager.JoinQueue(req3)
	if err == nil {
		t.Error("JoinQueue() expected error for full queue, got nil")
		return
	}
}

func TestJoinQueue_PriorityBuckets(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	eventID := "test-event-priority"

	// Join with high priority
	reqHigh := JoinQueueRequest{
		EventID:        eventID,
		DeviceID:       "device-high",
		UserID:         "user-high",
		PriorityBucket: "high",
	}
	entryHigh, err := manager.JoinQueue(reqHigh)
	if err != nil {
		t.Fatalf("High priority JoinQueue() failed: %v", err)
	}
	if entryHigh.PriorityBucket != "high" {
		t.Errorf("PriorityBucket mismatch: expected 'high', got %s", entryHigh.PriorityBucket)
	}

	// Join with normal priority
	reqNormal := JoinQueueRequest{
		EventID:        eventID,
		DeviceID:       "device-normal",
		UserID:         "user-normal",
		PriorityBucket: "normal",
	}
	entryNormal, err := manager.JoinQueue(reqNormal)
	if err != nil {
		t.Fatalf("Normal priority JoinQueue() failed: %v", err)
	}
	if entryNormal.PriorityBucket != "normal" {
		t.Errorf("PriorityBucket mismatch: expected 'normal', got %s", entryNormal.PriorityBucket)
	}

	// Verify different queue IDs
	if entryHigh.QueueID == entryNormal.QueueID {
		t.Error("High and normal priority entries should have different QueueIDs")
	}
}

func TestJoinQueue_DefaultPriorityBucket(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	req := JoinQueueRequest{
		EventID:  "test-event-default",
		DeviceID: "device-default",
		UserID:   "user-default",
		// PriorityBucket not set - should default to "normal"
	}

	entry, err := manager.JoinQueue(req)
	if err != nil {
		t.Fatalf("JoinQueue() failed: %v", err)
	}

	if entry.PriorityBucket != "normal" {
		t.Errorf("Default PriorityBucket should be 'normal', got %s", entry.PriorityBucket)
	}
}

func TestJoinQueue_ValidationErrors(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	tests := []struct {
		name    string
		req     JoinQueueRequest
		wantErr string
	}{
		{
			name: "missing event_id",
			req: JoinQueueRequest{
				DeviceID: "device-1",
				UserID:   "user-1",
			},
			wantErr: "event_id is required",
		},
		{
			name: "missing device_id",
			req: JoinQueueRequest{
				EventID: "event-1",
				UserID:  "user-1",
			},
			wantErr: "device_id is required",
		},
		{
			name: "missing user_id",
			req: JoinQueueRequest{
				EventID:  "event-1",
				DeviceID: "device-1",
			},
			wantErr: "user_id is required",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := manager.JoinQueue(tt.req)
			if err == nil {
				t.Errorf("JoinQueue() expected error containing '%s', got nil", tt.wantErr)
				return
			}
			if err.Error() != tt.wantErr {
				t.Errorf("JoinQueue() error = '%v', want '%s'", err, tt.wantErr)
			}
		})
	}
}

func TestJoinQueue_RateLimiting(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	eventID := "test-event-ratelimit"
	deviceID := "device-ratelimit"

	// Join MaxJoinsPerWindow times (should succeed)
	for i := 0; i < MaxJoinsPerWindow; i++ {
		req := JoinQueueRequest{
			EventID:        eventID,
			DeviceID:       deviceID,
			UserID:         "user-ratelimit",
			PriorityBucket: "normal",
		}
		_, err := manager.JoinQueue(req)
		if err != nil {
			t.Fatalf("JoinQueue() #%d failed: %v", i+1, err)
		}
		// Small delay to ensure different timestamps
		time.Sleep(10 * time.Millisecond)
	}

	// Next join should fail due to rate limit
	req := JoinQueueRequest{
		EventID:        eventID,
		DeviceID:       deviceID,
		UserID:         "user-ratelimit",
		PriorityBucket: "normal",
	}
	_, err := manager.JoinQueue(req)
	if err == nil {
		t.Error("JoinQueue() expected rate limit error, got nil")
		return
	}
}

func TestGetEventConfig_Default(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	eventID := "test-event-default-config"
	config, err := manager.GetEventConfig(eventID)
	if err != nil {
		t.Fatalf("GetEventConfig() failed: %v", err)
	}

	if config.EventID != eventID {
		t.Errorf("EventID mismatch: expected %s, got %s", eventID, config.EventID)
	}
	if !config.Enabled {
		t.Error("Default config should be enabled")
	}
	if config.MaxSize != 10000 {
		t.Errorf("Default MaxSize should be 10000, got %d", config.MaxSize)
	}
	if config.ReleaseRate != 10 {
		t.Errorf("Default ReleaseRate should be 10, got %d", config.ReleaseRate)
	}
}

func TestSetEventConfig(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	config := &EventConfig{
		EventID:     "test-event-set",
		Enabled:     true,
		MaxSize:     5000,
		ReleaseRate: 20,
	}

	if err := manager.SetEventConfig(config); err != nil {
		t.Fatalf("SetEventConfig() failed: %v", err)
	}

	// Retrieve and verify
	retrieved, err := manager.GetEventConfig(config.EventID)
	if err != nil {
		t.Fatalf("GetEventConfig() failed: %v", err)
	}

	if retrieved.EventID != config.EventID {
		t.Errorf("EventID mismatch: expected %s, got %s", config.EventID, retrieved.EventID)
	}
	if retrieved.Enabled != config.Enabled {
		t.Errorf("Enabled mismatch: expected %v, got %v", config.Enabled, retrieved.Enabled)
	}
	if retrieved.MaxSize != config.MaxSize {
		t.Errorf("MaxSize mismatch: expected %d, got %d", config.MaxSize, retrieved.MaxSize)
	}
	if retrieved.ReleaseRate != config.ReleaseRate {
		t.Errorf("ReleaseRate mismatch: expected %d, got %d", config.ReleaseRate, retrieved.ReleaseRate)
	}
}
