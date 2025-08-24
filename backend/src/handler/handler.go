package handler

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"

	"github.com/ahmedakef/gotutor/backend/src/controller"
	"github.com/ahmedakef/gotutor/backend/src/db"
	"github.com/rs/zerolog"
)

type Handler struct {
	logger     zerolog.Logger
	db         *db.DB
	controller *controller.Controller
}

// NewHandler creates a new Handler
func NewHandler(logger zerolog.Logger, db *db.DB, controller *controller.Controller) *Handler {
	return &Handler{
		logger:     logger,
		db:         db,
		controller: controller,
	}
}

// writeJSONResponse JSON-encodes resp and writes to w with the given HTTP
// status.
func (h *Handler) writeJSONResponse(w http.ResponseWriter, resp interface{}, status int) {
	w.Header().Set("Content-Type", "application/json")
	var buf bytes.Buffer
	if err := json.NewEncoder(&buf).Encode(resp); err != nil {
		h.logger.Error().Err(err).Msg("error encoding response")
		http.Error(w, http.StatusText(http.StatusInternalServerError), http.StatusInternalServerError)
		return
	}
	w.WriteHeader(status)
	if _, err := io.Copy(w, &buf); err != nil {
		h.logger.Error().Err(err).Msg("io.Copy(w, &buf)")
		return
	}
}

// ErrorResponse is the response in case of an error
type ErrorResponse struct {
	Error string `json:"error"`
}

func (h *Handler) respondWithError(w http.ResponseWriter, message string, statusCode int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(ErrorResponse{Error: message})
}

func (h *Handler) logRequest(r *http.Request) {
	h.logger.Info().Strs("X-Real-Ip", r.Header["X-Real-Ip"]).Msg("request received")
}

// GetExecutionStepsRequest is the request for the GetExecutionSteps method
type GetExecutionStepsRequest struct {
	SourceCode string `json:"source_code"`
}

// HandleGetExecutionSteps handles the GetExecutionSteps request
func (h *Handler) HandleGetExecutionSteps(w http.ResponseWriter, r *http.Request) {
	h.logRequest(r)

	var req GetExecutionStepsRequest
	err := json.NewDecoder(r.Body).Decode(&req)
	if err != nil {
		h.respondWithError(w, "failed to decode request", http.StatusBadRequest)
		return
	}

	resp, err := h.controller.GetExecutionSteps(r.Context(), req.SourceCode)
	if err != nil {
		h.respondWithError(w, err.Error(), http.StatusInternalServerError)
		return
	}

	h.writeJSONResponse(w, resp, http.StatusOK)
}

// CompileRequest is the request for the Compile method
type CompileRequest struct {
	SourceCode string `json:"source_code"`
}

// HandleCompile handles the Compile request
func (h *Handler) HandleCompile(w http.ResponseWriter, r *http.Request) {
	h.logRequest(r)

	var req CompileRequest
	err := json.NewDecoder(r.Body).Decode(&req)
	if err != nil {
		h.respondWithError(w, "failed to decode request", http.StatusBadRequest)
		return
	}

	resp, err := h.controller.Compile(r.Context(), req.SourceCode)
	if err != nil {
		h.respondWithError(w, err.Error(), http.StatusInternalServerError)
		return
	}

	h.writeJSONResponse(w, resp, http.StatusOK)
}
