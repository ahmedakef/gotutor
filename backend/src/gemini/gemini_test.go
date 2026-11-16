package gemini

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func newTestClient(t *testing.T, handler http.HandlerFunc) *Client {
	t.Helper()
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	c := New("test-key", "")
	c.baseURL = srv.URL
	return c
}

func TestGenerate(t *testing.T) {
	t.Parallel()

	c := newTestClient(t, func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, "/models/"+DefaultModel+":generateContent", r.URL.Path)
		assert.Equal(t, "test-key", r.Header.Get("x-goog-api-key"))

		var req generateContentRequest
		require.NoError(t, json.NewDecoder(r.Body).Decode(&req))
		assert.Equal(t, "system", req.SystemInstruction.Parts[0].Text)
		assert.Equal(t, "user", req.Contents[0].Role)
		assert.Equal(t, "prompt", req.Contents[0].Parts[0].Text)

		_, _ = w.Write([]byte(`{"candidates":[{"content":{"role":"model","parts":[
			{"text":"thinking...","thought":true},
			{"text":"package main"},
			{"text":"\n"}
		]},"finishReason":"STOP"}]}`))
	})

	got, err := c.Generate(context.Background(), "system", "prompt")
	require.NoError(t, err)
	assert.Equal(t, "package main\n", got)
}

func TestGenerateErrors(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name      string
		status    int
		body      string
		wantErr   string
		rateLimit bool
	}{
		{
			name:      "rate_limited",
			status:    http.StatusTooManyRequests,
			body:      `{"error":{"code":429,"message":"quota exceeded","status":"RESOURCE_EXHAUSTED"}}`,
			wantErr:   "quota exceeded",
			rateLimit: true,
		},
		{
			name:    "server_error_without_json",
			status:  http.StatusInternalServerError,
			body:    `oops`,
			wantErr: "500 Internal Server Error",
		},
		{
			name:    "prompt_blocked",
			status:  http.StatusOK,
			body:    `{"promptFeedback":{"blockReason":"SAFETY"}}`,
			wantErr: "prompt blocked: SAFETY",
		},
		{
			name:    "no_candidates",
			status:  http.StatusOK,
			body:    `{"candidates":[]}`,
			wantErr: "no candidates",
		},
		{
			name:    "truncated",
			status:  http.StatusOK,
			body:    `{"candidates":[{"content":{"parts":[{"text":"package"}]},"finishReason":"MAX_TOKENS"}]}`,
			wantErr: "MAX_TOKENS",
		},
		{
			name:    "only_thoughts",
			status:  http.StatusOK,
			body:    `{"candidates":[{"content":{"parts":[{"text":"hmm","thought":true}]},"finishReason":"STOP"}]}`,
			wantErr: "no text",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			c := newTestClient(t, func(w http.ResponseWriter, _ *http.Request) {
				w.WriteHeader(tt.status)
				_, _ = w.Write([]byte(tt.body))
			})

			_, err := c.Generate(context.Background(), "", "prompt")
			require.Error(t, err)
			assert.Contains(t, err.Error(), tt.wantErr)
			assert.Equal(t, tt.rateLimit, errors.Is(err, ErrRateLimited))
		})
	}
}
