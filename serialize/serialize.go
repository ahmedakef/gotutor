package serialize

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/ahmedakef/gotutor/gateway"
	"github.com/rs/zerolog"

	"github.com/go-delve/delve/service/api"
)

// _maxGoroutines matches the number of goroutines the frontend shows
const _maxGoroutines = 100

var errNoMain = errors.New("main function not found")
var defaultLoadConfig = api.LoadConfig{
	FollowPointers:     true,
	MaxVariableRecurse: 2,
	MaxStringLen:       64,
	MaxStructFields:    10,
	MaxArrayValues:     10,
}

type Serializer struct {
	client *gateway.Debug
	logger zerolog.Logger

	// packageVarNames caches the names of main's package variables, see packageVariables
	packageVarNames []string
}

func NewSerializer(client *gateway.Debug, logger zerolog.Logger) *Serializer {
	return &Serializer{
		client: client,
		logger: logger,
	}
}

func (v *Serializer) ExecutionSteps(ctx context.Context, limit int) (ExecutionResponse, error) {
	start := time.Now()
	stepsSoFar := 0
	err := v.initMainBreakPoint(ctx)
	if err != nil {
		return ExecutionResponse{}, err
	}
	debugState, err := v.client.Continue(ctx)
	if err != nil {
		return ExecutionResponse{}, fmt.Errorf("main goroutine: continue")
	}

	if debugState.Exited {
		return ExecutionResponse{}, nil
	}

	var allSteps []Step
	for ctx.Err() == nil {
		stepsSoFar++
		if stepsSoFar >= limit {
			return ExecutionResponse{Steps: allSteps, Duration: time.Since(start).String()}, fmt.Errorf("%d limit reached", limit)
		}
		step, exited, err := v.goToNextLine(ctx, debugState.SelectedGoroutine)
		if err != nil {
			return ExecutionResponse{Steps: allSteps}, err
		}
		if step.isValid() {
			allSteps = append(allSteps, step)
		}
		if exited {
			break
		}
	}
	stdout, err := os.ReadFile("output/stdout.log")
	if err != nil {
		return ExecutionResponse{}, fmt.Errorf("read stdout: %w", err)
	}
	stderr, err := os.ReadFile("output/stderr.log")
	if err != nil {
		return ExecutionResponse{}, fmt.Errorf("read stderr: %w", err)
	}
	return ExecutionResponse{
		Steps:       allSteps,
		Duration:    time.Since(start).String(),
		StdOut:      string(stdout),
		StdErr:      string(stderr),
		StdOutBytes: stdout,
		StdErrBytes: stderr,
	}, nil
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

	packageVars, err := v.packageVariables(ctx)
	if err != nil {
		return Step{}, fmt.Errorf("package variables: %w", err)
	}

	stacktrace, err := v.userStacktrace(ctx, debugState.SelectedGoroutine.ID)
	if err != nil {
		return Step{}, fmt.Errorf("stacktrace: %w", err)
	}

	goroutines, err := v.listUserGoroutines(ctx)
	if err != nil {
		return Step{}, fmt.Errorf("list user goroutines: %w", err)
	}

	goroutinesData := []GoRoutineData{{ // we want to make the current goroutine the first one
		Goroutine:  debugState.SelectedGoroutine,
		Stacktrace: stacktrace,
	}}
	goroutines = removeGorotine(goroutines, debugState.SelectedGoroutine)
	for _, goroutine := range goroutines {
		stacktrace, err := v.userStacktrace(ctx, goroutine.ID)
		if err != nil {
			return Step{}, fmt.Errorf("goroutine: %d, stacktrace: %w", goroutine.ID, err)
		}
		// the frontend only shows goroutines that are running user code
		if len(stacktrace) == 0 {
			continue
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

// packageVariables loads the package variables of package main.
// delve's ListPackageVariables loads the value of every package variable in the binary
// (thousands, mostly from std) before filtering them, so it's only called once, without
// loading values, to find the names; each step then evaluates just those names.
func (v *Serializer) packageVariables(ctx context.Context) ([]api.Variable, error) {
	if v.packageVarNames == nil {
		vars, err := v.client.ListPackageVariables(ctx, `^main\.`, api.LoadConfig{})
		if err != nil {
			return nil, fmt.Errorf("ListPackageVariables: %w", err)
		}
		v.packageVarNames = make([]string, 0, len(vars))
		for _, pv := range vars {
			v.packageVarNames = append(v.packageVarNames, pv.Name)
		}
	}

	packageVars := make([]api.Variable, 0, len(v.packageVarNames))
	for _, name := range v.packageVarNames {
		pv, err := v.client.EvalVariable(ctx, api.EvalScope{GoroutineID: -1}, name, defaultLoadConfig)
		if err != nil {
			// like ListPackageVariables, skip variables whose value can't be read
			v.logger.Debug().Err(err).Str("name", name).Msg("eval package variable")
			continue
		}
		packageVars = append(packageVars, *pv)
	}
	return packageVars, nil
}

// listUserGoroutines lists goroutines that aren't runtime-internal (GC workers, finalizers, ...),
// capped at the number of goroutines the frontend shows.
func (v *Serializer) listUserGoroutines(ctx context.Context) ([]*api.Goroutine, error) {
	return v.client.ListGoroutinesWithFilter(ctx, 0, _maxGoroutines, []api.ListGoroutinesFilter{
		{Kind: api.GoroutineUser},
	})
}

// userStacktrace returns the frames of the goroutine that are in main.go, with their variables loaded.
// Variables are loaded only for these frames because loading them for runtime frames
// (gopark, selectgo, chanrecv, ...) is expensive and the frontend drops those frames anyway.
func (v *Serializer) userStacktrace(ctx context.Context, goroutineID int64) ([]api.Stackframe, error) {
	frames, err := v.client.Stacktrace(ctx, goroutineID, 100, 0, nil)
	if err != nil {
		return nil, err
	}
	var userFrames []api.Stackframe
	for i, frame := range frames {
		if !isInMainDotGo(frame.File) {
			continue
		}
		scope := api.EvalScope{GoroutineID: goroutineID, Frame: i}
		frame.Locals, err = v.client.ListLocalVariables(ctx, scope, defaultLoadConfig)
		if err != nil {
			return nil, fmt.Errorf("frame: %d, list local variables: %w", i, err)
		}
		frame.Arguments, err = v.client.ListFunctionArgs(ctx, scope, defaultLoadConfig)
		if err != nil {
			return nil, fmt.Errorf("frame: %d, list function args: %w", i, err)
		}
		userFrames = append(userFrames, frame)
	}
	return userFrames, nil
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
