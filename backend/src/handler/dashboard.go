package handler

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"embed"
	"encoding/hex"
	"html/template"
	"net/http"
	"net/url"
	"os"
	"sort"
	"time"

	"github.com/ahmedakef/gotutor/backend/src/db"
)

const (
	sourceCodeTruncatedLength = 450
)

//go:embed templates/*.html
var templateFS embed.FS

var templates = template.Must(template.ParseFS(templateFS, "templates/*.html"))

// sessionKey is generated at startup for signing cookies. Sessions don't survive restarts.
var sessionKey = func() []byte {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		panic(err)
	}
	return b
}()

const sessionCookieName = "gotutor_session"

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
	FullCode      string
	IsTruncated   bool
	UpdatedAt     string
	updatedAtTime time.Time
}

type dashboardData struct {
	CallCounters map[string]uint64
	SourceCodes  []sourceCodeView
	Emails       []emailView
	PprofPort    int
}

type emailView struct {
	Email            string
	SubscribedAt     string
	UnsubscribeURL   string
	subscribedAtTime time.Time
}

// HandleDashboard serves a password-protected dashboard showing DB contents.
func (h *Handler) HandleDashboard(w http.ResponseWriter, r *http.Request) {
	h.logRequest(r)

	// Check for valid session cookie on GET requests
	if r.Method == http.MethodGet {
		if isValidSession(r) {
			h.renderDashboard(w)
			return
		}
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

	// Set session cookie
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookieName,
		Value:    generateSessionToken(),
		Path:     "/dashboard",
		HttpOnly: true,
		SameSite: http.SameSiteStrictMode,
		MaxAge:   86400, // 24 hours
	})

	// Redirect to GET to avoid "Confirm Form Resubmission" on refresh
	http.Redirect(w, r, "/dashboard", http.StatusSeeOther)
}

func generateSessionToken() string {
	mac := hmac.New(sha256.New, sessionKey)
	mac.Write([]byte(getDashboardPassword()))
	return hex.EncodeToString(mac.Sum(nil))
}

func isValidSession(r *http.Request) bool {
	cookie, err := r.Cookie(sessionCookieName)
	if err != nil {
		return false
	}
	return cookie.Value == generateSessionToken()
}

func (h *Handler) renderDashboard(w http.ResponseWriter) {
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
		truncated := entry.Code
		isTruncated := len(truncated) > sourceCodeTruncatedLength
		if isTruncated {
			truncated = truncated[:sourceCodeTruncatedLength] + "..."
		}
		shortHash := entry.Hash
		if len(shortHash) > 16 {
			shortHash = shortHash[:16]
		}
		codeViews = append(codeViews, sourceCodeView{
			Hash:          entry.Hash,
			ShortHash:     shortHash,
			TruncatedCode: truncated,
			FullCode:      entry.Code,
			IsTruncated:   isTruncated,
			UpdatedAt:     db.FormatTimestamp(entry.UpdatedAt),
			updatedAtTime: db.ParseTimestamp(entry.UpdatedAt),
		})
	}

	sort.Slice(codeViews, func(i, j int) bool {
		return codeViews[i].updatedAtTime.After(codeViews[j].updatedAtTime)
	})

	var emailViews []emailView
	for _, entry := range emails {
		emailViews = append(emailViews, emailView{
			Email:            entry.Email,
			SubscribedAt:     db.FormatTimestamp(entry.SubscribedAt),
			UnsubscribeURL:   "/unsubscribe?" + url.Values{"email": {entry.Email}}.Encode(),
			subscribedAtTime: db.ParseTimestamp(entry.SubscribedAt),
		})
	}
	sort.Slice(emailViews, func(i, j int) bool {
		return emailViews[i].subscribedAtTime.After(emailViews[j].subscribedAtTime)
	})

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	templates.ExecuteTemplate(w, "dashboard.html", dashboardData{
		CallCounters: callCounters,
		SourceCodes:  codeViews,
		Emails:       emailViews,
		PprofPort:    h.pprofPort,
	})
}
