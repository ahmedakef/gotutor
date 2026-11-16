package handler

import (
	"net"
	"net/http"
	"sync"
	"time"
)

// ipRateLimiter allows each client IP a fixed number of requests per window.
// All counters reset together when the window ends, which keeps memory
// bounded by the number of IPs seen in one window.
type ipRateLimiter struct {
	mu          sync.Mutex
	limit       int
	window      time.Duration
	windowStart time.Time
	counts      map[string]int
	now         func() time.Time
}

func newIPRateLimiter(limit int, window time.Duration) *ipRateLimiter {
	return &ipRateLimiter{
		limit:  limit,
		window: window,
		counts: make(map[string]int),
		now:    time.Now,
	}
}

// Allow records a request from ip and reports whether it is within the limit.
func (l *ipRateLimiter) Allow(ip string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := l.now()
	if now.Sub(l.windowStart) >= l.window {
		l.windowStart = now
		clear(l.counts)
	}
	if l.counts[ip] >= l.limit {
		return false
	}
	l.counts[ip]++
	return true
}

// clientIP returns the address of the end user. The backend sits behind
// Cloudflare and then nginx, so nginx's X-Real-Ip holds a Cloudflare edge
// address; CF-Connecting-IP holds the visitor's. Requests that reach the origin
// directly can forge it, which is acceptable for a quota guard.
func clientIP(r *http.Request) string {
	if ip := r.Header.Get("CF-Connecting-IP"); ip != "" {
		return ip
	}
	if ip := r.Header.Get("X-Real-Ip"); ip != "" {
		return ip
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
