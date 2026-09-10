package httpapi

import (
	"context"
	"errors"
	"net/http"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
)

type MailboxService interface {
	ListMail(context.Context, string, string) (economy.MailboxPage, error)
	MailSummary(context.Context, string) (int64, error)
	ReadMail(context.Context, string, string) error
	ClaimMail(context.Context, string, economy.MailClaimRequest) (economy.CommandResult, error)
	ClaimAllMail(context.Context, string, string, []byte, []string) (economy.MailBatchResult, error)
}
type mailboxHandler struct {
	economyHandler
	mailbox MailboxService
}
type mailboxClaimRequest struct {
	ClientCompatibilityVersion *int `json:"clientCompatibilityVersion"`
}
type mailboxBatchRequest struct {
	ClientCompatibilityVersion *int     `json:"clientCompatibilityVersion"`
	MailIDs                    []string `json:"mailIds"`
}

func (handler mailboxHandler) list(w http.ResponseWriter, r *http.Request) {
	principal, ok := authenticatedPrincipalFromContext(r.Context())
	if !ok {
		handler.writeInternalError(w, r, errors.New("missing principal"))
		return
	}
	if len(r.URL.Query().Get("cursor")) > 512 {
		handler.mailError(w, r, economy.ErrInvalidMailRequest)
		return
	}
	result, err := handler.mailbox.ListMail(r.Context(), principal.AccountID, r.URL.Query().Get("cursor"))
	if handler.mailError(w, r, err) {
		return
	}
	writeJSON(w, http.StatusOK, result)
}
func (handler mailboxHandler) summary(w http.ResponseWriter, r *http.Request) {
	principal, ok := authenticatedPrincipalFromContext(r.Context())
	if !ok {
		handler.writeInternalError(w, r, errors.New("missing principal"))
		return
	}
	count, err := handler.mailbox.MailSummary(r.Context(), principal.AccountID)
	if handler.mailError(w, r, err) {
		return
	}
	writeJSON(w, http.StatusOK, map[string]int64{"unclaimedCount": count})
}
func (handler mailboxHandler) read(w http.ResponseWriter, r *http.Request) {
	principal, ok := authenticatedPrincipalFromContext(r.Context())
	if !ok {
		handler.writeInternalError(w, r, errors.New("missing principal"))
		return
	}
	if handler.mailError(w, r, handler.mailbox.ReadMail(r.Context(), principal.AccountID, r.PathValue("mailId"))) {
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"read": true})
}
func (handler mailboxHandler) claim(w http.ResponseWriter, r *http.Request) {
	principal, key, raw, _, ok := decodeEconomyCommand[mailboxClaimRequest](handler.economyHandler, w, r)
	if !ok {
		return
	}
	result, err := handler.mailbox.ClaimMail(r.Context(), principal.AccountID, economy.MailClaimRequest{IdempotencyKey: key, RawBody: raw, MailID: r.PathValue("mailId")})
	if handler.mailError(w, r, err) {
		return
	}
	writeJSON(w, http.StatusOK, result)
}
func (handler mailboxHandler) claimAll(w http.ResponseWriter, r *http.Request) {
	principal, key, raw, input, ok := decodeEconomyCommand[mailboxBatchRequest](handler.economyHandler, w, r)
	if !ok {
		return
	}
	result, err := handler.mailbox.ClaimAllMail(r.Context(), principal.AccountID, key, raw, input.MailIDs)
	if handler.mailError(w, r, err) {
		return
	}
	writeJSON(w, http.StatusOK, result)
}
func (handler mailboxHandler) mailError(w http.ResponseWriter, r *http.Request, err error) bool {
	if errors.Is(err, economy.ErrMailUnavailable) {
		writeAPIError(w, r, http.StatusNotFound, "MAIL_UNAVAILABLE", "수령할 수 없거나 만료된 우편입니다.")
		return true
	}
	if errors.Is(err, economy.ErrInvalidMailRequest) {
		writeAPIError(w, r, http.StatusBadRequest, "INVALID_MAIL_REQUEST", "우편 요청 형식이 올바르지 않습니다.")
		return true
	}
	return handler.writeEconomyError(w, r, err)
}
