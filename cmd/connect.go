/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"context"
	"fmt"

	"github.com/ahmedakef/gotutor/dlv"
	"github.com/rs/zerolog"
	"github.com/spf13/cobra"
)

// connectCmd represents the connect command
var connectCmd = &cobra.Command{
	Use:   "connect",
	Short: "A brief description of your command",
	Long: `A longer description that spans multiple lines and likely contains examples
and usage of using your command. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.`,
	RunE: connect,
}

func connect(cmd *cobra.Command, args []string) error {
	ctx, cancel := context.WithCancel(cmd.Context())
	defer cancel()
	logger := ctx.Value(loggerKey).(zerolog.Logger)
	multipleGoroutines, err := cmd.Flags().GetBool("multiple-goroutines")
	if err != nil {
		return fmt.Errorf("failed to get multiple-goroutines flag: %w", err)
	}

	addr, err := cmd.Flags().GetString("address")
	if err != nil {
		return fmt.Errorf("failed to get address flag: %w", err)
	}

	client, err := dlv.Connect(addr)
	if err != nil {
		logger.Error().Err(err).Msg("failed to connect to server")
		return nil
	}

	err = getAndWriteSteps(ctx, client, logger, multipleGoroutines)
	if err != nil {
		logger.Error().Err(err).Msg("getAndWriteSteps")
		return nil
	}
	return nil
}

func init() {
	connectCmd.Flags().String("address", ":8083", "address of the server to connect to")
	rootCmd.AddCommand(connectCmd)
}
