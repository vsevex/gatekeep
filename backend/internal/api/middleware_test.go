package api

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gorilla/mux"
)

func TestAdminAuthMiddleware_ValidKey(t *testing.T) {
	adminAPIKey := "test-api-key"
	router := mux.NewRouter()
	router.Use(AdminAuthMiddleware(adminAPIKey))
	router.HandleFunc("/test", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}).Methods("GET")

	req := httptest.NewRequest("GET", "/test", nil)
	req.Header.Set("X-API-Key", adminAPIKey)
	rr := httptest.NewRecorder()

	router.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", rr.Code)
	}
}

func TestAdminAuthMiddleware_InvalidKey(t *testing.T) {
	adminAPIKey := "test-api-key"
	router := mux.NewRouter()
	router.Use(AdminAuthMiddleware(adminAPIKey))
	router.HandleFunc("/test", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}).Methods("GET")

	req := httptest.NewRequest("GET", "/test", nil)
	req.Header.Set("X-API-Key", "wrong-key")
	rr := httptest.NewRecorder()

	router.ServeHTTP(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("Expected status 401, got %d", rr.Code)
	}
}

func TestAdminAuthMiddleware_MissingKey(t *testing.T) {
	adminAPIKey := "test-api-key"
	router := mux.NewRouter()
	router.Use(AdminAuthMiddleware(adminAPIKey))
	router.HandleFunc("/test", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}).Methods("GET")

	req := httptest.NewRequest("GET", "/test", nil)
	rr := httptest.NewRecorder()

	router.ServeHTTP(rr, req)

	if rr.Code != http.StatusUnauthorized {
		t.Errorf("Expected status 401, got %d", rr.Code)
	}
}

func TestAdminAuthMiddleware_BearerToken(t *testing.T) {
	adminAPIKey := "test-api-key"
	router := mux.NewRouter()
	router.Use(AdminAuthMiddleware(adminAPIKey))
	router.HandleFunc("/test", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}).Methods("GET")

	req := httptest.NewRequest("GET", "/test", nil)
	req.Header.Set("Authorization", "Bearer "+adminAPIKey)
	rr := httptest.NewRecorder()

	router.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", rr.Code)
	}
}

func TestRateLimitMiddleware(t *testing.T) {
	router := mux.NewRouter()
	router.Use(RateLimitMiddleware())
	router.HandleFunc("/test", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}).Methods("GET")

	// Make 60 requests (should succeed)
	for i := 0; i < 60; i++ {
		req := httptest.NewRequest("GET", "/test", nil)
		rr := httptest.NewRecorder()
		router.ServeHTTP(rr, req)

		if rr.Code != http.StatusOK {
			t.Errorf("Request #%d: Expected status 200, got %d", i+1, rr.Code)
		}
	}

	// 61st request should be rate limited
	req := httptest.NewRequest("GET", "/test", nil)
	rr := httptest.NewRecorder()
	router.ServeHTTP(rr, req)

	if rr.Code != http.StatusTooManyRequests {
		t.Errorf("Expected status 429, got %d", rr.Code)
	}
}
