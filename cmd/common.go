package cmd

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/ahmedakef/gotutor/gateway"
	"github.com/ahmedakef/gotutor/serialize"
	"github.com/rs/zerolog"
)

func getAndWriteSteps(ctx context.Context, client *gateway.Debug, logger zerolog.Logger) error {

	defer func() {
		logger.Info().Msg("killing the debugger")
		err := client.Detach(true)
		if err != nil {
			logger.Error().Err(err).Msg("failed to halt the execution")
		}
	}()

	serializer := serialize.NewSerializer(client, logger)
	steps, err := serializer.ExecutionSteps(ctx)
	if err != nil {
		return fmt.Errorf("failed to get execution steps: %w", err)
	}
	// put the result in steps.json file
	file, err := os.OpenFile("steps.json", os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0644)
	if err != nil {
		return fmt.Errorf("failed to open steps.json file: %w", err)
	}
	defer file.Close()

	err = json.NewEncoder(file).Encode(steps)
	if err != nil {
		return fmt.Errorf("failed to encode steps: %w", err)
	}
	// Explicitly flush the file buffer
	err = file.Sync()
	if err != nil {
		return fmt.Errorf("failed to flush file buffer: %w", err)
	}
	return nil
}
