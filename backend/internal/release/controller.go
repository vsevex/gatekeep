package release

import (
	"context"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/redis/go-redis/v9"

	redisclient "gatekeep/internal/redis"
	"gatekeep/internal/token"
)

// Controller manages the release of users from the queue
type Controller struct {
	redisClient *redisclient.Client
	tokenGen    *token.Generator
	ctx         context.Context
	cancel      context.CancelFunc
	wg          sync.WaitGroup
	mu          sync.RWMutex

	// Release state
	paused          bool
	releaseRate     int // users per second
	maxCapacity     int // maximum concurrent admissions
	currentCapacity int // current number of admitted users
}

// ReleaseState represents the state of the release controller
type ReleaseState struct {
	Paused          bool `json:"paused"`
	ReleaseRate     int  `json:"release_rate"`
	MaxCapacity     int  `json:"max_capacity"`
	CurrentCapacity int  `json:"current_capacity"`
}

// NewController creates a new release controller
func NewController(redisClient *redisclient.Client, tokenGen *token.Generator) *Controller {
	ctx, cancel := context.WithCancel(context.Background())
	return &Controller{
		redisClient:     redisClient,
		tokenGen:        tokenGen,
		ctx:             ctx,
		cancel:          cancel,
		paused:          false,
		releaseRate:     10, // Default: 10 users per second
		maxCapacity:     1000,
		currentCapacity: 0,
	}
}

// Start starts the release scheduler
func (c *Controller) Start() {
	c.wg.Add(1)
	go c.releaseScheduler()
}

// Stop stops the release scheduler
func (c *Controller) Stop() {
	c.cancel()
	c.wg.Wait()
}

// SetReleaseRate sets the release rate (users per second)
func (c *Controller) SetReleaseRate(rate int) error {
	if rate < 0 {
		return fmt.Errorf("release rate must be >= 0")
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.releaseRate = rate
	return nil
}

// SetMaxCapacity sets the maximum capacity
func (c *Controller) SetMaxCapacity(capacity int) error {
	if capacity < 0 {
		return fmt.Errorf("max capacity must be >= 0")
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.maxCapacity = capacity
	return nil
}

// Pause pauses the release process
func (c *Controller) Pause() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.paused = true
}

// Resume resumes the release process
func (c *Controller) Resume() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.paused = false
}

// GetState returns the current release state
func (c *Controller) GetState() ReleaseState {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return ReleaseState{
		Paused:          c.paused,
		ReleaseRate:     c.releaseRate,
		MaxCapacity:     c.maxCapacity,
		CurrentCapacity: c.currentCapacity,
	}
}

// ReleaseUsers releases users from the queue at the configured rate
func (c *Controller) ReleaseUsers(eventID string, count int) (int, error) {
	if count <= 0 {
		return 0, fmt.Errorf("count must be > 0")
	}

	c.mu.RLock()
	paused := c.paused
	releaseRate := c.releaseRate
	maxCapacity := c.maxCapacity
	currentCapacity := c.currentCapacity
	c.mu.RUnlock()

	if paused {
		return 0, fmt.Errorf("release is paused")
	}

	// Check capacity
	availableCapacity := maxCapacity - currentCapacity
	if availableCapacity <= 0 {
		return 0, fmt.Errorf("max capacity reached")
	}

	// Limit count to available capacity
	if count > availableCapacity {
		count = availableCapacity
	}

	// Limit count to release rate (per second)
	if count > releaseRate {
		count = releaseRate
	}

	released := 0
	ctx, cancel := context.WithTimeout(c.ctx, 5*time.Second)
	defer cancel()

	// Release users from queue
	for i := 0; i < count; i++ {
		// Try high priority first (sorted set)
		queueID, err := c.popFromPriorityQueue(ctx, eventID)
		if err == redis.Nil {
			// No high priority users, try normal queue
			queueID, err = c.popFromNormalQueue(ctx, eventID)
			if err == redis.Nil {
				// Queue is empty
				break
			}
			if err != nil {
				return released, fmt.Errorf("failed to pop from queue: %w", err)
			}
		} else if err != nil {
			return released, fmt.Errorf("failed to pop from priority queue: %w", err)
		}

		// Get queue entry
		entry, err := c.getQueueEntry(ctx, queueID)
		if err != nil {
			return released, fmt.Errorf("failed to get queue entry: %w", err)
		}

		// Generate admission token
		admissionToken, err := c.tokenGen.GenerateToken(entry.EventID, entry.DeviceID, entry.UserID, entry.QueueID)
		if err != nil {
			return released, fmt.Errorf("failed to generate token: %w", err)
		}

		// Mark as admitted
		if err := c.markAsAdmitted(ctx, eventID, queueID); err != nil {
			return released, fmt.Errorf("failed to mark as admitted: %w", err)
		}

		// Update capacity
		c.mu.Lock()
		c.currentCapacity++
		c.mu.Unlock()

		released++
		_ = admissionToken // Token is generated and stored, can be returned if needed
	}

	// Save state after release
	_ = c.SaveState()

	return released, nil
}

// popFromPriorityQueue pops a user from the priority queue (sorted set)
func (c *Controller) popFromPriorityQueue(ctx context.Context, eventID string) (string, error) {
	zsetKey := fmt.Sprintf("queue:zset:%s", eventID)
	result, err := c.redisClient.GetClient().ZPopMin(ctx, zsetKey, 1).Result()
	if err != nil {
		return "", err
	}
	if len(result) == 0 {
		return "", redis.Nil
	}
	return result[0].Member.(string), nil
}

// popFromNormalQueue pops a user from the normal queue (list)
func (c *Controller) popFromNormalQueue(ctx context.Context, eventID string) (string, error) {
	listKey := fmt.Sprintf("queue:list:%s", eventID)
	queueID, err := c.redisClient.GetClient().LPop(ctx, listKey).Result()
	if err != nil {
		return "", err
	}
	return queueID, nil
}

// getQueueEntry retrieves a queue entry from Redis
func (c *Controller) getQueueEntry(ctx context.Context, queueID string) (*QueueEntry, error) {
	entryKey := fmt.Sprintf("queue:entry:%s", queueID)
	data, err := c.redisClient.GetClient().Get(ctx, entryKey).Result()
	if err != nil {
		return nil, err
	}

	var entry QueueEntry
	if err := json.Unmarshal([]byte(data), &entry); err != nil {
		return nil, err
	}

	return &entry, nil
}

// markAsAdmitted marks a user as admitted
func (c *Controller) markAsAdmitted(ctx context.Context, eventID, queueID string) error {
	admittedKey := fmt.Sprintf("queue:admitted:%s", eventID)
	return c.redisClient.GetClient().SAdd(ctx, admittedKey, queueID).Err()
}

// releaseScheduler runs the release scheduler goroutine
func (c *Controller) releaseScheduler() {
	defer c.wg.Done()

	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-c.ctx.Done():
			return
		case <-ticker.C:
			c.mu.RLock()
			paused := c.paused
			releaseRate := c.releaseRate
			c.mu.RUnlock()

			if paused || releaseRate == 0 {
				continue
			}

			// Get all active events (simplified - in production, you'd track active events)
			// For now, we'll skip automatic release and require manual calls
			// This can be extended to scan for active events
		}
	}
}

// QueueEntry represents a queue entry (imported from queue package structure)
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
