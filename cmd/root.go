/*
Copyright © 2024 Ahmed Akef aemed.akef.1@gmail.com
*/
package cmd

import (
	"context"
	"os"
	"time"

	"github.com/rs/zerolog"
	"github.com/spf13/cobra"
)

type ctxKey string

const loggerKey ctxKey = "logger"

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "gotutor",
	Short: "A brief description of your application",
	Long: `A longer description that spans multiple lines and likely contains
examples and usage of using your application. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.`,
	PersistentPreRun: func(cmd *cobra.Command, args []string) {
		logger := zerolog.New(
			zerolog.ConsoleWriter{Out: os.Stderr, TimeFormat: time.RFC3339},
		).Level(zerolog.TraceLevel).With().Timestamp().Caller().Logger()

		ctx := context.WithValue(context.Background(), loggerKey, logger)
		cmd.SetContext(ctx)
	},
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
	rootCmd.PersistentFlags().Bool("multiple-goroutines", false, "handle multiple goroutines // not well supported yet")
}
