/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"errors"
	"fmt"
	"time"
	"vis/dlv"
	"vis/serialize"

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
	client, err := dlv.Connect(addr)
	if err != nil {
		fmt.Println("failed to connect to server: ", err)
		return nil
	}
	serializer := serialize.NewSerializer(client)
	_, err = serializer.ExecutionSteps()
	if err != nil {
		fmt.Println("failed to get execution steps: ", err)
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
