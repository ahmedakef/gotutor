package main

import (
	"fmt"
	"github.com/go-delve/delve/pkg/gobuild"
	"github.com/go-delve/delve/pkg/goversion"
	"io"
	"os"
	"path/filepath"
	"runtime"
)

// given a sourcePath, build the binary in temporary directory and return the path to the binary
func buildFromFile(sourcePath string) (string, bool) {
	tmpDir, err := os.MkdirTemp("", "build")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create temp directory: %v\n", err)
		return "", false
	}
	defer os.RemoveAll(tmpDir)
	destPath := filepath.Join(tmpDir, filepath.Base(sourcePath)+".go")
	err = copy(sourcePath, destPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to copy file: %v\n", err)
		return "", false
	}

	args := []string{destPath}
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

// copy copies a file from src to dst
func copy(src, dst string) error {
	sourceFile, err := os.Open(src)
	if err != nil {
		return err
	}
	defer sourceFile.Close()

	destFile, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer destFile.Close()

	_, err = io.Copy(destFile, sourceFile)
	if err != nil {
		return err
	}

	return nil
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
	return buildFlagsDefault
}
