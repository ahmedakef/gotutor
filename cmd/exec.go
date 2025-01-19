/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"context"
	"fmt"

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
	multipleGoroutines, err := cmd.Flags().GetBool("multiple-goroutines")
	if err != nil {
		return fmt.Errorf("failed to get multiple-goroutines flag: %w", err)
	}

	ctx, cancel := context.WithCancel(cmd.Context())
	defer cancel()
	logger := ctx.Value("logger").(zerolog.Logger)

	binaryPath := "."
	if len(args) == 1 {
		binaryPath = args[0]
	}

	client, err := dlv.RunServerAndGetClient(binaryPath, "", dlv.GetBuildFlags(), debugger.ExecutingGeneratedFile)
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
	rootCmd.AddCommand(execCmd)

}
