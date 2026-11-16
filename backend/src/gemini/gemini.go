// Package gemini is a minimal client for the Gemini API generateContent
// endpoint.
package gemini

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"
)

const (
	// DefaultModel has the largest daily request quota on the free tier.
	DefaultModel = "gemini-3.5-flash-lite"

	_defaultBaseURL = "https://generativelanguage.googleapis.com/v1beta"
	_requestTimeout = 90 * time.Second
)

// ErrRateLimited is returned when the API key has used up its quota.
var ErrRateLimited = errors.New("gemini rate limit exceeded")

// Client calls a single Gemini model.
type Client struct {
	apiKey     string
	model      string
	baseURL    string
	httpClient *http.Client
}

// New creates a Client. An empty model selects DefaultModel.
func New(apiKey, model string) *Client {
	if model == "" {
		model = DefaultModel
	}
	return &Client{
		apiKey:     apiKey,
		model:      model,
		baseURL:    _defaultBaseURL,
		httpClient: &http.Client{Timeout: _requestTimeout},
	}
}

// Model returns the name of the model the client calls.
func (c *Client) Model() string {
	return c.model
}

type part struct {
	Text    string `json:"text"`
	Thought bool   `json:"thought,omitempty"`
}

type content struct {
	Role  string `json:"role,omitempty"`
	Parts []part `json:"parts"`
}

type generateContentRequest struct {
	SystemInstruction *content  `json:"systemInstruction,omitempty"`
	Contents          []content `json:"contents"`
}

type generateContentResponse struct {
	Candidates []struct {
		Content      content `json:"content"`
		FinishReason string  `json:"finishReason"`
	} `json:"candidates"`
	PromptFeedback struct {
		BlockReason string `json:"blockReason"`
	} `json:"promptFeedback"`
}

type errorResponse struct {
	Error struct {
		Message string `json:"message"`
		Status  string `json:"status"`
	} `json:"error"`
}

// Generate sends one user prompt with a system instruction and returns the
// model's text answer.
func (c *Client) Generate(ctx context.Context, systemInstruction, prompt string) (string, error) {
	reqBody := generateContentRequest{
		Contents: []content{{Role: "user", Parts: []part{{Text: prompt}}}},
	}
	if systemInstruction != "" {
		reqBody.SystemInstruction = &content{Parts: []part{{Text: systemInstruction}}}
	}
	body, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("marshal request: %w", err)
	}

	url := fmt.Sprintf("%s/models/%s:generateContent", c.baseURL, c.model)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return "", fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-goog-api-key", c.apiKey)

	res, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("POST %s: %w", url, err)
	}
	defer res.Body.Close()

	if res.StatusCode != http.StatusOK {
		var errResp errorResponse
		// The message is only extra detail, so a body that doesn't decode
		// still leaves the status code to report.
		_ = json.NewDecoder(res.Body).Decode(&errResp)
		if res.StatusCode == http.StatusTooManyRequests {
			return "", fmt.Errorf("%w: %s", ErrRateLimited, errResp.Error.Message)
		}
		return "", fmt.Errorf("unexpected response from gemini: %s: %s", res.Status, errResp.Error.Message)
	}

	var resp generateContentResponse
	if err := json.NewDecoder(res.Body).Decode(&resp); err != nil {
		return "", fmt.Errorf("decode response: %w", err)
	}
	if resp.PromptFeedback.BlockReason != "" {
		return "", fmt.Errorf("prompt blocked: %s", resp.PromptFeedback.BlockReason)
	}
	if len(resp.Candidates) == 0 {
		return "", errors.New("response has no candidates")
	}

	candidate := resp.Candidates[0]
	// A truncated answer would replace the user's code with half a program.
	if candidate.FinishReason != "" && candidate.FinishReason != "STOP" {
		return "", fmt.Errorf("generation stopped early: %s", candidate.FinishReason)
	}

	var text strings.Builder
	for _, p := range candidate.Content.Parts {
		if !p.Thought {
			text.WriteString(p.Text)
		}
	}
	if text.Len() == 0 {
		return "", errors.New("response has no text")
	}
	return text.String(), nil
}
