package redis

import (
	"context"
	"testing"
	"time"

	"gatekeep/internal/config"
)

func TestNewClient_SuccessfulConnection(t *testing.T) {
	// This test requires a running Redis instance
	// Skip if Redis is not available
	cfg := &config.Config{
		Port:          8080,
		RedisAddr:     "localhost:6379",
		RedisPassword: "",
		TokenSecret:   "this-is-a-very-long-secret-key-that-is-at-least-32-characters",
		AdminAPIKey:   "admin-key",
		LogLevel:      "info",
		MetricsPort:   9090,
	}

	client, err := NewClient(cfg)
	if err != nil {
		t.Skipf("Skipping test: Redis not available: %v", err)
		return
	}
	defer client.Close()

	// Verify connection is working
	ctx := context.Background()
	if err := client.HealthCheck(ctx); err != nil {
		t.Errorf("HealthCheck() failed: %v", err)
	}
}

func TestNewClient_ConnectionFailure(t *testing.T) {
	cfg := &config.Config{
		Port:          8080,
		RedisAddr:     "localhost:9999", // Invalid port
		RedisPassword: "",
		TokenSecret:   "this-is-a-very-long-secret-key-that-is-at-least-32-characters",
		AdminAPIKey:   "admin-key",
		LogLevel:      "info",
		MetricsPort:   9090,
	}

	client, err := NewClient(cfg)
	if err == nil {
		if client != nil {
			client.Close()
		}
		t.Error("NewClient() expected error for invalid address, got nil")
		return
	}

	if client != nil {
		t.Error("NewClient() should return nil client on error")
	}
}

func TestNewClient_ConnectionRetry(t *testing.T) {
	// Test with invalid address - should retry and fail
	cfg := &config.Config{
		Port:          8080,
		RedisAddr:     "invalid-host:6379",
		RedisPassword: "",
		TokenSecret:   "this-is-a-very-long-secret-key-that-is-at-least-32-characters",
		AdminAPIKey:   "admin-key",
		LogLevel:      "info",
		MetricsPort:   9090,
	}

	start := time.Now()
	client, err := NewClient(cfg)
	duration := time.Since(start)

	if err == nil {
		if client != nil {
			client.Close()
		}
		t.Error("NewClient() expected error, got nil")
		return
	}

	// Verify retry logic was attempted (should take some time due to retries)
	if duration < 1*time.Second {
		t.Errorf("Expected retry logic to take at least 1 second, took %v", duration)
	}
}

func TestHealthCheck_Success(t *testing.T) {
	cfg := &config.Config{
		Port:          8080,
		RedisAddr:     "localhost:6379",
		RedisPassword: "",
		TokenSecret:   "this-is-a-very-long-secret-key-that-is-at-least-32-characters",
		AdminAPIKey:   "admin-key",
		LogLevel:      "info",
		MetricsPort:   9090,
	}

	client, err := NewClient(cfg)
	if err != nil {
		t.Skipf("Skipping test: Redis not available: %v", err)
		return
	}
	defer client.Close()

	ctx := context.Background()
	if err := client.HealthCheck(ctx); err != nil {
		t.Errorf("HealthCheck() failed: %v", err)
	}
}

func TestHealthCheck_ContextTimeout(t *testing.T) {
	cfg := &config.Config{
		Port:          8080,
		RedisAddr:     "localhost:6379",
		RedisPassword: "",
		TokenSecret:   "this-is-a-very-long-secret-key-that-is-at-least-32-characters",
		AdminAPIKey:   "admin-key",
		LogLevel:      "info",
		MetricsPort:   9090,
	}

	client, err := NewClient(cfg)
	if err != nil {
		t.Skipf("Skipping test: Redis not available: %v", err)
		return
	}
	defer client.Close()

	// Create a context that's already cancelled
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	// Health check should respect context cancellation
	err = client.HealthCheck(ctx)
	if err == nil {
		t.Error("HealthCheck() expected error with cancelled context, got nil")
	}
}

func TestHealthCheck_Timeout(t *testing.T) {
	cfg := &config.Config{
		Port:          8080,
		RedisAddr:     "localhost:6379",
		RedisPassword: "",
		TokenSecret:   "this-is-a-very-long-secret-key-that-is-at-least-32-characters",
		AdminAPIKey:   "admin-key",
		LogLevel:      "info",
		MetricsPort:   9090,
	}

	client, err := NewClient(cfg)
	if err != nil {
		t.Skipf("Skipping test: Redis not available: %v", err)
		return
	}
	defer client.Close()

	// Create a context with very short timeout
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Nanosecond)
	defer cancel()

	// Wait a bit to ensure timeout
	time.Sleep(10 * time.Millisecond)

	err = client.HealthCheck(ctx)
	if err == nil {
		t.Error("HealthCheck() expected timeout error, got nil")
	}
}

func TestGetClient(t *testing.T) {
	cfg := &config.Config{
		Port:          8080,
		RedisAddr:     "localhost:6379",
		RedisPassword: "",
		TokenSecret:   "this-is-a-very-long-secret-key-that-is-at-least-32-characters",
		AdminAPIKey:   "admin-key",
		LogLevel:      "info",
		MetricsPort:   9090,
	}

	client, err := NewClient(cfg)
	if err != nil {
		t.Skipf("Skipping test: Redis not available: %v", err)
		return
	}
	defer client.Close()

	rdb := client.GetClient()
	if rdb == nil {
		t.Error("GetClient() returned nil")
	}
}

func TestClose(t *testing.T) {
	cfg := &config.Config{
		Port:          8080,
		RedisAddr:     "localhost:6379",
		RedisPassword: "",
		TokenSecret:   "this-is-a-very-long-secret-key-that-is-at-least-32-characters",
		AdminAPIKey:   "admin-key",
		LogLevel:      "info",
		MetricsPort:   9090,
	}

	client, err := NewClient(cfg)
	if err != nil {
		t.Skipf("Skipping test: Redis not available: %v", err)
		return
	}

	if err := client.Close(); err != nil {
		t.Errorf("Close() failed: %v", err)
	}

	// Verify connection is closed by attempting health check
	ctx := context.Background()
	err = client.HealthCheck(ctx)
	if err == nil {
		t.Error("HealthCheck() expected error after Close(), got nil")
	}
}

func TestStats(t *testing.T) {
	cfg := &config.Config{
		Port:          8080,
		RedisAddr:     "localhost:6379",
		RedisPassword: "",
		TokenSecret:   "this-is-a-very-long-secret-key-that-is-at-least-32-characters",
		AdminAPIKey:   "admin-key",
		LogLevel:      "info",
		MetricsPort:   9090,
	}

	client, err := NewClient(cfg)
	if err != nil {
		t.Skipf("Skipping test: Redis not available: %v", err)
		return
	}
	defer client.Close()

	stats := client.Stats()
	if stats == nil {
		t.Error("Stats() returned nil")
		return
	}

	// Verify stats structure exists (values are uint32, so always >= 0)
	_ = stats.Hits
	_ = stats.Misses
	_ = stats.Timeouts
	_ = stats.TotalConns
	_ = stats.IdleConns
	_ = stats.StaleConns
}
