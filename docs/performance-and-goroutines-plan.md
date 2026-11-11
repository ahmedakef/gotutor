# Faster execution and goroutine tracing plan

| # | Approach | Status |
|---|----------|--------|
| 1 | Pre-warm the Go build cache in the image + timing logs | Planned |
| 2 | Breakpoint on every user line, then `Continue` (real goroutine tracing) | **Deferred** |
| 3 | Make `buildStep` cheaper (user goroutines and user frames only) | Planned |
| 4 | Drop duplicate stdout/stderr bytes from the response | Planned |
| 5 | Frontend "running" badge + regenerated example steps | Planned |

## How a request works today
A `/GetExecutionSteps` request goes through these steps:

1. The backend runs `docker run ahmedakef/gotutor debug /data/main.go` (`backend/src/controller/controller.go`).
2. Inside the container, `dlv.Build` compiles the program with `-gcflags all=-N -l` (`dlv/build.go`; delve `pkg/gobuild/gobuild.go`). The container is new on every request and is limited to `--cpus 1`, so the Go build cache always starts empty. The whole std dependency tree (`fmt`, `runtime`, `sync`, `time`, …) gets recompiled without optimizations on every request.
3. `serialize.ExecutionSteps` (`serialize/serialize.go`) only follows **the main goroutine**:
   - It picks `debugState.SelectedGoroutine` once and stays on it.
   - It steps over `go …` lines with `Next`.
   - Spawned goroutines are never stepped through. They only show up as snapshots in the side panel.
   - An earlier attempt at multi-goroutine stepping is dead code in `serialize/advance_in_multiple_goroutines.go`. It stalled because Step/Next misbehave when several goroutines are involved (delve#1529).
4. Every step makes these calls:
   - `SwitchGoroutine`, then `Step`, `StepOut`, or a temporary breakpoint plus `Continue`.
   - `buildStep`, which lists **every** goroutine. That includes runtime ones like the GC workers and the finalizer.
   - For each of those goroutines, a 100-frame `Stacktrace` that loads locals for **every** frame, including runtime frames such as `gopark`, `selectgo`, and `chanrecv`.

   The frontend then throws all of that runtime data away (`frontend/src/Steps/View.elm` `filterUserFrames`). For the checked-in example, the tracer alone took 3.9s, not counting the build.

## 1. Pre-warm the Go build cache in the image (Planned)
In the final stage of the `Dockerfile`, run `go build -gcflags='all=-N -l' std`. This fills `/root/.cache/go-build` with std compiled exactly the way delve compiles it, so a user build only has to compile `main.go` and link. The command has to run in the final alpine stage, because that stage has the same GOROOT, HOME, and CGO settings as the runtime and the cache keys depend on them.

`cmd/debug.go` logs the build time and the trace time, so improvements and regressions can be measured.

If the container is ever made `--read-only`, point `GOCACHE` at a copy on tmpfs or keep the cache writable.

## 2. Breakpoint on every user line, then Continue (Deferred)
Rewrite `serialize.ExecutionSteps` and delete the Step/StepOut machinery: `goToNextLine`, `continueToUserCode`, `continueToFirstFrameInMainDotGo`, `isInvokingGoroutine`, `getNextLine`, `goroutineInRuntime`, and `advance_in_multiple_goroutines.go`.

The new loop:
1. Keep the existing `main.main` breakpoint and the first `Continue`. This skips `init` code, same as today.
2. For every line in `main.go`, call `CreateBreakpoint{File, Line}`. Ignore delve's "could not find statement" error. Delve resolves each line to the right PC on its own: it skips function prologues and the auto-generated `gowrap` / `·dwrap·` wrappers (delve `pkg/proc/bininfo.go` `FindFileLocation`).
3. Loop until the program exits, the step limit is hit, or the context is cancelled:
   - Call `Continue`.
   - The goroutine that hit the breakpoint is `debugState.SelectedGoroutine`. Record a step for it, putting it first in the list.
   - The frontend already takes the current line from the first goroutine's first user frame.
4. If the program stops somewhere other than one of our line breakpoints (delve's built-in `unrecovered-panic` / `runtime-fatal-throw`), record one step if that goroutine has a user frame, so the panic site is shown. Then continue.

Run the traced program with `GOMAXPROCS=1`, set with `os.Setenv` in `dlv.RunServerAndGetClient` before `server.Run`:
- Only one goroutine runs user code at a time, so two goroutines can't hit breakpoints at once and lose a step.
- The interleaving is easier for learners to follow.
- Go 1.24 ignores the `--cpus 1` cgroup limit when it picks GOMAXPROCS, so without this the value would depend on the host's CPU count.

What this would give:
- Goroutines are traced line by line in the order the scheduler actually runs them.
- Stdlib callbacks into user code are traced too (`sort.Slice` less funcs, HTTP handlers).
- Each step costs a single `Continue`.

Known gap: delve sets one breakpoint PC per line, so a `for i := …; i < n; i++` header only shows on the first pass. One possible fix is to read the binary's `debug/dwarf` line table and add `Addr` breakpoints at the other `is_stmt` PCs on that line in the same function.

Tests to add along with it:
- **Sequential program:** the line sequence is exactly as expected.
- **WaitGroup workers:** some steps have an active goroutine other than #1, and those steps land inside the worker function.
- **Channels + select:** both goroutines appear as active.
- **Panic:** the last step points at the panic line.

## 3. Make `buildStep` cheaper (Planned)
Changes:
- List only user goroutines with `ListGoroutinesWithFilter(…, GoroutineUser)`, capped at 100, which matches what the frontend shows. Delve counts `runtime.main` as user code, so the main goroutine stays in the list.
- Fetch each stack trace without loading variables. Then load locals and arguments only for frames in `main.go`, and drop every other frame.
- Leave out goroutines that have no user frames. The frontend hides them anyway.
- Keep `api.Stackframe` and `api.Goroutine` unchanged, so the Elm decoders keep working.

## 4. Shrink the response payload (Planned)
`StdOutBytes` and `StdErrBytes` are only needed on the `/compile` path. In the `/GetExecutionSteps` response they are base64 copies of `StdOut`/`StdErr`. The controller clears them before caching and returning, and the fields are now tagged `omitempty`.

## 5. Frontend touch (Planned)
The goroutine whose line is highlighted is marked as "running" in the goroutines panel. `frontend/src/initialProgram/steps.json` is regenerated with `make updateExample`.
