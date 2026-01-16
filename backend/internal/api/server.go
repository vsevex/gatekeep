package api

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	"gatekeep/internal/config"
	"gatekeep/internal/queue"
	"gatekeep/internal/release"
)

// Server wraps the HTTP server
type Server struct {
	handler *Handler
	router  *mux.Router
	config  *config.Config
	server  *http.Server
}

// NewServer creates a new API server
func NewServer(
	cfg *config.Config,
	queueManager *queue.Manager,
	releaseController *release.Controller,
) *Server {
	handler := NewHandler(queueManager, releaseController)
	router := mux.NewRouter()

	// Register queue client routes
	handler.RegisterQueueRoutes(router)

	// Register admin routes
	handler.RegisterRoutes(router, cfg.AdminAPIKey)

	// Register Prometheus metrics endpoint
	router.Path("/metrics").Handler(promhttp.Handler())

	// Health check endpoint
	router.Path("/health").HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("OK"))
	})

	addr := fmt.Sprintf(":%d", cfg.Port)
	server := &http.Server{
		Addr:         addr,
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	return &Server{
		handler: handler,
		router:  router,
		config:  cfg,
		server:  server,
	}
}

// Start starts the HTTP server
func (s *Server) Start() error {
	return s.server.ListenAndServe()
}

// Shutdown gracefully shuts down the HTTP server
func (s *Server) Shutdown(ctx context.Context) error {
	return s.server.Shutdown(ctx)
}
