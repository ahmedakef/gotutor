package dlv

import (
	"fmt"
	"os"
	"runtime"

	"github.com/go-delve/delve/pkg/gobuild"
	"github.com/go-delve/delve/pkg/goversion"
)

// given a sourcePath, build the binary in temporary directory and return the path to the binary
func Build(sourcePath string) (string, bool) {
	args := []string{sourcePath}
	debugName, success := buildBinary(args, false)
	if !success {
		return "", false
	}
	return debugName, true
}

func buildBinary(args []string, isTest bool) (string, bool) {
	buildFlags := getBuildFlags()
	var debugName string
	var err error
	if isTest {
		debugName = gobuild.DefaultDebugBinaryPath("debug.test")
	} else {
		debugName = gobuild.DefaultDebugBinaryPath("__debug_bin")
	}

	if isTest {
		err = gobuild.GoTestBuild(debugName, args, buildFlags)
	} else {
		err = gobuild.GoBuild(debugName, args, buildFlags)
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		return "", false
	}
	return debugName, true
}

func getBuildFlags() string {
	buildFlagsDefault := ""
	if runtime.GOOS == "windows" {
		ver, _ := goversion.Installed()
		if ver.Major > 0 && !ver.AfterOrEqual(goversion.GoVersion{Major: 1, Minor: 9, Rev: -1}) {
			// Work-around for https://github.com/golang/go/issues/13154
			buildFlagsDefault = "-ldflags='-linkmode internal'"
		}
	}
	//buildFlagsDefault += " -gcflags='all=-N -l'" // Disable optimizations and inlining
	return buildFlagsDefault
}
