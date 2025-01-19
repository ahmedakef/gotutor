package serialize

import (
	"github.com/go-delve/delve/service/api"
)

type GoRoutineData struct {
	Goroutine  *api.Goroutine
	Stacktrace []api.Stackframe
}

type Step struct {
	PackageVariables []api.Variable
	GoroutinesData   []GoRoutineData
}

func (s *Step) isValid() bool {
	return len(s.GoroutinesData) > 0 && s.GoroutinesData[0].Goroutine != nil && s.GoroutinesData[0].Goroutine.CurrentLoc.File != ""
}
