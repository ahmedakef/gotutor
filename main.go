package main

import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"
	"vis/serialize"

	"github.com/go-delve/delve/pkg/gobuild"
)

var addr = ":8083"

func main() {
	done := make(chan bool, 1)
	go waitForSignal(done)

	debugName, ok := buildFromFile("source")
	if !ok {
		fmt.Println("Failed to build binary")
		return
	}
	defer gobuild.Remove(debugName)
	serverDone := make(chan struct{})
	go func() {
		err := runDebugServer(debugName, addr)
		if err != nil {
			fmt.Println("Failed to run debug server", err)
			return
		}
		close(serverDone)
	}()
	time.Sleep(1 * time.Second)
	client, err := connect(addr)
	if err != nil {
		fmt.Println("Failed to connect to server:", err)
		return
	}
	serializer := serialize.NewSerializer(client)
	serializer.ExecutionSteps()

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
