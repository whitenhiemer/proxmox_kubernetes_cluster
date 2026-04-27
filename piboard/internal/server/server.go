// Package server provides the HTTP server and SSE endpoint for piboard.
package server

import (
	"context"
	"encoding/json"
	"fmt"
	"io/fs"
	"log/slog"
	"net/http"
	"time"

	"piboard/internal/config"
	"piboard/internal/prometheus"
)

// Server wraps the HTTP server with dashboard-specific handlers.
type Server struct {
	httpServer *http.Server
	poller     *prometheus.Poller
}

// New creates a configured HTTP server with all routes registered.
func New(cfg *config.Config, poller *prometheus.Poller, webFS fs.FS) *Server {
	mux := http.NewServeMux()

	// Static files (embedded)
	mux.Handle("GET /", http.FileServerFS(webFS))

	// SSE status stream
	mux.HandleFunc("GET /api/status", sseHandler(poller))

	// Health check
	mux.HandleFunc("GET /api/health", healthHandler(poller))

	return &Server{
		httpServer: &http.Server{
			Addr:         cfg.ListenAddr,
			Handler:      securityHeaders(mux),
			ReadTimeout:  5 * time.Second,
			WriteTimeout: 0, // SSE requires no write timeout
			IdleTimeout:  120 * time.Second,
		},
		poller: poller,
	}
}

// ListenAndServe starts the HTTP server.
func (s *Server) ListenAndServe() error {
	slog.Info("starting server", "addr", s.httpServer.Addr)
	return s.httpServer.ListenAndServe()
}

// Shutdown gracefully stops the server.
func (s *Server) Shutdown(ctx context.Context) error {
	shutdownCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	return s.httpServer.Shutdown(shutdownCtx)
}

// securityHeaders applies standard security headers to all responses.
func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Content-Security-Policy", "default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self'")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		next.ServeHTTP(w, r)
	})
}

// sseHandler streams DashboardStatus as Server-Sent Events.
func sseHandler(poller *prometheus.Poller) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		flusher, ok := w.(http.Flusher)
		if !ok {
			http.Error(w, "streaming not supported", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "text/event-stream")
		w.Header().Set("Cache-Control", "no-cache")
		w.Header().Set("Connection", "keep-alive")

		id, ch := poller.Subscribe()
		defer poller.Unsubscribe(id)

		// Send current snapshot immediately so the UI renders without
		// waiting for the next poll cycle
		if err := writeSSE(w, flusher, poller.CurrentStatus()); err != nil {
			return
		}

		for {
			select {
			case <-r.Context().Done():
				return
			case status, ok := <-ch:
				if !ok {
					return
				}
				if err := writeSSE(w, flusher, status); err != nil {
					return
				}
			}
		}
	}
}

// writeSSE marshals a status to JSON and writes it as an SSE data frame.
func writeSSE(w http.ResponseWriter, flusher http.Flusher, status prometheus.DashboardStatus) error {
	data, err := json.Marshal(status)
	if err != nil {
		slog.Error("marshaling status", "error", err)
		return err
	}

	if _, err := fmt.Fprintf(w, "data: %s\n\n", data); err != nil {
		return err
	}

	flusher.Flush()
	return nil
}

// healthHandler returns 200 if the poller has data, 503 otherwise.
func healthHandler(poller *prometheus.Poller) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		status := poller.CurrentStatus()
		if status.Timestamp.IsZero() {
			w.WriteHeader(http.StatusServiceUnavailable)
			fmt.Fprint(w, "no data yet")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{
			"status":    "ok",
			"timestamp": status.Timestamp,
		})
	}
}
