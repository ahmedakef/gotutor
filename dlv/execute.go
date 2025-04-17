package dlv

import (
	"errors"
	"fmt"
	"os"

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
	// Clear stdout file before starting debug session
	if err := truncateFile("output/stdout.log"); err != nil {
		return nil, fmt.Errorf("failed to clear stdout file: %w", err)
	}
	if err := truncateFile("output/stderr.log"); err != nil {
		return nil, fmt.Errorf("failed to clear stderr file: %w", err)
	}
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
			Stdout:                proc.OutputRedirect{Path: "output/stdout.log"},
			Stderr:                proc.OutputRedirect{Path: "output/stderr.log"},
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

func truncateFile(path string) error {
	// Create creates or truncates the named file. If the file already exists
	file, err := os.Create(path)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer file.Close()
	return nil
}
