/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"context"
	"fmt"
	"time"

	"github.com/rs/zerolog"

	"github.com/ahmedakef/gotutor/dlv"
	"github.com/go-delve/delve/pkg/gobuild"
	"github.com/spf13/cobra"
)

// debugCmd represents the debug command
var debugCmd = &cobra.Command{
	Use:   "debug",
	Short: "A brief description of your command",
	Long: `A longer description that spans multiple lines and likely contains examples
and usage of using your command. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.`,
	RunE: debug,
	Args: cobra.RangeArgs(0, 1),
}

func debug(cmd *cobra.Command, args []string) error {
	sourcePath := ""
	if len(args) == 1 {
		sourcePath = args[0]
	}
	binaryPath, err := dlv.Build(sourcePath, "")
	if err != nil {
		return fmt.Errorf("failed to build binary: %w", err)
	}
	defer gobuild.Remove(binaryPath)
	debugServerErr := make(chan error, 1)
	go func() {
		err := dlv.RunDebugServer(binaryPath, addr)
		debugServerErr <- err
	}()
	time.Sleep(1 * time.Second)

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

	select {
	case err := <-debugServerErr:
		if err != nil {
			logger.Error().Err(err).Msg("debugServer error occurred")
		}
	default:
	}

	return nil
}

func init() {
	rootCmd.AddCommand(debugCmd)

}
