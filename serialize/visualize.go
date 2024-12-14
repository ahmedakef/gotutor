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
		activeGoroutines, err := v.getUserGoroutines()
		if err != nil || len(activeGoroutines) == 0 {
			return steps, err
		}
		if len(goroutines) == 0 {
			goroutines = activeGoroutines
		} else {
			goroutines = filterNotActiveGoroutines(goroutines, activeGoroutines)
		}
		if len(goroutines) == 0 {
			break
		}
		goroutine := goroutines[0]
		goroutines = goroutines[1:]
		debugState, err = v.client.SwitchGoroutine(goroutine.ID)
		if err != nil {
			return nil, err
		}
		exited, err := v.stepOutToUserCode(debugState)
		if err != nil {
			return steps, err
		}
		if exited {
			break
		}
		step, err := v.buildStep(debugState)
		if err != nil {
			return steps, err
		}
		steps = append(steps, step)

		debugState, err = v.client.Next()
		if err != nil {
			return steps, err
		}
		if debugState.Exited {
			break
		}

		exited, err = v.stepOutToUserCode(debugState)
		if err != nil {
			return steps, err
		}
		if exited {
			break
		}
		step, err = v.buildStep(debugState)
		if err != nil {
			return steps, err
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
		if internalFunction(goroutine.GoStatementLoc.File) {
			continue
		}
		filteredGoroutines = append(filteredGoroutines, goroutine)

	}
	return filteredGoroutines, nil
}

func filterNotActiveGoroutines(goroutines, activeGoroutines []*api.Goroutine) []*api.Goroutine {
	var activeGoroutinesIDs = make(map[int64]bool)
	for _, goroutine := range activeGoroutines {
		activeGoroutinesIDs[goroutine.ID] = true
	}
	var filteredGoroutines []*api.Goroutine
	for _, goroutine := range goroutines {
		if activeGoroutinesIDs[goroutine.ID] {
			filteredGoroutines = append(filteredGoroutines, goroutine)
		}
	}
	return filteredGoroutines

}

func (v *serializer) stepOutToUserCode(debugState *api.DebuggerState) (bool, error) {
	var err error
	for internalFunction(debugState.SelectedGoroutine.CurrentLoc.File) {
		debugState, err = v.client.StepOut()
		if err != nil {
			return false, err
		}
		if debugState.Exited {
			return true, nil
		}
	}
	return false, nil
}

func (v *serializer) buildStep(debugState *api.DebuggerState) (Step, error) {
	variables, err := v.client.ListLocalVariables(
		api.EvalScope{GoroutineID: debugState.SelectedGoroutine.ID},
		api.LoadConfig{},
	)
	if err != nil {
		return Step{}, err
	}
	return Step{
		Goroutine: debugState.SelectedGoroutine,
		Variables: variables,
	}, nil
}

func internalFunction(goroutineFile string) bool {
	return strings.Contains(goroutineFile, "src/runtime/") ||
		strings.Contains(goroutineFile, "/libexec/")
}
