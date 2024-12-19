package gateway

import (
	"context"

	"github.com/go-delve/delve/service/api"
	"github.com/go-delve/delve/service/rpc2"
)

type Debug struct {
	client    *rpc2.RPCClient
	semaphore chan struct{}
}

func NewDebug(client *rpc2.RPCClient) *Debug {
	return &Debug{
		client:    client,
		semaphore: make(chan struct{}, 1),
	}
}

func (d *Debug) ListLocalVariables(ctx context.Context, scope api.EvalScope, cfg api.LoadConfig) ([]api.Variable, error) {
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	d.getToken()
	defer d.releaseToken()
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}

	return d.client.ListLocalVariables(scope, cfg)
}

func (d *Debug) ListFunctionArgs(ctx context.Context, scope api.EvalScope, cfg api.LoadConfig) ([]api.Variable, error) {
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	d.getToken()
	defer d.releaseToken()
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}

	return d.client.ListFunctionArgs(scope, cfg)
}

func (d *Debug) ListPackageVariables(ctx context.Context, filter string, cfg api.LoadConfig) ([]api.Variable, error) {
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	d.getToken()
	defer d.releaseToken()
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}

	return d.client.ListPackageVariables(filter, cfg)
}

func (d *Debug) CreateBreakpoint(ctx context.Context, breakPoint *api.Breakpoint) (*api.Breakpoint, error) {
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	d.getToken()
	defer d.releaseToken()
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}

	return d.client.CreateBreakpoint(breakPoint)
}

func (d *Debug) ClearBreakpointByName(ctx context.Context, name string) (*api.Breakpoint, error) {
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	d.getToken()
	defer d.releaseToken()
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}

	return d.client.ClearBreakpointByName(name)
}

func (d *Debug) Stacktrace(ctx context.Context, goroutineId int64, depth int, opts api.StacktraceOptions, cfg *api.LoadConfig) ([]api.Stackframe, error) {
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	d.getToken()
	defer d.releaseToken()
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}

	return d.client.Stacktrace(goroutineId, depth, opts, cfg)
}

func (d *Debug) Continue(ctx context.Context) (*api.DebuggerState, error) {
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	d.getToken()
	defer d.releaseToken()
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}

	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	case debugState := <-d.client.Continue():
		return debugState, nil
	}
}

func (d *Debug) Next(ctx context.Context) (*api.DebuggerState, error) {
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	d.getToken()
	defer d.releaseToken()
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}

	return d.client.Next()
}

func (d *Debug) Step(ctx context.Context) (*api.DebuggerState, error) {
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	d.getToken()
	defer d.releaseToken()
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}

	return d.client.Step()
}

func (d *Debug) StepOut(ctx context.Context) (*api.DebuggerState, error) {
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	d.getToken()
	defer d.releaseToken()
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}

	return d.client.StepOut()
}

func (d *Debug) ListGoroutines(ctx context.Context, start, count int) ([]*api.Goroutine, int, error) {
	if ctx.Err() != nil {
		return nil, 0, ctx.Err()
	}
	d.getToken()
	defer d.releaseToken()
	if ctx.Err() != nil {
		return nil, 0, ctx.Err()
	}

	return d.client.ListGoroutines(start, count)
}

func (d *Debug) SwitchGoroutine(ctx context.Context, goroutineID int64) (*api.DebuggerState, error) {
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	d.getToken()
	defer d.releaseToken()
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}

	return d.client.SwitchGoroutine(goroutineID)
}

func (d *Debug) Detach(kill bool) error {
	d.getToken()
	defer d.releaseToken()

	return d.client.Detach(kill)
}

func (d *Debug) getToken() {
	d.semaphore <- struct{}{}
}

func (d *Debug) releaseToken() {
	<-d.semaphore
}
