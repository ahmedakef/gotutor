package serialize

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"os"
	"strings"
	"sync"

	"github.com/ahmedakef/gotutor/gateway"

	"github.com/go-delve/delve/service/api"
)

var noMainErr = errors.New("main function not found")

type Serializer struct {
	client          *gateway.Debug
	breakPointsLock sync.Mutex
}

func NewSerializer(client *gateway.Debug) *Serializer {
	return &Serializer{
		client: client,
	}
}

func (v *Serializer) ExecutionSteps(ctx context.Context) ([]Step, error) {
	err := v.initMainBreakPoint(ctx)
	if err != nil {
		return nil, err
	}
	debugState, err := v.client.Continue(ctx)
	if err != nil {
		return nil, fmt.Errorf("main goroutine: continue")
	}

	if debugState.Exited {
		return nil, nil
	}

	var allSteps []Step
	for ctx.Err() == nil {
		steps, exit, err := v.stepForward(ctx)
		if err != nil {
			return allSteps, err
		}
		if exit {
			break
		}
		allSteps = append(allSteps, steps...)
	}

	return allSteps, nil
}

func (v *Serializer) initMainBreakPoint(ctx context.Context) error {
	v.breakPointsLock.Lock()
	_, err := v.client.CreateBreakpoint(ctx, &api.Breakpoint{
		Name:         "main",
		FunctionName: "main.main",
	})
	v.breakPointsLock.Unlock()
	return err
}

func (v *Serializer) stepForward(ctx context.Context) ([]Step, bool, error) {
	var allSteps []Step
	activeGoroutines, err := v.getUserGoroutines(ctx)
	if err != nil || len(activeGoroutines) == 0 {
		return nil, true, err
	}
	for _, goroutine := range activeGoroutines {
		step, exit, err := v.pressNext(ctx, goroutine)
		if err != nil {
			return allSteps, true, fmt.Errorf("goroutine: %d, pressNext: %v\n", goroutine.ID, err)
		}
		if exit {
			fmt.Printf("goroutine: %d, read exit signal\n", goroutine.ID)
			return allSteps, true, nil
		}
		if step.isValid() {
			allSteps = append(allSteps, step)
		}
		steps, err := v.getGoroutinesState(ctx)
		if err != nil {
			fmt.Println("getGoroutinesState: ", err)
			break
		}
		allSteps = append(allSteps, steps...)

	}
	return allSteps, false, nil
}

func (v *Serializer) getGoroutinesState(ctx context.Context) ([]Step, error) {
	goroutines, err := v.getUserGoroutines(ctx)
	if err != nil {
		fmt.Println("get user goroutines: ", err)
		return nil, fmt.Errorf("get user goroutines: %w", err)
	}
	var steps []Step
	for _, goroutine := range goroutines {
		step, _, err := v.getGoroutineState(ctx, goroutine)
		if err != nil {
			return nil, fmt.Errorf("goroutine: %d, getGoroutineState: %w", goroutine.ID, err)
		}
		if step.isValid() {
			steps = append(steps, step)
		}
	}
	return steps, nil
}

func (v *Serializer) getGoroutineState(ctx context.Context, goroutine *api.Goroutine) (Step, bool, error) {
	fmt.Printf("goroutine: %d, getGoroutineState\n", goroutine.ID)

	debugState, err := v.client.SwitchGoroutine(ctx, goroutine.ID)
	if err != nil {
		return Step{}, true, fmt.Errorf("goroutine: %d, switching goroutine: %v\n", goroutine.ID, err)
	}

	if debugState.Exited {
		return Step{}, true, nil
	}

	if !isUserCode(debugState.SelectedGoroutine.CurrentLoc.File) {
		return Step{}, false, nil
	}
	step, err := v.buildStep(ctx, debugState)
	if err != nil {
		return Step{}, true, fmt.Errorf("goroutine: %d, building step: %v\n", goroutine.ID, err)
	}
	return step, false, nil
}

func (v *Serializer) pressNext(ctx context.Context, goroutine *api.Goroutine) (Step, bool, error) {
	debugState, err := v.client.SwitchGoroutine(ctx, goroutine.ID)
	if err != nil {
		return Step{}, true, fmt.Errorf("goroutine: %d, switching goroutine: %v\n", goroutine.ID, err)
	}
	if isUserCode(debugState.SelectedGoroutine.CurrentLoc.File) {
		debugState, err = v.client.Next(ctx)
		if err != nil {
			return Step{}, true, fmt.Errorf("pressNext: %d, next: %v\n", goroutine.ID, err)
		}
		if debugState.Exited {
			fmt.Println("pressNext:Next:debugState.Exited")
			return Step{}, true, nil
		}
		step, err := v.buildStep(ctx, debugState)
		if err != nil {
			return Step{}, true, fmt.Errorf("goroutine: %d, building step: %v\n", goroutine.ID, err)
		}
		return step, false, nil
	}
	debugState, err = v.stepOutToUserCode(ctx, debugState)
	if errors.Is(err, noMainErr) {
		return Step{}, true, nil
	}
	if err != nil {
		return Step{}, true, fmt.Errorf("goroutine: %d, stepping out: %v\n", goroutine.ID, err)
	}
	if debugState.Exited {
		return Step{}, true, nil
	}
	step, err := v.buildStep(ctx, debugState)
	if err != nil {
		return Step{}, true, fmt.Errorf("goroutine: %d, building step: %v\n", goroutine.ID, err)
	}
	return step, false, nil
}

func (v *Serializer) getUserGoroutines(ctx context.Context) ([]*api.Goroutine, error) {
	goroutines, _, err := v.client.ListGoroutines(ctx, 0, 0)
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

func (v *Serializer) stepOutToUserCode(ctx context.Context, debugState *api.DebuggerState) (*api.DebuggerState, error) {
	if isUserCode(debugState.SelectedGoroutine.CurrentLoc.File) {
		return debugState, nil
	}
	v.breakPointsLock.Lock()
	defer v.breakPointsLock.Unlock()
	fmt.Printf("goroutine: %d, stepping out to user code\n", debugState.SelectedGoroutine.ID)
	stack, err := v.client.Stacktrace(ctx, debugState.SelectedGoroutine.ID, 1000, 0, nil)
	if err != nil {
		return nil, fmt.Errorf("goroutine: %d, get stacktrace: %w", debugState.SelectedGoroutine.ID, err)
	}
	//fmt.Printf("current breakpoints: %#v\n", debugState.SelectedGoroutine.CurrentLoc)
	//fmt.Printf("stack: %#v\n ", stack)
	var breakPointName string
	for _, frame := range stack {
		if strings.HasSuffix(frame.Location.File, "main.go") {
			nextLine := getNextLine(frame.Location.File, frame.Location.Line)
			breakPointName = fmt.Sprintf("gID%dL%d", debugState.SelectedGoroutine.ID, nextLine)
			_, err = v.client.CreateBreakpoint(ctx, &api.Breakpoint{
				Name: breakPointName,
				File: frame.Location.File,
				Line: nextLine,
				Cond: fmt.Sprintf("runtime.curg.goid == %d", debugState.SelectedGoroutine.ID),
			})
			if err != nil {
				return nil, fmt.Errorf("goroutine: %d, create breakpoint: %s: %w", debugState.SelectedGoroutine.ID, breakPointName, err)
			}
			break
		}
	}
	if breakPointName == "" {
		return nil, noMainErr
	}
	debugState, err = v.client.Continue(ctx)
	if err != nil {
		return nil, fmt.Errorf("goroutine: %d, continue: %w", debugState.SelectedGoroutine.ID, err)
	}
	if debugState.Exited {
		return debugState, nil
	}
	_, err = v.client.ClearBreakpointByName(ctx, breakPointName)
	if err != nil {
		return nil, fmt.Errorf("goroutine: %d, clear breakpoint: %w", debugState.SelectedGoroutine.ID, err)
	}
	return debugState, nil
}

func (v *Serializer) buildStep(ctx context.Context, debugState *api.DebuggerState) (Step, error) {
	variables, err := v.client.ListLocalVariables(ctx,
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

// getNextLine takes a file and line of current statement and returns the next line that has statement
func getNextLine(filePath string, currentLine int) int {
	file, err := os.Open(filePath)
	if err != nil {
		fmt.Printf("error opening file: %v\n", err)
		return currentLine
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	lineNumber := 0
	for scanner.Scan() {
		lineNumber++
		if lineNumber > currentLine && strings.TrimSpace(scanner.Text()) != "" {
			return lineNumber
		}
	}
	if err := scanner.Err(); err != nil {
		fmt.Printf("error reading file: %v\n", err)
	}
	return currentLine
}

func internalFunction(goroutineFile string) bool {
	return strings.Contains(goroutineFile, "src/runtime/") ||
		strings.Contains(goroutineFile, "/libexec/")
}

func isUserCode(goroutineFile string) bool {
	return strings.HasSuffix(goroutineFile, "main.go")
}
