package httpapi

import "net/http"

func withCORS(allowedOrigins []string, next http.Handler) http.Handler {
	allowed := make(map[string]struct{}, len(allowedOrigins))
	for _, origin := range allowedOrigins {
		allowed[origin] = struct{}{}
	}

	return http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		origin := request.Header.Get("Origin")
		if origin == "" {
			next.ServeHTTP(response, request)
			return
		}

		response.Header().Add("Vary", "Origin")
		if _, exists := allowed[origin]; !exists {
			writeAPIError(
				response,
				request,
				http.StatusForbidden,
				"ORIGIN_NOT_ALLOWED",
				"허용되지 않은 요청 출처입니다.",
			)
			return
		}

		response.Header().Set("Access-Control-Allow-Origin", origin)
		response.Header().Set("Access-Control-Allow-Credentials", "true")
		response.Header().Set(
			"Access-Control-Expose-Headers",
			requestIDHeader+", Retry-After, ETag",
		)
		if request.Method == http.MethodOptions {
			response.Header().Add("Vary", "Access-Control-Request-Headers")
			response.Header().Set(
				"Access-Control-Allow-Methods",
				"GET, POST, PUT, OPTIONS",
			)
			response.Header().Set(
				"Access-Control-Allow-Headers",
				"Authorization, Content-Type, Idempotency-Key, If-None-Match, Rune-Nexus-Save-Writer",
			)
			response.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(response, request)
	})
}
