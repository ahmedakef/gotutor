package main

import (
	"context"
	"os"
	"time"

	restate "github.com/restatedev/sdk-go"
	"github.com/restatedev/sdk-go/server"
	"github.com/rs/zerolog"
)

func main() {
	logger := zerolog.New(
		zerolog.ConsoleWriter{Out: os.Stderr, TimeFormat: time.RFC3339},
	).Level(zerolog.TraceLevel).With().Timestamp().Caller().Logger()

	rs := server.NewRestate().
		Bind(restate.Reflect(newHandler(logger)))

	if err := rs.Start(context.Background(), ":9080"); err != nil {
		logger.Fatal().Err(err).Msg("failed to start HTTP server")
	}
}
