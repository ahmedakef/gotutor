/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"context"
	"errors"
	"fmt"
	"time"

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
	binaryPath, ok := dlv.Build(sourcePath)
	if !ok {
		return errors.New("failed to build binary")
	}
	defer gobuild.Remove(binaryPath)
	debugServerErr := make(chan error, 1)
	go func() {
		err := dlv.RunDebugServer(binaryPath, addr)
		debugServerErr <- err
	}()
	time.Sleep(1 * time.Second)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	err := getAndWriteSteps(ctx)
	if err != nil {
		fmt.Println("getAndWriteSteps:", err)
		return nil
	}

	select {
	case <-debugServerErr:
		fmt.Printf("debugServer error occurred: %v\n", err)
	default:
	}

	return nil
}

func init() {
	rootCmd.AddCommand(debugCmd)

}
