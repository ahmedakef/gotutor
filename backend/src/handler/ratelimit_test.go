package handler

import (
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestIPRateLimiter(t *testing.T) {
	t.Parallel()

	now := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	l := newIPRateLimiter(2, time.Hour)
	l.now = func() time.Time { return now }

	assert.True(t, l.Allow("a"))
	assert.True(t, l.Allow("a"))
	assert.False(t, l.Allow("a"), "third request in the window")
	assert.True(t, l.Allow("b"), "other IPs have their own count")

	now = now.Add(time.Hour)
	assert.True(t, l.Allow("a"), "counts reset in the next window")
}

func TestClientIP(t *testing.T) {
	t.Parallel()

	r := httptest.NewRequest("POST", "/fix-code", nil)
	r.RemoteAddr = "10.0.0.1:1234"
	assert.Equal(t, "10.0.0.1", clientIP(r))

	r.Header.Set("X-Real-Ip", "172.67.0.1")
	assert.Equal(t, "172.67.0.1", clientIP(r))

	r.Header.Set("CF-Connecting-IP", "203.0.113.7")
	assert.Equal(t, "203.0.113.7", clientIP(r))
}
