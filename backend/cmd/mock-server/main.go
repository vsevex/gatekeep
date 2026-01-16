package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
)

// MockQueueEntry represents a queue entry in the mock server
type MockQueueEntry struct {
	QueueID        string    `json:"queue_id"`
	EventID        string    `json:"event_id"`
	DeviceID       string    `json:"device_id"`
	UserID         string    `json:"user_id"`
	Position       int       `json:"position"`
	EnqueuedAt     time.Time `json:"enqueued_at"`
	LastHeartbeat  time.Time `json:"last_heartbeat"`
	PriorityBucket string    `json:"priority_bucket"`
	Admitted       bool      `json:"admitted"`
}

// MockQueueStatus represents the status response
type MockQueueStatus struct {
	QueueID              string              `json:"queue_id"`
	Position             int                 `json:"position"`
	EstimatedWaitSeconds int                 `json:"estimated_wait_seconds"`
	Status               string              `json:"status"` // "waiting", "admitted", "expired"
	EnqueuedAt           time.Time           `json:"enqueued_at"`
	LastHeartbeat        time.Time           `json:"last_heartbeat"`
	TotalInQueue         *int                `json:"total_in_queue,omitempty"`
	AdmissionToken       *MockAdmissionToken `json:"admission_token,omitempty"`
}

// MockAdmissionToken represents an admission token
type MockAdmissionToken struct {
	Token     string    `json:"token"`
	EventID   string    `json:"event_id"`
	DeviceID  string    `json:"device_id"`
	UserID    string    `json:"user_id"`
	IssuedAt  time.Time `json:"issued_at"`
	ExpiresAt time.Time `json:"expires_at"`
	QueueID   string    `json:"queue_id"`
}

// JoinRequest represents a join queue request
type JoinRequest struct {
	EventID        string            `json:"event_id"`
	DeviceID       string            `json:"device_id"`
	UserID         string            `json:"user_id,omitempty"`
	PriorityBucket string            `json:"priority_bucket,omitempty"`
	Metadata       map[string]string `json:"metadata,omitempty"`
}

// HeartbeatRequest represents a heartbeat request
type HeartbeatRequest struct {
	QueueID string `json:"queue_id"`
}

// MockServer simulates a queue server with dummy users
type MockServer struct {
	mu               sync.RWMutex
	queues           map[string][]*MockQueueEntry // eventID -> entries
	entries          map[string]*MockQueueEntry   // queueID -> entry
	admitted         map[string]bool              // queueID -> admitted
	releaseRate      int                          // users per second to admit
	initialQueueSize int                          // initial dummy users in queue
}

// NewMockServer creates a new mock server
func NewMockServer(initialQueueSize, releaseRate int) *MockServer {
	server := &MockServer{
		queues:           make(map[string][]*MockQueueEntry),
		entries:          make(map[string]*MockQueueEntry),
		admitted:         make(map[string]bool),
		releaseRate:      releaseRate,
		initialQueueSize: initialQueueSize,
	}

	// Start the admission processor
	go server.processAdmissions()

	return server
}

// processAdmissions continuously processes the queue and admits users
func (s *MockServer) processAdmissions() {
	ticker := time.NewTicker(time.Second / time.Duration(s.releaseRate))
	defer ticker.Stop()

	for range ticker.C {
		s.mu.Lock()
		for eventID, entries := range s.queues {
			if len(entries) == 0 {
				continue
			}

			// Admit the first user in the queue
			entry := entries[0]
			if !entry.Admitted && !s.admitted[entry.QueueID] {
				entry.Admitted = true
				s.admitted[entry.QueueID] = true

				// Remove from queue
				s.queues[eventID] = entries[1:]

				// Update positions for remaining users
				for i, e := range s.queues[eventID] {
					e.Position = i + 1
				}
			}
		}
		s.mu.Unlock()
	}
}

// populateDummyUsers adds dummy users to a queue for an event
func (s *MockServer) populateDummyUsers(eventID string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.queues[eventID]; exists {
		// Already populated
		return
	}

	// Create dummy users
	dummyUsers := make([]*MockQueueEntry, s.initialQueueSize)
	now := time.Now()

	for i := 0; i < s.initialQueueSize; i++ {
		queueID := uuid.New().String()
		entry := &MockQueueEntry{
			QueueID:        queueID,
			EventID:        eventID,
			DeviceID:       fmt.Sprintf("dummy-device-%d", i),
			UserID:         fmt.Sprintf("dummy-user-%d", i),
			Position:       i + 1,
			EnqueuedAt:     now.Add(-time.Duration(i) * time.Second),
			LastHeartbeat:  now,
			PriorityBucket: "normal",
			Admitted:       false,
		}
		dummyUsers[i] = entry
		s.entries[queueID] = entry
	}

	s.queues[eventID] = dummyUsers
}

// handleJoin handles POST /queue/join
func (s *MockServer) handleJoin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req JoinRequest
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

	// Use device_id as user_id if not provided
	userID := req.UserID
	if userID == "" {
		userID = req.DeviceID
	}

	// Default priority bucket
	priorityBucket := req.PriorityBucket
	if priorityBucket == "" {
		priorityBucket = "normal"
	}

	// Populate dummy users for this event if not already done
	s.populateDummyUsers(req.EventID)

	// Check if user already in queue
	s.mu.RLock()
	var existingEntry *MockQueueEntry
	for _, entry := range s.queues[req.EventID] {
		if entry.DeviceID == req.DeviceID && entry.EventID == req.EventID {
			existingEntry = entry
			break
		}
	}
	s.mu.RUnlock()

	if existingEntry != nil {
		// Return existing entry
		status := s.entryToStatus(existingEntry)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_ = json.NewEncoder(w).Encode(status)
		return
	}

	// Create new entry
	s.mu.Lock()
	queueID := uuid.New().String()
	now := time.Now()

	// Add to end of queue
	position := len(s.queues[req.EventID]) + 1
	entry := &MockQueueEntry{
		QueueID:        queueID,
		EventID:        req.EventID,
		DeviceID:       req.DeviceID,
		UserID:         userID,
		Position:       position,
		EnqueuedAt:     now,
		LastHeartbeat:  now,
		PriorityBucket: priorityBucket,
		Admitted:       false,
	}

	s.queues[req.EventID] = append(s.queues[req.EventID], entry)
	s.entries[queueID] = entry
	s.mu.Unlock()

	// Return status
	status := s.entryToStatus(entry)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(status)
}

// handleStatus handles GET /queue/status
func (s *MockServer) handleStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	queueID := r.URL.Query().Get("queue_id")
	if queueID == "" {
		http.Error(w, "queue_id is required", http.StatusBadRequest)
		return
	}

	s.mu.RLock()
	entry, exists := s.entries[queueID]
	isAdmitted := s.admitted[queueID]
	s.mu.RUnlock()

	if !exists {
		http.Error(w, "queue entry not found: "+queueID, http.StatusNotFound)
		return
	}

	// Update position based on current queue state
	s.mu.Lock()
	if entry.EventID != "" {
		// Find position in queue
		position := 0
		for i, e := range s.queues[entry.EventID] {
			if e.QueueID == queueID {
				position = i + 1
				break
			}
		}
		if position > 0 {
			entry.Position = position
		}
	}
	entry.LastHeartbeat = time.Now()
	s.mu.Unlock()

	status := s.entryToStatus(entry)
	if isAdmitted {
		status.Status = "admitted"
		status.Position = 0
		// Generate admission token
		status.AdmissionToken = s.generateToken(entry)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(status)
}

// handleHeartbeat handles POST /queue/heartbeat
func (s *MockServer) handleHeartbeat(w http.ResponseWriter, r *http.Request) {
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

	s.mu.Lock()
	entry, exists := s.entries[req.QueueID]
	isAdmitted := s.admitted[req.QueueID]
	if exists {
		entry.LastHeartbeat = time.Now()

		// Update position
		if entry.EventID != "" {
			position := 0
			for i, e := range s.queues[entry.EventID] {
				if e.QueueID == req.QueueID {
					position = i + 1
					break
				}
			}
			if position > 0 {
				entry.Position = position
			}
		}
	}
	s.mu.Unlock()

	if !exists {
		http.Error(w, "queue entry not found: "+req.QueueID, http.StatusNotFound)
		return
	}

	status := s.entryToStatus(entry)
	if isAdmitted {
		status.Status = "admitted"
		status.Position = 0
		status.AdmissionToken = s.generateToken(entry)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(status)
}

// entryToStatus converts a queue entry to status
func (s *MockServer) entryToStatus(entry *MockQueueEntry) *MockQueueStatus {
	s.mu.RLock()
	queueSize := len(s.queues[entry.EventID])
	isAdmitted := s.admitted[entry.QueueID]
	s.mu.RUnlock()

	status := "waiting"
	if isAdmitted {
		status = "admitted"
	}

	// Calculate estimated wait (position / release rate)
	// If release rate is 2 users/second, position 50 = 25 seconds
	// Use float division to avoid truncation, then round up
	var estimatedWait int
	if entry.Position > 0 && s.releaseRate > 0 {
		estimatedWait = int(float64(entry.Position) / float64(s.releaseRate))
		if estimatedWait < 1 && entry.Position > 0 {
			estimatedWait = 1 // At least 1 second if there are users ahead
		}
	} else {
		estimatedWait = 0
	}

	totalInQueue := queueSize
	statusObj := &MockQueueStatus{
		QueueID:              entry.QueueID,
		Position:             entry.Position,
		EstimatedWaitSeconds: estimatedWait,
		Status:               status,
		EnqueuedAt:           entry.EnqueuedAt,
		LastHeartbeat:        entry.LastHeartbeat,
		TotalInQueue:         &totalInQueue,
	}

	if isAdmitted {
		statusObj.AdmissionToken = s.generateToken(entry)
	}

	return statusObj
}

// generateToken generates a mock admission token
func (s *MockServer) generateToken(entry *MockQueueEntry) *MockAdmissionToken {
	now := time.Now()
	return &MockAdmissionToken{
		Token:     fmt.Sprintf("mock_token_%s_%d", entry.QueueID, now.Unix()),
		EventID:   entry.EventID,
		DeviceID:  entry.DeviceID,
		UserID:    entry.UserID,
		IssuedAt:  now,
		ExpiresAt: now.Add(1 * time.Hour),
		QueueID:   entry.QueueID,
	}
}

func main() {
	// Configuration
	port := 8080
	initialQueueSize := 50 // Start with 50 dummy users in queue
	releaseRate := 2       // Admit 2 users per second

	log.Printf("Starting mock Gatekeep server on port %d", port)
	log.Printf("Initial queue size: %d users", initialQueueSize)
	log.Printf("Release rate: %d users/second", releaseRate)

	server := NewMockServer(initialQueueSize, releaseRate)

	router := mux.NewRouter()

	// Queue endpoints
	queueRouter := router.PathPrefix("/queue").Subrouter()
	queueRouter.HandleFunc("/join", server.handleJoin).Methods("POST")
	queueRouter.HandleFunc("/status", server.handleStatus).Methods("GET")
	queueRouter.HandleFunc("/heartbeat", server.handleHeartbeat).Methods("POST")

	// Health check
	router.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("OK"))
	}).Methods("GET")

	// CORS middleware
	corsHandler := func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, X-Device-ID, X-User-ID")
			if r.Method == "OPTIONS" {
				w.WriteHeader(http.StatusOK)
				return
			}
			next.ServeHTTP(w, r)
		})
	}

	http.Handle("/", corsHandler(router))

	log.Printf("Mock server ready! Test with:")
	log.Printf("  POST http://localhost:%d/queue/join", port)
	log.Printf("  GET  http://localhost:%d/queue/status?queue_id=<queue_id>", port)
	log.Printf("  POST http://localhost:%d/queue/heartbeat", port)

	if err := http.ListenAndServe(fmt.Sprintf(":%d", port), nil); err != nil {
		log.Fatal(err)
	}
}
