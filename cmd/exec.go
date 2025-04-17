/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"context"

	"github.com/ahmedakef/gotutor/dlv"
	"github.com/go-delve/delve/service/debugger"
	"github.com/rs/zerolog"

	"github.com/spf13/cobra"
)

// execCmd represents the exec command
var execCmd = &cobra.Command{
	Use:   "exec",
	Short: "Execute a precompiled binary, and begin a debug session",
	Long: `Execute a precompiled binary and begin a debug session.

This command will cause Delve to exec the binary and immediately attach to it to
begin a new debug session. Please note that if the binary was not compiled with
optimizations disabled, it may be difficult to properly debug it. Please
consider compiling debugging binaries with -gcflags="all=-N -l" on Go 1.10
or later, -gcflags="-N -l" on earlier versions of Go.`,
	Args: cobra.MinimumNArgs(1),
	RunE: execute,
}

func execute(cmd *cobra.Command, args []string) error {

	ctx, cancel := context.WithCancel(cmd.Context())
	defer cancel()
	logger := ctx.Value(loggerKey).(zerolog.Logger)

	binaryPath := args[0]
	client, err := dlv.RunServerAndGetClient(binaryPath, "", dlv.GetBuildFlags(), debugger.ExecutingExistingFile)
	if err != nil {
		logger.Error().Err(err).Msg("runServerAndGetClient")
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
	rootCmd.AddCommand(execCmd)

}
