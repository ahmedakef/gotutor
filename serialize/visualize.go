package serialize

import (
	"strings"

	"github.com/go-delve/delve/service/api"
	"github.com/go-delve/delve/service/rpc2"
)

type serializer struct {
	client *rpc2.RPCClient
}

func NewSerializer(client *rpc2.RPCClient) *serializer {
	return &serializer{client: client}
}

func (v *serializer) ExecutionSteps() ([]Step, error) {
	var steps []Step
	var goroutines []*api.Goroutine
	err := v.initMainBreakPoint()
	if err != nil {
		return steps, err
	}
	debugState := <-v.client.Continue()
	for !debugState.Exited {
		if len(goroutines) == 0 {
			goroutines, err = v.getUserGoroutines()
			if err != nil {
				return steps, err
			}
		}
		debugState, err = v.client.Next()
		if err != nil {
			return steps, err
		}
		if debugState.Exited {
			break
		}
		variables, err := v.client.ListLocalVariables(
			api.EvalScope{GoroutineID: -1},
			api.LoadConfig{},
		)
		if err != nil {
			return steps, err
		}
		step := Step{
			Goroutine: debugState.SelectedGoroutine,
			Variables: variables,
		}
		steps = append(steps, step)
	}

	return steps, nil
}

func (v *serializer) initMainBreakPoint() error {
	_, err := v.client.CreateBreakpoint(&api.Breakpoint{
		Name:         "main",
		FunctionName: "main.main",
	})
	return err
}

func (v *serializer) getUserGoroutines() ([]*api.Goroutine, error) {
	goroutines, _, err := v.client.ListGoroutines(0, 0)
	if err != nil {
		return nil, err
	}
	var filteredGoroutines []*api.Goroutine
	for _, goroutine := range goroutines {
		if !strings.Contains(goroutine.CurrentLoc.File, "src/runtime/") {
			filteredGoroutines = append(filteredGoroutines, goroutine)
		}
	}
	return filteredGoroutines, nil
}
