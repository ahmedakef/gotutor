package controller

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/ahmedakef/gotutor/backend/src/sandbox/sandboxtypes"
)

const (
	maxRunTime        = 5 * time.Second
	sandboxBackendURL = "http://localhost:9090/run"
	runTimeoutError   = "timeout running program"
)

// sandboxRun runs a Go binary in a sandbox environment.
func (c *Controller) sandboxRun(ctx context.Context, exePath, testParam string) (execRes sandboxtypes.Response, err error) {

	exeBytes, err := os.ReadFile(exePath)
	if err != nil {
		return execRes, err
	}
	ctx, cancel := context.WithTimeout(ctx, maxRunTime)
	defer cancel()
	sreq, err := http.NewRequestWithContext(ctx, "POST", sandboxBackendURL, bytes.NewReader(exeBytes))
	if err != nil {
		return execRes, fmt.Errorf("NewRequestWithContext %q: %w", sandboxBackendURL, err)
	}
	sreq.Header.Add("Idempotency-Key", "1") // lets Transport do retries with a POST
	if testParam != "" {
		sreq.Header.Add("X-Argument", testParam)
	}
	sreq.GetBody = func() (io.ReadCloser, error) { return io.NopCloser(bytes.NewReader(exeBytes)), nil }
	res, err := http.DefaultClient.Do(sreq)
	if err != nil {
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			execRes.Error = runTimeoutError
			return execRes, nil
		}
		return execRes, fmt.Errorf("POST %q: %w", sandboxBackendURL, err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		log.Printf("unexpected response from backend: %v", res.Status)
		return execRes, fmt.Errorf("unexpected response from backend: %v", res.Status)
	}
	if err := json.NewDecoder(res.Body).Decode(&execRes); err != nil {
		log.Printf("JSON decode error from backend: %v", err)
		return execRes, errors.New("error parsing JSON from backend")
	}
	return execRes, nil
}
