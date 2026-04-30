// Package metrics tracks runtime signals about the docker sandbox.
package metrics

import (
	"context"
	"os/exec"
	"strings"
	"sync/atomic"
	"time"

	"github.com/rs/zerolog"
)

const (
	containerNamePrefix = "gotutor-"
	pollInterval        = 1 * time.Minute
	dockerCallTimeout   = 15 * time.Second
)

// ContainerStats is a point-in-time snapshot of sandbox container counts.
type ContainerStats struct {
	Count     int
	OldestAge time.Duration
	LastPoll  time.Time
	LastError string
}

// ContainerWatcher periodically inspects running gotutor-* docker containers
// and exposes the count and oldest age. The intent is to detect leaks: per
// request the controller already tries hard to kill its container (Cancel
// callback + deferred docker kill + --rm). Counts that grow past the
// concurrency cap, or ages past the per-request docker timeout, mean those
// safeguards have failed and the daemon is accumulating dead work.
type ContainerWatcher struct {
	logger zerolog.Logger

	count    atomic.Int32
	oldestNs atomic.Int64
	lastPoll atomic.Int64 // unix nanos
	lastErr  atomic.Pointer[string]
}

// NewContainerWatcher returns a watcher; call Start to begin polling.
func NewContainerWatcher(logger zerolog.Logger) *ContainerWatcher {
	return &ContainerWatcher{logger: logger}
}

// Start launches the polling goroutine. It runs until ctx is cancelled.
func (w *ContainerWatcher) Start(ctx context.Context) {
	go w.run(ctx)
}

// Stats returns the latest snapshot. Safe to call from any goroutine.
func (w *ContainerWatcher) Stats() ContainerStats {
	var lastErr string
	if p := w.lastErr.Load(); p != nil {
		lastErr = *p
	}
	var lastPoll time.Time
	if ns := w.lastPoll.Load(); ns > 0 {
		lastPoll = time.Unix(0, ns)
	}
	return ContainerStats{
		Count:     int(w.count.Load()),
		OldestAge: time.Duration(w.oldestNs.Load()),
		LastPoll:  lastPoll,
		LastError: lastErr,
	}
}

func (w *ContainerWatcher) run(ctx context.Context) {
	t := time.NewTicker(pollInterval)
	defer t.Stop()
	w.poll(ctx)
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			w.poll(ctx)
		}
	}
}

func (w *ContainerWatcher) poll(ctx context.Context) {
	count, oldest, err := w.snapshot(ctx)
	w.lastPoll.Store(time.Now().UnixNano())
	if err != nil {
		w.logger.Warn().Err(err).Msg("container metric poll failed")
		msg := err.Error()
		w.lastErr.Store(&msg)
		return
	}
	empty := ""
	w.lastErr.Store(&empty)
	w.count.Store(int32(count))
	w.oldestNs.Store(int64(oldest))
}

// snapshot returns (count, oldest age, error). Two docker calls: ps to list
// IDs, then a single inspect to get start times. Splitting avoids docker
// ps format-string drift across versions for CreatedAt.
func (w *ContainerWatcher) snapshot(ctx context.Context) (int, time.Duration, error) {
	ids, err := w.listIDs(ctx)
	if err != nil {
		return 0, 0, err
	}
	if len(ids) == 0 {
		return 0, 0, nil
	}
	starts, err := w.inspectStartTimes(ctx, ids)
	if err != nil {
		// We still know the count even if inspect failed.
		return len(ids), 0, err
	}
	now := time.Now()
	var oldest time.Duration
	for _, st := range starts {
		if age := now.Sub(st); age > oldest {
			oldest = age
		}
	}
	return len(ids), oldest, nil
}

func (w *ContainerWatcher) listIDs(ctx context.Context) ([]string, error) {
	psCtx, cancel := context.WithTimeout(ctx, dockerCallTimeout)
	defer cancel()
	out, err := exec.CommandContext(psCtx, "docker", "ps",
		"--filter", "name=^"+containerNamePrefix,
		"--filter", "status=running",
		"--quiet", "--no-trunc").Output()
	if err != nil {
		return nil, err
	}
	return strings.Fields(strings.TrimSpace(string(out))), nil
}

func (w *ContainerWatcher) inspectStartTimes(ctx context.Context, ids []string) ([]time.Time, error) {
	insCtx, cancel := context.WithTimeout(ctx, dockerCallTimeout)
	defer cancel()
	args := append([]string{"inspect", "--format", "{{.State.StartedAt}}"}, ids...)
	out, err := exec.CommandContext(insCtx, "docker", args...).Output()
	if err != nil {
		return nil, err
	}
	var times []time.Time
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		t, err := time.Parse(time.RFC3339Nano, line)
		if err != nil {
			continue
		}
		times = append(times, t)
	}
	return times, nil
}
