package queue

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// GetQueueStatus retrieves the current status of a queue entry
func (m *Manager) GetQueueStatus(queueID string) (*QueueStatus, error) {
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

	// Check if entry is expired (no heartbeat for too long)
	if time.Since(entry.LastHeartbeat) > QueueEntryTTL {
		return &QueueStatus{
			QueueID:              queueID,
			Position:             0,
			EstimatedWaitSeconds: 0,
			Status:               "expired",
			EnqueuedAt:           entry.EnqueuedAt,
			LastHeartbeat:        entry.LastHeartbeat,
		}, nil
	}

	// Check if user is already admitted
	admittedKey := QueueAdmittedKey(entry.EventID)
	isAdmitted, err := m.redisClient.GetClient().SIsMember(ctx, admittedKey, queueID).Result()
	if err != nil {
		return nil, fmt.Errorf("failed to check admission status: %w", err)
	}

	if isAdmitted {
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
	if position < 0 {
		// Entry not found in queue, might have been removed
		return &QueueStatus{
			QueueID:              queueID,
			Position:             0,
			EstimatedWaitSeconds: 0,
			Status:               "expired",
			EnqueuedAt:           entry.EnqueuedAt,
			LastHeartbeat:        entry.LastHeartbeat,
		}, nil
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

	// Update entry position
	entry.Position = position
	entryData, _ = SerializeQueueEntry(entry)
	m.redisClient.GetClient().Set(ctx, entryKey, entryData, QueueEntryTTL)

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

// calculateEstimatedWait calculates the estimated wait time in seconds
func (m *Manager) calculateEstimatedWait(eventID string, position int, priorityBucket string) int {
	// Get event configuration for release rate
	config, err := m.GetEventConfig(eventID)
	if err != nil {
		// Default release rate if config unavailable
		config = &EventConfig{
			ReleaseRate: 10,
		}
	}

	// Calculate based on position and release rate
	// If release rate is 10 users/second, position 50 means ~5 seconds wait
	if config.ReleaseRate <= 0 {
		return 0
	}

	estimatedSeconds := position / config.ReleaseRate
	if estimatedSeconds < 0 {
		return 0
	}

	// Add some buffer for high priority queues
	if priorityBucket == "high" {
		estimatedSeconds = estimatedSeconds / 2 // High priority moves faster
	}

	return estimatedSeconds
}
