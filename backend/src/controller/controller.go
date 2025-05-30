package controller

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/ahmedakef/gotutor/backend/src/cache"
	"github.com/ahmedakef/gotutor/backend/src/db"
	"github.com/ahmedakef/gotutor/serialize"
	"github.com/rs/zerolog"
	"golang.org/x/sync/semaphore"
)

const (
	_allowedConcurrency = 10
)

// Handler is a struct which represents the backend handler
type Controller struct {
	logger zerolog.Logger
	cache  cache.LRUCache
	db     *db.DB
	sem    *semaphore.Weighted
}

// NewController creates a new controller
func NewController(logger zerolog.Logger, cache cache.LRUCache, db *db.DB) *Controller {
	return &Controller{
		logger: logger,
		cache:  cache,
		db:     db,
		sem:    semaphore.NewWeighted(_allowedConcurrency),
	}
}

// GetExecutionSteps gets the execution steps for the given source code
func (c *Controller) GetExecutionSteps(ctx context.Context, sourceCode string) (serialize.ExecutionResponse, error) {
	_, err := c.db.IncrementCallCounter(db.GetExecutionSteps)
	if err != nil {
		c.logger.Err(err).Msg("failed to increment call counter")
	}

	// check if the request is already in the cache
	cachedResponse, ok := c.cache.Get(sourceCode)
	if ok {
		c.logger.Info().Msg("cache hit")
		return cachedResponse, nil
	}

	if err := c.sem.Acquire(ctx, 1); err != nil {
		return serialize.ExecutionResponse{}, fmt.Errorf("failed to acquire semaphore: %w", err)
	}
	defer c.sem.Release(1)

	if err := c.db.SaveSourceCode(sourceCode); err != nil {
		c.logger.Err(err).Msg("failed to save source code")
	}

	tmpDir, err := os.MkdirTemp("", "sandbox")
	if err != nil {
		return serialize.ExecutionResponse{}, fmt.Errorf("error creating temp directory: %v", err)
	}

	defer func() {
		err := os.RemoveAll(tmpDir)
		if err != nil {
			c.logger.Error().Err(err).Msg("failed to remove sources directory")
		}
	}()
	sourcePath := fmt.Sprintf("%s/main.go", tmpDir)
	err = writeSourceCodeToFile(sourcePath, sourceCode)
	if err != nil {
		return serialize.ExecutionResponse{}, fmt.Errorf("failed to write source code to file: %w", err)
	}

	sourceCodeMapping := fmt.Sprintf("%s:/data/main.go", sourcePath)
	outputMapping := fmt.Sprintf("%s:/root/output", tmpDir)
	deadlineCtx, cancel := context.WithTimeout(ctx, 300*time.Second)
	defer cancel()
	dockerCommand := exec.CommandContext(deadlineCtx, "docker", "run", "--rm", "--network", "none", "-v", sourceCodeMapping, "-v", outputMapping, "ahmedakef/gotutor", "debug", "/data/main.go")
	dockerOut, err := dockerCommand.CombinedOutput()
	if err != nil {
		return serialize.ExecutionResponse{}, fmt.Errorf("failed to run docker command: %w : %s", err, string(dockerOut))
	}
	if outputSanitized, ok := outputContainsError(string(dockerOut)); ok {
		return serialize.ExecutionResponse{}, errors.New(outputSanitized)
	}

	stepsStr, err := readFileToString(fmt.Sprintf("%s/steps.json", tmpDir))
	if err != nil {
		return serialize.ExecutionResponse{}, fmt.Errorf("failed to read output file: %w, dockerOut: %s", err, string(dockerOut))
	}
	// decode the output
	var response serialize.ExecutionResponse
	err = json.NewDecoder(strings.NewReader(stepsStr)).Decode(&response)
	if err != nil {
		return serialize.ExecutionResponse{}, fmt.Errorf("failed to decode output: %w", err)
	}

	c.cache.Set(sourceCode, response)
	return response, nil
}

// Compile compiles the given source code
func (c *Controller) Compile(ctx context.Context, sourceCode string) (*serialize.ExecutionResponse, error) {
	_, err := c.db.IncrementCallCounter(db.Compile)
	if err != nil {
		c.logger.Err(err).Msg("failed to increment call counter")
	}

	if err := c.sem.Acquire(ctx, 1); err != nil {
		return nil, fmt.Errorf("failed to acquire semaphore: %w", err)
	}
	defer c.sem.Release(1)

	tmpDir, err := os.MkdirTemp("", "sandbox")
	if err != nil {
		return nil, fmt.Errorf("error creating temp directory: %v", err)
	}
	defer func() {
		err := os.RemoveAll(tmpDir)
		if err != nil {
			c.logger.Error().Err(err).Msg("failed to remove sources directory")
		}
	}()

	br, err := c.sandboxBuild(ctx, tmpDir, []byte(sourceCode), false)
	if err != nil {
		return nil, fmt.Errorf("failed to build: %w", err)
	}
	if br.errorMessage != "" {
		return nil, errors.New(removeBanner(br.errorMessage))
	}

	execRes, err := c.sandboxRun(ctx, br.exePath, br.testParam)
	if err != nil {
		return nil, err
	}
	if execRes.Error != "" {
		return nil, errors.New(execRes.Error)
	}

	rec := new(Recorder)
	rec.Stdout().Write(execRes.Stdout)
	rec.Stderr().Write(execRes.Stderr)
	events, err := rec.Events()
	if err != nil {
		log.Printf("error decoding events: %v", err)
		return nil, fmt.Errorf("error decoding events: %v", err)
	}

	stdout, stderr := convertEventsToStdoutStderr(events)
	return &serialize.ExecutionResponse{
		Steps:  nil,
		StdOut: stdout,
		StdErr: stderr,
	}, nil
}

func convertEventsToStdoutStderr(events []Event) (stdout, stderr string) {
	for _, event := range events {
		if event.Kind == "stdout" {
			stdout += event.Message
		} else if event.Kind == "stderr" {
			stderr += event.Message
		}
	}
	return stdout, stderr
}
