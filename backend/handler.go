package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/ahmedakef/gotutor/serialize"
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
	dataDir, err := prepareTempDir(port)
	if err != nil {
		return nil, restate.TerminalError(fmt.Errorf("failed to prepare sources directory: %w", err), http.StatusInternalServerError)
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
		return nil, restate.TerminalError(fmt.Errorf("failed to write source code to file: %w", err), http.StatusInternalServerError)
	}

	currentDir, err := os.Getwd()
	if err != nil {
		return nil, restate.TerminalError(fmt.Errorf("failed to get current directory: %w", err), http.StatusInternalServerError)
	}
	sourceCodeMapping := fmt.Sprintf("%s/%s:/data/main.go", currentDir, sourcePath)
	outputMapping := fmt.Sprintf("%s/%s/output:/root/output", currentDir, dataDir)
	dockerCommand := exec.CommandContext(ctx, "docker", "run", "--rm", "-v", sourceCodeMapping, "-v", outputMapping, "ahmedakef/gotutor", "debug", "/data/main.go")
	out, err := dockerCommand.CombinedOutput()
	h.logger.Info().Msg(string(out))
	if err != nil {
		return nil, restate.TerminalError(fmt.Errorf("failed to run docker command: %w", err), http.StatusInternalServerError)
	}

	output, err := readFileToString(fmt.Sprintf("%s/output/steps.json", dataDir))
	if err != nil {
		return nil, restate.TerminalError(fmt.Errorf("failed to read output file: %w", err), http.StatusInternalServerError)
	}
	// decode the output
	var steps []serialize.Step
	err = json.NewDecoder(strings.NewReader(output)).Decode(&steps)
	if err != nil {
		return nil, restate.TerminalError(fmt.Errorf("failed to decode output: %w", err), http.StatusInternalServerError)
	}

	return steps, nil
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
