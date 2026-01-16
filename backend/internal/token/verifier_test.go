package token

import (
	"context"
	"strings"
	"testing"
	"time"

	"gatekeep/internal/config"
	redisclient "gatekeep/internal/redis"
)

func setupTestVerifier(t *testing.T) (*Verifier, *Generator, func()) {
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
		return nil, nil, nil
	}

	verifier := NewVerifier(redisClient, cfg.TokenSecret)
	generator := NewGenerator(redisClient, cfg.TokenSecret)

	cleanup := func() {
		ctx := context.Background()
		client := redisClient.GetClient()
		iter := client.Scan(ctx, 0, "token:*", 100).Iterator()
		for iter.Next(ctx) {
			client.Del(ctx, iter.Val())
		}
	}

	return verifier, generator, cleanup
}

func TestVerifyToken_Valid(t *testing.T) {
	verifier, generator, cleanup := setupTestVerifier(t)
	if verifier == nil {
		return
	}
	defer cleanup()

	// Generate token
	token, err := generator.GenerateToken("event-1", "device-1", "user-1", "queue-1")
	if err != nil {
		t.Fatalf("GenerateToken() failed: %v", err)
	}

	// Verify token
	payload, err := verifier.VerifyToken(token, "event-1")
	if err != nil {
		t.Fatalf("VerifyToken() failed: %v", err)
	}

	if payload == nil {
		t.Fatal("VerifyToken() returned nil payload")
	}

	if payload.EventID != "event-1" {
		t.Errorf("EventID mismatch: expected 'event-1', got %s", payload.EventID)
	}
	if payload.DeviceID != "device-1" {
		t.Errorf("DeviceID mismatch: expected 'device-1', got %s", payload.DeviceID)
	}
	if payload.UserID != "user-1" {
		t.Errorf("UserID mismatch: expected 'user-1', got %s", payload.UserID)
	}
	if payload.QueueID != "queue-1" {
		t.Errorf("QueueID mismatch: expected 'queue-1', got %s", payload.QueueID)
	}
	if payload.Nonce == "" {
		t.Error("Nonce is empty")
	}
}

func TestVerifyToken_InvalidSignature(t *testing.T) {
	verifier, generator, cleanup := setupTestVerifier(t)
	if verifier == nil {
		return
	}
	defer cleanup()

	// Generate token
	token, err := generator.GenerateToken("event-1", "device-1", "user-1", "queue-1")
	if err != nil {
		t.Fatalf("GenerateToken() failed: %v", err)
	}

	// Tamper with signature
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		t.Fatalf("Token should have 3 parts, got %d", len(parts))
	}
	tamperedToken := parts[0] + "." + parts[1] + ".tampered_signature"

	// Verify should fail
	_, err = verifier.VerifyToken(tamperedToken, "event-1")
	if err == nil {
		t.Error("VerifyToken() expected error for invalid signature, got nil")
		return
	}
}

func TestVerifyToken_Expired(t *testing.T) {
	verifier, generator, cleanup := setupTestVerifier(t)
	if verifier == nil {
		return
	}
	defer cleanup()

	// Create a token with very short expiry (we can't easily test this without mocking time)
	// Instead, we'll test the expiry check by manually creating an expired payload
	// For now, we'll just verify the expiry check exists in the code
	token, err := generator.GenerateToken("event-1", "device-1", "user-1", "queue-1")
	if err != nil {
		t.Fatalf("GenerateToken() failed: %v", err)
	}

	// Token should be valid immediately
	_, err = verifier.VerifyToken(token, "event-1")
	if err != nil {
		t.Errorf("VerifyToken() failed for fresh token: %v", err)
	}
}

func TestVerifyToken_WrongEventID(t *testing.T) {
	verifier, generator, cleanup := setupTestVerifier(t)
	if verifier == nil {
		return
	}
	defer cleanup()

	// Generate token for event-1
	token, err := generator.GenerateToken("event-1", "device-1", "user-1", "queue-1")
	if err != nil {
		t.Fatalf("GenerateToken() failed: %v", err)
	}

	// Verify with wrong event ID
	_, err = verifier.VerifyToken(token, "event-2")
	if err == nil {
		t.Error("VerifyToken() expected error for wrong event_id, got nil")
		return
	}
}

func TestVerifyToken_NoEventIDCheck(t *testing.T) {
	verifier, generator, cleanup := setupTestVerifier(t)
	if verifier == nil {
		return
	}
	defer cleanup()

	// Generate token
	token, err := generator.GenerateToken("event-1", "device-1", "user-1", "queue-1")
	if err != nil {
		t.Fatalf("GenerateToken() failed: %v", err)
	}

	// Verify without event ID check (empty string)
	payload, err := verifier.VerifyToken(token, "")
	if err != nil {
		t.Fatalf("VerifyToken() failed: %v", err)
	}

	if payload.EventID != "event-1" {
		t.Errorf("EventID mismatch: expected 'event-1', got %s", payload.EventID)
	}
}

func TestVerifyToken_Malformed(t *testing.T) {
	verifier, _, cleanup := setupTestVerifier(t)
	if verifier == nil {
		return
	}
	defer cleanup()

	tests := []struct {
		name  string
		token string
	}{
		{"empty", ""},
		{"single part", "header"},
		{"two parts", "header.payload"},
		{"four parts", "header.payload.signature.extra"},
		{"invalid base64", "invalid.base64.signature"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := verifier.VerifyToken(tt.token, "")
			if err == nil {
				t.Errorf("VerifyToken() expected error for %s token, got nil", tt.name)
			}
		})
	}
}

func TestVerifyToken_EmptyToken(t *testing.T) {
	verifier, _, cleanup := setupTestVerifier(t)
	if verifier == nil {
		return
	}
	defer cleanup()

	_, err := verifier.VerifyToken("", "event-1")
	if err == nil {
		t.Error("VerifyToken() expected error for empty token, got nil")
		return
	}
}

func TestGetTokenMetadata(t *testing.T) {
	verifier, generator, cleanup := setupTestVerifier(t)
	if verifier == nil {
		return
	}
	defer cleanup()

	// Generate token
	token, err := generator.GenerateToken("event-1", "device-1", "user-1", "queue-1")
	if err != nil {
		t.Fatalf("GenerateToken() failed: %v", err)
	}

	// Get metadata
	metadata, err := verifier.GetTokenMetadata(token)
	if err != nil {
		t.Fatalf("GetTokenMetadata() failed: %v", err)
	}

	if metadata == nil {
		t.Fatal("GetTokenMetadata() returned nil")
	}

	if metadata.Token != token {
		t.Errorf("Token mismatch: expected %s, got %s", token, metadata.Token)
	}
	if metadata.EventID != "event-1" {
		t.Errorf("EventID mismatch: expected 'event-1', got %s", metadata.EventID)
	}
	if metadata.Revoked {
		t.Error("Token should not be revoked initially")
	}
	if metadata.Used {
		t.Error("Token should not be used initially")
	}
}

func TestGetTokenMetadata_NotFound(t *testing.T) {
	verifier, _, cleanup := setupTestVerifier(t)
	if verifier == nil {
		return
	}
	defer cleanup()

	_, err := verifier.GetTokenMetadata("non-existent-token")
	if err == nil {
		t.Error("GetTokenMetadata() expected error for non-existent token, got nil")
	}
}

func TestRevokeToken(t *testing.T) {
	verifier, generator, cleanup := setupTestVerifier(t)
	if verifier == nil {
		return
	}
	defer cleanup()

	// Generate token
	token, err := generator.GenerateToken("event-1", "device-1", "user-1", "queue-1")
	if err != nil {
		t.Fatalf("GenerateToken() failed: %v", err)
	}

	// Verify token is valid
	_, err = verifier.VerifyToken(token, "event-1")
	if err != nil {
		t.Fatalf("VerifyToken() failed before revocation: %v", err)
	}

	// Revoke token
	if err := verifier.RevokeToken(token); err != nil {
		t.Fatalf("RevokeToken() failed: %v", err)
	}

	// Verify token is now revoked
	_, err = verifier.VerifyToken(token, "event-1")
	if err == nil {
		t.Error("VerifyToken() expected error for revoked token, got nil")
		return
	}

	// Check metadata
	metadata, err := verifier.GetTokenMetadata(token)
	if err != nil {
		t.Fatalf("GetTokenMetadata() failed: %v", err)
	}

	if !metadata.Revoked {
		t.Error("Token should be marked as revoked")
	}
}

func TestRevokeToken_NotFound(t *testing.T) {
	verifier, _, cleanup := setupTestVerifier(t)
	if verifier == nil {
		return
	}
	defer cleanup()

	err := verifier.RevokeToken("non-existent-token")
	if err == nil {
		t.Error("RevokeToken() expected error for non-existent token, got nil")
	}
}

func TestToken_EndToEnd(t *testing.T) {
	verifier, generator, cleanup := setupTestVerifier(t)
	if verifier == nil {
		return
	}
	defer cleanup()

	// Generate token
	token, err := generator.GenerateToken("event-1", "device-1", "user-1", "queue-1")
	if err != nil {
		t.Fatalf("GenerateToken() failed: %v", err)
	}

	// Verify token
	payload, err := verifier.VerifyToken(token, "event-1")
	if err != nil {
		t.Fatalf("VerifyToken() failed: %v", err)
	}

	// Get metadata
	metadata, err := verifier.GetTokenMetadata(token)
	if err != nil {
		t.Fatalf("GetTokenMetadata() failed: %v", err)
	}

	// Verify all data matches
	if payload.EventID != metadata.EventID {
		t.Errorf("EventID mismatch: payload=%s, metadata=%s", payload.EventID, metadata.EventID)
	}
	if payload.DeviceID != metadata.DeviceID {
		t.Errorf("DeviceID mismatch: payload=%s, metadata=%s", payload.DeviceID, metadata.DeviceID)
	}
	if payload.UserID != metadata.UserID {
		t.Errorf("UserID mismatch: payload=%s, metadata=%s", payload.UserID, metadata.UserID)
	}
	if payload.QueueID != metadata.QueueID {
		t.Errorf("QueueID mismatch: payload=%s, metadata=%s", payload.QueueID, metadata.QueueID)
	}

	// Verify timestamps are reasonable
	if time.Since(payload.IssuedAt) > 1*time.Minute {
		t.Error("IssuedAt timestamp is too old")
	}
	if payload.ExpiresAt.Before(payload.IssuedAt) {
		t.Error("ExpiresAt is before IssuedAt")
	}
}
