package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/go-delve/delve/pkg/gobuild"
)

func main() {
	done := make(chan bool, 1)
	go waitForSignal(done)

	debugName, ok := buildFromFile("source")
	if !ok {
		fmt.Println("Failed to build binary")
		os.Exit(1)
	}
	defer gobuild.Remove(debugName)
	serverDone := make(chan struct{})
	go func() {
		err := runDebugServer(debugName)
		if err != nil {
			fmt.Println("Failed to run debug server", err)
			os.Exit(1)
		}
		close(serverDone)
	}()

	select {
	case <-done:
		fmt.Println("Exiting")
	case <-serverDone:
		fmt.Println("Exiting")
	}
}

func waitForSignal(done chan bool) {
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)

	sig := <-sigs
	fmt.Println("\nreceived:", sig)
	done <- true

}
