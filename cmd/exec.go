/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/spf13/cobra"
	"os"
	"time"
	"vis/dlv"
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
	steps, err := getSteps(ctx)
	if err != nil {
		fmt.Println("getSteps: ", err)
		return nil
	}
	cancel()

	// put the result in steps.json file
	file, err := os.OpenFile("steps.json", os.O_WRONLY|os.O_CREATE, 0644)
	if err != nil {
		fmt.Println("failed to open steps.json file: ", err)
		return nil
	}
	defer file.Close()

	err = json.NewEncoder(file).Encode(steps)
	if err != nil {
		fmt.Println("failed to encode steps: ", err)
		return nil
	}
	// Explicitly flush the file buffer
	err = file.Sync()
	if err != nil {
		fmt.Println("failed to flush file buffer: ", err)
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
