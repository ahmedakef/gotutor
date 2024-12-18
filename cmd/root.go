/*
Copyright © 2024 Ahmed Akef aemed.akef.1@gmail.com
*/
package cmd

import (
	"context"
	"fmt"
	"os"

	"github.com/ahmedakef/gotutor/serialize"

	"github.com/ahmedakef/gotutor/gateway"

	"github.com/ahmedakef/gotutor/dlv"

	"github.com/spf13/cobra"
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "gotutor",
	Short: "A brief description of your application",
	Long: `A longer description that spans multiple lines and likely contains
examples and usage of using your application. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.`,
	//PersistentPreRun: func(cmd *cobra.Command, args []string) {
	//	// Create a cancellable context
	//	ctx, cancel := context.WithCancel(context.Background())
	//
	//	// Set up channel to listen for interrupt signals
	//	sigs := make(chan os.Signal, 1)
	//	signal.Notify(sigs, os.Interrupt, syscall.SIGTERM)
	//
	//	// Goroutine to handle the interrupt signal
	//	go func() {
	//		<-sigs
	//		cancel()
	//	}()
	//
	//	cmd.SetContext(ctx)
	//},
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}

func init() {
}

func dlvGatewayClient(address string) (*gateway.Debug, error) {
	rpcClient, err := dlv.Connect(addr)
	if err != nil {
		fmt.Println("failed to connect to server: ", err)
		return nil, fmt.Errorf("failed to connect to server: %w", err)
	}
	client := gateway.NewDebug(rpcClient)
	return client, nil

}

func getSteps(ctx context.Context) ([]serialize.Step, error) {
	client, err := dlvGatewayClient(addr)
	if err != nil {
		fmt.Println("failed to create dlvGatewayClient: ", err)
		return nil, nil
	}

	defer func() {
		fmt.Println("killing the debugger")
		err = client.Detach(true)
		if err != nil {
			fmt.Printf("failed to halt the execution: %v\n", err)
		}
	}()
	serializer := serialize.NewSerializer(client)
	steps, err := serializer.ExecutionSteps(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get execution steps: %w", err)
	}
	return steps, nil
}
