package redis

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"

	"gatekeep/internal/config"
)

// Client wraps the Redis client with additional functionality
type Client struct {
	rdb    *redis.Client
	config *config.Config
}

// NewClient creates a new Redis client with the provided configuration
func NewClient(cfg *config.Config) (*Client, error) {
	rdb := redis.NewClient(&redis.Options{
		Addr:            cfg.RedisAddr,
		Password:        cfg.RedisPassword,
		DB:              0, // Default DB
		DialTimeout:     5 * time.Second,
		ReadTimeout:     3 * time.Second,
		WriteTimeout:    3 * time.Second,
		PoolSize:        10, // Connection pool size
		MinIdleConns:    5,  // Minimum idle connections
		MaxIdleConns:    10, // Maximum idle connections
		PoolTimeout:     4 * time.Second,
		ConnMaxIdleTime: 5 * time.Minute,
		MaxRetries:      3,
	})

	client := &Client{
		rdb:    rdb,
		config: cfg,
	}

	// Test connection with retry logic
	if err := client.connectWithRetry(context.Background(), 3, 1*time.Second); err != nil {
		return nil, fmt.Errorf("failed to connect to Redis: %w", err)
	}

	return client, nil
}

// connectWithRetry attempts to connect to Redis with retry logic
func (c *Client) connectWithRetry(ctx context.Context, maxRetries int, retryDelay time.Duration) error {
	var lastErr error
	for i := 0; i < maxRetries; i++ {
		if i > 0 {
			time.Sleep(retryDelay)
			retryDelay *= 2 // Exponential backoff
		}

		// Create a context with timeout for the ping
		pingCtx, cancel := context.WithTimeout(ctx, 3*time.Second)
		err := c.rdb.Ping(pingCtx).Err()
		cancel()

		if err == nil {
			return nil
		}
		lastErr = err
	}

	return fmt.Errorf("connection failed after %d retries: %w", maxRetries, lastErr)
}

// HealthCheck verifies that the Redis connection is healthy
func (c *Client) HealthCheck(ctx context.Context) error {
	// Create a context with timeout
	healthCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	if err := c.rdb.Ping(healthCtx).Err(); err != nil {
		return fmt.Errorf("Redis health check failed: %w", err)
	}

	return nil
}

// GetClient returns the underlying Redis client
func (c *Client) GetClient() *redis.Client {
	return c.rdb
}

// Close closes the Redis connection
func (c *Client) Close() error {
	return c.rdb.Close()
}

// Stats returns connection pool statistics
func (c *Client) Stats() *redis.PoolStats {
	return c.rdb.PoolStats()
}
