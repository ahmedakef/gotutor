package handler

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestCleanCodeResponse(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name string
		in   string
		want string
	}{
		{
			name: "multiline_go_fence",
			in: "```go\nfunc main() {\n    fmt.Println(\"hi\")\n}\n```",
			want: "func main() {\n    fmt.Println(\"hi\")\n}",
		},
		{
			name: "fence_no_lang",
			in:   "```\npackage main\n```",
			want: "package main",
		},
		{
			name: "fence_golang_alias",
			in:   "```golang\nvar x = 1\n```",
			want: "var x = 1",
		},
		{
			name: "fence_crlf",
			in:   "```go\r\na := 1\r\n```",
			want: "a := 1",
		},
		{
			name: "fence_trim_outer_whitespace",
			in: "  \n```go\nx := 1\n```\n  ",
			want: "x := 1",
		},
		{
			name: "preamble_then_fence",
			in: "Here is the fix:\n```go\npackage p\nfunc F() {}\n```",
			want: "package p\nfunc F() {}",
		},
		{
			name: "no_fence_package",
			in:   "package main\n\nfunc main() {}",
			want: "package main\n\nfunc main() {}",
		},
		{
			name: "no_fence_func_only",
			in:   "func main() {\n}",
			want: "func main() {\n}",
		},
		{
			name: "no_fence_stops_at_explanation",
			in: "func main() {}\n\nExplanation: because",
			want: "func main() {}",
		},
		{
			name: "no_fence_stops_at_markdown_fence_line",
			in: "func F() {}\n```",
			want: "func F() {}",
		},
		{
			name: "no_match_returns_trimmed_input",
			in:   "  just prose  ",
			want: "just prose",
		},
		{
			name: "empty_fence_falls_back",
			in:   "```go\n\n```\nfunc ok() {}",
			want: "func ok() {}",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			got := cleanCodeResponse(tt.in)
			assert.Equal(t, tt.want, got)
		})
	}
}
