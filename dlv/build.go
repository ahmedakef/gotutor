package dlv

import (
	"fmt"
	"runtime"

	"github.com/go-delve/delve/pkg/gobuild"
	"github.com/go-delve/delve/pkg/goversion"
)

// Build builds the binary in temporary directory and return the path to the binary given a sourcePath
func Build(sourcePath string, outputPrefix string) (string, error) {
	args := []string{sourcePath}
	debugName, err := buildBinary(args, outputPrefix, false)
	return debugName, err
}

func buildBinary(args []string, outputPrefix string, isTest bool) (string, error) {
	buildFlags := GetBuildFlags()
	var debugName string
	var err error
	if isTest {
		debugName = gobuild.DefaultDebugBinaryPath(outputPrefix + "debug.test")
	} else {
		debugName = gobuild.DefaultDebugBinaryPath(outputPrefix + "__debug_bin")
	}

	var out []byte
	if isTest {
		_, out, err = gobuild.GoTestBuildCombinedOutput(debugName, args, buildFlags)
	} else {
		_, out, err = gobuild.GoBuildCombinedOutput(debugName, args, buildFlags)
	}
	if err != nil {
		err = fmt.Errorf("%v%w", string(out), err)
	}
	return debugName, err
}

// GetBuildFlags returns the default build flags for the current platform
func GetBuildFlags() string {
	buildFlagsDefault := ""
	if runtime.GOOS == "windows" {
		ver, _ := goversion.Installed()
		if ver.Major > 0 && !ver.AfterOrEqual(goversion.GoVersion{Major: 1, Minor: 9, Rev: -1}) {
			// Work-around for https://github.com/golang/go/issues/13154
			buildFlagsDefault = "-ldflags='-linkmode internal'"
		}
	}
	//buildFlagsDefault += " -gcflags='all=-N -l'" // Disable optimizations and inlining, probably already added in goBuildArgs2 in github.com/go-delve/delve@v1.24.0/pkg/gobuild/gobuild.go
	return buildFlagsDefault
}
