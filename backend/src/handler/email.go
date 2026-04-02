package handler

import (
	"encoding/json"
	"fmt"
	"html"
	"net/http"
	"strings"
)

// EmailSubscriptionRequest is the request for the email subscription
type EmailSubscriptionRequest struct {
	Email string `json:"email"`
}

// EmailSubscriptionResponse is the response for the email subscription
type EmailSubscriptionResponse struct {
	Message string `json:"message"`
}

// HandleEmailSubscription handles email subscription requests
func (h *Handler) HandleEmailSubscription(w http.ResponseWriter, r *http.Request) {
	h.logRequest(r)

	var req EmailSubscriptionRequest
	err := json.NewDecoder(r.Body).Decode(&req)
	if err != nil {
		h.respondWithError(w, "failed to decode request", http.StatusBadRequest)
		return
	}

	req.Email = strings.TrimSpace(req.Email)
	if req.Email == "" {
		h.respondWithError(w, "email is required", http.StatusBadRequest)
		return
	}

	// Basic email validation
	if !isValidEmail(req.Email) {
		h.respondWithError(w, "invalid email format", http.StatusBadRequest)
		return
	}

	err = h.db.SaveEmailSubscription(req.Email)
	if err != nil {
		h.logger.Error().Err(err).Str("email", req.Email).Msg("failed to save email subscription")
		h.respondWithError(w, "failed to save email subscription", http.StatusInternalServerError)
		return
	}

	h.writeJSONResponse(w, EmailSubscriptionResponse{
		Message: "Email subscription saved successfully",
	}, http.StatusOK)
}

// isValidEmail validates email format.
func isValidEmail(email string) bool {
	if len(email) < 5 || len(email) > 254 {
		return false
	}

	parts := strings.Split(email, "@")
	if len(parts) != 2 {
		return false
	}
	local, domain := parts[0], parts[1]

	// Local part: 1-64 chars, no leading/trailing dots, no consecutive dots
	if len(local) == 0 || len(local) > 64 {
		return false
	}
	if local[0] == '.' || local[len(local)-1] == '.' {
		return false
	}
	// Domain: must have at least one dot, no leading/trailing/consecutive dots or hyphens
	if len(domain) == 0 || len(domain) > 253 {
		return false
	}
	if !strings.Contains(domain, ".") {
		return false
	}

	return true
}

type unsubscribeData struct {
	Title    string
	Message  string
	Color    string
	ShowForm bool
}

// HandleUnsubscribe handles email unsubscribe requests via GET.
func (h *Handler) HandleUnsubscribe(w http.ResponseWriter, r *http.Request) {
	h.logRequest(r)

	email := strings.TrimSpace(r.URL.Query().Get("email"))
	if email == "" {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		templates.ExecuteTemplate(w, "unsubscribe.html", unsubscribeData{
			Title: "Unsubscribe", ShowForm: true,
		})
		return
	}

	if !isValidEmail(email) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(http.StatusBadRequest)
		templates.ExecuteTemplate(w, "unsubscribe.html", unsubscribeData{
			Title: "Invalid Email", Message: "Please provide a valid email address.", Color: "#e74c3c", ShowForm: true,
		})
		return
	}

	err := h.db.DeleteEmailSubscription(email)
	if err != nil {
		h.logger.Error().Err(err).Str("email", email).Msg("failed to unsubscribe email")
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.WriteHeader(http.StatusInternalServerError)
		templates.ExecuteTemplate(w, "unsubscribe.html", unsubscribeData{
			Title: "Unsubscribe Failed", Message: fmt.Sprintf("Something went wrong. Please try again later: %s", err.Error()), Color: "#e74c3c",
		})
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	templates.ExecuteTemplate(w, "unsubscribe.html", unsubscribeData{
		Title: "Unsubscribed", Message: "You have been successfully unsubscribed: " + html.EscapeString(email), Color: "#27ae60",
	})
}
