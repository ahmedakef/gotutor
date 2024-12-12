package main

import (
	"fmt"
	"github.com/go-delve/delve/pkg/gobuild"
	"io"
	"os"
	"path/filepath"
)

// given a sourcePath, build the binary in temporary directory and return the path to the binary
func buildFromFile(sourcePath string, buildFlags string) (string, bool) {
	tmpDir, err := os.MkdirTemp("", "build")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to create temp directory: %v\n", err)
		return "", false
	}
	destPath := filepath.Join(tmpDir, filepath.Base(sourcePath)+".go")
	err = copy(sourcePath, destPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to copy file: %v\n", err)
		return "", false
	}

	args := []string{destPath}
	debugName, success := buildBinary(args, buildFlags, false)
	if !success {
		return "", false
	}
	return debugName, true
}

func buildBinary(args []string, buildFlags string, isTest bool) (string, bool) {

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
