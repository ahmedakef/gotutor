package serialize

import (
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
	//var goroutines []*api.Goroutine
	var err error
	v.initMainBreakPoint()
	debugState := <-v.client.Continue()
	for !debugState.Exited {
		debugState, err = v.client.Next()
		if err != nil {
			return steps, err
		}
		variables, err := v.client.ListLocalVariables(
			api.EvalScope{},
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
		_, _, err = v.client.ListGoroutines(0, 0)
		if err != nil {
			return steps, err
		}

	}

	return steps, nil
}

func (v *serializer) initMainBreakPoint() {
	v.client.CreateBreakpoint(&api.Breakpoint{
		Name:         "main",
		FunctionName: "main.main",
	})
}
