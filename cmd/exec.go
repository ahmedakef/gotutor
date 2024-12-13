/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"fmt"
	"time"
	"vis/dlv"
	"vis/serialize"

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

	serverDone := make(chan struct{})
	err := func() error {
		err := dlv.RunDebugServer(binaryPath, addr)
		close(serverDone)
		return err
	}()
	if err != nil {
		return fmt.Errorf("failed to run debug server: %w", err)
	}
	time.Sleep(1 * time.Second)
	client, err := dlv.Connect(addr)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %w", err)
	}
	serializer := serialize.NewSerializer(client)
	serializer.ExecutionSteps()
	return nil

}

func init() {
	rootCmd.AddCommand(execCmd)

}
