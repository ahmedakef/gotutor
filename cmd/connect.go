/*
Copyright © 2024 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"fmt"
	"vis/dlv"
	"vis/serialize"

	"github.com/spf13/cobra"
)

// connectCmd represents the connect command
var connectCmd = &cobra.Command{
	Use:   "connect",
	Short: "A brief description of your command",
	Long: `A longer description that spans multiple lines and likely contains examples
and usage of using your command. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.`,
	RunE: connect,
}

func connect(cmd *cobra.Command, args []string) error {
	client, err := dlv.Connect(addr)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %w", err)
	}
	serializer := serialize.NewSerializer(client)
	serializer.ExecutionSteps()

	return nil
}

func init() {
	rootCmd.AddCommand(connectCmd)
}
