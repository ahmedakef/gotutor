package dlv

import (
	"errors"
	"fmt"
	"net"
	"strings"

	"github.com/ahmedakef/gotutor/gateway"
	"github.com/go-delve/delve/pkg/logflags"
	"github.com/go-delve/delve/pkg/proc"
	"github.com/go-delve/delve/service"
	"github.com/go-delve/delve/service/api"
	"github.com/go-delve/delve/service/debugger"
	"github.com/go-delve/delve/service/rpc2"
	"github.com/go-delve/delve/service/rpccommon"
)

func RunServerAndGetClient(debugName string, target string, buildFlags string, kind debugger.ExecuteKind) (*gateway.Debug, error) {
	listener, clientConn := service.ListenerPipe()
	defer listener.Close()

	disconnectChan := make(chan struct{})
	// Create and start a debugger server
	processArgs := []string{debugName, target}
	server := rpccommon.NewServer(&service.Config{
		Listener:           listener,
		ProcessArgs:        processArgs,
		AcceptMulti:        false,
		APIVersion:         2,
		CheckLocalConnUser: true,
		DisconnectChan:     disconnectChan,
		Debugger: debugger.Config{
			AttachPid:             0,
			WorkingDir:            ".",
			Backend:               "default",
			CoreFile:              "",
			Foreground:            false,
			Packages:              []string{},
			BuildFlags:            buildFlags,
			ExecuteKind:           debugger.ExecutingGeneratedFile,
			DebugInfoDirectories:  []string{},
			CheckGoVersion:        true,
			TTY:                   "",
			Stdin:                 "",
			Stdout:                proc.OutputRedirect{Path: ""},
			Stderr:                proc.OutputRedirect{Path: ""},
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
				return nil, errors.New("can not debug non-main package")
			case debugger.ExecutingExistingFile:
				return nil, fmt.Errorf("%s is not executable\n", processArgs[0])
			default:
				// fallthrough
			}
		}
		return nil, err
	}

	return newClientFromConn(listener.Addr().String(), clientConn)

}

func Connect(addr string) (*gateway.Debug, error) {
	var clientConn net.Conn
	if clientConn = netDial(addr); clientConn == nil {
		return nil, errors.New("already logged")
	}
	client := rpc2.NewClientFromConn(clientConn)
	if client.IsMulticlient() {
		state, _ := client.GetStateNonBlocking()
		// The error return of GetState will usually be the ErrProcessExited,
		// which we don't care about. If there are other errors they will show up
		// later, here we are only concerned about stopping a running target so
		// that we can initialize our connection.
		if state != nil && state.Running {
			_, err := client.Halt()
			if err != nil {
				return nil, fmt.Errorf("could not halt: %w", err)
			}
		}
	}
	return gateway.NewDebug(client), nil
}

func newClientFromConn(addr string, clientConn net.Conn) (*gateway.Debug, error) {
	var client *rpc2.RPCClient
	if clientConn == nil { // I don't understand the code exactly just copied it from dlv
		if clientConn = netDial(addr); clientConn == nil {
			return nil, errors.New("already logged")
		}
	}
	client = rpc2.NewClientFromConn(clientConn)
	return gateway.NewDebug(client), nil

}

const unixAddrPrefix = "unix:"

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
