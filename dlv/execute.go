package dlv

import (
	"errors"
	"fmt"

	"github.com/ahmedakef/gotutor/gateway"
	"github.com/go-delve/delve/pkg/proc"
	"github.com/go-delve/delve/service"
	"github.com/go-delve/delve/service/api"
	"github.com/go-delve/delve/service/debugger"
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
			ExecuteKind:           kind,
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
				return nil, fmt.Errorf("%s is not executable", processArgs[0])
			default:
				// fallthrough
			}
		}
		return nil, err
	}

	return newClientFromConn(listener.Addr().String(), clientConn)

}
