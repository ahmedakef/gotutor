package main

import (
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/ahmedakef/gotutor/backend/src/cache"
	"github.com/ahmedakef/gotutor/backend/src/controller"
	"github.com/ahmedakef/gotutor/backend/src/db"
	"github.com/ahmedakef/gotutor/backend/src/handler"
	"github.com/rs/zerolog"
)

const (
	_port             = 8080
	_maxCacheSize     = 250 * 1024 * 1024 // 100MB
	_maxCacheItems    = 100
	_cacheTTL         = 0
	_callsBucket      = "GetExecutionStepsCalls"
	_sourceCodeBucket = "SourceCode"
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
		logger.Info().Err(err).Msg("failed to create database")
	}
	defer db.Close()

	controller := controller.NewController(logger, cache, db)
	h := handler.NewHandler(logger, db, controller)

	mux := http.NewServeMux()
	mux.HandleFunc("/GetExecutionSteps", h.HandleGetExecutionSteps)
	mux.HandleFunc("/compile", h.HandleCompile)
	mux.HandleFunc("/fmt", h.HandleFmt)

	logger.Info().Msg(fmt.Sprintf("starting server on http://localhost:%d", _port))
	if err := http.ListenAndServe(fmt.Sprintf(":%d", _port), handler.CorsMiddleware(mux)); err != nil {
		logger.Fatal().Err(err).Msg("failed to start server")
	}
}
