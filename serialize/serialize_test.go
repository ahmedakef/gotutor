package serialize_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ahmedakef/gotutor/dlv"
	"github.com/ahmedakef/gotutor/serialize"
	"github.com/go-delve/delve/pkg/gobuild"
	"github.com/go-delve/delve/service/debugger"
	"github.com/rs/zerolog"
)

func TestExecutionStepsOnlyContainsUserCode(t *testing.T) {
	sourcePath, err := filepath.Abs("../example/main.go")
	if err != nil {
		t.Fatal(err)
	}
	// the debugger writes the program output to output/ in the working directory
	t.Chdir(t.TempDir())
	if err := os.Mkdir("output", 0755); err != nil {
		t.Fatal(err)
	}

	binaryPath, err := dlv.Build(sourcePath, "")
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	defer gobuild.Remove(binaryPath)

	client, err := dlv.RunServerAndGetClient(binaryPath, sourcePath, dlv.GetBuildFlags(), debugger.ExecutingGeneratedFile)
	if err != nil {
		t.Fatalf("run server: %v", err)
	}
	defer client.Detach(true)

	resp, err := serialize.NewSerializer(client, zerolog.Nop()).ExecutionSteps(t.Context(), 1000)
	if err != nil {
		t.Fatalf("execution steps: %v", err)
	}
	if len(resp.Steps) == 0 {
		t.Fatal("no steps")
	}

	sawWorker := false
	for i, step := range resp.Steps {
		if len(step.PackageVariables) != 1 || step.PackageVariables[0].Name != "main.packageVar" {
			t.Errorf("step %d: want only main.packageVar in package variables, got %+v", i, step.PackageVariables)
		}
		if len(step.GoroutinesData) == 0 || step.GoroutinesData[0].Goroutine.ID != 1 {
			t.Fatalf("step %d: want the main goroutine first", i)
		}
		for _, g := range step.GoroutinesData {
			if len(g.Stacktrace) == 0 {
				t.Errorf("step %d: goroutine %d has no user frames", i, g.Goroutine.ID)
			}
			for _, frame := range g.Stacktrace {
				if !strings.HasSuffix(frame.File, "main.go") {
					t.Errorf("step %d: goroutine %d has non-user frame %s", i, g.Goroutine.ID, frame.Function.Name())
				}
			}
			if len(g.Stacktrace) > 0 && g.Stacktrace[0].Function.Name() == "main.work" {
				sawWorker = true
				if len(g.Stacktrace[0].Arguments) != 2 {
					t.Errorf("step %d: want main.work arguments to be loaded, got %+v", i, g.Stacktrace[0].Arguments)
				}
			}
		}
	}
	if !sawWorker {
		t.Error("want the worker goroutines to be listed")
	}
}
