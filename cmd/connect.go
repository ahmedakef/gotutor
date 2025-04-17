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
	Short: "Connect to a headless debug server with a terminal client.",
	Long:  `Connect to a running headless debug server with a terminal client. Prefix with 'unix:' to use a unix domain socket.`,
	RunE:  connect,
}

func connect(cmd *cobra.Command, args []string) error {
	ctx, cancel := context.WithCancel(cmd.Context())
	defer cancel()
	logger := ctx.Value(loggerKey).(zerolog.Logger)

	addr, err := cmd.Flags().GetString("address")
	if err != nil {
		return fmt.Errorf("failed to get address flag: %w", err)
	}

	client, err := dlv.Connect(addr)
	if err != nil {
		logger.Error().Err(err).Msg("failed to connect to server")
		return nil
	}

	err = getAndWriteSteps(ctx, client, logger)
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
