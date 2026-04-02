package handler

import (
	"embed"
	"html/template"
	"net/http"
	"os"
)

//go:embed templates/*.html
var templateFS embed.FS

var templates = template.Must(template.ParseFS(templateFS, "templates/*.html"))

func getDashboardPassword() string {
	if p := os.Getenv("DASHBOARD_PASSWORD"); p != "" {
		return p
	}
	return "admin"
}

type loginData struct {
	Error string
}

type sourceCodeView struct {
	Hash          string
	ShortHash     string
	TruncatedCode string
	UpdatedAt     string
}

type dashboardData struct {
	CallCounters map[string]uint64
	SourceCodes  []sourceCodeView
	Emails       []emailView
}

type emailView struct {
	Email        string
	SubscribedAt string
}

// HandleDashboard serves a password-protected dashboard showing DB contents.
func (h *Handler) HandleDashboard(w http.ResponseWriter, r *http.Request) {
	h.logRequest(r)

	if r.Method == http.MethodGet {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		templates.ExecuteTemplate(w, "login.html", loginData{})
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	if err := r.ParseForm(); err != nil {
		http.Error(w, "Bad request", http.StatusBadRequest)
		return
	}

	password := r.FormValue("password")
	if password != getDashboardPassword() {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(http.StatusUnauthorized)
		templates.ExecuteTemplate(w, "login.html", loginData{Error: "Invalid password"})
		return
	}

	callCounters, err := h.db.GetAllCallCounters()
	if err != nil {
		h.logger.Error().Err(err).Msg("failed to get call counters")
		http.Error(w, "Internal error", http.StatusInternalServerError)
		return
	}

	sourceCodes, err := h.db.GetAllSourceCodes()
	if err != nil {
		h.logger.Error().Err(err).Msg("failed to get source codes")
		http.Error(w, "Internal error", http.StatusInternalServerError)
		return
	}

	emails, err := h.db.GetAllEmails()
	if err != nil {
		h.logger.Error().Err(err).Msg("failed to get emails")
		http.Error(w, "Internal error", http.StatusInternalServerError)
		return
	}

	var codeViews []sourceCodeView
	for _, entry := range sourceCodes {
		code := entry.Code
		if len(code) > 200 {
			code = code[:200] + "..."
		}
		shortHash := entry.Hash
		if len(shortHash) > 16 {
			shortHash = shortHash[:16]
		}
		codeViews = append(codeViews, sourceCodeView{
			Hash:          entry.Hash,
			ShortHash:     shortHash,
			TruncatedCode: code,
			UpdatedAt:     entry.UpdatedAt,
		})
	}

	var emailViews []emailView
	for _, entry := range emails {
		emailViews = append(emailViews, emailView{
			Email:        entry.Email,
			SubscribedAt: entry.SubscribedAt,
		})
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	templates.ExecuteTemplate(w, "dashboard.html", dashboardData{
		CallCounters: callCounters,
		SourceCodes:  codeViews,
		Emails:       emailViews,
	})
}
