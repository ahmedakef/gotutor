package serialize

import (
	"context"
	"fmt"
	"sort"
	"strings"

	"github.com/go-delve/delve/service/api"
)

// this is code that is not working because of the issue [Delve Issue #1529](https://github.com/go-delve/delve/issues/1529)

// stepForwardMultipleGoroutines steps forward in all active goroutines
// doesn't work perfectly
func (v *Serializer) stepForwardMultipleGoroutines(ctx context.Context) ([]Step, bool, error) {
	var allSteps []Step
	activeGoroutines, err := v.getUserGoroutines(ctx)
	if err != nil || len(activeGoroutines) == 0 {
		return nil, true, err
	}
	for _, goroutine := range activeGoroutines {
		step, exited, err := v.goToNextLineConsideringJumpingFromOtherGoroutine(ctx, goroutine)
		if err != nil {
			return allSteps, true, fmt.Errorf("goroutine: %d, goToNextLineConsideringJumpingFromOtherGoroutine: %w", goroutine.ID, err)
		}
		if step.isValid() {
			allSteps = append(allSteps, step)
		}
		if exited {
			v.logger.Debug().Msg(fmt.Sprintf("goroutine: %d, read exit signal", goroutine.ID))
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

// goToNextLineConsideringJumpingFromOtherGoroutine steps to the next line in the given goroutine
// while considering that we are switching from another goroutine
func (v *Serializer) goToNextLineConsideringJumpingFromOtherGoroutine(ctx context.Context, goroutine *api.Goroutine) (Step, bool, error) {
	debugState, err := v.client.SwitchGoroutine(ctx, goroutine.ID)
	if err != nil {
		if strings.Contains(err.Error(), "unknown goroutine") {
			return Step{}, false, nil
		}
		return Step{}, true, fmt.Errorf("goroutine: %d, switching goroutine: %v", goroutine.ID, err)
	}

	if goroutineInRuntime(debugState.SelectedGoroutine.CurrentLoc.File) {
		return Step{}, false, nil
	}

	if isInMainDotGo(debugState.SelectedGoroutine.CurrentLoc.File) {
		debugState, err = v.client.Step(ctx)
		if err != nil {
			return Step{}, true, fmt.Errorf("goroutine: %d, Step: %w", goroutine.ID, err)
		}
	} else {
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

	if !isInMainDotGo(debugState.SelectedGoroutine.CurrentLoc.File) {
		return Step{}, false, nil
	}
	step, err := v.buildStep(ctx, debugState)
	if err != nil {
		return Step{}, true, fmt.Errorf("goroutine: %d, building step: %w", goroutine.ID, err)
	}
	return step, false, nil
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
			v.logger.Debug().Msg(fmt.Sprintf("goroutine: %d, read exit signal", goroutine.ID))
			return steps, true, nil
		}
	}
	return steps, false, nil
}

func (v *Serializer) getGoroutineState(ctx context.Context, goroutine *api.Goroutine) (Step, bool, error) {
	v.logger.Debug().Msg(fmt.Sprintf("goroutine: %d, getGoroutineState", goroutine.ID))

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

	if goroutineInRuntime(debugState.SelectedGoroutine.CurrentLoc.File) {
		return Step{}, false, nil
	}

	if !isInMainDotGo(debugState.SelectedGoroutine.CurrentLoc.File) {
		debugState, err = v.client.StepOut(ctx)
		if err != nil {
			return Step{}, true, fmt.Errorf("StepOut: %w", err)
		}
		if debugState.Exited {
			return Step{}, true, nil
		}
		if !isInMainDotGo(debugState.SelectedGoroutine.CurrentLoc.File) {
			return Step{}, false, nil
		}
	}
	step, err := v.buildStep(ctx, debugState)
	if err != nil {
		return Step{}, true, fmt.Errorf("goroutine: %d, building step: %w", goroutine.ID, err)
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
	// assuming the later go routines has work to do while the earlier ones are waiting
	sort.Slice(filteredGoroutines, func(i, j int) bool {
		return filteredGoroutines[i].ID > filteredGoroutines[j].ID
	})
	return filteredGoroutines, nil
}
