/*
Copyright © 2024 Ahmed Akef aemed.akef.1@gmail.com
*/
package cmd

import (
	"github.com/spf13/cobra"
	"os"
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "vis",
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
