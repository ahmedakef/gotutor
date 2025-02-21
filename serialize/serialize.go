package serialize

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"os"
	"strings"

	"github.com/ahmedakef/gotutor/gateway"
	"github.com/rs/zerolog"

	"github.com/go-delve/delve/service/api"
)

var errNoMain = errors.New("main function not found")
var defaultLoadConfig = api.LoadConfig{MaxStringLen: 64, MaxStructFields: 10, MaxArrayValues: 10}

type Serializer struct {
	client *gateway.Debug
	logger zerolog.Logger
}

func NewSerializer(client *gateway.Debug, logger zerolog.Logger) *Serializer {
	return &Serializer{
		client: client,
		logger: logger,
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

		step, exited, err := v.goToNextLine(ctx, debugState.SelectedGoroutine)
		if err != nil {
			return allSteps, err
		}
		if step.isValid() {
			allSteps = append(allSteps, step)
		}
		if exited {
			break
		}

	}

	return allSteps, nil
}

func (v *Serializer) initMainBreakPoint(ctx context.Context) error {
	_, err := v.client.CreateBreakpoint(ctx, &api.Breakpoint{
		Name:         "main",
		FunctionName: "main.main",
	})
	return err
}

// goToNextLine steps to the next line in the given goroutine
func (v *Serializer) goToNextLine(ctx context.Context, goroutine *api.Goroutine) (Step, bool, error) {
	debugState, err := v.client.SwitchGoroutine(ctx, goroutine.ID)
	if err != nil {
		return Step{}, true, fmt.Errorf("goroutine: %d, switching goroutine: %w", goroutine.ID, err)
	}

	var exited bool
	invokingGoroutine, err := v.isInvokingGoroutine(debugState.SelectedGoroutine.CurrentLoc.File, debugState.SelectedGoroutine.CurrentLoc.Line)
	if err != nil {
		return Step{}, true, fmt.Errorf("goroutine: %d, isInvokingGoroutine: %w", goroutine.ID, err)
	}
	if invokingGoroutine {
		debugState, err = v.client.Next(ctx)
		if err != nil {
			return Step{}, true, fmt.Errorf("step: %w", err)
		}
		if debugState.Exited {
			return Step{}, true, nil
		}
	} else if isInMainDotGo(debugState.SelectedGoroutine.CurrentLoc.File) {
		debugState, err = v.client.Step(ctx)
		if err != nil {
			return Step{}, true, fmt.Errorf("step: %w", err)
		}
		if debugState.Exited {
			v.logger.Debug().Any("debugState", debugState).Msg("read exit signal")
			return Step{}, true, nil
		}
	} else if equalLocation(debugState.SelectedGoroutine.CurrentLoc, debugState.SelectedGoroutine.UserCurrentLoc) { // if not in runtime
		debugState, err = v.client.StepOut(ctx)
		if err != nil {
			return Step{}, true, fmt.Errorf("stepOut: %w", err)
		}
		if debugState.Exited {
			return Step{}, true, nil
		}
	} else if goroutineInRuntime(debugState.SelectedGoroutine.CurrentLoc.File) { // if in runtime
		debugState, exited, err = v.continueToUserCode(ctx, debugState)
		if err != nil {
			return Step{}, true, fmt.Errorf("continueToUserCode: %w", err)
		}
		if exited {
			v.logger.Debug().Any("debugState", debugState).Msg("read exit signal")
			return Step{}, true, nil
		}
	} else { // in a function in runtime but still have user code in one of the frames
		debugState, exited, err = v.continueToFirstFrameInMainDotGo(ctx, debugState)
		if err != nil {
			return Step{}, true, fmt.Errorf("continueToFirstFrameInMainDotGo: %w", err)
		}
		if exited {
			v.logger.Debug().Any("debugState", debugState).Msg("read exit signal")
			return Step{}, true, nil
		}
	}
	// if not in user code, don't build the step
	if !isInMainDotGo(debugState.SelectedGoroutine.CurrentLoc.File) {
		return Step{}, false, nil
	}

	step, err := v.buildStep(ctx, debugState)
	if err != nil {
		return Step{}, true, fmt.Errorf("goroutine: %d, building step: %w", debugState.SelectedGoroutine.ID, err)
	}
	return step, false, nil
}

func (v *Serializer) buildStep(ctx context.Context, debugState *api.DebuggerState) (Step, error) {

	packageVars, err := v.client.ListPackageVariables(ctx,
		"^main.",
		defaultLoadConfig,
	)
	if err != nil {
		return Step{}, fmt.Errorf("ListPackageVariables: %w", err)
	}

	stacktrace, err := v.client.Stacktrace(ctx, debugState.SelectedGoroutine.ID, 100, 0, &defaultLoadConfig)
	if err != nil {
		return Step{}, fmt.Errorf("stacktrace: %w", err)
	}

	goroutines, err := v.getAllGoroutines(ctx)
	if err != nil {
		return Step{}, fmt.Errorf("get all goroutines: %w", err)
	}

	goroutinesData := []GoRoutineData{{ // we want to make the current goroutine the first one
		Goroutine:  debugState.SelectedGoroutine,
		Stacktrace: stacktrace,
	}}
	goroutines = removeGorotine(goroutines, debugState.SelectedGoroutine)
	for _, goroutine := range goroutines {
		stacktrace, err := v.client.Stacktrace(ctx, goroutine.ID, 100, 0, &defaultLoadConfig)
		if err != nil {
			return Step{}, fmt.Errorf("goroutine: %d, stacktrace: %w", goroutine.ID, err)
		}
		goroutinesData = append(goroutinesData, GoRoutineData{
			Goroutine:  goroutine,
			Stacktrace: stacktrace,
		})
	}

	return Step{
		PackageVariables: packageVars,
		GoroutinesData:   goroutinesData,
	}, nil
}

func removeGorotine(goroutines []*api.Goroutine, goroutine *api.Goroutine) []*api.Goroutine {
	var filteredGoroutines []*api.Goroutine
	for _, g := range goroutines {
		if g.ID != goroutine.ID {
			filteredGoroutines = append(filteredGoroutines, g)
		}
	}
	return filteredGoroutines
}

func (v *Serializer) getAllGoroutines(ctx context.Context) ([]*api.Goroutine, error) {
	goroutines, _, err := v.client.ListGoroutines(ctx, 0, 0)
	return goroutines, err
}

func (v *Serializer) isInvokingGoroutine(filePath string, line int) (bool, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return false, fmt.Errorf("error opening file: %w", err)
	}
	defer func() {
		err := file.Close()
		if err != nil {
			v.logger.Error().Err(err).Msg("error closing file")
		}
	}()

	scanner := bufio.NewScanner(file)
	lineNumber := 0
	for scanner.Scan() {
		lineNumber++
		if lineNumber == line {
			return strings.Contains(scanner.Text(), "go "), nil
		}
	}
	if err := scanner.Err(); err != nil {
		return false, fmt.Errorf("error reading file: %w", err)
	}
	return false, nil
}

func (v *Serializer) continueToUserCode(ctx context.Context, debugState *api.DebuggerState) (*api.DebuggerState, bool, error) {
	if isInMainDotGo(debugState.SelectedGoroutine.CurrentLoc.File) {
		return debugState, false, nil
	}
	v.logger.Debug().Msg(fmt.Sprintf("goroutine: %d, continue to user code", debugState.SelectedGoroutine.ID))
	userCurrentLoc := debugState.SelectedGoroutine.UserCurrentLoc
	userCurrentLocFile := userCurrentLoc.File
	userCurrentLocLine, err := v.getNextLine(userCurrentLocFile, userCurrentLoc.Line)
	if err != nil {
		return nil, true, fmt.Errorf("goroutine: %d, get next line: %w", debugState.SelectedGoroutine.ID, err)
	}

	breakPointName := fmt.Sprintf("gID%dL%d", debugState.SelectedGoroutine.ID, userCurrentLocLine)
	_, err = v.client.CreateBreakpoint(ctx, &api.Breakpoint{
		Name: breakPointName,
		File: userCurrentLocFile,
		Line: userCurrentLocLine,
		Cond: fmt.Sprintf("runtime.curg.goid == %d", debugState.SelectedGoroutine.ID),
	})
	if err != nil {
		return nil, true, fmt.Errorf("goroutine: %d, create breakpoint: %s: %w", debugState.SelectedGoroutine.ID, breakPointName, err)
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

func (v *Serializer) continueToFirstFrameInMainDotGo(ctx context.Context, debugState *api.DebuggerState) (*api.DebuggerState, bool, error) {
	v.logger.Debug().Msg(fmt.Sprintf("goroutine: %d, continueToFirstFrameInMainDotGo", debugState.SelectedGoroutine.ID))
	stack, err := v.client.Stacktrace(ctx, debugState.SelectedGoroutine.ID, 100, 0, nil)
	if err != nil {
		return nil, true, fmt.Errorf("goroutine: %d, get stacktrace: %w", debugState.SelectedGoroutine.ID, err)
	}
	var breakPointName string
	for _, frame := range stack {
		if strings.HasSuffix(frame.Location.File, "main.go") {
			nextLine, err := v.getNextLine(frame.Location.File, frame.Location.Line)
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
func (v *Serializer) getNextLine(filePath string, currentLine int) (int, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return currentLine, fmt.Errorf("error opening file: %w", err)
	}
	defer func() {
		err := file.Close()
		if err != nil {
			v.logger.Error().Err(err).Msg("error closing file")
		}
	}()

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

func equalLocation(loc1, loc2 api.Location) bool {
	return loc1.File == loc2.File && loc1.Line == loc2.Line
}

func internalFunction(goroutineFile string) bool {
	return strings.Contains(goroutineFile, "src/runtime/") ||
		strings.Contains(goroutineFile, "/libexec/")
}

// isInMainDotGo checks if the current location is in main.go file
func isInMainDotGo(goroutineFile string) bool {
	mainFie := strings.HasSuffix(goroutineFile, "main.go")
	return mainFie
}

// goroutineInRuntime checks if the goroutine is in runtime
// tbh I don't know if empty file means it's in runtime or not
// this was suggested by copilot
// anyway we need to not execute step of step out in this case as this case errors out the delve server
func goroutineInRuntime(goroutineFile string) bool {
	emptyFile := goroutineFile == "" // calling step out while the goroutine has CurrentLoc.File as empty string cause runtime error in delve server

	return emptyFile
}
