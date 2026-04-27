// Piboard: a Raspberry Pi monitoring dashboard for the homelab.
// Queries Prometheus and serves a 800x480 status board via SSE.
package main

import (
	"context"
	"embed"
	"flag"
	"io/fs"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"piboard/internal/config"
	"piboard/internal/prometheus"
	"piboard/internal/server"
)

//go:embed web/*
var webFS embed.FS

func main() {
	configPath := flag.String("config", "config.yaml", "path to configuration file")
	flag.Parse()

	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	slog.SetDefault(logger)

	cfg, err := config.Load(*configPath)
	if err != nil {
		slog.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	slog.Info("config loaded",
		"prometheus", cfg.PrometheusURL,
		"services", len(cfg.Services),
		"poll_interval", cfg.PollIntervalSeconds,
	)

	// Subdirectory of the embedded FS so paths resolve to /index.html not /web/index.html
	webSub, err := fs.Sub(webFS, "web")
	if err != nil {
		slog.Error("failed to create web sub-filesystem", "error", err)
		os.Exit(1)
	}

	poller := prometheus.NewPoller(cfg)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	go poller.Run(ctx)

	srv := server.New(cfg, poller, webSub)
	go func() {
		if err := srv.ListenAndServe(); err != nil {
			slog.Error("server stopped", "error", err)
		}
	}()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	sig := <-sigCh

	slog.Info("shutting down", "signal", sig)
	cancel()

	if err := srv.Shutdown(context.Background()); err != nil {
		slog.Error("shutdown error", "error", err)
	}
}
