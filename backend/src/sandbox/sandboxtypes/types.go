// The sandboxtypes package contains the shared types
// to communicate between the different sandbox components.
package sandboxtypes

// Request is the request from the frontend to the sandbox backend.
type Request struct {
	Binary    []byte `json:"binary"`
	MainDotGo []byte `json:"mainDotGo"`
	BuildLoc  string `json:"buildLoc"`
}

// Response is the response from the sandbox backend to
// the frontend.
//
// The stdout/stderr are base64 encoded which isn't ideal but is good
// enough for now. Maybe we'll move to protobufs later.
type Response struct {
	// Error, if non-empty, means we failed to run the binary.
	// It's meant to be user-visible.
	Error string `json:"error,omitempty"`

	ExitCode       int    `json:"exitCode"`
	ExecutionSteps []byte `json:"executionSteps"`
}
