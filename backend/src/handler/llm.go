package handler

import (
	"encoding/json"
	"net/http"
	"regexp"
	"strings"

	"github.com/ahmedakef/gotutor/backend/src/db"
	"github.com/tmc/langchaingo/llms/ollama"
)

// FixCodeRequest is the request for the FixCode method
type FixCodeRequest struct {
	SourceCode string `json:"source_code"`
	Error      string `json:"error,omitempty"`
}

// FixCodeResponse is the response for the FixCode method
type FixCodeResponse struct {
	FixedCode string `json:"fixed_code"`
}

// HandleFixCode handles the FixCode request using LLM
func (h *Handler) HandleFixCode(w http.ResponseWriter, r *http.Request) {
	h.logRequest(r)

	_, err := h.db.IncrementCallCounter(db.FixCode)
	if err != nil {
		h.logger.Err(err).Msg("failed to increment call counter")
	}

	var req FixCodeRequest
	err = json.NewDecoder(r.Body).Decode(&req)
	if err != nil {
		h.respondWithError(w, "failed to decode request", http.StatusBadRequest)
		return
	}

	if req.SourceCode == "" {
		h.respondWithError(w, "source_code is required", http.StatusBadRequest)
		return
	}

	// Initialize LLM
	llm, err := ollama.New(ollama.WithModel("stable-code:3b"))
	if err != nil {
		h.logger.Error().Err(err).Msg("failed to initialize LLM")
		h.respondWithError(w, "failed to initialize LLM", http.StatusInternalServerError)
		return
	}

	// Create prompt for fixing code
	prompt := "Fix this Go code and return the corrected version only"
	if req.Error != "" {
		prompt += ". The error encountered was: " + req.Error
	}
	prompt += ": `" + req.SourceCode + "`"

	// Call LLM
	resp, err := llm.Call(r.Context(), prompt)
	if err != nil {
		h.logger.Error().Err(err).Msg("failed to call LLM")
		h.respondWithError(w, "failed to process code with LLM: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// Clean up the response
	fixedCode := cleanCodeResponse(resp)

	h.writeJSONResponse(w, FixCodeResponse{FixedCode: fixedCode}, http.StatusOK)
}

// cleanCodeResponse extracts clean Go code from LLM response
func cleanCodeResponse(resp string) string {
	// Remove markdown code blocks
	re := regexp.MustCompile("```(?:go)?\n?(.*?)\n?```")
	matches := re.FindStringSubmatch(resp)
	if len(matches) > 1 {
		resp = matches[1]
	}

	// Split by lines and find the code section
	lines := strings.Split(resp, "\n")
	var codeLines []string
	inCode := false

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)

		// Start collecting when we see "package main"
		if strings.HasPrefix(trimmed, "package main") {
			inCode = true
			codeLines = append(codeLines, line)
			continue
		}

		// Stop collecting when we hit explanation text
		if inCode && (strings.HasPrefix(trimmed, "Explanation:") ||
			strings.HasPrefix(trimmed, "```") ||
			strings.HasPrefix(trimmed, "Here's") ||
			strings.HasPrefix(trimmed, "This corrected") ||
			strings.HasPrefix(trimmed, "*")) {
			break
		}

		// Collect code lines
		if inCode {
			codeLines = append(codeLines, line)
		}
	}

	if len(codeLines) > 0 {
		return strings.Join(codeLines, "\n")
	}

	return resp
}
