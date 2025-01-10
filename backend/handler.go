package main

import (
	"time"

	restate "github.com/restatedev/sdk-go"
)

// Handler is a struct which represents a Restate service; reflection will turn exported methods into service handlers
type Handler struct{}

func (Handler) Greet(ctx restate.Context, name string) (string, error) {
	//  Durably execute a set of steps; resilient against failures
	greetingId := restate.Rand(ctx).UUID().String()

	if _, err := restate.Run(ctx, func(ctx restate.RunContext) (restate.Void, error) {
		return restate.Void{}, SendNotification(greetingId, name)
	}); err != nil {
		return "", err
	}

	if err := restate.Sleep(ctx, 1*time.Second); err != nil {
		return "", err
	}

	if _, err := restate.Run(ctx, func(ctx restate.RunContext) (restate.Void, error) {
		return restate.Void{}, SendReminder(greetingId)
	}); err != nil {
		return "", err
	}

	// Respond to caller
	return "You said hi to " + name + "!", nil
}
