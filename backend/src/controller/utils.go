package controller

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"time"
)

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

func writeSourceCodeToFile(sourcePath, sourceCode string) error {
	file, err := os.Create(sourcePath)
	if err != nil {
		return fmt.Errorf("create %s file: %w", sourcePath, err)
	}
	defer file.Close()

	_, err = file.WriteString(sourceCode)
	if err != nil {
		return fmt.Errorf("write to %s file: %w", sourcePath, err)
	}
	return nil
}

func readFileToString(filePath string) (string, error) {
	contents, err := os.ReadFile(filePath)
	if err != nil {
		return "", fmt.Errorf("error while reading %s file: %w", filePath, err)
	}
	return string(contents), nil
}
