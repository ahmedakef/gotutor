package controller

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"text/template"
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

var playgroundTemplate = template.Must(template.ParseFiles("playground.txt"))

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
		return nil, err
	}
	if br.errorMessage != "" {
		return nil, errors.New(removeBanner(br.errorMessage))
	}

	binary, err := readFileToString(br.exePath)
	if err != nil {
		return nil, fmt.Errorf("failed to read binary: %w", err)
	}

	file, err := os.Create("playground_output.txt")
	if err != nil {
		return nil, fmt.Errorf("failed to create playground output file: %w", err)
	}
	defer file.Close()

	playgroundTemplate.Execute(file, map[string]interface{}{
		"binary": binary,
	})

	return &serialize.ExecutionResponse{}, nil

}
