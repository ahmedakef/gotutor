package dlv

import (
	"os"
	"os/exec"
	"strings"
)

func RunDebugServer(debugName string, addr string) error {
	return dlvCommandRun("exec", debugName, "--headless", "--listen="+addr)
}

func dlvCommandRun(command string, args ...string) error {
	_, dlvCommand := dlvCommandExecCmd(command, args...)
	dlvCommand.Stderr = os.Stdout
	dlvCommand.Stdout = os.Stderr
	return dlvCommand.Run()

}

func dlvCommandExecCmd(command string, args ...string) (string, *exec.Cmd) {
	allArgs := []string{command}
	allArgs = append(allArgs, args...)
	dlvCommand := exec.Command("dlv", allArgs...)
	return strings.Join(append([]string{"dlv"}, allArgs...), " "), dlvCommand
}
