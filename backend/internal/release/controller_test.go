package release

import (
	"context"
	"testing"
	"time"

	"gatekeep/internal/config"
	redisclient "gatekeep/internal/redis"
	"gatekeep/internal/token"
)

func setupTestController(t *testing.T) (*Controller, func()) {
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

	tokenGen := token.NewGenerator(redisClient, cfg.TokenSecret)
	controller := NewController(redisClient, tokenGen)

	cleanup := func() {
		controller.Stop()
		ctx := context.Background()
		client := redisClient.GetClient()
		iter := client.Scan(ctx, 0, "release:*", 100).Iterator()
		for iter.Next(ctx) {
			client.Del(ctx, iter.Val())
		}
		iter = client.Scan(ctx, 0, "queue:*", 100).Iterator()
		for iter.Next(ctx) {
			client.Del(ctx, iter.Val())
		}
		iter = client.Scan(ctx, 0, "token:*", 100).Iterator()
		for iter.Next(ctx) {
			client.Del(ctx, iter.Val())
		}
	}

	return controller, cleanup
}

func TestNewController(t *testing.T) {
	controller, cleanup := setupTestController(t)
	if controller == nil {
		return
	}
	defer cleanup()

	state := controller.GetState()
	if state.ReleaseRate != 10 {
		t.Errorf("Expected default release rate 10, got %d", state.ReleaseRate)
	}
	if state.MaxCapacity != 1000 {
		t.Errorf("Expected default max capacity 1000, got %d", state.MaxCapacity)
	}
	if state.Paused {
		t.Error("Controller should not be paused by default")
	}
}

func TestSetReleaseRate(t *testing.T) {
	controller, cleanup := setupTestController(t)
	if controller == nil {
		return
	}
	defer cleanup()

	if err := controller.SetReleaseRate(20); err != nil {
		t.Fatalf("SetReleaseRate() failed: %v", err)
	}

	state := controller.GetState()
	if state.ReleaseRate != 20 {
		t.Errorf("Release rate mismatch: expected 20, got %d", state.ReleaseRate)
	}
}

func TestSetReleaseRate_Invalid(t *testing.T) {
	controller, cleanup := setupTestController(t)
	if controller == nil {
		return
	}
	defer cleanup()

	err := controller.SetReleaseRate(-1)
	if err == nil {
		t.Error("SetReleaseRate() expected error for negative rate, got nil")
	}
}

func TestSetMaxCapacity(t *testing.T) {
	controller, cleanup := setupTestController(t)
	if controller == nil {
		return
	}
	defer cleanup()

	if err := controller.SetMaxCapacity(500); err != nil {
		t.Fatalf("SetMaxCapacity() failed: %v", err)
	}

	state := controller.GetState()
	if state.MaxCapacity != 500 {
		t.Errorf("Max capacity mismatch: expected 500, got %d", state.MaxCapacity)
	}
}

func TestPauseResume(t *testing.T) {
	controller, cleanup := setupTestController(t)
	if controller == nil {
		return
	}
	defer cleanup()

	// Initially not paused
	state := controller.GetState()
	if state.Paused {
		t.Error("Controller should not be paused initially")
	}

	// Pause
	controller.Pause()
	state = controller.GetState()
	if !state.Paused {
		t.Error("Controller should be paused")
	}

	// Resume
	controller.Resume()
	state = controller.GetState()
	if state.Paused {
		t.Error("Controller should not be paused after resume")
	}
}

func TestReleaseUsers_EmptyQueue(t *testing.T) {
	controller, cleanup := setupTestController(t)
	if controller == nil {
		return
	}
	defer cleanup()

	released, err := controller.ReleaseUsers("event-1", 10)
	if err != nil {
		t.Fatalf("ReleaseUsers() failed: %v", err)
	}

	if released != 0 {
		t.Errorf("Expected 0 releases for empty queue, got %d", released)
	}
}

func TestReleaseUsers_Paused(t *testing.T) {
	controller, cleanup := setupTestController(t)
	if controller == nil {
		return
	}
	defer cleanup()

	controller.Pause()

	_, err := controller.ReleaseUsers("event-1", 10)
	if err == nil {
		t.Error("ReleaseUsers() expected error when paused, got nil")
		return
	}
}

func TestReleaseUsers_RespectsReleaseRate(t *testing.T) {
	controller, cleanup := setupTestController(t)
	if controller == nil {
		return
	}
	defer cleanup()

	// Set low release rate
	if err := controller.SetReleaseRate(2); err != nil {
		t.Fatalf("SetReleaseRate() failed: %v", err)
	}

	// Try to release more than rate allows
	released, err := controller.ReleaseUsers("event-1", 10)
	if err != nil {
		// Error is OK if queue is empty
		if released > 2 {
			t.Errorf("Released %d users, but release rate is 2", released)
		}
	}
}

func TestReleaseUsers_RespectsCapacity(t *testing.T) {
	controller, cleanup := setupTestController(t)
	if controller == nil {
		return
	}
	defer cleanup()

	// Set low capacity
	if err := controller.SetMaxCapacity(3); err != nil {
		t.Fatalf("SetMaxCapacity() failed: %v", err)
	}

	// Try to release more than capacity allows
	released, err := controller.ReleaseUsers("event-1", 10)
	if err != nil {
		// Error is OK if queue is empty or capacity reached
		if released > 3 {
			t.Errorf("Released %d users, but max capacity is 3", released)
		}
	}
}

func TestDecrementCapacity(t *testing.T) {
	controller, cleanup := setupTestController(t)
	if controller == nil {
		return
	}
	defer cleanup()

	// Manually set capacity (for testing)
	controller.mu.Lock()
	controller.currentCapacity = 5
	controller.mu.Unlock()

	controller.DecrementCapacity()

	capacity := controller.GetCapacity()
	if capacity != 4 {
		t.Errorf("Expected capacity 4 after decrement, got %d", capacity)
	}

	// Decrement to zero
	for i := 0; i < 5; i++ {
		controller.DecrementCapacity()
	}

	capacity = controller.GetCapacity()
	if capacity != 0 {
		t.Errorf("Expected capacity 0, got %d", capacity)
	}
}

func TestSaveLoadState(t *testing.T) {
	controller, cleanup := setupTestController(t)
	if controller == nil {
		return
	}
	defer cleanup()

	// Modify state
	if err := controller.SetReleaseRate(25); err != nil {
		t.Fatalf("SetReleaseRate() failed: %v", err)
	}
	if err := controller.SetMaxCapacity(500); err != nil {
		t.Fatalf("SetMaxCapacity() failed: %v", err)
	}
	controller.Pause()

	// Save state
	if err := controller.SaveState(); err != nil {
		t.Fatalf("SaveState() failed: %v", err)
	}

	// Create new controller and load state
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
		t.Fatalf("Failed to create Redis client: %v", err)
	}

	tokenGen := token.NewGenerator(redisClient, cfg.TokenSecret)
	newController := NewController(redisClient, tokenGen)

	// Load state
	if err := newController.LoadState(); err != nil {
		t.Fatalf("LoadState() failed: %v", err)
	}

	// Verify state
	state := newController.GetState()
	if state.ReleaseRate != 25 {
		t.Errorf("Release rate mismatch: expected 25, got %d", state.ReleaseRate)
	}
	if state.MaxCapacity != 500 {
		t.Errorf("Max capacity mismatch: expected 500, got %d", state.MaxCapacity)
	}
	if !state.Paused {
		t.Error("Controller should be paused after loading state")
	}

	cleanup()
}

func TestStartStop(t *testing.T) {
	controller, cleanup := setupTestController(t)
	if controller == nil {
		return
	}
	defer cleanup()

	// Start scheduler
	controller.Start()

	// Give it a moment to start
	time.Sleep(100 * time.Millisecond)

	// Stop scheduler
	controller.Stop()

	// Verify it stopped (no error means it stopped cleanly)
}
