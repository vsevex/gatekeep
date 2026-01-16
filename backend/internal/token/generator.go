package token

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"

	redisclient "gatekeep/internal/redis"
)

const (
	// DefaultTokenTTL is the default TTL for tokens (1 hour)
	DefaultTokenTTL = 1 * time.Hour
	// TokenHeaderAlgorithm is the algorithm used for signing
	TokenHeaderAlgorithm = "HS256"
	// TokenType is the token type
	TokenType = "JWT"
)

// Generator handles token generation
type Generator struct {
	redisClient *redisclient.Client
	secret      []byte
	ctx         context.Context
}

// NewGenerator creates a new token generator
func NewGenerator(redisClient *redisclient.Client, secret string) *Generator {
	return &Generator{
		redisClient: redisClient,
		secret:      []byte(secret),
		ctx:         context.Background(),
	}
}

// GenerateToken generates a new admission token
func (g *Generator) GenerateToken(eventID, deviceID, userID, queueID string) (string, error) {
	now := time.Now()
	expiresAt := now.Add(DefaultTokenTTL)

	// Generate nonce
	nonce := uuid.New().String()

	// Create payload
	payload := TokenPayload{
		EventID:   eventID,
		DeviceID:  deviceID,
		UserID:    userID,
		QueueID:   queueID,
		IssuedAt:  now,
		ExpiresAt: expiresAt,
		Nonce:     nonce,
	}

	// Create header
	header := TokenHeader{
		Algorithm: TokenHeaderAlgorithm,
		Type:      TokenType,
	}

	// Encode header
	headerJSON, err := json.Marshal(header)
	if err != nil {
		return "", fmt.Errorf("failed to marshal header: %w", err)
	}
	headerEncoded := base64.RawURLEncoding.EncodeToString(headerJSON)

	// Encode payload
	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return "", fmt.Errorf("failed to marshal payload: %w", err)
	}
	payloadEncoded := base64.RawURLEncoding.EncodeToString(payloadJSON)

	// Create signature
	signatureInput := headerEncoded + "." + payloadEncoded
	signature := g.createSignature(signatureInput)
	signatureEncoded := base64.RawURLEncoding.EncodeToString(signature)

	// Combine into token
	token := signatureInput + "." + signatureEncoded

	// Store token metadata in Redis
	if err := g.storeTokenMetadata(token, payload); err != nil {
		return "", fmt.Errorf("failed to store token metadata: %w", err)
	}

	return token, nil
}

// createSignature creates an HMAC-SHA256 signature
func (g *Generator) createSignature(input string) []byte {
	h := hmac.New(sha256.New, g.secret)
	h.Write([]byte(input))
	return h.Sum(nil)
}

// storeTokenMetadata stores token metadata in Redis with TTL
func (g *Generator) storeTokenMetadata(token string, payload TokenPayload) error {
	metadata := TokenMetadata{
		Token:     token,
		EventID:   payload.EventID,
		DeviceID:  payload.DeviceID,
		UserID:    payload.UserID,
		QueueID:   payload.QueueID,
		IssuedAt:  payload.IssuedAt,
		ExpiresAt: payload.ExpiresAt,
		Revoked:   false,
		Used:      false,
	}

	metadataJSON, err := json.Marshal(metadata)
	if err != nil {
		return fmt.Errorf("failed to marshal metadata: %w", err)
	}

	key := TokenKey(token)
	ctx, cancel := context.WithTimeout(g.ctx, 2*time.Second)
	defer cancel()

	ttl := time.Until(payload.ExpiresAt)
	if ttl <= 0 {
		ttl = DefaultTokenTTL
	}

	return g.redisClient.GetClient().Set(ctx, key, metadataJSON, ttl).Err()
}
