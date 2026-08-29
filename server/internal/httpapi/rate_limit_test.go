package httpapi

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestAuthenticationRateLimitsAreEndpointSpecific(t *testing.T) {
	now := time.Date(2026, 8, 20, 0, 0, 0, 0, time.UTC)
	nextCalls := 0
	handler := authenticationRateLimitTestHandler(
		AuthenticationRateLimits{
			GoogleRequests:  2,
			RefreshRequests: 1,
			Window:          time.Minute,
			MaxClients:      100,
		},
		func() time.Time { return now },
		http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
			nextCalls++
			response.WriteHeader(http.StatusNoContent)
		}),
	)

	for requestIndex := 0; requestIndex < 2; requestIndex++ {
		response := serveRateLimitedRequest(handler, "/v1/auth/google", "192.0.2.1:1000")
		if response.Code != http.StatusNoContent {
			t.Fatalf("Google request %d status = %d", requestIndex+1, response.Code)
		}
	}
	googleLimited := serveRateLimitedRequest(handler, "/v1/auth/google", "192.0.2.1:1000")
	requireRateLimitResponse(t, googleLimited, "30")

	refreshAllowed := serveRateLimitedRequest(handler, "/v1/auth/refresh", "192.0.2.1:1000")
	if refreshAllowed.Code != http.StatusNoContent {
		t.Fatalf("refresh status = %d", refreshAllowed.Code)
	}
	refreshLimited := serveRateLimitedRequest(handler, "/v1/auth/refresh", "192.0.2.1:1000")
	requireRateLimitResponse(t, refreshLimited, "60")

	logout := serveRateLimitedRequest(handler, "/v1/auth/logout", "192.0.2.1:1000")
	if logout.Code != http.StatusNoContent || nextCalls != 4 {
		t.Fatalf("logout status = %d, nextCalls = %d", logout.Code, nextCalls)
	}
}

func TestAuthenticationRateLimitRefillsTokens(t *testing.T) {
	now := time.Date(2026, 8, 20, 0, 0, 0, 0, time.UTC)
	handler := authenticationRateLimitTestHandler(
		AuthenticationRateLimits{
			GoogleRequests:  1,
			RefreshRequests: 1,
			Window:          time.Minute,
			MaxClients:      100,
		},
		func() time.Time { return now },
		http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
			response.WriteHeader(http.StatusNoContent)
		}),
	)

	first := serveRateLimitedRequest(handler, "/v1/auth/google", "192.0.2.1:1000")
	second := serveRateLimitedRequest(handler, "/v1/auth/google", "192.0.2.1:1000")
	if first.Code != http.StatusNoContent || second.Code != http.StatusTooManyRequests {
		t.Fatalf("initial statuses = %d, %d", first.Code, second.Code)
	}

	now = now.Add(time.Minute)
	afterRefill := serveRateLimitedRequest(handler, "/v1/auth/google", "192.0.2.1:1000")
	if afterRefill.Code != http.StatusNoContent {
		t.Fatalf("status after refill = %d", afterRefill.Code)
	}
}

func TestLegacyTransferRateLimitsAreSeparatedFromAuthentication(t *testing.T) {
	handler := authenticationRateLimitTestHandler(
		AuthenticationRateLimits{
			GoogleRequests:                10,
			RefreshRequests:               10,
			LegacyTransferCreateRequests:  1,
			LegacyTransferConsumeRequests: 2,
			Window:                        time.Minute,
			MaxClients:                    100,
		},
		time.Now,
		http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
			response.WriteHeader(http.StatusNoContent)
		}),
	)

	firstCreate := serveRateLimitedRequest(handler, "/v1/legacy-save-transfers", "192.0.2.1:1000")
	secondCreate := serveRateLimitedRequest(handler, "/v1/legacy-save-transfers", "192.0.2.1:1000")
	if firstCreate.Code != http.StatusNoContent || secondCreate.Code != http.StatusTooManyRequests {
		t.Fatalf("create statuses = %d, %d", firstCreate.Code, secondCreate.Code)
	}
	for index := range 2 {
		response := serveRateLimitedRequest(handler, "/v1/legacy-save-transfers/consume", "192.0.2.1:1000")
		if response.Code != http.StatusNoContent {
			t.Fatalf("consume request %d status = %d", index+1, response.Code)
		}
	}
	limitedConsume := serveRateLimitedRequest(handler, "/v1/legacy-save-transfers/consume", "192.0.2.1:1000")
	if limitedConsume.Code != http.StatusTooManyRequests {
		t.Fatalf("limited consume status = %d", limitedConsume.Code)
	}
}

func TestAuthenticationRateLimitTrustsForwardedAddressOnlyWhenConfigured(t *testing.T) {
	for _, testCase := range []struct {
		name              string
		trustProxyHeaders bool
		secondStatus      int
	}{
		{
			name:              "ignore untrusted forwarded addresses",
			trustProxyHeaders: false,
			secondStatus:      http.StatusTooManyRequests,
		},
		{
			name:              "separate trusted forwarded addresses",
			trustProxyHeaders: true,
			secondStatus:      http.StatusNoContent,
		},
	} {
		t.Run(testCase.name, func(t *testing.T) {
			handler := authenticationRateLimitTestHandler(
				AuthenticationRateLimits{
					GoogleRequests:    1,
					RefreshRequests:   1,
					Window:            time.Minute,
					MaxClients:        100,
					TrustProxyHeaders: testCase.trustProxyHeaders,
				},
				time.Now,
				http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
					response.WriteHeader(http.StatusNoContent)
				}),
			)

			first := newRateLimitedRequest("/v1/auth/google", "172.20.0.2:1000")
			first.Header.Set("X-Forwarded-For", "192.0.2.1")
			firstResponse := httptest.NewRecorder()
			handler.ServeHTTP(firstResponse, first)

			second := newRateLimitedRequest("/v1/auth/google", "172.20.0.2:1000")
			second.Header.Set("X-Forwarded-For", "192.0.2.2")
			secondResponse := httptest.NewRecorder()
			handler.ServeHTTP(secondResponse, second)

			if firstResponse.Code != http.StatusNoContent ||
				secondResponse.Code != testCase.secondStatus {
				t.Fatalf(
					"statuses = %d, %d",
					firstResponse.Code,
					secondResponse.Code,
				)
			}
		})
	}
}

func TestAuthenticationRateLimitRejectsInvalidForwardedAddress(t *testing.T) {
	handler := authenticationRateLimitTestHandler(
		AuthenticationRateLimits{
			GoogleRequests:    1,
			RefreshRequests:   1,
			Window:            time.Minute,
			MaxClients:        100,
			TrustProxyHeaders: true,
		},
		time.Now,
		http.HandlerFunc(func(response http.ResponseWriter, _ *http.Request) {
			response.WriteHeader(http.StatusNoContent)
		}),
	)

	first := newRateLimitedRequest("/v1/auth/google", "172.20.0.2:1000")
	first.Header.Set("X-Forwarded-For", "not-an-address")
	firstResponse := httptest.NewRecorder()
	handler.ServeHTTP(firstResponse, first)

	second := newRateLimitedRequest("/v1/auth/google", "172.20.0.2:1000")
	second.Header.Set("X-Forwarded-For", "also-invalid")
	secondResponse := httptest.NewRecorder()
	handler.ServeHTTP(secondResponse, second)

	if firstResponse.Code != http.StatusNoContent ||
		secondResponse.Code != http.StatusTooManyRequests {
		t.Fatalf(
			"statuses = %d, %d",
			firstResponse.Code,
			secondResponse.Code,
		)
	}
}

func TestAuthenticationRateLimitBoundsClientState(t *testing.T) {
	now := time.Date(2026, 8, 20, 0, 0, 0, 0, time.UTC)
	buckets := newClientTokenBuckets(1, time.Minute, 2)
	if allowed, _ := buckets.allow("client-1", now); !allowed {
		t.Fatal("client-1 was unexpectedly limited")
	}
	now = now.Add(time.Second)
	if allowed, _ := buckets.allow("client-2", now); !allowed {
		t.Fatal("client-2 was unexpectedly limited")
	}
	now = now.Add(time.Second)
	if allowed, _ := buckets.allow("client-3", now); !allowed {
		t.Fatal("client-3 was unexpectedly limited")
	}
	if len(buckets.clientState) != 2 {
		t.Fatalf("client state size = %d", len(buckets.clientState))
	}
	if _, exists := buckets.clientState["client-1"]; exists {
		t.Fatal("oldest client state was not evicted")
	}
}

func TestAuthenticationRateLimitIsConcurrencySafe(t *testing.T) {
	const allowedRequests = 8
	buckets := newClientTokenBuckets(allowedRequests, time.Minute, 100)
	now := time.Date(2026, 8, 20, 0, 0, 0, 0, time.UTC)
	var allowed atomic.Int64
	var waitGroup sync.WaitGroup

	for requestIndex := 0; requestIndex < 64; requestIndex++ {
		waitGroup.Add(1)
		go func() {
			defer waitGroup.Done()
			if accepted, _ := buckets.allow("same-client", now); accepted {
				allowed.Add(1)
			}
		}()
	}
	waitGroup.Wait()

	if allowed.Load() != allowedRequests {
		t.Fatalf("allowed requests = %d", allowed.Load())
	}
}

func authenticationRateLimitTestHandler(
	limits AuthenticationRateLimits,
	now func() time.Time,
	next http.Handler,
) http.Handler {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	return withRequestMetadata(
		logger,
		withCORS(
			[]string{"https://sejiiinn.github.io"},
			withAuthenticationRateLimitsAt(limits, now, next),
		),
	)
}

func serveRateLimitedRequest(
	handler http.Handler,
	path string,
	remoteAddress string,
) *httptest.ResponseRecorder {
	request := newRateLimitedRequest(path, remoteAddress)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	return response
}

func newRateLimitedRequest(path string, remoteAddress string) *http.Request {
	request := httptest.NewRequest(http.MethodPost, path, nil)
	request.RemoteAddr = remoteAddress
	request.Header.Set("Origin", "https://sejiiinn.github.io")
	return request
}

func requireRateLimitResponse(
	t *testing.T,
	response *httptest.ResponseRecorder,
	wantRetryAfter string,
) {
	t.Helper()
	if response.Code != http.StatusTooManyRequests {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	if response.Header().Get("Retry-After") != wantRetryAfter {
		t.Fatalf("Retry-After = %q", response.Header().Get("Retry-After"))
	}
	if response.Header().Get(requestIDHeader) == "" {
		t.Fatal("response is missing a request ID")
	}
	if response.Header().Get("Access-Control-Allow-Origin") !=
		"https://sejiiinn.github.io" {
		t.Fatalf(
			"Access-Control-Allow-Origin = %q",
			response.Header().Get("Access-Control-Allow-Origin"),
		)
	}
	if response.Header().Get("Access-Control-Expose-Headers") !=
		requestIDHeader+", Retry-After, ETag" {
		t.Fatalf(
			"Access-Control-Expose-Headers = %q",
			response.Header().Get("Access-Control-Expose-Headers"),
		)
	}
	var body errorResponse
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body.Code != "RATE_LIMIT_EXCEEDED" || body.RequestID == "" {
		t.Fatalf("body = %#v", body)
	}
}
