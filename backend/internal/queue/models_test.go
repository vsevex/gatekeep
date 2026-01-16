package queue

import (
	"strings"
	"testing"
	"time"
)

func TestQueueEntry_Serialization(t *testing.T) {
	entry := &QueueEntry{
		QueueID:        "test-queue-id",
		EventID:        "test-event-id",
		DeviceID:       "test-device-id",
		UserID:         "test-user-id",
		Position:       5,
		EnqueuedAt:     time.Now(),
		LastHeartbeat:  time.Now(),
		PriorityBucket: "normal",
	}

	// Serialize
	data, err := SerializeQueueEntry(entry)
	if err != nil {
		t.Fatalf("SerializeQueueEntry() failed: %v", err)
	}

	if data == "" {
		t.Error("SerializeQueueEntry() returned empty string")
	}

	// Deserialize
	deserialized, err := DeserializeQueueEntry(data)
	if err != nil {
		t.Fatalf("DeserializeQueueEntry() failed: %v", err)
	}

	// Verify fields
	if deserialized.QueueID != entry.QueueID {
		t.Errorf("QueueID mismatch: expected %s, got %s", entry.QueueID, deserialized.QueueID)
	}
	if deserialized.EventID != entry.EventID {
		t.Errorf("EventID mismatch: expected %s, got %s", entry.EventID, deserialized.EventID)
	}
	if deserialized.DeviceID != entry.DeviceID {
		t.Errorf("DeviceID mismatch: expected %s, got %s", entry.DeviceID, deserialized.DeviceID)
	}
	if deserialized.UserID != entry.UserID {
		t.Errorf("UserID mismatch: expected %s, got %s", entry.UserID, deserialized.UserID)
	}
	if deserialized.Position != entry.Position {
		t.Errorf("Position mismatch: expected %d, got %d", entry.Position, deserialized.Position)
	}
	if deserialized.PriorityBucket != entry.PriorityBucket {
		t.Errorf("PriorityBucket mismatch: expected %s, got %s", entry.PriorityBucket, deserialized.PriorityBucket)
	}
}

func TestQueueEntry_Deserialization_InvalidJSON(t *testing.T) {
	invalidJSON := "{invalid json}"
	_, err := DeserializeQueueEntry(invalidJSON)
	if err == nil {
		t.Error("DeserializeQueueEntry() expected error for invalid JSON, got nil")
	}
}

func TestValidateQueueEntry_Valid(t *testing.T) {
	entry := &QueueEntry{
		QueueID:        "test-queue-id",
		EventID:        "test-event-id",
		DeviceID:       "test-device-id",
		UserID:         "test-user-id",
		Position:       5,
		EnqueuedAt:     time.Now(),
		LastHeartbeat:  time.Now(),
		PriorityBucket: "normal",
	}

	if err := ValidateQueueEntry(entry); err != nil {
		t.Errorf("ValidateQueueEntry() failed for valid entry: %v", err)
	}
}

func TestValidateQueueEntry_Invalid(t *testing.T) {
	tests := []struct {
		name    string
		entry   *QueueEntry
		wantErr string
	}{
		{
			name: "missing queue_id",
			entry: &QueueEntry{
				EventID:        "test-event-id",
				DeviceID:       "test-device-id",
				UserID:         "test-user-id",
				PriorityBucket: "normal",
			},
			wantErr: "queue_id is required",
		},
		{
			name: "missing event_id",
			entry: &QueueEntry{
				QueueID:        "test-queue-id",
				DeviceID:       "test-device-id",
				UserID:         "test-user-id",
				PriorityBucket: "normal",
			},
			wantErr: "event_id is required",
		},
		{
			name: "missing device_id",
			entry: &QueueEntry{
				QueueID:        "test-queue-id",
				EventID:        "test-event-id",
				UserID:         "test-user-id",
				PriorityBucket: "normal",
			},
			wantErr: "device_id is required",
		},
		{
			name: "missing user_id",
			entry: &QueueEntry{
				QueueID:        "test-queue-id",
				EventID:        "test-event-id",
				DeviceID:       "test-device-id",
				PriorityBucket: "normal",
			},
			wantErr: "user_id is required",
		},
		{
			name: "negative position",
			entry: &QueueEntry{
				QueueID:        "test-queue-id",
				EventID:        "test-event-id",
				DeviceID:       "test-device-id",
				UserID:         "test-user-id",
				Position:       -1,
				PriorityBucket: "normal",
			},
			wantErr: "position must be >= 0",
		},
		{
			name: "missing priority_bucket",
			entry: &QueueEntry{
				QueueID:  "test-queue-id",
				EventID:  "test-event-id",
				DeviceID: "test-device-id",
				UserID:   "test-user-id",
			},
			wantErr: "priority_bucket is required",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateQueueEntry(tt.entry)
			if err == nil {
				t.Errorf("ValidateQueueEntry() expected error containing '%s', got nil", tt.wantErr)
				return
			}
			if err.Error() != tt.wantErr {
				t.Errorf("ValidateQueueEntry() error = '%v', want '%s'", err, tt.wantErr)
			}
		})
	}
}

func TestValidateQueueStatus_Valid(t *testing.T) {
	status := &QueueStatus{
		QueueID:              "test-queue-id",
		Position:             5,
		EstimatedWaitSeconds: 120,
		Status:               "waiting",
		EnqueuedAt:           time.Now(),
		LastHeartbeat:        time.Now(),
	}

	if err := ValidateQueueStatus(status); err != nil {
		t.Errorf("ValidateQueueStatus() failed for valid status: %v", err)
	}
}

func TestValidateQueueStatus_Invalid(t *testing.T) {
	tests := []struct {
		name    string
		status  *QueueStatus
		wantErr string
	}{
		{
			name: "missing queue_id",
			status: &QueueStatus{
				Position:             5,
				EstimatedWaitSeconds: 120,
				Status:               "waiting",
			},
			wantErr: "queue_id is required",
		},
		{
			name: "negative position",
			status: &QueueStatus{
				QueueID:              "test-queue-id",
				Position:             -1,
				EstimatedWaitSeconds: 120,
				Status:               "waiting",
			},
			wantErr: "position must be >= 0",
		},
		{
			name: "negative estimated_wait_seconds",
			status: &QueueStatus{
				QueueID:              "test-queue-id",
				Position:             5,
				EstimatedWaitSeconds: -1,
				Status:               "waiting",
			},
			wantErr: "estimated_wait_seconds must be >= 0",
		},
		{
			name: "invalid status",
			status: &QueueStatus{
				QueueID:              "test-queue-id",
				Position:             5,
				EstimatedWaitSeconds: 120,
				Status:               "invalid-status",
			},
			wantErr: "invalid status",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateQueueStatus(tt.status)
			if err == nil {
				t.Errorf("ValidateQueueStatus() expected error containing '%s', got nil", tt.wantErr)
				return
			}
			if !strings.Contains(err.Error(), tt.wantErr) {
				t.Errorf("ValidateQueueStatus() error = '%v', want error containing '%s'", err, tt.wantErr)
			}
		})
	}
}

func TestValidateQueueStatus_ValidStatuses(t *testing.T) {
	validStatuses := []string{"waiting", "admitted", "expired"}

	for _, status := range validStatuses {
		t.Run(status, func(t *testing.T) {
			queueStatus := &QueueStatus{
				QueueID:              "test-queue-id",
				Position:             5,
				EstimatedWaitSeconds: 120,
				Status:               status,
			}

			if err := ValidateQueueStatus(queueStatus); err != nil {
				t.Errorf("ValidateQueueStatus() failed for valid status '%s': %v", status, err)
			}
		})
	}
}

func TestRedisKeyGeneration(t *testing.T) {
	tests := []struct {
		name     string
		keyFunc  func(string) string
		arg      string
		expected string
	}{
		{
			name:     "QueueEntryKey",
			keyFunc:  QueueEntryKey,
			arg:      "queue-123",
			expected: "queue:entry:queue-123",
		},
		{
			name:     "QueueListKey",
			keyFunc:  QueueListKey,
			arg:      "event-456",
			expected: "queue:list:event-456",
		},
		{
			name:     "QueueSortedSetKey",
			keyFunc:  QueueSortedSetKey,
			arg:      "event-456",
			expected: "queue:zset:event-456",
		},
		{
			name:     "QueueEventConfigKey",
			keyFunc:  QueueEventConfigKey,
			arg:      "event-456",
			expected: "queue:config:event-456",
		},
		{
			name:     "QueueAdmittedKey",
			keyFunc:  QueueAdmittedKey,
			arg:      "event-456",
			expected: "queue:admitted:event-456",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := tt.keyFunc(tt.arg)
			if result != tt.expected {
				t.Errorf("%s() = %s, want %s", tt.name, result, tt.expected)
			}
		})
	}
}

func TestRedisKeyGeneration_MultiArg(t *testing.T) {
	deviceID := "device-123"
	eventID := "event-456"

	rateLimitKey := QueueRateLimitKey(deviceID, eventID)
	expectedRateLimit := "queue:ratelimit:device-123:event-456"
	if rateLimitKey != expectedRateLimit {
		t.Errorf("QueueRateLimitKey() = %s, want %s", rateLimitKey, expectedRateLimit)
	}

	deviceEventKey := QueueDeviceEventKey(deviceID, eventID)
	expectedDeviceEvent := "queue:device:event:device-123:event-456"
	if deviceEventKey != expectedDeviceEvent {
		t.Errorf("QueueDeviceEventKey() = %s, want %s", deviceEventKey, expectedDeviceEvent)
	}
}
