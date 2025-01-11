package main

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/ahmedakef/gotutor/dlv"
	"github.com/ahmedakef/gotutor/gateway"
	"github.com/ahmedakef/gotutor/serialize"
	"github.com/go-delve/delve/pkg/gobuild"
	restate "github.com/restatedev/sdk-go"
	"github.com/rs/zerolog"
	"golang.org/x/exp/rand"
	"gopkg.in/square/go-jose.v2/json"
)

// Handler is a struct which represents a Restate service; reflection will turn exported methods into service handlers
type Handler struct {
	logger zerolog.Logger
}

func newHandler() *Handler {
	logger := zerolog.New(
		zerolog.ConsoleWriter{Out: os.Stderr, TimeFormat: time.RFC3339},
	).Level(zerolog.TraceLevel).With().Timestamp().Caller().Logger()
	return &Handler{
		logger: logger,
	}
}

type GetExecutionStepsRequest struct {
	SourceCode string `json:"source_code"`
}

func (h *Handler) GetExecutionSteps(ctx restate.Context, req GetExecutionStepsRequest) ([]serialize.Step, error) {
	port := generateRandomPort()
	addr := fmt.Sprintf(":%d", port)
	dir := fmt.Sprintf("sources/%d", port)
	err := os.MkdirAll(fmt.Sprintf("sources/%d", port), os.ModePerm)
	if err != nil {
		return nil, restate.TerminalError(fmt.Errorf("failed to create sources directory: %w", err))
	}
	// wrtie the source code to a file
	sourcePath := fmt.Sprintf("%s/main.go", dir)
	file, err := os.OpenFile(sourcePath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0644)
	if err != nil {
		return nil, restate.TerminalError(fmt.Errorf("failed to create %s file: %w", sourcePath, err))
	}
	_, err = file.WriteString(req.SourceCode)
	if err != nil {
		return nil, restate.TerminalError(fmt.Errorf("failed to write to %s file: %w", sourcePath, err))
	}
	defer file.Close()
	// delete the file after the function returns
	defer func() {
		err := os.Remove(sourcePath)
		if err != nil {
			h.logger.Error().Err(err).Msg("failed to remove source file")
		}
	}()

	binaryPath, err := dlv.Build(sourcePath, dir)
	if binaryPath != "" {
		defer gobuild.Remove(binaryPath)
	}
	if err != nil {
		return nil, restate.TerminalError(fmt.Errorf("failed to build binary: %w", err))
	}

	debugServerErr := make(chan error, 1)
	go func() {
		err := dlv.RunDebugServer(binaryPath, addr)
		debugServerErr <- err
	}()
	time.Sleep(1 * time.Second)

	multipleGoroutines := false
	steps, err := h.getSteps(ctx, addr, multipleGoroutines)
	if err != nil {
		return nil, restate.TerminalError(fmt.Errorf("get and write steps: %w", err))
	}

	select {
	case err := <-debugServerErr:
		if err != nil {
			h.logger.Error().Err(err).Msg("debugServer error occurred")
		}
	default:
	}
	h.logger.Info().Msg("execution steps retrieved successfully")
	ss, _ := json.Marshal(steps)
	h.logger.Info().Msg(string(ss))
	// Respond to caller
	return steps, nil
}

func (h *Handler) getSteps(ctx context.Context, addr string, multipleGoroutines bool) ([]serialize.Step, error) {
	client, err := h.dlvGatewayClient(addr)
	if err != nil {
		return nil, fmt.Errorf("create dlvGatewayClient: %w", err)
	}

	defer func() {
		h.logger.Info().Msg("killing the debugger")
		err = client.Detach(true)
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

func (h *Handler) dlvGatewayClient(addr string) (*gateway.Debug, error) {
	rpcClient, err := dlv.Connect(addr)
	if err != nil {
		return nil, fmt.Errorf("connect to server: %w", err)
	}
	client := gateway.NewDebug(rpcClient)
	return client, nil

}

func generateRandomPort() int {
	rand.Seed(uint64(time.Now().UnixNano()))
	return rand.Intn(65535-1024) + 1024
}
