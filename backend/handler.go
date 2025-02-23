package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/ahmedakef/gotutor/serialize"
	"github.com/rs/zerolog"
	"golang.org/x/exp/rand"
	"golang.org/x/sync/semaphore"
)

const _allowedConcurrency = 100

// Handler is a struct which represents the backend handler
type Handler struct {
	logger zerolog.Logger
}

func newHandler(logger zerolog.Logger) *Handler {
	return &Handler{
		logger: logger,
	}
}

type GetExecutionStepsRequest struct {
	SourceCode string `json:"source_code"`
}

func (h *Handler) GetExecutionSteps(ctx context.Context, req GetExecutionStepsRequest) (serialize.ExecutionResponse, error) {
	sem := semaphore.NewWeighted(_allowedConcurrency)

	if err := sem.Acquire(ctx, 1); err != nil {
		return serialize.ExecutionResponse{}, fmt.Errorf("failed to acquire semaphore: %w", err)
	}
	defer sem.Release(1)

	port := generateRandomPort()
	dataDir, err := prepareTempDir(port)
	if err != nil {
		return serialize.ExecutionResponse{}, fmt.Errorf("failed to prepare sources directory: %w", err)
	}
	defer func() {
		err := os.RemoveAll(dataDir)
		if err != nil {
			h.logger.Error().Err(err).Msg("failed to remove sources directory")
		}
	}()
	sourcePath := fmt.Sprintf("%s/main.go", dataDir)
	err = writeSourceCodeToFile(sourcePath, req.SourceCode)
	if err != nil {
		return serialize.ExecutionResponse{}, fmt.Errorf("failed to write source code to file: %w", err)
	}

	currentDir, err := os.Getwd()
	if err != nil {
		return serialize.ExecutionResponse{}, fmt.Errorf("failed to get current directory: %w", err)
	}
	sourceCodeMapping := fmt.Sprintf("%s/%s:/data/main.go", currentDir, sourcePath)
	outputMapping := fmt.Sprintf("%s/%s/output:/root/output", currentDir, dataDir)
	deadlineCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	dockerCommand := exec.CommandContext(deadlineCtx, "docker", "run", "--rm", "-v", sourceCodeMapping, "-v", outputMapping, "ahmedakef/gotutor", "debug", "/data/main.go")
	out, err := dockerCommand.CombinedOutput()
	if err != nil || outputContainsError(string(out)) {
		if deadlineCtx.Err() == context.DeadlineExceeded {
			return serialize.ExecutionResponse{}, fmt.Errorf("execution timed out, remove infinte loops or long waiting times")
		}
		return serialize.ExecutionResponse{}, fmt.Errorf("failed to run docker command: %w : %s", err, string(out))
	}

	output, err := readFileToString(fmt.Sprintf("%s/output/steps.json", dataDir))
	if err != nil {
		return serialize.ExecutionResponse{}, fmt.Errorf("failed to read output file: %w", err)
	}
	// decode the output
	var response serialize.ExecutionResponse
	err = json.NewDecoder(strings.NewReader(output)).Decode(&response)
	if err != nil {
		return serialize.ExecutionResponse{}, fmt.Errorf("failed to decode output: %w", err)
	}
	response.Output = string(out)
	return response, nil
}

func generateRandomPort() int {
	rand.Seed(uint64(time.Now().UnixNano()))
	return rand.Intn(65535-1024) + 1024
}

func prepareTempDir(randomPort int) (string, error) {
	dir := fmt.Sprintf("data/%d", randomPort)
	err := os.MkdirAll(dir, os.ModePerm)
	if err != nil {
		return "", fmt.Errorf("create sources directory: %w", err)
	}
	return dir, nil
}

func writeSourceCodeToFile(sourcePath, sourceCode string) error {
	file, err := os.OpenFile(sourcePath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0644)
	if err != nil {
		return fmt.Errorf("create %s file: %w", sourcePath, err)
	}
	defer file.Close()

	_, err = file.WriteString(sourceCode)
	if err != nil {
		return fmt.Errorf("write to %s file: %w", sourcePath, err)
	}
	return nil
}

func readFileToString(filePath string) (string, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return "", fmt.Errorf("open %s file: %w", filePath, err)
	}
	defer file.Close()

	contents, err := io.ReadAll(file)
	if err != nil {
		return "", fmt.Errorf("read %s file: %w", filePath, err)
	}
	return string(contents), nil
}

func outputContainsError(output string) bool {
	return strings.Contains(output, "failed to build binary")
}
