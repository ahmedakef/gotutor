package serialize

import (
	"github.com/go-delve/delve/service/api"
)

type Step struct {
	Goroutine        *api.Goroutine
	Variables        []api.Variable
	Args             []api.Variable
	PackageVariables []api.Variable
	Stacktrace       []api.Stackframe
}

func (s *Step) isValid() bool {
	return s.Goroutine != nil && s.Goroutine.CurrentLoc.File != ""
}
