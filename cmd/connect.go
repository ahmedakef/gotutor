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
		fmt.Println("failed to connect to server: ", err)
		return nil
	}
	serializer := serialize.NewSerializer(client)
	_, err = serializer.ExecutionSteps()
	if err != nil {
		fmt.Println("failed to get execution steps: ", err)
		return nil
	}
	return nil
}

func init() {
	rootCmd.AddCommand(connectCmd)
}
