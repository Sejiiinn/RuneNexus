package httpapi

import (
	"context"
	"github.com/Sejiiinn/RuneNexus/server/internal/auth"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestGemRateLimitSharesAccountAcrossRoutesAndSessions(t *testing.T) {
	now := time.Unix(0, 0)
	buckets := newClientTokenBuckets(2, time.Minute, 3)
	calls := 0
	handler := withGemAccountRateLimit(buckets, func() time.Time { return now }, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { calls++; w.WriteHeader(204) }))
	request := func(path, account, session string) int {
		r := httptest.NewRequest("POST", path, nil)
		r = r.WithContext(context.WithValue(r.Context(), authenticatedPrincipalContextKey{}, auth.Principal{AccountID: account, SessionID: session}))
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, r)
		if w.Code == 429 && w.Header().Get("Retry-After") == "" {
			t.Fatal("missing retry metadata")
		}
		return w.Code
	}
	if request("/v1/economy/runs/start", "a", "1") != 204 || request("/v1/economy/gems/offer", "a", "2") != 204 || request("/v1/economy/gems/choose", "a", "3") != 429 {
		t.Fatal("same account bypassed shared bucket")
	}
	if request("/v1/economy/runs/close", "b", "1") != 204 {
		t.Fatal("account isolation failed")
	}
	now = now.Add(30 * time.Second)
	if request("/v1/economy/gems/purchase", "a", "1") != 204 {
		t.Fatal("refill failed")
	}
	for _, id := range []string{"c", "d", "e", "f"} {
		request("/v1/economy/gems/offer", id, "1")
	}
	if len(buckets.clientState) > 3 {
		t.Fatal("unbounded account rate keys")
	}
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, httptest.NewRequest("POST", "/v1/economy/gems/offer", nil))
	if w.Code != 401 {
		t.Fatal("unauthenticated request admitted")
	}
}
