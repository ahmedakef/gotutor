package controller

import (
	"go/ast"
	"go/doc"
	"go/parser"
	"go/token"
	"strings"
	"unicode"
	"unicode/utf8"

	"github.com/ahmedakef/gotutor/backend/src/pkg/txtar"
)

// experiments returns the experiments listed in // GOEXPERIMENT=xxx comments
// at the top of src.
func experiments(src string) []string {
	var exp []string
	for src != "" {
		line := src
		src = ""
		if i := strings.Index(line, "\n"); i >= 0 {
			line, src = line[:i], line[i+1:]
		}
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		if !strings.HasPrefix(line, "//") {
			break
		}
		line = strings.TrimSpace(strings.TrimPrefix(line, "//"))
		if !strings.HasPrefix(line, "GOEXPERIMENT") {
			continue
		}
		line = strings.TrimSpace(strings.TrimPrefix(line, "GOEXPERIMENT"))
		if !strings.HasPrefix(line, "=") {
			continue
		}
		line = strings.TrimSpace(strings.TrimPrefix(line, "="))
		if line != "" {
			exp = append(exp, line)
		}
	}
	return exp
}

// isTestFunc tells whether fn has the type of a testing, or fuzz function, or a TestMain func.
func isTestFunc(fn *ast.FuncDecl) bool {
	if fn.Type.Results != nil && len(fn.Type.Results.List) > 0 ||
		fn.Type.Params.List == nil ||
		len(fn.Type.Params.List) != 1 ||
		len(fn.Type.Params.List[0].Names) > 1 {
		return false
	}
	ptr, ok := fn.Type.Params.List[0].Type.(*ast.StarExpr)
	if !ok {
		return false
	}
	// We can't easily check that the type is *testing.T or *testing.F
	// because we don't know how testing has been imported,
	// but at least check that it's *T (or *F) or *something.T (or *something.F).
	if name, ok := ptr.X.(*ast.Ident); ok && (name.Name == "T" || name.Name == "F" || name.Name == "M") {
		return true
	}
	if sel, ok := ptr.X.(*ast.SelectorExpr); ok && (sel.Sel.Name == "T" || sel.Sel.Name == "F" || sel.Sel.Name == "M") {
		return true
	}
	return false
}

// isTest tells whether name looks like a test (or benchmark, or fuzz, according to prefix).
// It is a Test (say) if there is a character after Test that is not a lower-case letter.
// We don't want mistaken Testimony or erroneous Benchmarking.
func isTest(name, prefix string) bool {
	if !strings.HasPrefix(name, prefix) {
		return false
	}
	if len(name) == len(prefix) { // "Test" is ok
		return true
	}
	r, _ := utf8.DecodeRuneInString(name[len(prefix):])
	return !unicode.IsLower(r)
}

// isTestProg returns source code that executes all valid tests and examples in src.
// If the main function is present or there are no tests or examples, it returns nil.
// getTestProg emulates the "go test" command as closely as possible.
// Benchmarks are not supported because of sandboxing.
func isTestProg(src []byte) bool {
	fset := token.NewFileSet()
	// Early bail for most cases.
	f, err := parser.ParseFile(fset, txtar.ProgName, src, parser.ImportsOnly)
	if err != nil || f.Name.Name != "main" {
		return false
	}

	// Parse everything and extract test names.
	f, err = parser.ParseFile(fset, txtar.ProgName, src, parser.ParseComments)
	if err != nil {
		return false
	}

	var hasTest bool
	var hasFuzz bool
	for _, d := range f.Decls {
		n, ok := d.(*ast.FuncDecl)
		if !ok {
			continue
		}
		name := n.Name.Name
		switch {
		case name == "main":
			// main declared as a method will not obstruct creation of our main function.
			if n.Recv == nil {
				return false
			}
		case name == "TestMain" && isTestFunc(n):
			hasTest = true
		case isTest(name, "Test") && isTestFunc(n):
			hasTest = true
		case isTest(name, "Fuzz") && isTestFunc(n):
			hasFuzz = true
		}
	}

	if hasTest || hasFuzz {
		return true
	}

	return len(doc.Examples(f)) > 0
}

var failedTestPattern = "--- FAIL"
