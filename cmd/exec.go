/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"context"
	"fmt"
	"time"

	"github.com/ahmedakef/gotutor/dlv"
	"github.com/spf13/cobra"
)

var addr = ":8083"

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
	binaryPath := "."
	if len(args) == 1 {
		binaryPath = args[0]
	}

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
	case err := <-debugServerErr:
		if err != nil {
			fmt.Printf("debugServer error occurred: %v\n", err)
		}
	default:
	}
	return nil

}

func init() {
	rootCmd.AddCommand(execCmd)

}
