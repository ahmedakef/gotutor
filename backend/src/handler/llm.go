package handler

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/ahmedakef/gotutor/backend/src/db"
	"github.com/ahmedakef/gotutor/backend/src/gemini"
)

const (
	_fixCodeLimitPerIP  = 10
	_fixCodeLimitWindow = time.Hour

	_fixCodeSystemInstruction = "You fix Go programs for GoTutor, a tool that shows how Go programs execute step by step. " +
		"Reply with the complete corrected program as one Go file inside a single ```go code block, and nothing else. " +
		"Change only what is needed to fix the program, and keep its structure, names and comments."
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

	if h.gemini == nil {
		h.respondWithError(w, "fixing code with AI is not available on this server", http.StatusServiceUnavailable)
		return
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

	if !h.fixCodeLimiter.Allow(clientIP(r)) {
		msg := fmt.Sprintf("you can fix code with AI up to %d times per hour, try again later", _fixCodeLimitPerIP)
		h.respondWithError(w, msg, http.StatusTooManyRequests)
		return
	}

	resp, err := h.gemini.Generate(r.Context(), _fixCodeSystemInstruction, fixCodePrompt(req.SourceCode, req.Error))
	if errors.Is(err, gemini.ErrRateLimited) {
		h.logger.Warn().Err(err).Str("model", h.gemini.Model()).Msg("LLM quota exhausted")
		h.respondWithError(w, "the AI service has reached its usage limit, try again later", http.StatusTooManyRequests)
		return
	}
	if err != nil {
		h.logger.Error().Err(err).Str("model", h.gemini.Model()).Msg("failed to call LLM")
		h.respondWithError(w, "failed to get a fix from the AI service, try again later", http.StatusBadGateway)
		return
	}

	// Clean up the response
	fixedCode := cleanCodeResponse(resp)

	h.writeJSONResponse(w, FixCodeResponse{FixedCode: fixedCode}, http.StatusOK)
}

// fixCodePrompt builds the user prompt from the program and, if the frontend
// sent one, the error it produced.
func fixCodePrompt(sourceCode, errMsg string) string {
	var b strings.Builder
	if errMsg != "" {
		b.WriteString("This Go program fails with the following error:\n```\n")
		b.WriteString(errMsg)
		b.WriteString("\n```\n\nFix it.")
	} else {
		b.WriteString("Find and fix the bugs in this Go program.")
	}
	b.WriteString("\n\n```go\n")
	b.WriteString(sourceCode)
	b.WriteString("\n```")
	return b.String()
}

// cleanCodeResponse extracts clean Go code from LLM response
func cleanCodeResponse(resp string) string {
	resp = strings.TrimSpace(resp)

	// Markdown fences often wrap multiline code; "." must match newlines (?s).
	re := regexp.MustCompile("(?s)```(?:golang|go)?\\s*\\r?\\n?(.*?)```")
	if m := re.FindStringSubmatch(resp); len(m) > 1 {
		if inner := strings.TrimSpace(m[1]); inner != "" {
			return inner
		}
	}

	// No usable fenced block: scan for a Go snippet (not only full packages).
	lines := strings.Split(resp, "\n")
	var codeLines []string
	inCode := false

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)

		if !inCode {
			if strings.HasPrefix(trimmed, "package ") {
				inCode = true
			} else if strings.HasPrefix(trimmed, "func ") || strings.HasPrefix(trimmed, "import ") {
				inCode = true
			}
			if inCode {
				codeLines = append(codeLines, line)
			}
			continue
		}

		if strings.HasPrefix(trimmed, "Explanation:") ||
			strings.HasPrefix(trimmed, "```") ||
			strings.HasPrefix(trimmed, "Here's") ||
			strings.HasPrefix(trimmed, "This corrected") ||
			strings.HasPrefix(trimmed, "*") {
			break
		}

		codeLines = append(codeLines, line)
	}

	if len(codeLines) > 0 {
		return strings.TrimSpace(strings.Join(codeLines, "\n"))
	}

	return resp
}
