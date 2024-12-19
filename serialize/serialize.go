package serialize

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"os"
	"sort"
	"strings"
	"sync"

	"github.com/ahmedakef/gotutor/gateway"

	"github.com/go-delve/delve/service/api"
)

var errNoMain = errors.New("main function not found")

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
		steps, exited, err := v.stepForward(ctx)
		if err != nil {
			return allSteps, err
		}
		allSteps = append(allSteps, steps...)
		if exited {
			break
		}
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
		step, exited, err := v.goToNextLine(ctx, goroutine)
		if err != nil {
			return allSteps, true, fmt.Errorf("goroutine: %d, goToNextLine: %w", goroutine.ID, err)
		}
		if step.isValid() {
			allSteps = append(allSteps, step)
		}
		if exited {
			fmt.Printf("goroutine: %d, read exit signal\n", goroutine.ID)
			return allSteps, true, nil
		}

		steps, exited, err := v.getGoroutinesState(ctx)
		if err != nil {
			return allSteps, true, fmt.Errorf("goroutine: %d, getGoroutinesState: %w", goroutine.ID, err)
		}
		allSteps = append(allSteps, steps...)
		if exited {
			return allSteps, true, nil
		}

	}
	return allSteps, false, nil
}

func (v *Serializer) getGoroutinesState(ctx context.Context) ([]Step, bool, error) {
	goroutines, err := v.getUserGoroutines(ctx)
	if err != nil {
		return nil, true, fmt.Errorf("get user goroutines: %w", err)
	}
	var steps []Step
	for _, goroutine := range goroutines {
		step, exited, err := v.getGoroutineState(ctx, goroutine)
		if err != nil {
			return nil, true, fmt.Errorf("goroutine: %d, getGoroutineState: %w", goroutine.ID, err)
		}
		if step.isValid() {
			steps = append(steps, step)
		}
		if exited {
			fmt.Printf("goroutine: %d, read exit signal\n", goroutine.ID)
			return steps, true, nil
		}
	}
	return steps, false, nil
}

func (v *Serializer) getGoroutineState(ctx context.Context, goroutine *api.Goroutine) (Step, bool, error) {
	fmt.Printf("goroutine: %d, getGoroutineState\n", goroutine.ID)

	debugState, err := v.client.SwitchGoroutine(ctx, goroutine.ID)
	if err != nil {
		if strings.Contains(err.Error(), "unknown goroutine") {
			return Step{}, false, nil
		}
		return Step{}, true, fmt.Errorf("goroutine: %d, switching goroutine: %w", goroutine.ID, err)
	}

	if debugState.Exited {
		return Step{}, true, nil
	}

	//fmt.Printf("File:Line: %s:%d\n", debugState.SelectedGoroutine.CurrentLoc.File, debugState.SelectedGoroutine.CurrentLoc.Line)
	if !isUserCode(debugState.SelectedGoroutine.CurrentLoc.File) {
		//fmt.Printf("File:Line: %s:%d\n", debugState.SelectedGoroutine.CurrentLoc.File, debugState.SelectedGoroutine.CurrentLoc.Line)
		debugState, err = v.client.StepOut(ctx)
		if err != nil {
			return Step{}, true, fmt.Errorf("StepOut: %w", err)
		}
		if debugState.Exited {
			return Step{}, true, nil
		}
		if !isUserCode(debugState.SelectedGoroutine.CurrentLoc.File) {
			return Step{}, false, nil
		}
	}
	step, err := v.buildStep(ctx, debugState)
	if err != nil {
		return Step{}, true, fmt.Errorf("goroutine: %d, building step: %w", goroutine.ID, err)
	}
	return step, false, nil
}

func (v *Serializer) goToNextLine(ctx context.Context, goroutine *api.Goroutine) (Step, bool, error) {
	debugState, err := v.client.SwitchGoroutine(ctx, goroutine.ID)
	if err != nil {
		if strings.Contains(err.Error(), "unknown goroutine") {
			return Step{}, false, nil
		}
		return Step{}, true, fmt.Errorf("goroutine: %d, switching goroutine: %v", goroutine.ID, err)
	}

	if isUserCode(debugState.SelectedGoroutine.CurrentLoc.File) {
		debugState, err = v.client.Step(ctx)
		if err != nil {
			return Step{}, true, fmt.Errorf("goroutine: %d, Step: %w", goroutine.ID, err)
		}
	} else {
		//fmt.Printf("debugState: %#v\n", debugState)
		//fmt.Printf("debugState.SelectedGoroutine: %#v\n", debugState.SelectedGoroutine)
		//fmt.Printf("File:Line: %s:%d\n", debugState.SelectedGoroutine.CurrentLoc.File, debugState.SelectedGoroutine.CurrentLoc.Line)
		debugState, err = v.client.StepOut(ctx)
		if err != nil {
			return Step{}, true, fmt.Errorf("goroutine: %d, StepOut: %w", goroutine.ID, err)
		}
	}
	if debugState.Exited {
		return Step{}, true, nil
	}

	if debugState.SelectedGoroutine.ID != goroutine.ID {
		// the goroutine has been switched
		return Step{}, false, nil
	}

	if isUserCode(debugState.SelectedGoroutine.CurrentLoc.File) {
		step, err := v.buildStep(ctx, debugState)
		if err != nil {
			return Step{}, true, fmt.Errorf("goroutine: %d, building step: %w", goroutine.ID, err)
		}
		return step, false, nil
	}
	return Step{}, false, nil
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
	// assuming the later go routines has work to do while the earlier ones are waiting
	sort.Slice(filteredGoroutines, func(i, j int) bool {
		return filteredGoroutines[i].ID > filteredGoroutines[j].ID
	})
	return filteredGoroutines, nil
}

func (v *Serializer) buildStep(ctx context.Context, debugState *api.DebuggerState) (Step, error) {
	variables, err := v.client.ListLocalVariables(ctx,
		api.EvalScope{GoroutineID: debugState.SelectedGoroutine.ID},
		api.LoadConfig{},
	)
	if err != nil {
		return Step{}, err
	}
	args, err := v.client.ListFunctionArgs(ctx,
		api.EvalScope{GoroutineID: debugState.SelectedGoroutine.ID},
		api.LoadConfig{},
	)
	if err != nil {
		return Step{}, err
	}

	packageVars, err := v.client.ListPackageVariables(ctx,
		"^main.",
		api.LoadConfig{},
	)
	if err != nil {
		return Step{}, err
	}
	return Step{
		Goroutine:        debugState.SelectedGoroutine,
		Variables:        variables,
		Args:             args,
		PackageVariables: packageVars,
	}, nil
}

func internalFunction(goroutineFile string) bool {
	return strings.Contains(goroutineFile, "src/runtime/") ||
		strings.Contains(goroutineFile, "/libexec/")
}

func isUserCode(goroutineFile string) bool {
	return strings.HasSuffix(goroutineFile, "main.go")
}

// old functions no longer used

func (v *Serializer) stepOutToUserCode(ctx context.Context, debugState *api.DebuggerState) (*api.DebuggerState, bool, error) {
	var err error
	fmt.Printf("goroutine: %d, stepOutToUserCode\n", debugState.SelectedGoroutine.ID)
	fmt.Printf("File:Line: %s:%d\n", debugState.SelectedGoroutine.CurrentLoc.File, debugState.SelectedGoroutine.CurrentLoc.Line)
	for !isUserCode(debugState.SelectedGoroutine.CurrentLoc.File) {
		debugState, err = v.client.StepOut(ctx)
		if err != nil {
			return nil, true, fmt.Errorf("StepOut: %w", err)
		}
		if debugState.Exited {
			return debugState, true, nil
		}
		fmt.Printf("File:Line: %s:%d\n", debugState.SelectedGoroutine.CurrentLoc.File, debugState.SelectedGoroutine.CurrentLoc.Line)

	}
	return debugState, false, nil
}

func (v *Serializer) continueToUserCode(ctx context.Context, debugState *api.DebuggerState) (*api.DebuggerState, bool, error) {
	if isUserCode(debugState.SelectedGoroutine.CurrentLoc.File) {
		return debugState, false, nil
	}
	v.breakPointsLock.Lock()
	defer v.breakPointsLock.Unlock()
	fmt.Printf("goroutine: %d, continue to user code\n", debugState.SelectedGoroutine.ID)
	stack, err := v.client.Stacktrace(ctx, debugState.SelectedGoroutine.ID, 1000, 0, nil)
	if err != nil {
		return nil, true, fmt.Errorf("goroutine: %d, get stacktrace: %w", debugState.SelectedGoroutine.ID, err)
	}
	//fmt.Printf("current breakpoints: %#v\n", debugState.SelectedGoroutine.CurrentLoc)
	//fmt.Printf("stack: %#v\n ", stack)
	var breakPointName string
	for _, frame := range stack {
		if strings.HasSuffix(frame.Location.File, "main.go") {
			nextLine, err := getNextLine(frame.Location.File, frame.Location.Line)
			if err != nil {
				return nil, true, fmt.Errorf("goroutine: %d, get next line: %w", debugState.SelectedGoroutine.ID, err)
			}
			breakPointName = fmt.Sprintf("gID%dL%d", debugState.SelectedGoroutine.ID, nextLine)
			_, err = v.client.CreateBreakpoint(ctx, &api.Breakpoint{
				Name: breakPointName,
				File: frame.Location.File,
				Line: nextLine,
				Cond: fmt.Sprintf("runtime.curg.goid == %d", debugState.SelectedGoroutine.ID),
			})
			if err != nil {
				return nil, true, fmt.Errorf("goroutine: %d, create breakpoint: %s: %w", debugState.SelectedGoroutine.ID, breakPointName, err)
			}
			break
		}
	}
	if breakPointName == "" {
		return nil, true, errNoMain
	}
	debugState, err = v.client.Continue(ctx)
	if err != nil {
		return nil, true, fmt.Errorf("continue: %w", err)
	}
	if debugState.Exited {
		return debugState, true, nil
	}
	_, err = v.client.ClearBreakpointByName(ctx, breakPointName)
	if err != nil {
		return nil, true, fmt.Errorf("clear breakpoint: %w", err)
	}
	return debugState, false, nil
}

// getNextLine takes a file and line of current statement and returns the next line that has statement
func getNextLine(filePath string, currentLine int) (int, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return currentLine, fmt.Errorf("error opening file: %w", err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	lineNumber := 0
	for scanner.Scan() {
		lineNumber++
		if lineNumber > currentLine && strings.TrimSpace(scanner.Text()) != "" {
			return lineNumber, nil
		}
	}
	if err := scanner.Err(); err != nil {
		return 0, fmt.Errorf("error reading file: %w", err)
	}
	return currentLine, nil
}
