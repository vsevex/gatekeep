package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"gatekeep/internal/api"
	"gatekeep/internal/config"
	"gatekeep/internal/queue"
	redisclient "gatekeep/internal/redis"
	"gatekeep/internal/release"
	"gatekeep/internal/token"
)

func main() {
	log.Println("Gatekeep server starting...")

	// Load configuration from environment variables
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Validate configuration
	if err := cfg.Validate(); err != nil {
		log.Fatalf("Invalid configuration: %v", err)
	}

	log.Printf("Configuration loaded successfully")
	log.Printf("Server port: %d", cfg.Port)
	log.Printf("Metrics port: %d", cfg.MetricsPort)
	log.Printf("Redis address: %s", cfg.RedisAddr)
	log.Printf("Log level: %s", cfg.LogLevel)

	// Initialize Redis client
	redisClient, err := redisclient.NewClient(cfg)
	if err != nil {
		log.Fatalf("Failed to initialize Redis client: %v", err)
	}
	defer redisClient.Close()

	log.Println("Redis connection established")

	// Verify Redis health
	ctx := context.Background()
	if err := redisClient.HealthCheck(ctx); err != nil {
		log.Fatalf("Redis health check failed: %v", err)
	}

	log.Println("Redis health check passed")

	// Initialize queue manager
	queueManager := queue.NewManager(redisClient)
	log.Println("Queue manager initialized")

	// Initialize token generator
	tokenGen := token.NewGenerator(redisClient, cfg.TokenSecret)
	log.Println("Token generator initialized")

	// Initialize token verifier
	tokenVerifier := token.NewVerifier(redisClient, cfg.TokenSecret)
	log.Println("Token verifier initialized")
	_ = tokenVerifier // Will be used in future API endpoints

	// Initialize release controller
	releaseController := release.NewController(redisClient, tokenGen)
	log.Println("Release controller initialized")

	// Load release state from Redis
	if err := releaseController.LoadState(); err != nil {
		log.Printf("Warning: Failed to load release state: %v", err)
	} else {
		log.Println("Release state loaded from Redis")
	}

	// Start release scheduler
	releaseController.Start()
	log.Println("Release scheduler started")
	defer releaseController.Stop()

	// Initialize API server
	apiServer := api.NewServer(cfg, queueManager, releaseController)
	log.Println("API server initialized")

	// Setup graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	// Start server in a goroutine
	serverErrChan := make(chan error, 1)
	go func() {
		log.Printf("HTTP server listening on port %d", cfg.Port)
		log.Printf("Metrics endpoint available at http://localhost:%d/metrics", cfg.Port)
		log.Printf("Health check available at http://localhost:%d/health", cfg.Port)
		log.Printf("Admin API available at http://localhost:%d/admin/*", cfg.Port)
		if err := apiServer.Start(); err != nil && err != http.ErrServerClosed {
			serverErrChan <- err
		}
	}()

	// Wait for interrupt signal or server error
	select {
	case sig := <-sigChan:
		log.Printf("Received signal: %v, shutting down gracefully...", sig)
		// Graceful shutdown with timeout
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := apiServer.Shutdown(shutdownCtx); err != nil {
			log.Printf("Error during server shutdown: %v", err)
		}
	case err := <-serverErrChan:
		log.Fatalf("Server error: %v", err)
	}

	log.Println("Server shutdown complete")
}
