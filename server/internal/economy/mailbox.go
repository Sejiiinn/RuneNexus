package economy

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"sort"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/Sejiiinn/RuneNexus/server/internal/dbgen"
	"github.com/jackc/pgx/v5"
)

const MailboxPageSize = 20

var ErrMailUnavailable = errors.New("mail is unavailable")
var ErrInvalidMailRequest = errors.New("invalid mail request")

type Mail struct {
	ID            string     `json:"id"`
	Title         string     `json:"title"`
	Body          string     `json:"body"`
	FreeDiamonds  int64      `json:"freeDiamonds"`
	ModuleTickets int64      `json:"moduleTickets"`
	StartsAt      time.Time  `json:"startsAt"`
	ExpiresAt     time.Time  `json:"expiresAt"`
	ReadAt        *time.Time `json:"readAt"`
	ClaimedAt     *time.Time `json:"claimedAt"`
}
type MailboxPage struct {
	Mails      []Mail    `json:"mails"`
	NextCursor *string   `json:"nextCursor"`
	ServerTime time.Time `json:"serverTime"`
}
type MailClaimRequest struct {
	IdempotencyKey string
	RawBody        []byte
	MailID         string
}
type MailBatchItem struct {
	MailID  string `json:"mailId"`
	Claimed bool   `json:"claimed"`
	Code    string `json:"code,omitempty"`
	Message string `json:"message,omitempty"`
}
type MailBatchResult struct {
	CommandResult
	Results []MailBatchItem `json:"results"`
}
type CreateMailRequest struct {
	DispatchKey       string    `json:"dispatchKey"`
	Title             string    `json:"title"`
	Body              string    `json:"body"`
	FreeDiamonds      int64     `json:"freeDiamonds"`
	ModuleTickets     int64     `json:"moduleTickets"`
	Audience          string    `json:"audience"`
	TargetAccountIDs  []string  `json:"targetAccountIds"`
	EligibilityCutoff time.Time `json:"eligibilityCutoff"`
	StartsAt          time.Time `json:"startsAt"`
	ExpiresAt         time.Time `json:"expiresAt"`
	CreatedBy         string    `json:"createdBy"`
}

// 대상 조건을 조회·읽음·지급에서 공통 적용. 전체 계정 순회 없음.
const mailEligibility = ` m.disabled_at IS NULL AND m.starts_at <= $2 AND m.expires_at > $2
 AND EXISTS (SELECT 1 FROM accounts a WHERE a.id=$1 AND a.status='active' AND
 ((m.audience='all' AND a.created_at <= m.eligibility_cutoff) OR
 (m.audience='targeted' AND EXISTS (SELECT 1 FROM mail_targets t WHERE t.account_id=a.id AND t.mail_id=m.id)))) `

func (service *Service) ListMail(ctx context.Context, accountID, cursor string) (MailboxPage, error) {
	result := MailboxPage{Mails: []Mail{}, ServerTime: service.now().UTC()}
	if _, err := parseUUID(accountID); err != nil {
		return result, ErrInvalidMailRequest
	}
	var before *time.Time
	var beforeID *string
	if cursor != "" {
		decoded, err := base64.RawURLEncoding.DecodeString(cursor)
		var position struct {
			At time.Time `json:"at"`
			ID string    `json:"id"`
		}
		if err != nil || json.Unmarshal(decoded, &position) != nil || position.At.IsZero() {
			return result, ErrInvalidMailRequest
		}
		if _, err := parseUUID(position.ID); err != nil {
			return result, ErrInvalidMailRequest
		}
		before = &position.At
		beforeID = &position.ID
	}
	rows, err := service.database.Query(ctx, `SELECT m.id::text,m.title,m.body,m.free_diamonds,m.module_tickets,m.starts_at,m.expires_at,r.read_at,c.claimed_at
 FROM mails m LEFT JOIN mail_reads r ON r.mail_id=m.id AND r.account_id=$1
 LEFT JOIN economy_reward_claims c ON c.account_id=$1 AND c.reward_key='mail:'||m.id::text
 WHERE `+mailEligibility+` AND ($3::timestamptz IS NULL OR (m.starts_at,m.id)<($3,$4::uuid))
 ORDER BY m.starts_at DESC,m.id DESC LIMIT 21`, accountID, result.ServerTime, before, beforeID)
	if err != nil {
		return result, fmt.Errorf("list mailbox: %w", err)
	}
	defer rows.Close()
	for rows.Next() {
		var mail Mail
		if err := rows.Scan(&mail.ID, &mail.Title, &mail.Body, &mail.FreeDiamonds, &mail.ModuleTickets, &mail.StartsAt, &mail.ExpiresAt, &mail.ReadAt, &mail.ClaimedAt); err != nil {
			return result, err
		}
		result.Mails = append(result.Mails, mail)
	}
	if err := rows.Err(); err != nil {
		return result, err
	}
	if len(result.Mails) > MailboxPageSize {
		result.Mails = result.Mails[:MailboxPageSize]
		last := result.Mails[len(result.Mails)-1]
		payload, _ := json.Marshal(struct {
			At time.Time `json:"at"`
			ID string    `json:"id"`
		}{last.StartsAt, last.ID})
		next := base64.RawURLEncoding.EncodeToString(payload)
		result.NextCursor = &next
	}
	return result, nil
}

func (service *Service) MailSummary(ctx context.Context, accountID string) (int64, error) {
	if _, err := parseUUID(accountID); err != nil {
		return 0, ErrInvalidMailRequest
	}
	var count int64
	err := service.database.QueryRow(ctx, `SELECT count(*) FROM mails m WHERE `+mailEligibility+` AND NOT EXISTS (SELECT 1 FROM economy_reward_claims c WHERE c.account_id=$1 AND c.reward_key='mail:'||m.id::text)`, accountID, service.now().UTC()).Scan(&count)
	return count, err
}
func (service *Service) ReadMail(ctx context.Context, accountID, mailID string) error {
	if _, err := parseUUID(accountID); err != nil {
		return ErrInvalidMailRequest
	}
	if _, err := parseUUID(mailID); err != nil {
		return ErrInvalidMailRequest
	}
	var exists bool
	err := service.database.QueryRow(ctx, `WITH eligible AS (SELECT m.id FROM mails m WHERE `+mailEligibility+` AND m.id=$3), inserted AS
 (INSERT INTO mail_reads(account_id,mail_id) SELECT $1,id FROM eligible ON CONFLICT DO NOTHING)
 SELECT EXISTS(SELECT 1 FROM eligible)`, accountID, service.now().UTC(), mailID).Scan(&exists)
	if err != nil {
		return err
	}
	if !exists {
		return ErrMailUnavailable
	}
	return nil
}

func (service *Service) ClaimMail(ctx context.Context, accountID string, request MailClaimRequest) (CommandResult, error) {
	account, err := parseUUID(accountID)
	if err != nil {
		return CommandResult{}, ErrInvalidMailRequest
	}
	mailUUID, err := parseUUID(request.MailID)
	if err != nil {
		return CommandResult{}, ErrInvalidMailRequest
	}
	request.MailID = formatUUID(mailUUID)
	// 경로도 영수증 해시에 포함하여 동일 본문의 다른 우편 재사용 차단.
	key, hash, err := requestIdentity(request.IdempotencyKey, append([]byte("mail:"+request.MailID+"\n"), request.RawBody...))
	if err != nil {
		return CommandResult{}, err
	}
	tx, err := service.database.Begin(ctx)
	if err != nil {
		return CommandResult{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	q := dbgen.New(tx)
	wallet, err := lockAuthoritativeEconomy(ctx, q, account)
	if err != nil {
		return CommandResult{}, err
	}
	stored, err := q.GetEconomyCommand(ctx, dbgen.GetEconomyCommandParams{AccountID: account, IdempotencyKey: key})
	if err == nil {
		if stored.CommandType != "reward_claim" {
			return CommandResult{}, ErrIdempotencyKeyReused
		}
		return existingCommandResult[CommandResult](stored, hash)
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, err
	}
	rewardKey := "mail:" + request.MailID
	claimed, err := q.GetEconomyRewardClaim(ctx, dbgen.GetEconomyRewardClaimParams{AccountID: account, RewardKey: rewardKey})
	if err == nil {
		var result CommandResult
		err = json.Unmarshal(claimed.ResponsePayload, &result)
		return result, err
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, err
	}
	var diamonds, tickets int64
	// 공유 잠금은 수령끼리 병렬 진행을 허용하고 운영 중지와만 직렬화.
	err = tx.QueryRow(ctx, `SELECT m.free_diamonds,m.module_tickets FROM mails m WHERE `+mailEligibility+` AND m.id=$3 FOR SHARE OF m`, accountID, service.now().UTC(), request.MailID).Scan(&diamonds, &tickets)
	if errors.Is(err, pgx.ErrNoRows) {
		return CommandResult{}, ErrMailUnavailable
	}
	if err != nil {
		return CommandResult{}, err
	}
	if wallet.FreeDiamonds > math.MaxInt64-diamonds || wallet.ModuleTickets > math.MaxInt64-tickets {
		return CommandResult{}, ErrInvalidCommand
	}
	system, err := q.GetEconomySystemState(ctx)
	if err != nil {
		return CommandResult{}, err
	}
	command, err := q.CreateEconomyCommand(ctx, dbgen.CreateEconomyCommandParams{AccountID: account, IdempotencyKey: key, CommandType: "reward_claim", RequestHash: hash, ResultingRevision: wallet.Revision + 1, AuthorityEpoch: system.AuthorityEpoch, CatalogVersion: int4(CatalogVersion), ResponsePayload: []byte(`{}`)})
	if err != nil {
		return CommandResult{}, err
	}
	evidence, _ := json.Marshal(map[string]string{"mailId": request.MailID})
	if err = q.CreateEconomyRewardClaim(ctx, dbgen.CreateEconomyRewardClaimParams{AccountID: account, RewardKey: rewardKey, CommandID: command.ID, Evidence: evidence}); err != nil {
		return CommandResult{}, err
	}
	updated, err := q.UpdatePlayerEconomy(ctx, dbgen.UpdatePlayerEconomyParams{AccountID: account, Revision: wallet.Revision + 1, FreeDiamonds: wallet.FreeDiamonds + diamonds, PaidDiamonds: wallet.PaidDiamonds, ModuleTickets: wallet.ModuleTickets + tickets, ModuleDrawCount: wallet.ModuleDrawCount, ModuleTicketPurchaseCount: wallet.ModuleTicketPurchaseCount, ModuleItemSequence: wallet.ModuleItemSequence, ResearchSlotTwoUnlocked: wallet.ResearchSlotTwoUnlocked, Revision_2: wallet.Revision})
	if err != nil {
		return CommandResult{}, err
	}
	order := int16(0)
	if err = createLedger(ctx, q, command.ID, &order, "free_diamond", diamonds, updated.FreeDiamonds, "mail_reward"); err != nil {
		return CommandResult{}, err
	}
	if err = createLedger(ctx, q, command.ID, &order, "module_ticket", tickets, updated.ModuleTickets, "mail_reward"); err != nil {
		return CommandResult{}, err
	}
	if _, err = tx.Exec(ctx, `INSERT INTO mail_reads(account_id,mail_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, account, request.MailID); err != nil {
		return CommandResult{}, err
	}
	snapshot, err := service.snapshot(ctx, q, updated)
	if err != nil {
		return CommandResult{}, err
	}
	result := CommandResult{Snapshot: snapshot, RewardKey: rewardKey, GrantedDiamonds: diamonds, GrantedModuleTickets: tickets}
	if err = storeCommandResult(ctx, q, command.ID, result); err != nil {
		return CommandResult{}, err
	}
	if err = tx.Commit(ctx); err != nil {
		return CommandResult{}, err
	}
	return result, nil
}

func (service *Service) ClaimAllMail(ctx context.Context, accountID, key string, raw []byte, ids []string) (MailBatchResult, error) {
	result := MailBatchResult{Results: []MailBatchItem{}}
	batchKey, err := parseUUID(key)
	if err != nil {
		return result, ErrInvalidIdempotencyKey
	}
	key = formatUUID(batchKey)
	if len(ids) == 0 || len(ids) > MailboxPageSize {
		return result, ErrInvalidMailRequest
	}
	seen := map[string]bool{}
	canonicalIDs := make([]string, len(ids))
	for i, id := range ids {
		parsed, err := parseUUID(id)
		if err != nil {
			return result, ErrInvalidMailRequest
		}
		canonicalIDs[i] = formatUUID(parsed)
		if seen[canonicalIDs[i]] {
			return result, ErrInvalidMailRequest
		}
		seen[canonicalIDs[i]] = true
	}
	ids = canonicalIDs
	// 배치 키는 전체 본문에 결속하되 성공 결과는 고정하지 않아 실패 재시도 허용.
	requestHash := sha256.Sum256(raw)
	if _, err := service.database.Exec(ctx, `INSERT INTO mail_claim_batches(account_id,idempotency_key,request_hash) VALUES($1,$2,$3) ON CONFLICT DO NOTHING`, accountID, key, requestHash[:]); err != nil {
		return result, err
	}
	var storedHash []byte
	if err := service.database.QueryRow(ctx, `SELECT request_hash FROM mail_claim_batches WHERE account_id=$1 AND idempotency_key=$2`, accountID, key).Scan(&storedHash); err != nil {
		return result, err
	}
	if !bytes.Equal(storedHash, requestHash[:]) {
		return result, ErrIdempotencyKeyReused
	}

	for _, id := range ids {
		// 배치 재시도에도 우편별 명령 ID 고정. 실패 항목은 다음 요청에서 재평가.
		sum := sha256.Sum256([]byte("mail-batch:" + key + ":" + id))
		childKey := fmt.Sprintf("%x-%x-%x-%x-%x", sum[0:4], sum[4:6], sum[6:8], sum[8:10], sum[10:16])
		claim, err := service.ClaimMail(ctx, accountID, MailClaimRequest{IdempotencyKey: childKey, RawBody: raw, MailID: id})
		if errors.Is(err, ErrMailUnavailable) {
			result.Results = append(result.Results, MailBatchItem{MailID: id, Code: "MAIL_UNAVAILABLE", Message: "수령할 수 없거나 만료된 우편입니다."})
			continue
		}
		if err != nil {
			return result, err
		}
		result.Results = append(result.Results, MailBatchItem{MailID: id, Claimed: true})
		result.GrantedDiamonds += claim.GrantedDiamonds
		result.GrantedModuleTickets += claim.GrantedModuleTickets
	}
	snapshot, err := service.Get(ctx, accountID)
	result.Snapshot = snapshot
	return result, err
}

func ValidateMail(request *CreateMailRequest) error {
	dispatchID, err := parseUUID(request.DispatchKey)
	if err != nil {
		return ErrInvalidMailRequest
	}
	request.DispatchKey = formatUUID(dispatchID)
	if request.EligibilityCutoff.IsZero() {
		request.EligibilityCutoff = request.StartsAt
	}
	if strings.TrimSpace(request.Title) == "" || utf8.RuneCountInString(request.Title) > 120 || strings.TrimSpace(request.Body) == "" || utf8.RuneCountInString(request.Body) > 4000 || strings.TrimSpace(request.CreatedBy) == "" || utf8.RuneCountInString(request.CreatedBy) > 120 || request.StartsAt.IsZero() || !request.ExpiresAt.After(request.StartsAt) || request.FreeDiamonds < 0 || request.FreeDiamonds > 1000000 || request.ModuleTickets < 0 || request.ModuleTickets > 100000 || (request.FreeDiamonds == 0 && request.ModuleTickets == 0) {
		return ErrInvalidMailRequest
	}
	if (request.Audience != "all" && request.Audience != "targeted") || (request.Audience == "all" && len(request.TargetAccountIDs) > 0) || (request.Audience == "targeted" && len(request.TargetAccountIDs) == 0) {
		return ErrInvalidMailRequest
	}
	seen := map[string]bool{}
	request.TargetAccountIDs = append([]string(nil), request.TargetAccountIDs...)
	for i, id := range request.TargetAccountIDs {
		parsed, err := parseUUID(id)
		if err != nil {
			return ErrInvalidMailRequest
		}
		canonical := formatUUID(parsed)
		if seen[canonical] {
			return ErrInvalidMailRequest
		}
		seen[canonical] = true
		request.TargetAccountIDs[i] = canonical
	}
	sort.Strings(request.TargetAccountIDs)
	request.StartsAt = request.StartsAt.UTC()
	request.ExpiresAt = request.ExpiresAt.UTC()
	request.EligibilityCutoff = request.EligibilityCutoff.UTC()
	return nil
}
func (service *Service) CreateMail(ctx context.Context, request CreateMailRequest) (string, error) {
	if err := ValidateMail(&request); err != nil {
		return "", err
	}
	tx, err := service.database.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	var id string
	payload, err := json.Marshal(request)
	if err != nil {
		return "", err
	}
	requestHash := sha256.Sum256(payload)
	err = tx.QueryRow(ctx, `INSERT INTO mails(title,body,free_diamonds,module_tickets,audience,eligibility_cutoff,starts_at,expires_at,created_by,dispatch_key,request_hash) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) ON CONFLICT(dispatch_key) DO NOTHING RETURNING id::text`, request.Title, request.Body, request.FreeDiamonds, request.ModuleTickets, request.Audience, request.EligibilityCutoff, request.StartsAt, request.ExpiresAt, request.CreatedBy, request.DispatchKey, requestHash[:]).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		var storedHash []byte
		if err = tx.QueryRow(ctx, `SELECT id::text,request_hash FROM mails WHERE dispatch_key=$1`, request.DispatchKey).Scan(&id, &storedHash); err != nil {
			return "", err
		}
		if !bytes.Equal(storedHash, requestHash[:]) {
			return "", ErrIdempotencyKeyReused
		}
		return id, nil
	}
	if err != nil {
		return "", err
	}
	if len(request.TargetAccountIDs) > 0 {
		_, err = tx.Exec(ctx, `INSERT INTO mail_targets(account_id,mail_id) SELECT unnest($1::uuid[]),$2::uuid`, request.TargetAccountIDs, id)
		if err != nil {
			return "", err
		}
	}
	if err = tx.Commit(ctx); err != nil {
		return "", err
	}
	return id, nil
}
func (service *Service) DisableMail(ctx context.Context, id, operator string) error {
	if _, err := parseUUID(id); err != nil || strings.TrimSpace(operator) == "" || utf8.RuneCountInString(operator) > 120 {
		return ErrInvalidMailRequest
	}
	result, err := service.database.Exec(ctx, `UPDATE mails SET disabled_at=coalesce(disabled_at,now()),disabled_by=coalesce(disabled_by,$2) WHERE id=$1`, id, operator)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return ErrMailUnavailable
	}
	return nil
}
