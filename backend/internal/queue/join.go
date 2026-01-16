package queue

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

const (
	// RateLimitWindow is the time window for rate limiting (1 minute)
	RateLimitWindow = 1 * time.Minute
	// MaxJoinsPerWindow is the maximum number of joins allowed per window
	MaxJoinsPerWindow = 5
	// QueueEntryTTL is the TTL for queue entries (30 minutes)
	QueueEntryTTL = 30 * time.Minute
)

// JoinQueueRequest is defined in models.go for interface compatibility

// JoinQueue adds a user to the queue
func (m *Manager) JoinQueue(req JoinQueueRequest) (*QueueEntry, error) {
	// Validate request
	if req.EventID == "" {
		return nil, fmt.Errorf("event_id is required")
	}
	if req.DeviceID == "" {
		return nil, fmt.Errorf("device_id is required")
	}
	// Use device_id as user_id if user_id is not provided
	if req.UserID == "" {
		req.UserID = req.DeviceID
	}
	if req.PriorityBucket == "" {
		req.PriorityBucket = "normal"
	}

	// Check event configuration
	config, err := m.GetEventConfig(req.EventID)
	if err != nil {
		return nil, fmt.Errorf("failed to get event config: %w", err)
	}

	if !config.Enabled {
		return nil, fmt.Errorf("queue for event %s is disabled", req.EventID)
	}

	// Check rate limiting
	if err := m.checkRateLimit(req.DeviceID, req.EventID); err != nil {
		return nil, err
	}

	// Check for existing queue entry (idempotency)
	deviceEventKey := QueueDeviceEventKey(req.DeviceID, req.EventID)
	ctx, cancel := context.WithTimeout(m.ctx, 5*time.Second)
	defer cancel()

	existingQueueID, err := m.redisClient.GetClient().Get(ctx, deviceEventKey).Result()
	if err == nil && existingQueueID != "" {
		// Entry exists, return it
		entryKey := QueueEntryKey(existingQueueID)
		entryData, err := m.redisClient.GetClient().Get(ctx, entryKey).Result()
		if err == nil {
			entry, err := DeserializeQueueEntry(entryData)
			if err == nil {
				// Update position
				entry.Position = m.calculatePosition(req.EventID, existingQueueID, req.PriorityBucket)
				return entry, nil
			}
		}
		// If entry data is missing, continue to create new entry
	}

	// Check queue size
	queueSize, err := m.getQueueSize(req.EventID, req.PriorityBucket)
	if err != nil {
		return nil, fmt.Errorf("failed to get queue size: %w", err)
	}

	if queueSize >= config.MaxSize {
		return nil, fmt.Errorf("queue is full (max size: %d)", config.MaxSize)
	}

	// Generate queue_id
	queueID := uuid.New().String()

	// Create queue entry
	now := time.Now()
	entry := &QueueEntry{
		QueueID:        queueID,
		EventID:        req.EventID,
		DeviceID:       req.DeviceID,
		UserID:         req.UserID,
		Position:       0, // Will be calculated after adding to queue
		EnqueuedAt:     now,
		LastHeartbeat:  now,
		PriorityBucket: req.PriorityBucket,
	}

	// Serialize entry
	entryData, err := SerializeQueueEntry(entry)
	if err != nil {
		return nil, fmt.Errorf("failed to serialize entry: %w", err)
	}

	// Use Redis transaction to ensure atomicity
	pipe := m.redisClient.GetClient().Pipeline()

	// Store queue entry
	entryKey := QueueEntryKey(queueID)
	pipe.Set(ctx, entryKey, entryData, QueueEntryTTL)

	// Add to queue (LIST for FIFO, ZSET for priority)
	if req.PriorityBucket == "high" {
		// Use sorted set for priority queues
		zsetKey := QueueSortedSetKey(req.EventID)
		score := float64(now.Unix()) // Use timestamp as score for FIFO within priority
		pipe.ZAdd(ctx, zsetKey, redis.Z{
			Score:  score,
			Member: queueID,
		})
	} else {
		// Use list for normal/low priority
		listKey := QueueListKey(req.EventID)
		pipe.RPush(ctx, listKey, queueID)
	}

	// Store device+event mapping for idempotency
	pipe.Set(ctx, deviceEventKey, queueID, QueueEntryTTL)

	// Execute transaction
	_, err = pipe.Exec(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to execute Redis transaction: %w", err)
	}

	// Calculate position
	entry.Position = m.calculatePosition(req.EventID, queueID, req.PriorityBucket)

	// Update entry with position
	entry.Position = m.calculatePosition(req.EventID, queueID, req.PriorityBucket)
	entryData, _ = SerializeQueueEntry(entry)
	m.redisClient.GetClient().Set(ctx, entryKey, entryData, QueueEntryTTL)

	return entry, nil
}

// checkRateLimit checks if the device has exceeded rate limits
func (m *Manager) checkRateLimit(deviceID, eventID string) error {
	key := QueueRateLimitKey(deviceID, eventID)

	ctx, cancel := context.WithTimeout(m.ctx, 2*time.Second)
	defer cancel()

	// Get current count
	count, err := m.redisClient.GetClient().Get(ctx, key).Int()
	if err == redis.Nil {
		count = 0
	} else if err != nil {
		return fmt.Errorf("failed to check rate limit: %w", err)
	}

	if count >= MaxJoinsPerWindow {
		return fmt.Errorf("rate limit exceeded: maximum %d joins per %v", MaxJoinsPerWindow, RateLimitWindow)
	}

	// Increment counter
	pipe := m.redisClient.GetClient().Pipeline()
	pipe.Incr(ctx, key)
	pipe.Expire(ctx, key, RateLimitWindow)
	_, err = pipe.Exec(ctx)
	if err != nil {
		return fmt.Errorf("failed to update rate limit: %w", err)
	}

	return nil
}

// getQueueSize returns the current size of the queue for a given priority bucket
func (m *Manager) getQueueSize(eventID, priorityBucket string) (int, error) {
	ctx, cancel := context.WithTimeout(m.ctx, 2*time.Second)
	defer cancel()

	if priorityBucket == "high" {
		zsetKey := QueueSortedSetKey(eventID)
		count, err := m.redisClient.GetClient().ZCard(ctx, zsetKey).Result()
		return int(count), err
	}

	listKey := QueueListKey(eventID)
	count, err := m.redisClient.GetClient().LLen(ctx, listKey).Result()
	return int(count), err
}

// calculatePosition calculates the position of a queue entry
func (m *Manager) calculatePosition(eventID, queueID, priorityBucket string) int {
	ctx, cancel := context.WithTimeout(m.ctx, 2*time.Second)
	defer cancel()

	if priorityBucket == "high" {
		// For sorted set, get rank (0-based)
		zsetKey := QueueSortedSetKey(eventID)
		rank, err := m.redisClient.GetClient().ZRank(ctx, zsetKey, queueID).Result()
		if err != nil {
			return -1
		}
		return int(rank) + 1 // Convert to 1-based
	}

	// For list, find position
	listKey := QueueListKey(eventID)
	items, err := m.redisClient.GetClient().LRange(ctx, listKey, 0, -1).Result()
	if err != nil {
		return -1
	}

	for i, item := range items {
		if item == queueID {
			return i + 1 // Convert to 1-based
		}
	}

	return -1
}
