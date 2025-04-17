/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"context"
	"fmt"

	"github.com/rs/zerolog"

	"github.com/ahmedakef/gotutor/dlv"
	"github.com/go-delve/delve/pkg/gobuild"
	"github.com/go-delve/delve/service/debugger"
	"github.com/spf13/cobra"
)

// debugCmd represents the debug command
var debugCmd = &cobra.Command{
	Use:   "debug",
	Short: "Compile and begin debugging main package in current directory, or the package specified.",
	Long: `Compiles your program with optimizations disabled, starts and attaches to it.

By default, with no arguments, Delve will compile the 'main' package in the
current directory, and begin to debug it. Alternatively you can specify a
package name and Delve will compile that package instead, and begin a new debug
session.`,
	RunE: debug,
	Args: cobra.RangeArgs(0, 1),
}

func debug(cmd *cobra.Command, args []string) error {

	ctx, cancel := context.WithCancel(cmd.Context())
	defer cancel()
	logger := ctx.Value(loggerKey).(zerolog.Logger)

	sourcePath := ""
	if len(args) == 1 {
		sourcePath = args[0]
	}
	binaryPath, err := dlv.Build(sourcePath, "")
	if err != nil {
		logger.Error().Err(err).Msg("failed to build binary")
		return nil
	}
	defer gobuild.Remove(binaryPath)

	client, err := dlv.RunServerAndGetClient(binaryPath, sourcePath, dlv.GetBuildFlags(), debugger.ExecutingGeneratedFile)
	if err != nil {
		return fmt.Errorf("runServerAndGetClient: %w", err)
	}

	err = getAndWriteSteps(ctx, client, logger)
	if err != nil {
		logger.Error().Err(err).Msg("getAndWriteSteps")
		return nil
	}

	return nil
}

func init() {
	rootCmd.AddCommand(debugCmd)

}
