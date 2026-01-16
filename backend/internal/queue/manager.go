package queue

import (
	"context"
	"encoding/json"
	"time"

	"github.com/redis/go-redis/v9"

	redisclient "gatekeep/internal/redis"
)

// Manager implements QueueManager interface
type Manager struct {
	redisClient *redisclient.Client
	ctx         context.Context
}

// NewManager creates a new queue manager
func NewManager(redisClient *redisclient.Client) *Manager {
	return &Manager{
		redisClient: redisClient,
		ctx:         context.Background(),
	}
}

// EventConfig represents the configuration for an event queue
type EventConfig struct {
	EventID     string `json:"event_id"`
	Enabled     bool   `json:"enabled"`
	MaxSize     int    `json:"max_size"`
	ReleaseRate int    `json:"release_rate"` // users per second
}

// GetEventConfig retrieves event configuration from Redis
func (m *Manager) GetEventConfig(eventID string) (*EventConfig, error) {
	key := QueueEventConfigKey(eventID)

	ctx, cancel := context.WithTimeout(m.ctx, 2*time.Second)
	defer cancel()

	data, err := m.redisClient.GetClient().Get(ctx, key).Result()
	if err == redis.Nil {
		// Default configuration if not set
		return &EventConfig{
			EventID:     eventID,
			Enabled:     true,
			MaxSize:     10000,
			ReleaseRate: 10,
		}, nil
	}
	if err != nil {
		return nil, err
	}

	// Parse JSON configuration
	config := &EventConfig{}
	if err := json.Unmarshal([]byte(data), config); err != nil {
		return nil, err
	}

	return config, nil
}

// SetEventConfig sets event configuration in Redis
func (m *Manager) SetEventConfig(config *EventConfig) error {
	key := QueueEventConfigKey(config.EventID)

	ctx, cancel := context.WithTimeout(m.ctx, 2*time.Second)
	defer cancel()

	data, err := json.Marshal(config)
	if err != nil {
		return err
	}

	return m.redisClient.GetClient().Set(ctx, key, data, 0).Err()
}
