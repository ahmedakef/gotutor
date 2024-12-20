/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"context"
	"fmt"
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
	logger := ctx.Value("logger").(zerolog.Logger)
	multipleGoroutines, err := cmd.Flags().GetBool("multiple-goroutines")
	if err != nil {
		return fmt.Errorf("failed to get multiple-goroutines flag: %w", err)
	}
	err = getAndWriteSteps(ctx, logger, multipleGoroutines)
	if err != nil {
		logger.Error().Err(err).Msg("getAndWriteSteps")
		return nil
	}
	return nil
}

func init() {
	rootCmd.AddCommand(connectCmd)
}
