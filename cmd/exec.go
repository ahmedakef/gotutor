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
	Short: "A brief description of your command",
	Long: `A longer description that spans multiple lines and likely contains examples
and usage of using your command. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.`,
	Args: cobra.MinimumNArgs(1),
	RunE: execute,
}

func execute(cmd *cobra.Command, args []string) error {

	ctx, cancel := context.WithCancel(cmd.Context())
	defer cancel()
	logger := ctx.Value(loggerKey).(zerolog.Logger)

	binaryPath := "."
	if len(args) == 1 {
		binaryPath = args[0]
	}

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
