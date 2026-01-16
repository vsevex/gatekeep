package api

import (
	"encoding/json"
	"net/http"

	"github.com/gorilla/mux"

	"gatekeep/internal/queue"
	"gatekeep/internal/release"
)

// Handler holds dependencies for API handlers
type Handler struct {
	queueManager      *queue.Manager
	releaseController *release.Controller
}

// NewHandler creates a new API handler
func NewHandler(queueManager *queue.Manager, releaseController *release.Controller) *Handler {
	return &Handler{
		queueManager:      queueManager,
		releaseController: releaseController,
	}
}

// ReleaseRequest represents a request to release users
type ReleaseRequest struct {
	EventID string `json:"event_id"`
	Count   int    `json:"count"`
}

// ReleaseResponse represents the response from a release operation
type ReleaseResponse struct {
	Released int    `json:"released"`
	EventID  string `json:"event_id"`
}

// HandleRelease handles POST /admin/release
func (h *Handler) HandleRelease(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req ReleaseRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	if req.EventID == "" {
		http.Error(w, "event_id is required", http.StatusBadRequest)
		return
	}

	if req.Count <= 0 {
		http.Error(w, "count must be > 0", http.StatusBadRequest)
		return
	}

	released, err := h.releaseController.ReleaseUsers(req.EventID, req.Count)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	response := ReleaseResponse{
		Released: released,
		EventID:  req.EventID,
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(response)
}

// PauseRequest represents a request to pause/resume
type PauseRequest struct {
	Paused bool `json:"paused"`
}

// HandlePause handles POST /admin/pause
func (h *Handler) HandlePause(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req PauseRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	if req.Paused {
		h.releaseController.Pause()
	} else {
		h.releaseController.Resume()
	}

	state := h.releaseController.GetState()
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(state)
}

// ConfigRequest represents a request to update event configuration
type ConfigRequest struct {
	EventID     string `json:"event_id"`
	Enabled     *bool  `json:"enabled,omitempty"`
	MaxSize     *int   `json:"max_size,omitempty"`
	ReleaseRate *int   `json:"release_rate,omitempty"`
}

// HandleConfig handles POST /admin/config
func (h *Handler) HandleConfig(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req ConfigRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	if req.EventID == "" {
		http.Error(w, "event_id is required", http.StatusBadRequest)
		return
	}

	// Get current config
	config, err := h.queueManager.GetEventConfig(req.EventID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Update config if provided
	if req.Enabled != nil {
		config.Enabled = *req.Enabled
	}
	if req.MaxSize != nil {
		if *req.MaxSize < 0 {
			http.Error(w, "max_size must be >= 0", http.StatusBadRequest)
			return
		}
		config.MaxSize = *req.MaxSize
	}
	if req.ReleaseRate != nil {
		if *req.ReleaseRate < 0 {
			http.Error(w, "release_rate must be >= 0", http.StatusBadRequest)
			return
		}
		config.ReleaseRate = *req.ReleaseRate
		if err := h.releaseController.SetReleaseRate(config.ReleaseRate); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
	}

	// Save config
	if err := h.queueManager.SetEventConfig(config); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(config)
}

// HandleMetrics handles GET /admin/metrics
func (h *Handler) HandleMetrics(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	state := h.releaseController.GetState()

	metrics := map[string]interface{}{
		"release_state": state,
		"capacity": map[string]int{
			"current": state.CurrentCapacity,
			"max":     state.MaxCapacity,
		},
		"release_rate": state.ReleaseRate,
		"paused":       state.Paused,
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(metrics)
}

// JoinQueueRequest represents a request to join a queue
type JoinQueueRequest struct {
	EventID        string            `json:"event_id"`
	DeviceID       string            `json:"device_id"`
	UserID         string            `json:"user_id,omitempty"`
	PriorityBucket string            `json:"priority_bucket,omitempty"`
	Metadata       map[string]string `json:"metadata,omitempty"`
}

// HandleJoinQueue handles POST /queue/join
func (h *Handler) HandleJoinQueue(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req JoinQueueRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	if req.EventID == "" {
		http.Error(w, "event_id is required", http.StatusBadRequest)
		return
	}

	if req.DeviceID == "" {
		http.Error(w, "device_id is required", http.StatusBadRequest)
		return
	}

	// Use device_id as user_id if user_id is not provided (queue manager will handle this)
	userID := req.UserID
	if userID == "" {
		userID = req.DeviceID
	}

	// Default priority bucket
	priorityBucket := req.PriorityBucket
	if priorityBucket == "" {
		priorityBucket = "normal"
	}

	queueReq := queue.JoinQueueRequest{
		EventID:        req.EventID,
		DeviceID:       req.DeviceID,
		UserID:         userID,
		PriorityBucket: priorityBucket,
	}

	entry, err := h.queueManager.JoinQueue(queueReq)
	if err != nil {
		// Check for specific error types
		if err.Error() == "queue is full (max size: 0)" ||
			err.Error() == "queue for event "+req.EventID+" is disabled" {
			http.Error(w, err.Error(), http.StatusServiceUnavailable)
			return
		}
		if err.Error() == "rate limit exceeded: maximum 5 joins per 1m0s" {
			http.Error(w, err.Error(), http.StatusTooManyRequests)
			return
		}
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Convert QueueEntry to QueueStatus for response
	status, err := h.queueManager.GetQueueStatus(entry.QueueID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(status)
}

// HandleGetQueueStatus handles GET /queue/status
func (h *Handler) HandleGetQueueStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	queueID := r.URL.Query().Get("queue_id")
	if queueID == "" {
		http.Error(w, "queue_id is required", http.StatusBadRequest)
		return
	}

	status, err := h.queueManager.GetQueueStatus(queueID)
	if err != nil {
		if err.Error() == "queue entry not found: "+queueID {
			http.Error(w, err.Error(), http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(status)
}

// HeartbeatRequest represents a request to send a heartbeat
type HeartbeatRequest struct {
	QueueID string `json:"queue_id"`
}

// HandleHeartbeat handles POST /queue/heartbeat
func (h *Handler) HandleHeartbeat(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req HeartbeatRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	if req.QueueID == "" {
		http.Error(w, "queue_id is required", http.StatusBadRequest)
		return
	}

	status, err := h.queueManager.SendHeartbeat(req.QueueID)
	if err != nil {
		if err.Error() == "queue entry not found: "+req.QueueID {
			http.Error(w, err.Error(), http.StatusNotFound)
			return
		}
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(status)
}

// RegisterRoutes registers all admin routes
func (h *Handler) RegisterRoutes(r *mux.Router, adminAPIKey string) {
	adminRouter := r.PathPrefix("/admin").Subrouter()

	// Apply middleware
	adminRouter.Use(AdminAuthMiddleware(adminAPIKey))
	adminRouter.Use(RequestLoggingMiddleware())
	adminRouter.Use(RateLimitMiddleware())

	// Register endpoints
	adminRouter.HandleFunc("/release", h.HandleRelease).Methods("POST")
	adminRouter.HandleFunc("/pause", h.HandlePause).Methods("POST")
	adminRouter.HandleFunc("/config", h.HandleConfig).Methods("POST")
	adminRouter.HandleFunc("/metrics", h.HandleMetrics).Methods("GET")
}

// RegisterQueueRoutes registers all queue client routes
func (h *Handler) RegisterQueueRoutes(r *mux.Router) {
	queueRouter := r.PathPrefix("/queue").Subrouter()

	// Apply middleware for queue routes
	queueRouter.Use(RequestLoggingMiddleware())
	queueRouter.Use(RateLimitMiddleware())

	// Register queue endpoints
	queueRouter.HandleFunc("/join", h.HandleJoinQueue).Methods("POST")
	queueRouter.HandleFunc("/status", h.HandleGetQueueStatus).Methods("GET")
	queueRouter.HandleFunc("/heartbeat", h.HandleHeartbeat).Methods("POST")
}
