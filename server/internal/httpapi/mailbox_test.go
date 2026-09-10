package httpapi

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

type mailboxStub struct {
	called            bool
	accountID, mailID string
}

func (s *mailboxStub) ListMail(context.Context, string, string) (economy.MailboxPage, error) {
	return economy.MailboxPage{}, nil
}
func (s *mailboxStub) MailSummary(context.Context, string) (int64, error) { return 1, nil }
func (s *mailboxStub) ReadMail(_ context.Context, account, id string) error {
	s.called = true
	s.accountID = account
	s.mailID = id
	return nil
}
func (s *mailboxStub) ClaimMail(_ context.Context, account string, r economy.MailClaimRequest) (economy.CommandResult, error) {
	s.called = true
	s.accountID = account
	s.mailID = r.MailID
	return economy.CommandResult{RewardKey: "mail:" + r.MailID}, nil
}
func (s *mailboxStub) ClaimAllMail(_ context.Context, account, key string, raw []byte, ids []string) (economy.MailBatchResult, error) {
	s.called = true
	s.accountID = account
	return economy.MailBatchResult{}, nil
}

func TestMailboxClaimValidatesCompatibilityAndRewardPayload(t *testing.T) {
	for _, test := range []struct {
		name, body string
		want       int
	}{
		{"old client", `{"clientCompatibilityVersion":1}`, http.StatusUpgradeRequired},
		{"injected rewards", fmt.Sprintf(`{"clientCompatibilityVersion":%d,"freeDiamonds":100000}`, gamesave.CurrentClientCompatibilityVersion), http.StatusBadRequest},
		{"valid", fmt.Sprintf(`{"clientCompatibilityVersion":%d}`, gamesave.CurrentClientCompatibilityVersion), http.StatusOK},
	} {
		t.Run(test.name, func(t *testing.T) {
			service := &mailboxStub{}
			handler := mailboxHandler{economyHandler: economyHandler{logger: slog.New(slog.NewTextHandler(io.Discard, nil))}, mailbox: service}
			request := economyRequest(http.MethodPost, "/v1/mailbox/test/claim", test.body)
			request.SetPathValue("mailId", "test")
			response := httptest.NewRecorder()
			handler.claim(response, request)
			if response.Code != test.want {
				t.Fatalf("status %d body %s", response.Code, response.Body)
			}
			if service.called != (test.want == http.StatusOK) {
				t.Fatalf("service called=%t", service.called)
			}
			if service.called && (service.accountID != testAccountID || service.mailID != "test") {
				t.Fatal("principal or mail path not propagated")
			}
		})
	}
}
func TestMailboxClaimRequiresIdempotencyKey(t *testing.T) {
	handler := mailboxHandler{economyHandler: economyHandler{logger: slog.New(slog.NewTextHandler(io.Discard, nil))}, mailbox: &mailboxStub{}}
	request := economyRequest(http.MethodPost, "/v1/mailbox/test/claim", fmt.Sprintf(`{"clientCompatibilityVersion":%d}`, gamesave.CurrentClientCompatibilityVersion))
	request.Header.Del(idempotencyKeyHeader)
	response := httptest.NewRecorder()
	handler.claim(response, request)
	requireAPIError(t, response, http.StatusBadRequest, "INVALID_IDEMPOTENCY_KEY")
}

func TestMailboxRoutesRequireAuthentication(t *testing.T) {
	handler := NewHandler(slog.New(slog.NewTextHandler(io.Discard, nil)), Dependencies{Authenticator: successfulAccessAuthenticator(t), MailboxService: &mailboxStub{}})
	for _, route := range []struct{ method, path string }{{"GET", "/v1/mailbox"}, {"GET", "/v1/mailbox/summary"}, {"POST", "/v1/mailbox/test/read"}, {"POST", "/v1/mailbox/test/claim"}, {"POST", "/v1/mailbox/claim-all"}} {
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, httptest.NewRequest(route.method, route.path, nil))
		if response.Code != http.StatusUnauthorized {
			t.Fatalf("%s %s status %d", route.method, route.path, response.Code)
		}
	}
}
func TestMailboxBatchCompatibilityGate(t *testing.T) {
	service := &mailboxStub{}
	handler := mailboxHandler{economyHandler: economyHandler{logger: slog.New(slog.NewTextHandler(io.Discard, nil))}, mailbox: service}
	response := httptest.NewRecorder()
	handler.claimAll(response, economyRequest("POST", "/v1/mailbox/claim-all", `{"clientCompatibilityVersion":1,"mailIds":[]}`))
	requireAPIError(t, response, http.StatusUpgradeRequired, "CLIENT_UPDATE_REQUIRED")
	if service.called {
		t.Fatal("outdated batch reached service")
	}
}
