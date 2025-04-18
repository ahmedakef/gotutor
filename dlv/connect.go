package dlv

import (
	"errors"
	"fmt"
	"net"
	"strings"

	"github.com/ahmedakef/gotutor/gateway"
	"github.com/go-delve/delve/pkg/logflags"
	"github.com/go-delve/delve/service/rpc2"
)

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
