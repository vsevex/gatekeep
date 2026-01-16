package queue

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// SendHeartbeat updates the heartbeat for a queue entry and extends TTL
func (m *Manager) SendHeartbeat(queueID string) (*QueueStatus, error) {
	if queueID == "" {
		return nil, fmt.Errorf("queue_id is required")
	}

	ctx, cancel := context.WithTimeout(m.ctx, 3*time.Second)
	defer cancel()

	// Retrieve queue entry
	entryKey := QueueEntryKey(queueID)
	entryData, err := m.redisClient.GetClient().Get(ctx, entryKey).Result()
	if err == redis.Nil {
		return nil, fmt.Errorf("queue entry not found: %s", queueID)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to retrieve queue entry: %w", err)
	}

	// Deserialize entry
	entry, err := DeserializeQueueEntry(entryData)
	if err != nil {
		return nil, fmt.Errorf("failed to deserialize queue entry: %w", err)
	}

	// Update heartbeat timestamp
	entry.LastHeartbeat = time.Now()

	// Check if user is admitted
	admittedKey := QueueAdmittedKey(entry.EventID)
	isAdmitted, err := m.redisClient.GetClient().SIsMember(ctx, admittedKey, queueID).Result()
	if err != nil {
		return nil, fmt.Errorf("failed to check admission status: %w", err)
	}

	if isAdmitted {
		// User is admitted, return status with token indicator
		return &QueueStatus{
			QueueID:              queueID,
			Position:             0,
			EstimatedWaitSeconds: 0,
			Status:               "admitted",
			EnqueuedAt:           entry.EnqueuedAt,
			LastHeartbeat:        entry.LastHeartbeat,
		}, nil
	}

	// Calculate current position
	position := m.calculatePosition(entry.EventID, queueID, entry.PriorityBucket)
	entry.Position = position

	// Serialize and update entry with extended TTL
	entryData, err = SerializeQueueEntry(entry)
	if err != nil {
		return nil, fmt.Errorf("failed to serialize entry: %w", err)
	}

	// Update entry with extended TTL
	if err := m.redisClient.GetClient().Set(ctx, entryKey, entryData, QueueEntryTTL).Err(); err != nil {
		return nil, fmt.Errorf("failed to update queue entry: %w", err)
	}

	// Calculate estimated wait time
	estimatedWait := m.calculateEstimatedWait(entry.EventID, position, entry.PriorityBucket)

	// Calculate total in queue
	totalInQueue, err := m.getQueueSize(entry.EventID, entry.PriorityBucket)
	if err != nil {
		// If we can't get queue size, continue without it
		totalInQueue = 0
	}
	totalInQueuePtr := &totalInQueue

	return &QueueStatus{
		QueueID:              queueID,
		Position:             position,
		EstimatedWaitSeconds: estimatedWait,
		Status:               "waiting",
		EnqueuedAt:           entry.EnqueuedAt,
		LastHeartbeat:        entry.LastHeartbeat,
		TotalInQueue:         totalInQueuePtr,
	}, nil
}

// CleanupAbandonedSessions removes queue entries that haven't sent a heartbeat
func (m *Manager) CleanupAbandonedSessions() error {
	// This is a simplified cleanup - in production, you'd want to scan all queue entries
	// For now, Redis TTL will handle most cleanup automatically
	// This function can be extended to actively scan and remove abandoned entries

	// Example: Clean up entries older than TTL
	// In a real implementation, you'd scan all queue:entry:* keys and check their TTL
	// or use a background job to periodically clean up

	return nil
}

// MarkAsAdmitted marks a queue entry as admitted and removes it from the queue
func (m *Manager) MarkAsAdmitted(queueID string) error {
	if queueID == "" {
		return fmt.Errorf("queue_id is required")
	}

	ctx, cancel := context.WithTimeout(m.ctx, 3*time.Second)
	defer cancel()

	// Get entry to find event ID
	entryKey := QueueEntryKey(queueID)
	entryData, err := m.redisClient.GetClient().Get(ctx, entryKey).Result()
	if err == redis.Nil {
		return fmt.Errorf("queue entry not found: %s", queueID)
	}
	if err != nil {
		return fmt.Errorf("failed to retrieve queue entry: %w", err)
	}

	entry, err := DeserializeQueueEntry(entryData)
	if err != nil {
		return fmt.Errorf("failed to deserialize queue entry: %w", err)
	}

	// Add to admitted set
	admittedKey := QueueAdmittedKey(entry.EventID)
	if err := m.redisClient.GetClient().SAdd(ctx, admittedKey, queueID).Err(); err != nil {
		return fmt.Errorf("failed to mark as admitted: %w", err)
	}

	// Remove from queue
	if entry.PriorityBucket == "high" {
		zsetKey := QueueSortedSetKey(entry.EventID)
		_ = m.redisClient.GetClient().ZRem(ctx, zsetKey, queueID).Err()
	} else {
		listKey := QueueListKey(entry.EventID)
		_ = m.redisClient.GetClient().LRem(ctx, listKey, 1, queueID).Err()
	}

	return nil
}
