// Copyright 2018 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package controller

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// vetCheckInDir runs go vet in the provided directory, using the
// provided GOPATH value. The returned error is only about whether
// go vet was able to run, not whether vet reported problem. The
// returned value is ("", nil) if vet successfully found nothing,
// and (non-empty, nil) if vet ran and found issues.
func vetCheckInDir(ctx context.Context, dir, goPath string, experiments []string) (output string, execErr error) {

	cmd := exec.Command("go", "vet", "--tags=faketime", "--mod=mod")
	cmd.Dir = dir
	// Linux go binary is not built with CGO_ENABLED=0.
	// Prevent vet to compile packages in cgo mode.
	// See #26307.
	cmd.Env = append(os.Environ(), "CGO_ENABLED=0", "GOPATH="+goPath)
	cmd.Env = append(cmd.Env,
		"GO111MODULE=on",
		"GOPROXY="+playgroundGoproxy(),
	)
	if len(experiments) > 0 {
		cmd.Env = append(cmd.Env, "GOEXPERIMENT="+strings.Join(experiments, ","))
	}
	out, err := cmd.CombinedOutput()
	if err == nil {
		return "", nil
	}
	if _, ok := err.(*exec.ExitError); !ok {
		return "", fmt.Errorf("error vetting go source: %v", err)
	}

	// Rewrite compiler errors to refer to progName
	// instead of '/tmp/sandbox1234/main.go'.
	errs := strings.Replace(string(out), dir, "", -1)
	errs = removeBanner(errs)
	return errs, nil
}
