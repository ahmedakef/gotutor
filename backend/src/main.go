package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/ahmedakef/gotutor/backend/src/cache"
	"github.com/ahmedakef/gotutor/backend/src/db"
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

type ErrorResponse struct {
	Message string `json:"message"`
}

func respondWithError(w http.ResponseWriter, message string, statusCode int) {
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(ErrorResponse{Message: message})
}

func respondWithJSON(w http.ResponseWriter, data interface{}, statusCode int) error {
	w.WriteHeader(statusCode)
	return json.NewEncoder(w).Encode(data)
}

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

	handler := newHandler(logger, cache, db)

	mux := http.NewServeMux()
	mux.HandleFunc("/GetExecutionSteps", func(w http.ResponseWriter, r *http.Request) {
		logger.Info().Strs("X-Real-Ip", r.Header["X-Real-Ip"]).Msg("request received")

		var req GetExecutionStepsRequest
		err := json.NewDecoder(r.Body).Decode(&req)
		if err != nil {
			respondWithError(w, "failed to decode request", http.StatusBadRequest)
			return
		}

		resp, err := handler.GetExecutionSteps(r.Context(), req)
		if err != nil {
			respondWithError(w, err.Error(), http.StatusInternalServerError)
			return
		}

		err = respondWithJSON(w, resp, http.StatusOK)
		if err != nil {
			logger.Error().Err(err).Msg("failed to respond with JSON")
		}
	})

	logger.Info().Msg(fmt.Sprintf("starting server on http://localhost:%d", _port))
	if err := http.ListenAndServe(fmt.Sprintf(":%d", _port), corsMiddleware(mux)); err != nil {
		logger.Fatal().Err(err).Msg("failed to start server")
	}
}
