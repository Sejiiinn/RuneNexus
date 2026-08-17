package httpapi

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

type readinessCheckerFunc func(context.Context) error

func (check readinessCheckerFunc) Ping(ctx context.Context) error {
	return check(ctx)
}

func TestLivenessDoesNotRequireDatabase(t *testing.T) {
	databaseCalled := false
	handler := newTestHandler(readinessCheckerFunc(func(context.Context) error {
		databaseCalled = true
		return errors.New("database unavailable")
	}))

	request := httptest.NewRequest(http.MethodGet, "/health/live", nil)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d", response.Code)
	}
	if databaseCalled {
		t.Fatal("liveness check called the database")
	}
	if !strings.Contains(response.Body.String(), `"status":"ok"`) {
		t.Fatalf("body = %q", response.Body.String())
	}
	if response.Header().Get(requestIDHeader) == "" {
		t.Fatal("response is missing a request ID")
	}
}

func TestReadinessReturnsUnavailableWhenDatabasePingFails(t *testing.T) {
	handler := newTestHandler(readinessCheckerFunc(func(context.Context) error {
		return errors.New("database unavailable")
	}))

	request := httptest.NewRequest(http.MethodGet, "/health/ready", nil)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)

	if response.Code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d", response.Code)
	}
	if !strings.Contains(response.Body.String(), `"status":"unavailable"`) {
		t.Fatalf("body = %q", response.Body.String())
	}
}

func TestReadinessReturnsOKWhenDatabasePingSucceeds(t *testing.T) {
	handler := newTestHandler(readinessCheckerFunc(func(context.Context) error {
		return nil
	}))

	request := httptest.NewRequest(http.MethodGet, "/health/ready", nil)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d", response.Code)
	}
}

func newTestHandler(database ReadinessChecker) http.Handler {
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	return NewHandler(logger, Dependencies{
		Database:         database,
		ReadinessTimeout: 50 * time.Millisecond,
	})
}
