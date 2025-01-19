package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/ahmedakef/gotutor/dlv"
	"github.com/ahmedakef/gotutor/gateway"
	"github.com/ahmedakef/gotutor/serialize"
	"github.com/go-delve/delve/service/debugger"
	restate "github.com/restatedev/sdk-go"
	"github.com/rs/zerolog"
	"golang.org/x/exp/rand"
)

// Handler is a struct which represents a Restate service; reflection will turn exported methods into service handlers
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

func (h *Handler) GetExecutionSteps(ctx restate.Context, req GetExecutionStepsRequest) ([]serialize.Step, error) {
	port := generateRandomPort()
	dir, err := prepareTempDir(port)
	if err != nil {
		return nil, restate.TerminalError(fmt.Errorf("failed to prepare sources directory: %w", err), http.StatusInternalServerError)
	}
	defer func() {
		err := os.RemoveAll(dir)
		if err != nil {
			h.logger.Error().Err(err).Msg("failed to remove sources directory")
		}
	}()
	sourcePath := fmt.Sprintf("%s/main.go", dir)
	err = writeSourceCodeToFile(sourcePath, req.SourceCode)
	if err != nil {
		return nil, restate.TerminalError(fmt.Errorf("failed to write source code to file: %w", err), http.StatusInternalServerError)
	}

	binaryPath, err := dlv.Build(sourcePath, dir)
	if err != nil {
		return nil, restate.TerminalError(fmt.Errorf("failed to build binary: %w", err), http.StatusBadRequest)
	}
	client, err := dlv.RunServerAndGetClient(binaryPath, sourcePath, dlv.GetBuildFlags(), debugger.ExecutingGeneratedFile)
	if err != nil {
		return nil, restate.TerminalError(fmt.Errorf("runServerAndGetClient: %w", err), http.StatusInternalServerError)
	}

	multipleGoroutines := false
	steps, err := h.getSteps(ctx, client, multipleGoroutines)
	if err != nil {
		return nil, fmt.Errorf("get and write steps: %w", err)
	}

	return steps, nil
}

func (h *Handler) getSteps(ctx context.Context, client *gateway.Debug, multipleGoroutines bool) ([]serialize.Step, error) {

	defer func() {
		h.logger.Info().Msg("killing the debugger")
		err := client.Detach(true)
		if err != nil {
			h.logger.Error().Err(err).Msg("Halt the execution")
		}
	}()

	serializer := serialize.NewSerializer(client, h.logger, multipleGoroutines)
	steps, err := serializer.ExecutionSteps(ctx)
	if err != nil {
		return nil, fmt.Errorf("get execution steps: %w", err)
	}
	return steps, nil
}

func generateRandomPort() int {
	rand.Seed(uint64(time.Now().UnixNano()))
	return rand.Intn(65535-1024) + 1024
}

func prepareTempDir(randomPort int) (string, error) {
	dir := fmt.Sprintf("sources/%d/", randomPort)
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
