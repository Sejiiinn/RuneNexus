package httpapi

import (
	"math"
	"net/http"
	"strconv"
	"time"
)

// One shared account bucket covers all gem mutations, recovery reads and run
// lifecycle requests. This bounds per-process load and memory, not global abuse:
// multi-replica deployments additionally need an ingress/shared account limiter.
func withGemAccountRateLimit(buckets *clientTokenBuckets, now func() time.Time, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		principal, ok := authenticatedPrincipalFromContext(r.Context())
		if !ok {
			writeAPIError(w, r, 401, "ACCESS_TOKEN_INVALID", "로그인이 필요합니다.")
			return
		}
		allowed, wait := buckets.allow(principal.AccountID, now())
		if !allowed {
			w.Header().Set("Retry-After", strconv.Itoa(max(1, int(math.Ceil(wait.Seconds())))))
			writeAPIError(w, r, 429, "RATE_LIMIT_EXCEEDED", "요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.")
			return
		}
		next.ServeHTTP(w, r)
	})
}
