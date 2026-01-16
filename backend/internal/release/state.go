package release

import (
	"context"
	"encoding/json"
	"fmt"
	"time"
)

const (
	// ReleaseStateKey is the Redis key for release state
	ReleaseStateKey = "release:state"
	// CapacityKey is the Redis key for capacity tracking
	CapacityKey = "release:capacity"
)

// SaveState saves the release state to Redis
func (c *Controller) SaveState() error {
	state := c.GetState()

	ctx, cancel := context.WithTimeout(c.ctx, 2*time.Second)
	defer cancel()

	stateJSON, err := json.Marshal(state)
	if err != nil {
		return fmt.Errorf("failed to marshal state: %w", err)
	}

	return c.redisClient.GetClient().Set(ctx, ReleaseStateKey, stateJSON, 0).Err()
}

// LoadState loads the release state from Redis
func (c *Controller) LoadState() error {
	ctx, cancel := context.WithTimeout(c.ctx, 2*time.Second)
	defer cancel()

	data, err := c.redisClient.GetClient().Get(ctx, ReleaseStateKey).Result()
	if err != nil {
		// State doesn't exist, use defaults
		return nil
	}

	var state ReleaseState
	if err := json.Unmarshal([]byte(data), &state); err != nil {
		return fmt.Errorf("failed to unmarshal state: %w", err)
	}

	c.mu.Lock()
	defer c.mu.Unlock()
	c.paused = state.Paused
	c.releaseRate = state.ReleaseRate
	c.maxCapacity = state.MaxCapacity
	c.currentCapacity = state.CurrentCapacity

	return nil
}

// DecrementCapacity decrements the current capacity (when user leaves)
func (c *Controller) DecrementCapacity() {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.currentCapacity > 0 {
		c.currentCapacity--
	}
}

// GetCapacity returns the current capacity
func (c *Controller) GetCapacity() int {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.currentCapacity
}
