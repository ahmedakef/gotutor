package serialize

import "github.com/go-delve/delve/service/api"

type Step struct {
	Goroutine *api.Goroutine
	Variables []api.Variable
}
