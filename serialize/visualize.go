package serialize

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"vis/dlv"

	"github.com/go-delve/delve/service/api"
)

type Serializer struct {
	address              string
	activeGoroutines     map[int64]bool
	activeGoroutinesLock sync.Mutex
	breakPointsLock      sync.Mutex
	steps                chan Step
	nextChan             chan bool
	semaphore            chan struct{}
	wg                   sync.WaitGroup
	ctx                  context.Context
	cancel               context.CancelFunc
}

func NewSerializer(ctx context.Context, addr string) *Serializer {
	ctx, cancel := context.WithCancel(ctx)
	return &Serializer{
		address:          addr,
		activeGoroutines: make(map[int64]bool),
		steps:            make(chan Step),
		nextChan:         make(chan bool, 10),
		semaphore:        make(chan struct{}, 1),
		wg:               sync.WaitGroup{},
		ctx:              ctx,
		cancel:           cancel,
	}
}

func (v *Serializer) ExecutionSteps() ([]Step, error) {
	rpcClient, err := dlv.Connect(v.address)
	if err != nil {
		return nil, fmt.Errorf("main goroutine: failed to connect to server: %w", err)
	}
	client := newDebugGateway(rpcClient, v.semaphore)
	err = v.initMainBreakPoint(v.ctx, client)
	if err != nil {
		return nil, err
	}
	debugState, err := client.Continue(v.ctx)
	if err != nil {
		return nil, fmt.Errorf("main goroutine: failed to continue")
	}

	if debugState.Exited {
		return nil, nil
	}
	v.nextChan <- true
	go v.spawnGoRoutines(v.ctx, client)

	var steps []Step
	for step := range v.steps {
		steps = append(steps, step)
	}
	v.wg.Wait()

	fmt.Println("killing the debugger")
	err = client.Detach(true)
	if err != nil {
		fmt.Printf("main goroutine: failed to halt the execution: %v\n", err)
	}
	return steps, nil
}

func (v *Serializer) initMainBreakPoint(ctx context.Context, client *debugGateway) error {
	v.breakPointsLock.Lock()
	_, err := client.CreateBreakpoint(ctx, &api.Breakpoint{
		Name:         "main",
		FunctionName: "main.main",
	})
	v.breakPointsLock.Unlock()
	return err
}

func (v *Serializer) spawnGoRoutines(ctx context.Context, client *debugGateway) {
	for {
		select {
		case <-ctx.Done():
			fmt.Println("Context is done:81")
			v.signalProgramExit()
			close(v.steps)
			return
		case <-v.nextChan:
			goroutines, err := v.getUserGoroutines(ctx, client)
			if err != nil {
				fmt.Println("Error getting goroutines: ", err)
				v.signalProgramExit()
				close(v.steps)
				return
			}
			for _, goroutine := range goroutines {
				v.activeGoroutinesLock.Lock()
				if v.activeGoroutines[goroutine.ID] {
					v.activeGoroutinesLock.Unlock()
					continue
				}
				v.activeGoroutines[goroutine.ID] = true
				v.activeGoroutinesLock.Unlock()
				v.wg.Add(1)
				go v.processGoroutine(ctx, goroutine)
			}
		}
	}
}

func (v *Serializer) processGoroutine(ctx context.Context, goroutine *api.Goroutine) {
	fmt.Printf("goroutine: %d, Started\n", goroutine.ID)
	defer func() {
		fmt.Printf("goroutine: %d, Done\n", goroutine.ID)
		v.wg.Done()
	}()
	defer func() {
		v.activeGoroutinesLock.Lock()
		delete(v.activeGoroutines, goroutine.ID)
		v.activeGoroutinesLock.Unlock()

	}()
	rpcClient, err := dlv.Connect(v.address)
	if err != nil {
		fmt.Printf("goroutine: %d, Error connecting to server: %v\n", goroutine.ID, err)
		return
	}
	client := newDebugGateway(rpcClient, v.semaphore)
	defer func() {
		err := client.Detach(false)
		fmt.Printf("goroutine: %d, calling Detach: %v\n", goroutine.ID, err)
	}()

	debugState, err := client.SwitchGoroutine(ctx, goroutine.ID)
	if err != nil {
		fmt.Printf("goroutine: %d, Error switching goroutine: %v\n", goroutine.ID, err)
		return
	}

	if debugState.Exited {
		fmt.Println("SwitchGoroutine:debugState.Exited:145")
		v.signalProgramExit()
		return
	}

	debugState, err = v.stepOutToUserCode(ctx, client, debugState)
	if err != nil {
		fmt.Printf("outer goroutine: %d, Error stepping out: %v\n", goroutine.ID, err)
		return
	}
	if debugState.Exited {
		fmt.Println("stepOutToUserCode:debugState.Exited:156")
		v.signalProgramExit()
		return
	}
	step, err := v.buildStep(ctx, client, debugState)
	if err != nil {
		fmt.Printf("outer goroutine: %d, Error building step: %v\n", goroutine.ID, err)
		return
	}
	if step.Goroutine != nil {
		v.steps <- step
	}
	for {
		select {
		case <-ctx.Done():
			return
		default:
			debugState, err = client.Next(ctx)
			if err != nil {
				fmt.Printf("inner goroutine: %d, Error while next: %v\n", goroutine.ID, err)
				return
			}
			if debugState.Exited {
				fmt.Println("Next:debugState.Exited:187")
				v.signalProgramExit()
				return
			}

			debugState, err = v.stepOutToUserCode(ctx, client, debugState)
			if err != nil {
				fmt.Printf("inner goroutine: %d, Error stepping out: %v\n", goroutine.ID, err)
				return
			}
			if debugState.Exited {
				fmt.Println("stepOutToUserCode:debugState.Exited:202")
				v.signalProgramExit()
				return
			}
			step, err := v.buildStep(ctx, client, debugState)
			if err != nil {
				fmt.Printf("goroutine: %d, Error building step: %v\n", goroutine.ID, err)
				return
			}
			if step.Goroutine != nil {
				v.steps <- step
				v.nextChan <- true
			}
		}
	}
}

func (v *Serializer) getUserGoroutines(ctx context.Context, client *debugGateway) ([]*api.Goroutine, error) {
	goroutines, _, err := client.ListGoroutines(ctx, 0, 0)
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

func (v *Serializer) stepOutToUserCode(ctx context.Context, client *debugGateway, debugState *api.DebuggerState) (*api.DebuggerState, error) {
	if isUserCode(debugState.SelectedGoroutine.CurrentLoc.File) {
		return debugState, nil
	}
	v.breakPointsLock.Lock()
	defer v.breakPointsLock.Unlock()
	fmt.Printf("goroutine: %d, stepping out to user code\n", debugState.SelectedGoroutine.ID)
	//fmt.Println("current breakpoints: ", debugState.SelectedGoroutine.CurrentLoc)
	stack, err := client.Stacktrace(ctx, debugState.SelectedGoroutine.ID, 1000, 0, nil)
	if err != nil {
		return nil, fmt.Errorf("goroutine: %d, failed to get stacktrace: %w", debugState.SelectedGoroutine.ID, err)
	}
	var breakPointName string
	for _, frame := range stack {
		if strings.HasSuffix(frame.Location.File, "main.go") {
			breakPointName = fmt.Sprintf("gID%dL%d", debugState.SelectedGoroutine.ID, frame.Location.Line)
			_, err = client.CreateBreakpoint(ctx, &api.Breakpoint{
				Name: breakPointName,
				File: frame.Location.File,
				Line: frame.Location.Line,
				Cond: fmt.Sprintf("runtime.curg.goid == %d", debugState.SelectedGoroutine.ID),
			})
			if err != nil {
				return nil, fmt.Errorf("goroutine: %d, failed to create breakpoint: %s: %w", debugState.SelectedGoroutine.ID, breakPointName, err)
			}
			break
		}
	}
	if breakPointName == "" {
		return nil, fmt.Errorf("no main.go found in the stacktrace")
	}
	debugState, err = client.Continue(ctx)
	if err != nil {
		return nil, fmt.Errorf("goroutine: %d, failed to continue: %w", debugState.SelectedGoroutine.ID, err)
	}
	if debugState.Exited {
		v.signalProgramExit()
		return debugState, nil
	}
	_, err = client.ClearBreakpointByName(ctx, breakPointName)
	if err != nil {
		return nil, fmt.Errorf("goroutine: %d, failed to clear breakpoint: %w", debugState.SelectedGoroutine.ID, err)
	}
	return debugState, nil
}

func (v *Serializer) buildStep(ctx context.Context, client *debugGateway, debugState *api.DebuggerState) (Step, error) {
	variables, err := client.ListLocalVariables(ctx,
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

func (v *Serializer) signalProgramExit() {
	v.cancel()
}

func internalFunction(goroutineFile string) bool {
	return strings.Contains(goroutineFile, "src/runtime/") ||
		strings.Contains(goroutineFile, "/libexec/")
}

func isUserCode(goroutineFile string) bool {
	return strings.HasSuffix(goroutineFile, "main.go")
}
