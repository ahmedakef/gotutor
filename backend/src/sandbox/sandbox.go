// Copyright 2019 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// The sandbox program is an HTTP server that receives untrusted
// linux/amd64 binaries in a POST request and then executes them in
// a gvisor sandbox using Docker, returning the output as a response
// to the POST.
//
// It's part of the Go playground (https://play.golang.org/).
package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/rand"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"sync"
	"syscall"
	"time"

	"github.com/ahmedakef/gotutor/backend/src/sandbox/sandboxtypes"
)

var (
	listenAddr = flag.String("listen", ":80", "HTTP server listen address. Only applicable when --mode=server")
	mode       = flag.String("mode", "server", "Whether to run in \"server\" mode or \"contained\" mode. The contained mode is used internally by the server mode.")
	dev        = flag.Bool("dev", false, "run in dev mode (show help messages)")
	numWorkers = flag.Int("workers", runtime.NumCPU(), "number of parallel gvisor containers to pre-spin up & let run concurrently")
	container  = flag.String("untrusted-container", "ahmedakef/gotutor-sandbox-gvisor:latest", "container image name that hosts the untrusted binary under gvisor")
)

const (
	maxBinarySize    = 100 << 20
	startTimeout     = 40 * time.Second
	runTimeout       = 25 * time.Second
	maxOutputSize    = 100 << 20
	memoryLimitBytes = 100 << 20
	binarySeparator  = "binarySeparator"
)

var (
	errTooMuchOutput = errors.New("Output too large")
	errRunTimeout    = errors.New("timeout running program")
)

// containedStartMessage is the first thing written to stdout by the
// gvisor-contained process when it starts up. This lets the parent HTTP
// server know that a particular container is ready to run a binary.
const containedStartMessage = "golang-gvisor-process-started\n"

// containedStderrHeader is written to stderr after the gvisor-contained process
// successfully reads the processMeta JSON line + executable binary from stdin,
// but before it's run.
var containedStderrHeader = []byte("golang-gvisor-process-got-input\n")

var (
	readyContainer chan *Container
	runSem         chan struct{}
)

type Container struct {
	name string

	stdin  io.WriteCloser
	stdout *limitedWriter
	stderr *limitedWriter

	cmd       *exec.Cmd
	cancelCmd context.CancelFunc

	waitErr chan error // 1-buffered; receives error from WaitOrStop(..., cmd, ...)
}

func (c *Container) Close() {
	setContainerWanted(c.name, false)

	c.cancelCmd()
	if err := c.Wait(); err != nil {
		log.Printf("error in c.Wait() for %q: %v, stderr: %s, stdout: %s", c.name, err, c.stderr.dst.String(), c.stdout.dst.String())
	}
}

func (c *Container) Wait() error {
	err := <-c.waitErr
	c.waitErr <- err
	return err
}

var httpServer *http.Server

func main() {
	flag.Parse()
	if *mode == "contained" {
		runInGvisor()
		panic("runInGvisor didn't exit")
	}
	if flag.NArg() != 0 {
		flag.Usage()
		os.Exit(1)
	}
	log.Printf("Go playground sandbox starting.")

	readyContainer = make(chan *Container)
	runSem = make(chan struct{}, *numWorkers)
	go handleSignals()

	mux := http.NewServeMux()

	if out, err := exec.Command("docker", "version").CombinedOutput(); err != nil {
		log.Fatalf("failed to connect to docker: %v, %s", err, out)
	}
	if *dev {
		log.Printf("Running in dev mode; container published to host at: http://localhost:9090/")
		log.Printf("Run a binary with: curl -v --data-binary @/home/aakef/hello http://localhost:9090/run\n")
	} else {
		if out, err := exec.Command("docker", "pull", *container).CombinedOutput(); err != nil {
			log.Fatalf("error pulling %s: %v, %s", *container, err, out)
		}
		log.Printf("Listening on %s", *listenAddr)
	}

	mux.Handle("/health", http.HandlerFunc(healthHandler))
	mux.Handle("/", http.HandlerFunc(rootHandler))
	mux.Handle("/run", http.HandlerFunc(runHandler))

	makeWorkers()
	go PeriodicallyDo(context.Background(), 10*time.Second, func(ctx context.Context, _ time.Time) {
		countDockerContainers(ctx)
	})

	httpServer = &http.Server{
		Addr:    *listenAddr,
		Handler: mux,
	}
	log.Fatal(httpServer.ListenAndServe())
}

// dockerContainer is the structure of each line output from docker ps.
type dockerContainer struct {
	// ID is the docker container ID.
	ID string `json:"ID"`
	// Image is the docker image name.
	Image string `json:"Image"`
	// Names is the docker container name.
	Names string `json:"Names"`
}

// countDockerContainers records the metric for the current number of docker containers.
// It also records the count of any unwanted containers.
func countDockerContainers(ctx context.Context) {
	cs, err := listDockerContainers(ctx)
	if err != nil {
		log.Printf("Error counting docker containers: %v", err)
	}
	log.Printf("Docker containers: %v", len(cs))
	var unwantedCount int64
	for _, c := range cs {
		if c.Names != "" && !isContainerWanted(c.Names) {
			unwantedCount++
		}
	}
	log.Printf("Unwanted containers: %v", unwantedCount)
}

// listDockerContainers returns the current running play_run containers reported by docker.
func listDockerContainers(ctx context.Context) ([]dockerContainer, error) {
	out := new(bytes.Buffer)
	cmd := exec.Command("docker", "ps", "--filter", "name=play_run_", "--format", "{{json .}}")
	cmd.Stdout, cmd.Stderr = out, out
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("listDockerContainers: cmd.Start() failed: %w", err)
	}
	ctx, cancel := context.WithTimeout(ctx, time.Second)
	defer cancel()
	if err := WaitOrStop(ctx, cmd, os.Interrupt, 250*time.Millisecond); err != nil {
		return nil, fmt.Errorf("listDockerContainers: WaitOrStop() failed: %w", err)
	}
	return parseDockerContainers(out.Bytes())
}

// parseDockerContainers parses the json formatted docker output from docker ps.
//
// If there is an error scanning the input, or non-JSON output is encountered, an error is returned.
func parseDockerContainers(b []byte) ([]dockerContainer, error) {
	// Parse the output to ensure it is well-formatted in the structure we expect.
	var containers []dockerContainer
	// Each output line is it's own JSON object, so unmarshal one line at a time.
	scanner := bufio.NewScanner(bytes.NewReader(b))
	for scanner.Scan() {
		var do dockerContainer
		if err := json.Unmarshal(scanner.Bytes(), &do); err != nil {
			return nil, fmt.Errorf("parseDockerContainers: error parsing docker ps output: %w", err)
		}
		containers = append(containers, do)
	}
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("parseDockerContainers: error reading docker ps output: %w", err)
	}
	return containers, nil
}

func handleSignals() {
	c := make(chan os.Signal, 1)
	signal.Notify(c, syscall.SIGINT)
	s := <-c
	log.Fatalf("closing on signal %d: %v", s, s)
}

var healthStatus struct {
	sync.Mutex
	lastCheck time.Time
	lastVal   error
}

func getHealthCached() error {
	healthStatus.Lock()
	defer healthStatus.Unlock()
	const recentEnough = 5 * time.Second
	if healthStatus.lastCheck.After(time.Now().Add(-recentEnough)) {
		return healthStatus.lastVal
	}

	err := checkHealth()
	if healthStatus.lastVal == nil && err != nil {
		// On transition from healthy to unhealthy, close all
		// idle HTTP connections so clients with them open
		// don't reuse them.
		httpServer.SetKeepAlivesEnabled(false) // side effect of closing all idle ones
		httpServer.SetKeepAlivesEnabled(true)  // and restore it back to normal
	}
	healthStatus.lastVal = err
	healthStatus.lastCheck = time.Now()
	return err
}

// checkHealth does a health check, without any caching. It's called via
// getHealthCached.
func checkHealth() error {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	c, err := getContainer(ctx)
	if err != nil {
		return fmt.Errorf("failed to get a sandbox container: %v", err)
	}
	// TODO: execute something too? for now we just check that sandboxed containers
	// are available.
	closed := make(chan struct{})
	go func() {
		c.Close()
		close(closed)
	}()
	select {
	case <-closed:
		// success.
		return nil
	case <-ctx.Done():
		return fmt.Errorf("timeout closing sandbox container")
	}
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	// TODO: split into liveness & readiness checks?
	if err := getHealthCached(); err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		fmt.Fprintf(w, "health check failure: %v\n", err)
		return
	}
	io.WriteString(w, "OK\n")
}

func rootHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	io.WriteString(w, "Hi from sandbox\n")
}

// processMeta is the JSON sent to the gvisor container before the untrusted binary.
// It currently contains only the arguments to pass to the binary.
// It might contain environment or other things later.
type processMeta struct {
	Args []string `json:"args"`
}

// runInGvisor is run when we're now inside gvisor. We have no network
// at this point. We can read our binary in from stdin and then run
// it.
func runInGvisor() {
	const binPath = "/tmpfs/play"
	const gotutorPath = "/usr/local/bin/gotutor"
	if _, err := io.WriteString(os.Stdout, containedStartMessage); err != nil {
		log.Fatalf("writing to stdout: %v", err)
	}
	slurp, err := io.ReadAll(os.Stdin)
	if err != nil {
		log.Fatalf("reading stdin in contained mode: %v", err)
	}
	nl := bytes.IndexByte(slurp, '\n')
	if nl == -1 {
		log.Fatalf("no newline found in input")
	}
	metaJSON, buildLocAndMainDotGoAndBin := slurp[:nl], slurp[nl+1:]

	nl = bytes.IndexByte(buildLocAndMainDotGoAndBin, '\n')
	buildLoc := buildLocAndMainDotGoAndBin[:nl]
	mainDotGoAndBin := buildLocAndMainDotGoAndBin[nl+1:]

	nl = bytes.Index(mainDotGoAndBin, []byte(binarySeparator))
	mainDotGo := mainDotGoAndBin[:nl]
	bin := mainDotGoAndBin[nl+len(binarySeparator):]

	if err := os.WriteFile(binPath, bin, 0755); err != nil {
		log.Fatalf("writing contained binary: %v", err)
	}

	mainDotGoPath := filepath.Join(string(buildLoc), "main.go")
	os.MkdirAll(string(buildLoc), 0755)
	if err := os.WriteFile(mainDotGoPath, mainDotGo, 0644); err != nil {
		log.Fatalf("writing contained main.go: %v", err)
	}

	defer os.Remove(binPath) // not that it matters much, this container will be nuked
	defer os.Remove(mainDotGoPath)

	var meta processMeta
	if err := json.NewDecoder(bytes.NewReader(metaJSON)).Decode(&meta); err != nil {
		log.Fatalf("error decoding JSON meta: %v", err)
	}

	if _, err := os.Stderr.Write(containedStderrHeader); err != nil {
		log.Fatalf("writing header to stderr: %v", err)
	}

	err = os.Mkdir("output", 0755)
	if err != nil {
		log.Fatalf("error creating output directory: %v", err)
	}
	cmd := exec.Command(gotutorPath, "exec", binPath)
	cmd.Args = append(cmd.Args, meta.Args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		log.Fatalf("cmd.Start(): %v", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), runTimeout-500*time.Millisecond)
	defer cancel()
	if err = WaitOrStop(ctx, cmd, os.Interrupt, 3*time.Second); err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			fmt.Fprintln(os.Stderr, "timeout running program")
		}
	}
	stepsFile, err := os.Open("output/steps.json")
	if err != nil {
		log.Fatalf("error opening steps.json: %v", err)
	}
	defer stepsFile.Close()
	io.Copy(cmd.Stdout, stepsFile)
	os.Exit(errExitCode(err))
}

func makeWorkers() {
	ctx := context.Background()
	for i := 0; i < *numWorkers; i++ {
		go workerLoop(ctx)
	}
}

func workerLoop(ctx context.Context) {
	for {
		log.Printf("Starting container")
		c, err := startContainer(ctx)
		if err != nil {
			log.Printf("error starting container: %v", err)
			time.Sleep(5 * time.Second)
			continue
		}
		readyContainer <- c
	}
}

func randHex(n int) string {
	b := make([]byte, n/2)
	_, err := rand.Read(b)
	if err != nil {
		panic(err)
	}
	return fmt.Sprintf("%x", b)
}

var (
	wantedMu        sync.Mutex
	containerWanted = map[string]bool{}
)

// setContainerWanted records whether a named container is wanted or
// not. Any unwanted containers are cleaned up asynchronously as a
// sanity check against leaks.
//
// TODO(bradfitz): add leak checker (background docker ps loop)
func setContainerWanted(name string, wanted bool) {
	wantedMu.Lock()
	defer wantedMu.Unlock()
	if wanted {
		containerWanted[name] = true
	} else {
		delete(containerWanted, name)
	}
}

func isContainerWanted(name string) bool {
	wantedMu.Lock()
	defer wantedMu.Unlock()
	return containerWanted[name]
}

func getContainer(ctx context.Context) (*Container, error) {
	select {
	case c := <-readyContainer:
		return c, nil
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

func startContainer(ctx context.Context) (*Container, error) {

	name := "play_run_" + randHex(8)
	setContainerWanted(name, true)
	cmd := exec.Command("docker", "run",
		"--name="+name,
		"--rm",
		"--tmpfs=/tmpfs:exec",
		"-i", // read stdin

		"--runtime=runsc",
		"--network=none",
		"--memory="+fmt.Sprint(memoryLimitBytes),

		*container,
		"--mode=contained")
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	pr, pw := io.Pipe()
	stdout := &limitedWriter{dst: &bytes.Buffer{}, n: maxOutputSize + int64(len(containedStartMessage))}
	stderr := &limitedWriter{dst: &bytes.Buffer{}, n: maxOutputSize}
	cmd.Stdout = &switchWriter{switchAfter: []byte(containedStartMessage), dst1: pw, dst2: stdout}
	cmd.Stderr = stderr
	if err := cmd.Start(); err != nil {
		return nil, err
	}

	ctx, cancel := context.WithCancel(ctx)
	c := &Container{
		name:      name,
		stdin:     stdin,
		stdout:    stdout,
		stderr:    stderr,
		cmd:       cmd,
		cancelCmd: cancel,
		waitErr:   make(chan error, 1),
	}
	go func() {
		c.waitErr <- WaitOrStop(ctx, cmd, os.Interrupt, 250*time.Millisecond)
	}()
	defer func() {
		if err != nil {
			c.Close()
		}
	}()

	startErr := make(chan error, 1)
	go func() {
		buf := make([]byte, len(containedStartMessage))
		_, err := io.ReadFull(pr, buf)
		if err != nil {
			startErr <- fmt.Errorf("error reading header from sandbox container: %v", err)
		} else if string(buf) != containedStartMessage {
			startErr <- fmt.Errorf("sandbox container sent wrong header %q; want %q", buf, containedStartMessage)
		} else {
			startErr <- nil
		}
	}()

	timer := time.NewTimer(startTimeout)
	defer timer.Stop()
	select {
	case <-timer.C:
		err := fmt.Errorf("timeout starting container %q", name)
		cancel()
		<-startErr
		return nil, err

	case err := <-startErr:
		if err != nil {
			return nil, err
		}
	case err := <-c.waitErr:
		if err != nil {
			return nil, fmt.Errorf("%w: %v", err, c.stderr.dst.String())
		}
	}

	log.Printf("started container %q", name)
	return c, nil
}

func runHandler(w http.ResponseWriter, r *http.Request) {
	t0 := time.Now()
	tlast := t0
	var logmu sync.Mutex
	logf := func(format string, args ...interface{}) {
		if !*dev {
			return
		}
		logmu.Lock()
		defer logmu.Unlock()
		t := time.Now()
		d := t.Sub(tlast)
		d0 := t.Sub(t0)
		tlast = t
		log.Print(fmt.Sprintf("+%10v +%10v ", d0, d) + fmt.Sprintf(format, args...))
	}
	logf("/run")

	if r.Method != "POST" {
		http.Error(w, "expected a POST", http.StatusBadRequest)
		return
	}

	// Bound the number of requests being processed at once.
	// (Before we slurp the binary into memory)
	select {
	case runSem <- struct{}{}:
	case <-r.Context().Done():
		return
	}
	defer func() { <-runSem }()

	body := http.MaxBytesReader(w, r.Body, maxBinarySize)
	request := &sandboxtypes.Request{}
	if err := json.NewDecoder(body).Decode(request); err != nil {
		log.Printf("failed to decode request: %v", err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	logf("read %d bytes", len(request.Binary))

	c, err := getContainer(r.Context())
	if err != nil {
		if cerr := r.Context().Err(); cerr != nil {
			log.Printf("getContainer, client side cancellation: %v", cerr)
			return
		}
		http.Error(w, "failed to get container", http.StatusInternalServerError)
		log.Printf("failed to get container: %v", err)
		return
	}
	logf("got container %s", c.name)

	ctx, cancel := context.WithTimeout(context.Background(), runTimeout)
	closed := make(chan struct{})
	defer func() {
		logf("leaving handler; about to close container")
		cancel()
		<-closed
	}()
	go func() {
		<-ctx.Done()
		if ctx.Err() == context.DeadlineExceeded {
			logf("timeout")
		}
		c.Close()
		close(closed)
	}()
	var meta processMeta
	meta.Args = r.Header["X-Argument"]
	metaJSON, _ := json.Marshal(&meta)
	metaJSON = append(metaJSON, '\n')
	if _, err := c.stdin.Write(metaJSON); err != nil {
		log.Printf("failed to write meta to child: %v", err)
		http.Error(w, "unknown error during docker run", http.StatusInternalServerError)
		return
	}
	buildLoc := append([]byte(request.BuildLoc), '\n')
	if _, err := c.stdin.Write(buildLoc); err != nil {
		log.Printf("failed to write build loc to child: %v", err)
		http.Error(w, "unknown error during docker run", http.StatusInternalServerError)
		return
	}
	mainDotGo := append(request.MainDotGo, binarySeparator...)
	if _, err := c.stdin.Write(mainDotGo); err != nil {
		log.Printf("failed to write main.go to child: %v", err)
		http.Error(w, "unknown error during docker run", http.StatusInternalServerError)
		return
	}
	if _, err := c.stdin.Write(request.Binary); err != nil {
		log.Printf("failed to write binary to child: %v", err)
		http.Error(w, "unknown error during docker run", http.StatusInternalServerError)
		return
	}

	c.stdin.Close()
	logf("wrote+closed")
	err = c.Wait()
	select {
	case <-ctx.Done():
		// Timed out or canceled before or exactly as Wait returned.
		// Either way, treat it as a timeout.
		sendError(w, "timeout running program")
		return
	default:
		logf("finished running; about to close container")
		cancel()
	}
	res := &sandboxtypes.Response{}
	if err != nil {
		if c.stderr.n < 0 || c.stdout.n < 0 {
			// Do not send truncated output, just send the error.
			sendError(w, errTooMuchOutput.Error())
			return
		}
		var ee *exec.ExitError
		if !errors.As(err, &ee) {
			http.Error(w, "unknown error during docker run", http.StatusInternalServerError)
			return
		}
		res.ExitCode = ee.ExitCode()
	}
	res.ExecutionSteps = c.stdout.dst.Bytes()
	sendResponse(w, res)
}

// limitedWriter is an io.Writer that returns an errTooMuchOutput when the cap (n) is hit.
type limitedWriter struct {
	dst *bytes.Buffer
	n   int64 // max bytes remaining
}

// Write is an io.Writer function that returns errTooMuchOutput when the cap (n) is hit.
//
// Partial data will be written to dst if p is larger than n, but errTooMuchOutput will be returned.
func (l *limitedWriter) Write(p []byte) (int, error) {
	defer func() { l.n -= int64(len(p)) }()

	if l.n <= 0 {
		return 0, errTooMuchOutput
	}

	if int64(len(p)) > l.n {
		n, err := l.dst.Write(p[:l.n])
		if err != nil {
			return n, err
		}
		return n, errTooMuchOutput
	}

	return l.dst.Write(p)
}

// switchWriter writes to dst1 until switchAfter is written, the it writes to dst2.
type switchWriter struct {
	dst1        io.Writer
	dst2        io.Writer
	switchAfter []byte
	buf         []byte
	found       bool
}

func (s *switchWriter) Write(p []byte) (int, error) {
	if s.found {
		return s.dst2.Write(p)
	}

	s.buf = append(s.buf, p...)
	i := bytes.Index(s.buf, s.switchAfter)
	if i == -1 {
		if len(s.buf) >= len(s.switchAfter) {
			s.buf = s.buf[len(s.buf)-len(s.switchAfter)+1:]
		}
		return s.dst1.Write(p)
	}

	s.found = true
	nAfter := len(s.buf) - (i + len(s.switchAfter))
	s.buf = nil

	n, err := s.dst1.Write(p[:len(p)-nAfter])
	if err != nil {
		return n, err
	}
	n2, err := s.dst2.Write(p[len(p)-nAfter:])
	return n + n2, err
}

func errExitCode(err error) int {
	if err == nil {
		return 0
	}
	var ee *exec.ExitError
	if errors.As(err, &ee) {
		return ee.ExitCode()
	}
	return 1
}

func sendError(w http.ResponseWriter, errMsg string) {
	sendResponse(w, &sandboxtypes.Response{Error: errMsg})
}

func sendResponse(w http.ResponseWriter, r *sandboxtypes.Response) {
	jres, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		http.Error(w, "error encoding JSON", http.StatusInternalServerError)
		log.Printf("json marshal: %v", err)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Content-Length", fmt.Sprint(len(jres)))
	w.Write(jres)
}

// cleanStderr removes spam stderr lines from the beginning of x
// and returns a slice of x.
func cleanStderr(x []byte) []byte {
	i := bytes.Index(x, containedStderrHeader)
	if i == -1 {
		return x
	}
	return x[i+len(containedStderrHeader):]
}

// WaitOrStop waits for the already-started command cmd by calling its Wait method.
//
// If cmd does not return before ctx is done, WaitOrStop sends it the given interrupt signal.
// If killDelay is positive, WaitOrStop waits that additional period for Wait to return before sending os.Kill.
func WaitOrStop(ctx context.Context, cmd *exec.Cmd, interrupt os.Signal, killDelay time.Duration) error {
	if cmd.Process == nil {
		panic("WaitOrStop called with a nil cmd.Process — missing Start call?")
	}
	if interrupt == nil {
		panic("WaitOrStop requires a non-nil interrupt signal")
	}

	errc := make(chan error)
	go func() {
		select {
		case errc <- nil:
			return
		case <-ctx.Done():
		}

		err := cmd.Process.Signal(interrupt)
		if err == nil {
			err = ctx.Err() // Report ctx.Err() as the reason we interrupted.
		} else if err.Error() == "os: process already finished" {
			errc <- nil
			return
		}

		if killDelay > 0 {
			timer := time.NewTimer(killDelay)
			select {
			// Report ctx.Err() as the reason we interrupted the process...
			case errc <- ctx.Err():
				timer.Stop()
				return
			// ...but after killDelay has elapsed, fall back to a stronger signal.
			case <-timer.C:
			}

			// Wait still hasn't returned.
			// Kill the process harder to make sure that it exits.
			//
			// Ignore any error: if cmd.Process has already terminated, we still
			// want to send ctx.Err() (or the error from the Interrupt call)
			// to properly attribute the signal that may have terminated it.
			_ = cmd.Process.Kill()
		}

		errc <- err
	}()

	waitErr := cmd.Wait()
	if interruptErr := <-errc; interruptErr != nil {
		return interruptErr
	}
	return waitErr
}

// PeriodicallyDo calls f every period until the provided context is cancelled.
func PeriodicallyDo(ctx context.Context, period time.Duration, f func(context.Context, time.Time)) {
	ticker := time.NewTicker(period)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-ticker.C:
			f(ctx, now)
		}
	}
}
