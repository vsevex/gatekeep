package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"gatekeep/internal/config"
	"gatekeep/internal/queue"
	redisclient "gatekeep/internal/redis"
	"gatekeep/internal/release"
	"gatekeep/internal/token"
)

func setupTestHandler(t *testing.T) (*Handler, string, func()) {
	cfg := &config.Config{
		Port:          8080,
		RedisAddr:     "localhost:6379",
		RedisPassword: "",
		TokenSecret:   "this-is-a-very-long-secret-key-that-is-at-least-32-characters",
		AdminAPIKey:   "test-admin-key",
		LogLevel:      "info",
		MetricsPort:   9090,
	}

	redisClient, err := redisclient.NewClient(cfg)
	if err != nil {
		t.Skipf("Skipping test: Redis not available: %v", err)
		return nil, "", nil
	}

	queueManager := queue.NewManager(redisClient)
	tokenGen := token.NewGenerator(redisClient, cfg.TokenSecret)
	releaseController := release.NewController(redisClient, tokenGen)

	handler := NewHandler(queueManager, releaseController)

	cleanup := func() {
		releaseController.Stop()
	}

	return handler, cfg.AdminAPIKey, cleanup
}

func TestHandleRelease(t *testing.T) {
	handler, apiKey, cleanup := setupTestHandler(t)
	if handler == nil {
		return
	}
	defer cleanup()

	reqBody := ReleaseRequest{
		EventID: "test-event",
		Count:   5,
	}
	body, _ := json.Marshal(reqBody)

	req := httptest.NewRequest("POST", "/admin/release", bytes.NewReader(body))
	req.Header.Set("X-API-Key", apiKey)
	rr := httptest.NewRecorder()

	handler.HandleRelease(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d: %s", rr.Code, rr.Body.String())
	}

	var response ReleaseResponse
	if err := json.NewDecoder(rr.Body).Decode(&response); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if response.EventID != reqBody.EventID {
		t.Errorf("EventID mismatch: expected %s, got %s", reqBody.EventID, response.EventID)
	}
}

func TestHandleRelease_InvalidRequest(t *testing.T) {
	handler, apiKey, cleanup := setupTestHandler(t)
	if handler == nil {
		return
	}
	defer cleanup()

	tests := []struct {
		name       string
		body       interface{}
		wantStatus int
	}{
		{"missing event_id", map[string]interface{}{"count": 5}, http.StatusBadRequest},
		{"zero count", map[string]interface{}{"event_id": "test", "count": 0}, http.StatusBadRequest},
		{"negative count", map[string]interface{}{"event_id": "test", "count": -1}, http.StatusBadRequest},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			body, _ := json.Marshal(tt.body)
			req := httptest.NewRequest("POST", "/admin/release", bytes.NewReader(body))
			req.Header.Set("X-API-Key", apiKey)
			rr := httptest.NewRecorder()

			handler.HandleRelease(rr, req)

			if rr.Code != tt.wantStatus {
				t.Errorf("Expected status %d, got %d", tt.wantStatus, rr.Code)
			}
		})
	}
}

func TestHandlePause(t *testing.T) {
	handler, apiKey, cleanup := setupTestHandler(t)
	if handler == nil {
		return
	}
	defer cleanup()

	// Test pause
	reqBody := PauseRequest{Paused: true}
	body, _ := json.Marshal(reqBody)

	req := httptest.NewRequest("POST", "/admin/pause", bytes.NewReader(body))
	req.Header.Set("X-API-Key", apiKey)
	rr := httptest.NewRecorder()

	handler.HandlePause(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", rr.Code)
	}

	state := handler.releaseController.GetState()
	if !state.Paused {
		t.Error("Controller should be paused")
	}

	// Test resume
	reqBody.Paused = false
	body, _ = json.Marshal(reqBody)

	req = httptest.NewRequest("POST", "/admin/pause", bytes.NewReader(body))
	req.Header.Set("X-API-Key", apiKey)
	rr = httptest.NewRecorder()

	handler.HandlePause(rr, req)

	state = handler.releaseController.GetState()
	if state.Paused {
		t.Error("Controller should not be paused after resume")
	}
}

func TestHandleConfig(t *testing.T) {
	handler, apiKey, cleanup := setupTestHandler(t)
	if handler == nil {
		return
	}
	defer cleanup()

	// Test config update
	enabled := true
	maxSize := 5000
	reqBody := ConfigRequest{
		EventID: "test-event",
		Enabled: &enabled,
		MaxSize: &maxSize,
	}
	body, _ := json.Marshal(reqBody)

	req := httptest.NewRequest("POST", "/admin/config", bytes.NewReader(body))
	req.Header.Set("X-API-Key", apiKey)
	rr := httptest.NewRecorder()

	handler.HandleConfig(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d: %s", rr.Code, rr.Body.String())
	}

	// Verify config was updated
	config, err := handler.queueManager.GetEventConfig("test-event")
	if err != nil {
		t.Fatalf("GetEventConfig() failed: %v", err)
	}

	if config.Enabled != enabled {
		t.Errorf("Enabled mismatch: expected %v, got %v", enabled, config.Enabled)
	}
	if config.MaxSize != maxSize {
		t.Errorf("MaxSize mismatch: expected %d, got %d", maxSize, config.MaxSize)
	}
}

func TestHandleMetrics(t *testing.T) {
	handler, apiKey, cleanup := setupTestHandler(t)
	if handler == nil {
		return
	}
	defer cleanup()

	req := httptest.NewRequest("GET", "/admin/metrics", nil)
	req.Header.Set("X-API-Key", apiKey)
	rr := httptest.NewRecorder()

	handler.HandleMetrics(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", rr.Code)
	}

	var metrics map[string]interface{}
	if err := json.NewDecoder(rr.Body).Decode(&metrics); err != nil {
		t.Fatalf("Failed to decode metrics: %v", err)
	}

	if metrics["release_state"] == nil {
		t.Error("Metrics should contain release_state")
	}
}
