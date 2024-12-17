package serialize

import (
	"context"
	"github.com/go-delve/delve/service/api"
	"github.com/go-delve/delve/service/rpc2"
)

type debugGateway struct {
	client    *rpc2.RPCClient
	semaphore chan struct{}
}

func newDebugGateway(client *rpc2.RPCClient, semaphore chan struct{}) *debugGateway {
	return &debugGateway{
		client:    client,
		semaphore: semaphore,
	}
}

func (d *debugGateway) ListLocalVariables(ctx context.Context, scope api.EvalScope, cfg api.LoadConfig) ([]api.Variable, error) {
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

func (d *debugGateway) CreateBreakpoint(ctx context.Context, breakPoint *api.Breakpoint) (*api.Breakpoint, error) {
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

func (d *debugGateway) ClearBreakpointByName(ctx context.Context, name string) (*api.Breakpoint, error) {
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

func (d *debugGateway) Stacktrace(ctx context.Context, goroutineId int64, depth int, opts api.StacktraceOptions, cfg *api.LoadConfig) ([]api.Stackframe, error) {
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

func (d *debugGateway) Continue(ctx context.Context) (*api.DebuggerState, error) {
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

func (d *debugGateway) Next(ctx context.Context) (*api.DebuggerState, error) {
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

func (d *debugGateway) ListGoroutines(ctx context.Context, start, count int) ([]*api.Goroutine, int, error) {
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

func (d *debugGateway) SwitchGoroutine(ctx context.Context, goroutineID int64) (*api.DebuggerState, error) {
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

func (d *debugGateway) Detach(kill bool) error {
	d.getToken()
	defer d.releaseToken()

	return d.client.Detach(kill)
}

func (d *debugGateway) getToken() {
	d.semaphore <- struct{}{}
}

func (d *debugGateway) releaseToken() {
	<-d.semaphore
}
