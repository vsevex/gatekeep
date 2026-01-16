package token

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"

	redisclient "gatekeep/internal/redis"
)

// Verifier handles token verification
type Verifier struct {
	redisClient *redisclient.Client
	secret      []byte
	ctx         context.Context
}

// NewVerifier creates a new token verifier
func NewVerifier(redisClient *redisclient.Client, secret string) *Verifier {
	return &Verifier{
		redisClient: redisClient,
		secret:      []byte(secret),
		ctx:         context.Background(),
	}
}

// VerifyToken verifies a token and returns the payload
func (v *Verifier) VerifyToken(token string, expectedEventID string) (*TokenPayload, error) {
	if token == "" {
		return nil, fmt.Errorf("token is required")
	}

	// Split token into parts
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return nil, fmt.Errorf("invalid token format: expected 3 parts, got %d", len(parts))
	}

	headerEncoded := parts[0]
	payloadEncoded := parts[1]
	signatureEncoded := parts[2]

	// Verify signature
	signatureInput := headerEncoded + "." + payloadEncoded
	expectedSignature := v.createSignature(signatureInput)
	expectedSignatureEncoded := base64.RawURLEncoding.EncodeToString(expectedSignature)

	if signatureEncoded != expectedSignatureEncoded {
		return nil, fmt.Errorf("invalid token signature")
	}

	// Decode payload
	payloadJSON, err := base64.RawURLEncoding.DecodeString(payloadEncoded)
	if err != nil {
		return nil, fmt.Errorf("failed to decode payload: %w", err)
	}

	var payload TokenPayload
	if err := json.Unmarshal(payloadJSON, &payload); err != nil {
		return nil, fmt.Errorf("failed to unmarshal payload: %w", err)
	}

	// Check expiry
	if time.Now().After(payload.ExpiresAt) {
		return nil, fmt.Errorf("token has expired")
	}

	// Validate event_id if provided
	if expectedEventID != "" && payload.EventID != expectedEventID {
		return nil, fmt.Errorf("token event_id mismatch: expected %s, got %s", expectedEventID, payload.EventID)
	}

	// Optional: Check Redis for revocation or single-use
	if err := v.checkTokenMetadata(token); err != nil {
		return nil, err
	}

	return &payload, nil
}

// createSignature creates an HMAC-SHA256 signature
func (v *Verifier) createSignature(input string) []byte {
	h := hmac.New(sha256.New, v.secret)
	h.Write([]byte(input))
	return h.Sum(nil)
}

// checkTokenMetadata checks token metadata in Redis
func (v *Verifier) checkTokenMetadata(token string) error {
	key := TokenKey(token)
	ctx, cancel := context.WithTimeout(v.ctx, 2*time.Second)
	defer cancel()

	data, err := v.redisClient.GetClient().Get(ctx, key).Result()
	if err == redis.Nil {
		// Token not found in Redis - might be expired or invalid
		// We still allow verification if signature is valid
		return nil
	}
	if err != nil {
		return fmt.Errorf("failed to check token metadata: %w", err)
	}

	var metadata TokenMetadata
	if err := json.Unmarshal([]byte(data), &metadata); err != nil {
		return fmt.Errorf("failed to unmarshal metadata: %w", err)
	}

	if metadata.Revoked {
		return fmt.Errorf("token has been revoked")
	}

	return nil
}

// GetTokenMetadata retrieves token metadata from Redis
func (v *Verifier) GetTokenMetadata(token string) (*TokenMetadata, error) {
	key := TokenKey(token)
	ctx, cancel := context.WithTimeout(v.ctx, 2*time.Second)
	defer cancel()

	data, err := v.redisClient.GetClient().Get(ctx, key).Result()
	if err == redis.Nil {
		return nil, fmt.Errorf("token metadata not found")
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get token metadata: %w", err)
	}

	var metadata TokenMetadata
	if err := json.Unmarshal([]byte(data), &metadata); err != nil {
		return nil, fmt.Errorf("failed to unmarshal metadata: %w", err)
	}

	return &metadata, nil
}

// RevokeToken revokes a token (admin operation)
func (v *Verifier) RevokeToken(token string) error {
	key := TokenKey(token)
	ctx, cancel := context.WithTimeout(v.ctx, 2*time.Second)
	defer cancel()

	data, err := v.redisClient.GetClient().Get(ctx, key).Result()
	if err == redis.Nil {
		return fmt.Errorf("token not found")
	}
	if err != nil {
		return fmt.Errorf("failed to get token metadata: %w", err)
	}

	var metadata TokenMetadata
	if err := json.Unmarshal([]byte(data), &metadata); err != nil {
		return fmt.Errorf("failed to unmarshal metadata: %w", err)
	}

	metadata.Revoked = true
	metadataJSON, err := json.Marshal(metadata)
	if err != nil {
		return fmt.Errorf("failed to marshal metadata: %w", err)
	}

	// Update with same TTL
	ttl := v.redisClient.GetClient().TTL(ctx, key).Val()
	return v.redisClient.GetClient().Set(ctx, key, metadataJSON, ttl).Err()
}
