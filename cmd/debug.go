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
}

func debug(cmd *cobra.Command, args []string) error {
	debugName, ok := dlv.BuildFromFile("source")
	if !ok {
		return errors.New("failed to build binary")
	}
	defer gobuild.Remove(debugName)
	serverDone := make(chan struct{})
	err := func() error {
		err := dlv.RunDebugServer(debugName, addr)
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
	rootCmd.AddCommand(debugCmd)

}
