package main

import (
	"errors"
	"fmt"
	"github.com/go-delve/delve/pkg/logflags"
	"github.com/go-delve/delve/pkg/proc"
	"github.com/go-delve/delve/service"
	"github.com/go-delve/delve/service/api"
	"github.com/go-delve/delve/service/debugger"
	"github.com/go-delve/delve/service/rpc2"
	"github.com/go-delve/delve/service/rpccommon"
	"net"
	"os"
	"os/signal"
	"runtime"
	"strings"
	"syscall"
)

var (
	// addr is the debugging server listen address.
	addr       = "127.0.0.1:0"
	workingDir = ""
	apiVersion = 2
	// checkLocalConnUser is true if the debugger should check that local
	// connections come from the same user that started the headless server
	checkLocalConnUser = true
	// backend selection
	backend = "default"
	// checkGoVersion is true if the debugger should check the version of Go
	// used to compile the executable and refuse to work on incompatible
	// versions.
	checkGoVersion = true

	// redirect specifications for target process
	redirects = [3]string{}
)

func execute(attachPid int, processArgs []string, kind debugger.ExecuteKind, debugName string, buildFlags string) int {

	continueOnStart := false
	acceptMulti := false
	if continueOnStart {
		if !acceptMulti {
			fmt.Fprint(os.Stderr, "Error: --continue requires --accept-multiclient\n")
			return 1
		}
	}

	var listener net.Listener
	var err error

	// Make a TCP listener
	listener, err = netListen(addr)

	if err != nil {
		fmt.Printf("couldn't start listener: %s\n", err)
		return 1
	}
	defer listener.Close()

	var server service.Server

	disconnectChan := make(chan struct{})

	if workingDir == "" {
		workingDir = "."
	}

	// Create and start a debugger server

	server = rpccommon.NewServer(&service.Config{
		Listener:           listener,
		ProcessArgs:        processArgs,
		AcceptMulti:        acceptMulti,
		APIVersion:         apiVersion,
		CheckLocalConnUser: checkLocalConnUser,
		DisconnectChan:     disconnectChan,
		Debugger: debugger.Config{
			AttachPid:             attachPid,
			WorkingDir:            workingDir,
			Backend:               backend,
			CoreFile:              "",
			Foreground:            true,
			Packages:              []string{debugName},
			BuildFlags:            buildFlags,
			ExecuteKind:           kind,
			DebugInfoDirectories:  []string{},
			CheckGoVersion:        checkGoVersion,
			TTY:                   "",
			Stdin:                 redirects[0],
			Stdout:                proc.OutputRedirect{Path: redirects[1]},
			Stderr:                proc.OutputRedirect{Path: redirects[2]},
			DisableASLR:           false,
			RrOnProcessPid:        0,
			AttachWaitFor:         "",
			AttachWaitForInterval: 1,
			AttachWaitForDuration: 0,
		},
	})

	if err := server.Run(); err != nil {
		if errors.Is(err, api.ErrNotExecutable) {
			switch kind {
			case debugger.ExecutingGeneratedFile:
				fmt.Fprintln(os.Stderr, "Can not debug non-main package")
				return 1
			case debugger.ExecutingExistingFile:
				fmt.Fprintf(os.Stderr, "%s is not executable\n", processArgs[0])
				return 1
			default:
				// fallthrough
			}
		}
		fmt.Fprintln(os.Stderr, err)
		return 1
	}

	if continueOnStart {
		addr := listener.Addr().String()
		if _, isuds := listener.(*net.UnixListener); isuds {
			addr = "unix:" + addr
		}
		client := rpc2.NewClientFromConn(netDial(addr))
		client.Disconnect(true) // true = continue after disconnect
	}
	waitForDisconnectSignal(disconnectChan)
	err = server.Stop()
	if err != nil {
		fmt.Println(err)
	}

	return 0
}

const unixAddrPrefix = "unix:"

func netListen(addr string) (net.Listener, error) {
	if strings.HasPrefix(addr, unixAddrPrefix) {
		return net.Listen("unix", addr[len(unixAddrPrefix):])
	}
	return net.Listen("tcp", addr)
}

// waitForDisconnectSignal is a blocking function that waits for either
// a SIGINT (Ctrl-C) or SIGTERM (kill -15) OS signal or for disconnectChan
// to be closed by the server when the client disconnects.
// Note that in headless mode, the debugged process is foregrounded
// (to have control of the tty for debugging interactive programs),
// so SIGINT gets sent to the debuggee and not to delve.
func waitForDisconnectSignal(disconnectChan chan struct{}) {
	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)
	if runtime.GOOS == "windows" {
		// On windows Ctrl-C sent to inferior process is delivered
		// as SIGINT to delve. Ignore it instead of stopping the server
		// in order to be able to debug signal handlers.
		go func() {
			for range ch {
			}
		}()
		<-disconnectChan
	} else {
		select {
		case <-ch:
		case <-disconnectChan:
		}
	}
}

func netDial(addr string) net.Conn {
	var conn net.Conn
	var err error
	if strings.HasPrefix(addr, unixAddrPrefix) {
		conn, err = net.Dial("unix", addr[len(unixAddrPrefix):])
	} else {
		conn, err = net.Dial("tcp", addr)
	}
	if err != nil {
		logflags.RPCLogger().Errorf("error dialing %s: %v", addr, err)
	}
	return conn
}
