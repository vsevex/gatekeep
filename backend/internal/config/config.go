package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/joho/godotenv"
)

// Config holds all configuration for the application
type Config struct {
	Port          int
	RedisAddr     string
	RedisPassword string
	TokenSecret   string
	AdminAPIKey   string
	LogLevel      string
	MetricsPort   int
}

// Load loads configuration from environment variables and .env file
// It first attempts to load from .env file (if it exists), then reads from
// system environment variables (which take precedence over .env file values)
func Load() (*Config, error) {
	// Try to load .env file (ignore error if file doesn't exist)
	_ = godotenv.Load()

	cfg := &Config{}

	// Load Port (default: 8080)
	portStr := getEnv("PORT", "8080")
	port, err := strconv.Atoi(portStr)
	if err != nil {
		return nil, fmt.Errorf("invalid PORT value: %s", portStr)
	}
	cfg.Port = port

	// Load RedisAddr (required)
	cfg.RedisAddr = getEnv("REDIS_ADDR", "")
	if cfg.RedisAddr == "" {
		return nil, fmt.Errorf("REDIS_ADDR is required")
	}

	// Load RedisPassword (optional)
	cfg.RedisPassword = getEnv("REDIS_PASSWORD", "")

	// Load TokenSecret (required)
	cfg.TokenSecret = getEnv("TOKEN_SECRET", "")
	if cfg.TokenSecret == "" {
		return nil, fmt.Errorf("TOKEN_SECRET is required")
	}

	// Load AdminAPIKey (required)
	cfg.AdminAPIKey = getEnv("ADMIN_API_KEY", "")
	if cfg.AdminAPIKey == "" {
		return nil, fmt.Errorf("ADMIN_API_KEY is required")
	}

	// Load LogLevel (default: "info")
	cfg.LogLevel = strings.ToLower(getEnv("LOG_LEVEL", "info"))
	validLogLevels := map[string]bool{
		"debug": true,
		"info":  true,
		"warn":  true,
		"error": true,
	}
	if !validLogLevels[cfg.LogLevel] {
		return nil, fmt.Errorf("invalid LOG_LEVEL: %s (must be one of: debug, info, warn, error)", cfg.LogLevel)
	}

	// Load MetricsPort (default: 9090)
	metricsPortStr := getEnv("METRICS_PORT", "9090")
	metricsPort, err := strconv.Atoi(metricsPortStr)
	if err != nil {
		return nil, fmt.Errorf("invalid METRICS_PORT value: %s", metricsPortStr)
	}
	cfg.MetricsPort = metricsPort

	return cfg, nil
}

// getEnv retrieves an environment variable or returns a default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// Validate performs additional validation on the configuration
func (c *Config) Validate() error {
	if c.Port < 1 || c.Port > 65535 {
		return fmt.Errorf("PORT must be between 1 and 65535, got: %d", c.Port)
	}

	if c.MetricsPort < 1 || c.MetricsPort > 65535 {
		return fmt.Errorf("METRICS_PORT must be between 1 and 65535, got: %d", c.MetricsPort)
	}

	if c.Port == c.MetricsPort {
		return fmt.Errorf("PORT and METRICS_PORT cannot be the same: %d", c.Port)
	}

	if len(c.TokenSecret) < 32 {
		return fmt.Errorf("TOKEN_SECRET must be at least 32 characters long for security")
	}

	return nil
}
