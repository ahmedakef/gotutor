package main

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
)

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
