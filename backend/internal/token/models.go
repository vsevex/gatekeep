package token

import (
	"time"
)

// TokenPayload represents the payload of a token
type TokenPayload struct {
	EventID   string    `json:"event_id"`
	DeviceID  string    `json:"device_id"`
	UserID    string    `json:"user_id"`
	QueueID   string    `json:"queue_id"`
	IssuedAt  time.Time `json:"issued_at"`
	ExpiresAt time.Time `json:"expires_at"`
	Nonce     string    `json:"nonce"`
}

// TokenHeader represents the token header
type TokenHeader struct {
	Algorithm string `json:"alg"`
	Type      string `json:"typ"`
}

// TokenMetadata represents metadata stored in Redis for a token
type TokenMetadata struct {
	Token     string    `json:"token"`
	EventID   string    `json:"event_id"`
	DeviceID  string    `json:"device_id"`
	UserID    string    `json:"user_id"`
	QueueID   string    `json:"queue_id"`
	IssuedAt  time.Time `json:"issued_at"`
	ExpiresAt time.Time `json:"expires_at"`
	Revoked   bool      `json:"revoked"`
	Used      bool      `json:"used"`
}

// TokenKey returns the Redis key for a token
func TokenKey(token string) string {
	return "token:" + token
}
