package queue

import (
	"encoding/json"
	"fmt"
	"time"
)

// QueueEntry represents a user's entry in the queue
type QueueEntry struct {
	QueueID        string    `json:"queue_id"`
	EventID        string    `json:"event_id"`
	DeviceID       string    `json:"device_id"`
	UserID         string    `json:"user_id"`
	Position       int       `json:"position"`
	EnqueuedAt     time.Time `json:"enqueued_at"`
	LastHeartbeat  time.Time `json:"last_heartbeat"`
	PriorityBucket string    `json:"priority_bucket"`
}

// QueueStatus represents the current status of a queue entry
type QueueStatus struct {
	QueueID              string    `json:"queue_id"`
	Position             int       `json:"position"`
	EstimatedWaitSeconds int       `json:"estimated_wait_seconds"`
	Status               string    `json:"status"` // "waiting", "admitted", "expired"
	EnqueuedAt           time.Time `json:"enqueued_at"`
	LastHeartbeat        time.Time `json:"last_heartbeat"`
	TotalInQueue         *int      `json:"total_in_queue,omitempty"` // Total users in queue
}

// QueueManager defines the interface for queue operations
type QueueManager interface {
	JoinQueue(req JoinQueueRequest) (*QueueEntry, error)
	GetQueueStatus(queueID string) (*QueueStatus, error)
	SendHeartbeat(queueID string) (*QueueStatus, error)
}

// JoinQueueRequest is defined in join.go but referenced here for the interface
// This forward declaration allows the interface to reference it
type JoinQueueRequest struct {
	EventID        string
	DeviceID       string
	UserID         string
	PriorityBucket string
}

// Redis key generation helpers

// QueueEntryKey returns the Redis key for a queue entry
func QueueEntryKey(queueID string) string {
	return fmt.Sprintf("queue:entry:%s", queueID)
}

// QueueListKey returns the Redis key for the queue list (for FIFO)
func QueueListKey(eventID string) string {
	return fmt.Sprintf("queue:list:%s", eventID)
}

// QueueSortedSetKey returns the Redis key for the priority queue (sorted set)
func QueueSortedSetKey(eventID string) string {
	return fmt.Sprintf("queue:zset:%s", eventID)
}

// QueueEventConfigKey returns the Redis key for event configuration
func QueueEventConfigKey(eventID string) string {
	return fmt.Sprintf("queue:config:%s", eventID)
}

// QueueAdmittedKey returns the Redis key for admitted users tracking
func QueueAdmittedKey(eventID string) string {
	return fmt.Sprintf("queue:admitted:%s", eventID)
}

// QueueRateLimitKey returns the Redis key for rate limiting
func QueueRateLimitKey(deviceID, eventID string) string {
	return fmt.Sprintf("queue:ratelimit:%s:%s", deviceID, eventID)
}

// QueueDeviceEventKey returns the Redis key for device+event lookup (for idempotency)
func QueueDeviceEventKey(deviceID, eventID string) string {
	return fmt.Sprintf("queue:device:event:%s:%s", deviceID, eventID)
}

// SerializeQueueEntry serializes a QueueEntry to JSON
func SerializeQueueEntry(entry *QueueEntry) (string, error) {
	data, err := json.Marshal(entry)
	if err != nil {
		return "", fmt.Errorf("failed to serialize queue entry: %w", err)
	}
	return string(data), nil
}

// DeserializeQueueEntry deserializes JSON to a QueueEntry
func DeserializeQueueEntry(data string) (*QueueEntry, error) {
	var entry QueueEntry
	if err := json.Unmarshal([]byte(data), &entry); err != nil {
		return nil, fmt.Errorf("failed to deserialize queue entry: %w", err)
	}
	return &entry, nil
}

// ValidateQueueEntry validates a QueueEntry
func ValidateQueueEntry(entry *QueueEntry) error {
	if entry.QueueID == "" {
		return fmt.Errorf("queue_id is required")
	}
	if entry.EventID == "" {
		return fmt.Errorf("event_id is required")
	}
	if entry.DeviceID == "" {
		return fmt.Errorf("device_id is required")
	}
	if entry.UserID == "" {
		return fmt.Errorf("user_id is required")
	}
	if entry.Position < 0 {
		return fmt.Errorf("position must be >= 0")
	}
	if entry.PriorityBucket == "" {
		return fmt.Errorf("priority_bucket is required")
	}
	return nil
}

// ValidateQueueStatus validates a QueueStatus
func ValidateQueueStatus(status *QueueStatus) error {
	if status.QueueID == "" {
		return fmt.Errorf("queue_id is required")
	}
	if status.Position < 0 {
		return fmt.Errorf("position must be >= 0")
	}
	if status.EstimatedWaitSeconds < 0 {
		return fmt.Errorf("estimated_wait_seconds must be >= 0")
	}
	validStatuses := map[string]bool{
		"waiting":  true,
		"admitted": true,
		"expired":  true,
	}
	if !validStatuses[status.Status] {
		return fmt.Errorf("invalid status: %s (must be one of: waiting, admitted, expired)", status.Status)
	}
	return nil
}
