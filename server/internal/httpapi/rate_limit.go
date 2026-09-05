package httpapi

import (
	"math"
	"net"
	"net/http"
	"net/netip"
	"strconv"
	"strings"
	"sync"
	"time"
)

type AuthenticationRateLimits struct {
	GoogleRequests                int
	RefreshRequests               int
	LegacyTransferCreateRequests  int
	LegacyTransferConsumeRequests int
	Window                        time.Duration
	MaxClients                    int
	TrustProxyHeaders             bool
}

type tokenBucket struct {
	tokens   float64
	updated  time.Time
	lastSeen time.Time
}

type clientTokenBuckets struct {
	mu          sync.Mutex
	capacity    float64
	refillRate  float64
	idleTTL     time.Duration
	maxClients  int
	clientState map[string]tokenBucket
}

func newClientTokenBuckets(
	requests int,
	window time.Duration,
	maxClients int,
) *clientTokenBuckets {
	return &clientTokenBuckets{
		capacity:    float64(requests),
		refillRate:  float64(requests) / window.Seconds(),
		idleTTL:     window,
		maxClients:  maxClients,
		clientState: make(map[string]tokenBucket),
	}
}

func (buckets *clientTokenBuckets) allow(
	client string,
	now time.Time,
) (bool, time.Duration) {
	buckets.mu.Lock()
	defer buckets.mu.Unlock()

	state, exists := buckets.clientState[client]
	if !exists {
		buckets.makeRoom(now)
		buckets.clientState[client] = tokenBucket{
			tokens:   buckets.capacity - 1,
			updated:  now,
			lastSeen: now,
		}
		return true, 0
	}

	if elapsed := now.Sub(state.updated); elapsed > 0 {
		state.tokens = min(
			buckets.capacity,
			state.tokens+elapsed.Seconds()*buckets.refillRate,
		)
		state.updated = now
	}
	state.lastSeen = now
	if state.tokens >= 1 {
		state.tokens--
		buckets.clientState[client] = state
		return true, 0
	}

	buckets.clientState[client] = state
	waitSeconds := (1 - state.tokens) / buckets.refillRate
	return false, time.Duration(math.Ceil(waitSeconds * float64(time.Second)))
}

func (buckets *clientTokenBuckets) makeRoom(now time.Time) {
	if len(buckets.clientState) < buckets.maxClients {
		return
	}

	for client, state := range buckets.clientState {
		if now.Sub(state.lastSeen) >= buckets.idleTTL {
			delete(buckets.clientState, client)
		}
	}
	if len(buckets.clientState) < buckets.maxClients {
		return
	}

	// 상한 도달 시 가장 오래 사용되지 않은 버킷 교체.
	var oldestClient string
	var oldestSeen time.Time
	for client, state := range buckets.clientState {
		if oldestClient == "" || state.lastSeen.Before(oldestSeen) {
			oldestClient = client
			oldestSeen = state.lastSeen
		}
	}
	delete(buckets.clientState, oldestClient)
}

func withAuthenticationRateLimits(
	limits AuthenticationRateLimits,
	next http.Handler,
) http.Handler {
	return withAuthenticationRateLimitsAt(limits, time.Now, next)
}

func withAuthenticationRateLimitsAt(
	limits AuthenticationRateLimits,
	now func() time.Time,
	next http.Handler,
) http.Handler {
	if limits.GoogleRequests <= 0 || limits.RefreshRequests <= 0 ||
		limits.Window <= 0 || limits.MaxClients <= 0 {
		return next
	}

	google := newClientTokenBuckets(
		limits.GoogleRequests,
		limits.Window,
		limits.MaxClients,
	)
	refresh := newClientTokenBuckets(
		limits.RefreshRequests,
		limits.Window,
		limits.MaxClients,
	)
	var legacyTransferCreate *clientTokenBuckets
	if limits.LegacyTransferCreateRequests > 0 {
		legacyTransferCreate = newClientTokenBuckets(
			limits.LegacyTransferCreateRequests,
			limits.Window,
			limits.MaxClients,
		)
	}
	var legacyTransferConsume *clientTokenBuckets
	if limits.LegacyTransferConsumeRequests > 0 {
		legacyTransferConsume = newClientTokenBuckets(
			limits.LegacyTransferConsumeRequests,
			limits.Window,
			limits.MaxClients,
		)
	}

	return http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		var buckets *clientTokenBuckets
		switch {
		case request.Method == http.MethodPost && (request.URL.Path == "/v1/auth/google" || request.URL.Path == "/v1/auth/web/google" || request.URL.Path == "/v1/auth/native/google"):
			buckets = google
		case request.Method == http.MethodPost && (request.URL.Path == "/v1/auth/refresh" || request.URL.Path == "/v1/auth/web/refresh" || request.URL.Path == "/v1/auth/native/refresh"):
			buckets = refresh
		case request.Method == http.MethodPost && request.URL.Path == "/v1/legacy-save-transfers" && legacyTransferCreate != nil:
			buckets = legacyTransferCreate
		case request.Method == http.MethodPost && request.URL.Path == "/v1/legacy-save-transfers/consume" && legacyTransferConsume != nil:
			buckets = legacyTransferConsume
		default:
			next.ServeHTTP(response, request)
			return
		}

		allowed, retryAfter := buckets.allow(
			rateLimitClient(request, limits.TrustProxyHeaders),
			now(),
		)
		if allowed {
			next.ServeHTTP(response, request)
			return
		}

		retryAfterSeconds := max(1, int(math.Ceil(retryAfter.Seconds())))
		response.Header().Set("Retry-After", strconv.Itoa(retryAfterSeconds))
		writeAPIError(
			response,
			request,
			http.StatusTooManyRequests,
			"RATE_LIMIT_EXCEEDED",
			"요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.",
		)
	})
}

func rateLimitClient(request *http.Request, trustProxyHeaders bool) string {
	if trustProxyHeaders {
		forwardedFor, _, _ := strings.Cut(request.Header.Get("X-Forwarded-For"), ",")
		if address, err := netip.ParseAddr(strings.TrimSpace(forwardedFor)); err == nil {
			return address.Unmap().String()
		}
	}

	host, _, err := net.SplitHostPort(request.RemoteAddr)
	if err != nil {
		host = request.RemoteAddr
	}
	if address, parseErr := netip.ParseAddr(strings.Trim(host, "[]")); parseErr == nil {
		return address.Unmap().String()
	}
	return "unknown"
}
