/*
Copyright © 2024 Ahmed Akef aemed.akef.1@gmail.com
*/
package cmd

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/ahmedakef/gotutor/serialize"

	"github.com/ahmedakef/gotutor/gateway"

	"github.com/ahmedakef/gotutor/dlv"

	"github.com/rs/zerolog"
	"github.com/spf13/cobra"
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "gotutor",
	Short: "A brief description of your application",
	Long: `A longer description that spans multiple lines and likely contains
examples and usage of using your application. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.`,
	PersistentPreRun: func(cmd *cobra.Command, args []string) {
		logger := zerolog.New(
			zerolog.ConsoleWriter{Out: os.Stderr, TimeFormat: time.RFC3339},
		).Level(zerolog.TraceLevel).With().Timestamp().Caller().Logger()

		ctx := context.WithValue(context.Background(), "logger", logger)
		cmd.SetContext(ctx)
	},
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}

func init() {
	rootCmd.PersistentFlags().Bool("multiple-goroutines", false, "handle multiple goroutines // not well supported yet")
}

func dlvGatewayClient(logger zerolog.Logger) (*gateway.Debug, error) {
	rpcClient, err := dlv.Connect(addr)
	if err != nil {
		logger.Error().Err(err).Msg("failed to connect to server")
		return nil, fmt.Errorf("failed to connect to server: %w", err)
	}
	client := gateway.NewDebug(rpcClient)
	return client, nil

}

func getAndWriteSteps(ctx context.Context, logger zerolog.Logger, multipleGoroutines bool) error {
	client, err := dlvGatewayClient(logger)
	if err != nil {
		return fmt.Errorf("failed to create dlvGatewayClient: %w", err)
	}

	defer func() {
		logger.Info().Msg("killing the debugger")
		err = client.Detach(true)
		if err != nil {
			logger.Error().Err(err).Msg("failed to halt the execution")
		}
	}()

	serializer := serialize.NewSerializer(client, logger, multipleGoroutines)
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
