package queue

import (
	"testing"
)

func TestGetQueueStatus_WaitingUser(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	// Join queue
	req := JoinQueueRequest{
		EventID:        "test-event-status",
		DeviceID:       "device-status",
		UserID:         "user-status",
		PriorityBucket: "normal",
	}

	entry, err := manager.JoinQueue(req)
	if err != nil {
		t.Fatalf("JoinQueue() failed: %v", err)
	}

	// Get status
	status, err := manager.GetQueueStatus(entry.QueueID)
	if err != nil {
		t.Fatalf("GetQueueStatus() failed: %v", err)
	}

	if status == nil {
		t.Fatal("GetQueueStatus() returned nil")
	}

	if status.QueueID != entry.QueueID {
		t.Errorf("QueueID mismatch: expected %s, got %s", entry.QueueID, status.QueueID)
	}
	if status.Status != "waiting" {
		t.Errorf("Status mismatch: expected 'waiting', got %s", status.Status)
	}
	if status.Position <= 0 {
		t.Errorf("Position should be > 0, got %d", status.Position)
	}
	if status.EstimatedWaitSeconds < 0 {
		t.Errorf("EstimatedWaitSeconds should be >= 0, got %d", status.EstimatedWaitSeconds)
	}
}

func TestGetQueueStatus_NonExistent(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	_, err := manager.GetQueueStatus("non-existent-queue-id")
	if err == nil {
		t.Error("GetQueueStatus() expected error for non-existent queue_id, got nil")
		return
	}
}

func TestGetQueueStatus_AdmittedUser(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	// Join queue
	req := JoinQueueRequest{
		EventID:        "test-event-admitted",
		DeviceID:       "device-admitted",
		UserID:         "user-admitted",
		PriorityBucket: "normal",
	}

	entry, err := manager.JoinQueue(req)
	if err != nil {
		t.Fatalf("JoinQueue() failed: %v", err)
	}

	// Mark as admitted
	if err := manager.MarkAsAdmitted(entry.QueueID); err != nil {
		t.Fatalf("MarkAsAdmitted() failed: %v", err)
	}

	// Get status
	status, err := manager.GetQueueStatus(entry.QueueID)
	if err != nil {
		t.Fatalf("GetQueueStatus() failed: %v", err)
	}

	if status.Status != "admitted" {
		t.Errorf("Status mismatch: expected 'admitted', got %s", status.Status)
	}
	if status.Position != 0 {
		t.Errorf("Position should be 0 for admitted users, got %d", status.Position)
	}
	if status.EstimatedWaitSeconds != 0 {
		t.Errorf("EstimatedWaitSeconds should be 0 for admitted users, got %d", status.EstimatedWaitSeconds)
	}
}

func TestGetQueueStatus_PositionCalculation(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	eventID := "test-event-position"

	// Join multiple users
	entries := make([]*QueueEntry, 3)
	for i := 0; i < 3; i++ {
		req := JoinQueueRequest{
			EventID:        eventID,
			DeviceID:       "device-position-" + string(rune(i)),
			UserID:         "user-position-" + string(rune(i)),
			PriorityBucket: "normal",
		}
		entry, err := manager.JoinQueue(req)
		if err != nil {
			t.Fatalf("JoinQueue() #%d failed: %v", i+1, err)
		}
		entries[i] = entry
	}

	// Check positions
	for i, entry := range entries {
		status, err := manager.GetQueueStatus(entry.QueueID)
		if err != nil {
			t.Fatalf("GetQueueStatus() #%d failed: %v", i+1, err)
		}
		expectedPosition := i + 1
		if status.Position != expectedPosition {
			t.Errorf("Position mismatch for entry #%d: expected %d, got %d", i+1, expectedPosition, status.Position)
		}
	}
}

func TestGetQueueStatus_EmptyQueueID(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	_, err := manager.GetQueueStatus("")
	if err == nil {
		t.Error("GetQueueStatus() expected error for empty queue_id, got nil")
		return
	}
}

func TestCalculateEstimatedWait(t *testing.T) {
	manager, cleanup := setupTestManager(t)
	if manager == nil {
		return
	}
	defer cleanup()

	eventID := "test-event-wait"

	// Set event config with known release rate
	config := &EventConfig{
		EventID:     eventID,
		Enabled:     true,
		MaxSize:     1000,
		ReleaseRate: 10, // 10 users per second
	}
	if err := manager.SetEventConfig(config); err != nil {
		t.Fatalf("SetEventConfig() failed: %v", err)
	}

	// Join user
	req := JoinQueueRequest{
		EventID:        eventID,
		DeviceID:       "device-wait",
		UserID:         "user-wait",
		PriorityBucket: "normal",
	}

	entry, err := manager.JoinQueue(req)
	if err != nil {
		t.Fatalf("JoinQueue() failed: %v", err)
	}

	// Get status and check estimated wait
	status, err := manager.GetQueueStatus(entry.QueueID)
	if err != nil {
		t.Fatalf("GetQueueStatus() failed: %v", err)
	}

	// With position 1 and release rate 10, wait should be ~0 seconds
	// But let's just verify it's a reasonable value
	if status.EstimatedWaitSeconds < 0 {
		t.Errorf("EstimatedWaitSeconds should be >= 0, got %d", status.EstimatedWaitSeconds)
	}
}
