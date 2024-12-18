package serialize

import (
	"github.com/go-delve/delve/service/api"
)

type Step struct {
	Goroutine *api.Goroutine
	Variables []api.Variable
}

func (s *Step) isValid() bool {
	return s.Goroutine != nil && s.Goroutine.CurrentLoc.File != ""
}
