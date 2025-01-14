package main

import (
	"fmt"
	"net/http"
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

	rs, err := server.NewRestate().
		Bind(restate.Reflect(newHandler(logger))).
		Bidirectional(false).
		Handler()
	if err != nil {
		logger.Fatal().Err(err).Msg("failed to create Restate server")
	}

	handler := corsMiddleware(rs)

	port := ":9080"
	logger.Info().Msg(fmt.Sprintf("Server is running on %s...", port))
	if err := http.ListenAndServe(port, handler); err != nil {
		logger.Fatal().Err(err).Msg("failed to start HTTP/2 server")
	}

}
