package main

import (
	"fmt"
	"net"
	"net/http"
	"net/http/pprof"
	"os"
	"time"

	"github.com/ahmedakef/gotutor/backend/src/cache"
	"github.com/ahmedakef/gotutor/backend/src/controller"
	"github.com/ahmedakef/gotutor/backend/src/db"
	"github.com/ahmedakef/gotutor/backend/src/handler"
	"github.com/rs/zerolog"
)

const (
	_port          = 8080
	_maxCacheSize  = 250 * 1024 * 1024 // 100MB
	_maxCacheItems = 100
	_cacheTTL      = 0
)

func main() {
	logger := zerolog.New(
		zerolog.ConsoleWriter{Out: os.Stderr, TimeFormat: time.RFC3339},
	).Level(zerolog.InfoLevel).With().Timestamp().Caller().Logger()

	cache := cache.NewLRUCache(_maxCacheSize, _maxCacheItems, _cacheTTL)

	dbPath := "gotutor.db"
	if os.Getenv("ENV") == "production" {
		dbPath = "/var/lib/gotutor/data/gotutor.db"
	}

	db, err := db.New(dbPath)
	if err != nil {
		logger.Fatal().Err(err).Msg("failed to create database")
	}
	if db == nil {
		logger.Fatal().Msg("database is unexpectedly nil")
	}
	defer db.Close()

	controller := controller.NewController(logger, cache, db)

	pprofPort := startPprof(logger)

	h := handler.NewHandler(logger, db, controller, pprofPort)

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", h.HandleHealthz)
	mux.HandleFunc("/GetExecutionSteps", h.HandleGetExecutionSteps)
	mux.HandleFunc("/compile", h.HandleCompile)
	mux.HandleFunc("/fmt", h.HandleFmt)
	mux.HandleFunc("/fix-code", h.HandleFixCode)
	mux.HandleFunc("/subscribe-email", h.HandleEmailSubscription)
	mux.HandleFunc("/unsubscribe", h.HandleUnsubscribe)
	mux.HandleFunc("/dashboard", h.HandleDashboard)

	srv := &http.Server{
		Addr:              fmt.Sprintf(":%d", _port),
		Handler:           handler.CorsMiddleware(mux),
		ReadHeaderTimeout: 30 * time.Second,
		ReadTimeout:       3 * time.Minute,
		WriteTimeout:      3 * time.Minute,
		IdleTimeout:       3 * time.Minute,
	}

	logger.Info().Msg(fmt.Sprintf("starting server on http://localhost:%d", _port))
	if err := srv.ListenAndServe(); err != nil {
		logger.Fatal().Err(err).Msg("failed to start server")
	}
}

// startPprof binds an unauthenticated pprof server to a random loopback port.
// Loopback-only is deliberate: pprof exposes goroutine dumps, heap, and
// /debug/pprof/cmdline (args/env), so it must never be reachable from the
// public interface. Remote access requires an SSH tunnel.
func startPprof(logger zerolog.Logger) int {
	mux := http.NewServeMux()
	mux.HandleFunc("/debug/pprof/", pprof.Index)
	mux.HandleFunc("/debug/pprof/cmdline", pprof.Cmdline)
	mux.HandleFunc("/debug/pprof/profile", pprof.Profile)
	mux.HandleFunc("/debug/pprof/symbol", pprof.Symbol)
	mux.HandleFunc("/debug/pprof/trace", pprof.Trace)

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		logger.Fatal().Err(err).Msg("failed to start pprof listener")
	}
	port := ln.Addr().(*net.TCPAddr).Port
	go func() {
		if err := http.Serve(ln, mux); err != nil {
			logger.Error().Err(err).Msg("pprof server stopped")
		}
	}()
	logger.Info().Int("port", port).Msg("pprof listening on 127.0.0.1")
	return port
}
