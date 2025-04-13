// copied from https://go.googlesource.com/playground/+/refs/heads/master/fmt.go
package main

import (
	"fmt"
	"go/format"
	"net/http"
	"path"

	"github.com/ahmedakef/gotutor/backend/src/db"
	"golang.org/x/mod/modfile"
	"golang.org/x/tools/imports"
)

type fmtResponse struct {
	Body string `json:"body"`
}

func (h *Handler) handleFmt(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_, err := h.db.IncrementCallCounter(db.Format)
	if err != nil {
		h.logger.Err(err).Msg("failed to increment call counter")
	}

	fs, err := splitFiles([]byte(r.FormValue("body")))
	if err != nil {
		respondWithError(w, err.Error(), http.StatusInternalServerError)
		return
	}

	fixImports := r.FormValue("imports") != ""
	for _, f := range fs.files {
		switch {
		case path.Ext(f) == ".go":
			var out []byte
			var err error
			in := fs.Data(f)
			if fixImports {
				// TODO: pass options to imports.Process so it
				// can find symbols in sibling files.
				out, err = imports.Process(f, in, nil)
			} else {
				out, err = format.Source(in)
			}
			if err != nil {
				errMsg := err.Error()
				if !fixImports {
					// Unlike imports.Process, format.Source does not prefix
					// the error with the file path. So, do it ourselves here.
					errMsg = fmt.Sprintf("%v:%v", f, errMsg)
				}
				respondWithError(w, errMsg, http.StatusInternalServerError)
				return
			}
			fs.AddFile(f, out)
		case path.Base(f) == "go.mod":
			out, err := formatGoMod(f, fs.Data(f))
			if err != nil {
				respondWithError(w, err.Error(), http.StatusInternalServerError)
				return
			}
			fs.AddFile(f, out)
		}
	}

	h.writeJSONResponse(w, fmtResponse{Body: string(fs.Format())}, http.StatusOK)
}

func formatGoMod(file string, data []byte) ([]byte, error) {
	f, err := modfile.Parse(file, data, nil)
	if err != nil {
		return nil, err
	}
	return f.Format()
}
