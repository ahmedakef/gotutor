package controller

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"go/parser"
	"go/token"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/ahmedakef/gotutor/backend/src/pkg/txtar"
)

const (
	// Time for 'go build' to download 3rd-party modules and compile.
	maxBuildTime = 10 * time.Second
)

const (
	goBuildTimeoutError = "timeout running go build"
)

// buildResult is the output of a sandbox build attempt.
type buildResult struct {
	// goPath is a temporary directory if the binary was built with module support.
	// TODO(golang.org/issue/25224) - Why is the module mode built so differently?
	goPath string
	// exePath is the path to the built binary.
	exePath string
	// testParam is set if tests should be run when running the binary.
	testParam string
	// errorMessage is an error message string to be returned to the user.
	errorMessage string
	// vetOut is the output of go vet, if requested.
	vetOut string
}

// cleanup cleans up the temporary goPath created when building with module support.
func (b *buildResult) cleanup() error {
	if b.goPath != "" {
		return os.RemoveAll(b.goPath)
	}
	return nil
}

// sandboxBuild builds a Go program and returns a build result that includes the build context.
//
// An error is returned if a non-user-correctable error has occurred.
func (c *Controller) sandboxBuild(ctx context.Context, tmpDir string, in []byte, vet bool) (br *buildResult, err error) {
	files, err := txtar.SplitFiles(in)
	if err != nil {
		return &buildResult{errorMessage: err.Error()}, nil
	}

	br = new(buildResult)
	defer br.cleanup()
	var buildPkgArg = "."
	if len(files.Data(txtar.ProgName)) > 0 {
		src := files.Data(txtar.ProgName)
		if isTestProg(src) {
			br.testParam = "-test.v"
			files.MvFile(txtar.ProgName, txtar.ProgTestName)
		}
	}

	if !files.Contains("go.mod") {
		files.AddFile("go.mod", []byte("module play\n"))
	}

	var exp []string
	for f, src := range files.Map() {
		// Before multi-file support we required that the
		// program be in package main, so continue to do that
		// for now. But permit anything in subdirectories to have other
		// packages.
		if !strings.Contains(f, "/") {
			fset := token.NewFileSet()
			f, err := parser.ParseFile(fset, f, src, parser.PackageClauseOnly)
			if err == nil && f.Name.Name != "main" {
				return &buildResult{errorMessage: "package name must be main"}, nil
			}
			exp = append(exp, experiments(string(src))...)
		}

		in := filepath.Join(tmpDir, f)
		if strings.Contains(f, "/") {
			if err := os.MkdirAll(filepath.Dir(in), 0755); err != nil {
				return nil, err
			}
		}
		if err := os.WriteFile(in, src, 0644); err != nil {
			return nil, fmt.Errorf("error creating temp file %q: %v", in, err)
		}
	}

	br.exePath = filepath.Join(tmpDir, "a.out")
	goCache := filepath.Join(tmpDir, "gocache")

	// Copy the gocache directory containing .a files for std, so that we can
	// avoid recompiling std during this build. Using -al (hard linking) is
	// faster than actually copying the bytes.
	//
	// This is necessary as .a files are no longer included in GOROOT following
	// https://go.dev/cl/432535.
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("error getting home directory: %v", err)
	}
	gocacheDir := filepath.Join(homeDir, "gocache")
	if err := exec.Command("cp", "-al", gocacheDir, goCache).Run(); err != nil {
		return nil, fmt.Errorf("error copying GOCACHE: %v", err)
	}

	var goArgs []string
	if br.testParam != "" {
		goArgs = append(goArgs, "test", "-c")
	} else {
		goArgs = append(goArgs, "build")
	}
	goArgs = append(goArgs, "-o", br.exePath, "-tags=faketime")

	cmd := exec.Command("/usr/local/go-faketime/bin/go", goArgs...)
	cmd.Dir = tmpDir
	cmd.Env = []string{"GOOS=linux", "GOARCH=amd64", "GOROOT=/usr/local/go-faketime"}
	cmd.Env = append(cmd.Env, "GOCACHE="+goCache)
	cmd.Env = append(cmd.Env, "CGO_ENABLED=0")
	cmd.Env = append(cmd.Env, "GOEXPERIMENT="+strings.Join(exp, ","))
	// Create a GOPATH just for modules to be downloaded
	// into GOPATH/pkg/mod.
	cmd.Args = append(cmd.Args, "-modcacherw")
	cmd.Args = append(cmd.Args, "-mod=mod")
	br.goPath, err = os.MkdirTemp("", "gopath")
	if err != nil {
		c.logger.Error().Err(err).Msg("error creating temp directory")
		return nil, fmt.Errorf("error creating temp directory: %v", err)
	}
	cmd.Env = append(cmd.Env, "GO111MODULE=on", "GOPROXY="+playgroundGoproxy())
	cmd.Args = append(cmd.Args, buildPkgArg)
	cmd.Env = append(cmd.Env, "GOPATH="+br.goPath)
	out := &bytes.Buffer{}
	cmd.Stderr, cmd.Stdout = out, out

	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("error starting go build: %v", err)
	}
	ctx, cancel := context.WithTimeout(ctx, maxBuildTime)
	defer cancel()
	if err := WaitOrStop(ctx, cmd, os.Interrupt, 250*time.Millisecond); err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			br.errorMessage = fmt.Sprintln(goBuildTimeoutError)
		} else if ee := (*exec.ExitError)(nil); !errors.As(err, &ee) {
			c.logger.Error().Err(err).Msg("error building program")
			return nil, fmt.Errorf("error building go source: %v", err)
		}
		// Return compile errors to the user.
		// Rewrite compiler errors to strip the tmpDir name.
		br.errorMessage = br.errorMessage + strings.Replace(out.String(), tmpDir+"/", "", -1)

		// "go build", invoked with a file name, puts this odd
		// message before any compile errors; strip it.
		br.errorMessage = strings.Replace(br.errorMessage, "# command-line-arguments\n", "", 1)

		return br, nil
	}
	const maxBinarySize = 100 << 20 // 100MB
	if fi, err := os.Stat(br.exePath); err != nil || fi.Size() == 0 || fi.Size() > maxBinarySize {
		if err != nil {
			return nil, fmt.Errorf("failed to stat binary: %v", err)
		}
		return nil, fmt.Errorf("invalid binary size %d", fi.Size())
	}
	if vet {
		// TODO: do this concurrently with the execution to reduce latency.
		br.vetOut, err = vetCheckInDir(ctx, tmpDir, br.goPath, exp)
		if err != nil {
			return nil, fmt.Errorf("running vet: %v", err)
		}
	}
	return br, nil
}

func outputContainsError(output string) (string, bool) {
	if strings.Contains(output, "failed to build binary") {
		startLoc := strings.Index(output, "data/main.go")
		endLoc := strings.Index(output, "exit status")
		if startLoc == -1 || endLoc == -1 {
			return "failed to build the binary", true
		}
		return output[startLoc : endLoc-2], true
	} else if strings.Contains(output, "limit reached") {
		return "failed to get execution steps: limit reached", true
	}
	return output, false
}

// removeBanner remove package name banner
func removeBanner(output string) string {
	if strings.HasPrefix(output, "#") {
		if nl := strings.Index(output, "\n"); nl != -1 {
			output = output[nl+1:]
		}
	}
	return output
}

// playgroundGoproxy returns the GOPROXY environment config the playground should use.
// It is fetched from the environment variable PLAY_GOPROXY. A missing or empty
// value for PLAY_GOPROXY returns the default value of https://proxy.golang.org.
func playgroundGoproxy() string {
	proxypath := os.Getenv("PLAY_GOPROXY")
	if proxypath != "" {
		return proxypath
	}
	return "https://proxy.golang.org"
}
