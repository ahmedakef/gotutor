package main

import (
	"fmt"
	"github.com/go-delve/delve/pkg/goversion"
	"github.com/go-delve/delve/service/debugger"
	"os"
	"runtime"
	"sync"

	"github.com/go-delve/delve/pkg/gobuild"
)

func main() {
	buildFlagsDefault := ""
	if runtime.GOOS == "windows" {
		ver, _ := goversion.Installed()
		if ver.Major > 0 && !ver.AfterOrEqual(goversion.GoVersion{Major: 1, Minor: 9, Rev: -1}) {
			// Work-around for https://github.com/golang/go/issues/13154
			buildFlagsDefault = "-ldflags='-linkmode internal'"
		}
	}
	debugName, ok := buildFromFile("source", buildFlagsDefault)
	if !ok {
		fmt.Println("Failed to build binary")
		os.Exit(1)
	}
	defer gobuild.Remove(debugName)
	var targetArgs []string
	processArgs := append([]string{debugName}, targetArgs...)
	wg := new(sync.WaitGroup)
	wg.Add(1)
	go func() {
		execute(0, processArgs, debugger.ExecutingGeneratedFile, debugName, buildFlagsDefault)
		wg.Done()
	}()
	wg.Wait()
}
