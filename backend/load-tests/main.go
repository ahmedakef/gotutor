package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/rs/zerolog"
)

const conccurentRequests = 100

type GetExecutionStepsRequest struct {
	SourceCode string `json:"source_code"`
}

func main() {
	logger := zerolog.New(
		zerolog.ConsoleWriter{Out: os.Stderr, TimeFormat: time.RFC3339},
	).Level(zerolog.InfoLevel).With().Timestamp().Caller().Logger()

	sourceCode, err := readFileToString("main.txt")
	if err != nil {
		logger.Error().Err(err).Msg("failed to read source code")
		return
	}

	var wg sync.WaitGroup
	url := "https://backend.gotutor.dev/GetExecutionSteps"
	failedRequests := 0
	for range conccurentRequests {
		wg.Add(1)
		go func() {
			defer wg.Done()
			requestBody := GetExecutionStepsRequest{
				SourceCode: sourceCode,
			}
			jsonBody, err := json.Marshal(requestBody)
			if err != nil {
				logger.Error().Err(err).Msg("failed to marshal request body")
				return
			}

			resp, err := http.Post(url, "application/json", bytes.NewBuffer(jsonBody))
			if err != nil {
				logger.Error().Err(err).Msg("failed to send request")
				return
			}
			if resp.StatusCode != http.StatusOK {
				failedRequests += 1
				logger.Error().Str("status", resp.Status).Msg("unexpected status code")
				responseBody, err := io.ReadAll(resp.Body)
				if err != nil {
					logger.Error().Err(err).Msg("failed to read response body")
				}
				logger.Info().Msg(string(responseBody))
			}
			defer resp.Body.Close()

		}()
	}

	wg.Wait()
	logger.Info().Int("succeededReqeusts", conccurentRequests-failedRequests).Msg("finished")

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
