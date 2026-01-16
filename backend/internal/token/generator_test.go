package token

import (
	"context"
	"strings"
	"testing"
	"time"

	"gatekeep/internal/config"
	redisclient "gatekeep/internal/redis"
)

func setupTestGenerator(t *testing.T) (*Generator, func()) {
	cfg := &config.Config{
		Port:          8080,
		RedisAddr:     "localhost:6379",
		RedisPassword: "",
		TokenSecret:   "this-is-a-very-long-secret-key-that-is-at-least-32-characters",
		AdminAPIKey:   "admin-key",
		LogLevel:      "info",
		MetricsPort:   9090,
	}

	redisClient, err := redisclient.NewClient(cfg)
	if err != nil {
		t.Skipf("Skipping test: Redis not available: %v", err)
		return nil, nil
	}

	generator := NewGenerator(redisClient, cfg.TokenSecret)

	cleanup := func() {
		ctx := context.Background()
		client := redisClient.GetClient()
		iter := client.Scan(ctx, 0, "token:*", 100).Iterator()
		for iter.Next(ctx) {
			client.Del(ctx, iter.Val())
		}
	}

	return generator, cleanup
}

func TestGenerateToken_Success(t *testing.T) {
	generator, cleanup := setupTestGenerator(t)
	if generator == nil {
		return
	}
	defer cleanup()

	token, err := generator.GenerateToken("event-1", "device-1", "user-1", "queue-1")
	if err != nil {
		t.Fatalf("GenerateToken() failed: %v", err)
	}

	if token == "" {
		t.Error("GenerateToken() returned empty token")
	}

	// Verify token format (header.payload.signature)
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		t.Errorf("Token format invalid: expected 3 parts, got %d", len(parts))
	}
}

func TestGenerateToken_Format(t *testing.T) {
	generator, cleanup := setupTestGenerator(t)
	if generator == nil {
		return
	}
	defer cleanup()

	token, err := generator.GenerateToken("event-1", "device-1", "user-1", "queue-1")
	if err != nil {
		t.Fatalf("GenerateToken() failed: %v", err)
	}

	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		t.Fatalf("Token should have 3 parts, got %d", len(parts))
	}

	// Verify each part is base64url encoded (no padding, URL-safe)
	for i, part := range parts {
		if part == "" {
			t.Errorf("Part %d is empty", i)
		}
		// Base64URL should not contain +, /, or = characters
		if strings.Contains(part, "+") || strings.Contains(part, "/") || strings.Contains(part, "=") {
			t.Errorf("Part %d contains invalid base64url characters", i)
		}
	}
}

func TestGenerateToken_NonceUniqueness(t *testing.T) {
	generator, cleanup := setupTestGenerator(t)
	if generator == nil {
		return
	}
	defer cleanup()

	tokens := make(map[string]bool, 10)
	for i := 0; i < 10; i++ {
		token, err := generator.GenerateToken("event-1", "device-1", "user-1", "queue-1")
		if err != nil {
			t.Fatalf("GenerateToken() #%d failed: %v", i+1, err)
		}
		if tokens[token] {
			t.Errorf("Duplicate token generated at iteration %d", i+1)
		}
		tokens[token] = true
	}
}

func TestGenerateToken_StoredInRedis(t *testing.T) {
	generator, cleanup := setupTestGenerator(t)
	if generator == nil {
		return
	}
	defer cleanup()

	token, err := generator.GenerateToken("event-1", "device-1", "user-1", "queue-1")
	if err != nil {
		t.Fatalf("GenerateToken() failed: %v", err)
	}

	// Verify token is stored in Redis
	key := TokenKey(token)
	ctx := context.Background()
	data, err := generator.redisClient.GetClient().Get(ctx, key).Result()
	if err != nil {
		t.Fatalf("Token not found in Redis: %v", err)
	}

	if data == "" {
		t.Error("Token metadata is empty in Redis")
	}
}

func TestGenerateToken_TTL(t *testing.T) {
	generator, cleanup := setupTestGenerator(t)
	if generator == nil {
		return
	}
	defer cleanup()

	token, err := generator.GenerateToken("event-1", "device-1", "user-1", "queue-1")
	if err != nil {
		t.Fatalf("GenerateToken() failed: %v", err)
	}

	// Check TTL
	key := TokenKey(token)
	ctx := context.Background()
	ttl, err := generator.redisClient.GetClient().TTL(ctx, key).Result()
	if err != nil {
		t.Fatalf("Failed to get TTL: %v", err)
	}

	// TTL should be approximately DefaultTokenTTL (1 hour)
	expectedTTL := DefaultTokenTTL
	tolerance := 5 * time.Minute // Allow some tolerance

	if ttl < expectedTTL-tolerance || ttl > expectedTTL+tolerance {
		t.Errorf("TTL mismatch: expected ~%v, got %v", expectedTTL, ttl)
	}
}

func TestGenerateToken_Concurrent(t *testing.T) {
	generator, cleanup := setupTestGenerator(t)
	if generator == nil {
		return
	}
	defer cleanup()

	// Generate tokens concurrently
	done := make(chan bool, 10)
	tokens := make([]string, 10)

	for i := 0; i < 10; i++ {
		go func(idx int) {
			token, err := generator.GenerateToken("event-1", "device-1", "user-1", "queue-1")
			if err == nil {
				tokens[idx] = token
			}
			done <- (err == nil)
		}(i)
	}

	// Wait for all to complete
	successCount := 0
	for i := 0; i < 10; i++ {
		if <-done {
			successCount++
		}
	}

	if successCount != 10 {
		t.Errorf("Expected all 10 concurrent token generations to succeed, got %d successes", successCount)
	}

	// Verify all tokens are unique
	tokenSet := make(map[string]bool)
	for _, token := range tokens {
		if token != "" {
			if tokenSet[token] {
				t.Error("Duplicate token generated in concurrent test")
			}
			tokenSet[token] = true
		}
	}
}

func TestGenerateToken_DifferentInputs(t *testing.T) {
	generator, cleanup := setupTestGenerator(t)
	if generator == nil {
		return
	}
	defer cleanup()

	testCases := []struct {
		name     string
		eventID  string
		deviceID string
		userID   string
		queueID  string
	}{
		{"all different", "event-1", "device-1", "user-1", "queue-1"},
		{"same event", "event-1", "device-2", "user-2", "queue-2"},
		{"same device", "event-2", "device-1", "user-3", "queue-3"},
		{"same user", "event-3", "device-3", "user-1", "queue-4"},
	}

	tokens := make(map[string]bool)
	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			token, err := generator.GenerateToken(tc.eventID, tc.deviceID, tc.userID, tc.queueID)
			if err != nil {
				t.Fatalf("GenerateToken() failed: %v", err)
			}
			if tokens[token] {
				t.Error("Duplicate token generated")
			}
			tokens[token] = true
		})
	}
}
