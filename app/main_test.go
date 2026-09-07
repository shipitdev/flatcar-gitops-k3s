package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestRootHandler(t *testing.T) {
	req := httptest.NewRequest("GET", "/", nil)
	rec := httptest.NewRecorder()

	mux := setupRoutes()
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	var res Response
	if err := json.NewDecoder(rec.Body).Decode(&res); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if res.Version != "v2.0.0" {
		t.Errorf("expected version v2.0.0, got %s", res.Version)
	}

	if !strings.Contains(res.Message, "Enterprise Edition") {
		t.Errorf("unexpected message: %s", res.Message)
	}
}

func TestHealthProbes(t *testing.T) {
	mux := setupRoutes()

	// Test /healthz
	reqHealth := httptest.NewRequest("GET", "/healthz", nil)
	recHealth := httptest.NewRecorder()
	mux.ServeHTTP(recHealth, reqHealth)

	if recHealth.Code != http.StatusOK {
		t.Errorf("expected 200 for /healthz, got %d", recHealth.Code)
	}

	// Test /readyz
	reqReady := httptest.NewRequest("GET", "/readyz", nil)
	recReady := httptest.NewRecorder()
	mux.ServeHTTP(recReady, reqReady)

	if recReady.Code != http.StatusOK {
		t.Errorf("expected 200 for /readyz, got %d", recReady.Code)
	}
}

func TestMetricsEndpoint(t *testing.T) {
	mux := setupRoutes()
	handler := metricsMiddleware(mux)

	// Trigger a request to populate the metrics
	reqRoot := httptest.NewRequest("GET", "/", nil)
	recRoot := httptest.NewRecorder()
	handler.ServeHTTP(recRoot, reqRoot)

	// Now check /metrics
	req := httptest.NewRequest("GET", "/metrics", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200 for /metrics, got %d", rec.Code)
	}

	body := rec.Body.String()
	if !strings.Contains(body, "http_requests_total") {
		t.Errorf("expected metrics output to contain 'http_requests_total'")
	}

	if !strings.Contains(body, "http_request_duration_seconds") {
		t.Errorf("expected metrics output to contain 'http_request_duration_seconds'")
	}
}
