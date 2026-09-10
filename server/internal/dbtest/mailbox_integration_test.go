//go:build integration

package dbtest_test

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	"github.com/jackc/pgx/v5/pgxpool"
)

func mailAccount(t *testing.T, ctx context.Context, pool *pgxpool.Pool) string {
	t.Helper()
	var id string
	if err := pool.QueryRow(ctx, `INSERT INTO accounts DEFAULT VALUES RETURNING id::text`).Scan(&id); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _, _ = pool.Exec(context.Background(), `DELETE FROM accounts WHERE id=$1`, id) })
	if _, err := pool.Exec(ctx, `INSERT INTO player_economies(account_id,authority_state,bootstrap_save_revision,bootstrapped_at) VALUES($1,'server_authoritative',1,now())`, id); err != nil {
		t.Fatal(err)
	}
	return id
}
func createTestMail(t *testing.T, ctx context.Context, pool *pgxpool.Pool, service *economy.Service, request economy.CreateMailRequest) string {
	t.Helper()
	id, err := service.CreateMail(ctx, request)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _, _ = pool.Exec(context.Background(), `DELETE FROM mails WHERE id=$1`, id) })
	return id
}
func testMailRequest() economy.CreateMailRequest {
	now := time.Now().UTC()
	var dispatch [16]byte
	if _, err := rand.Read(dispatch[:]); err != nil {
		panic(err)
	}
	dispatchKey := fmt.Sprintf("%x-%x-%x-%x-%x", dispatch[0:4], dispatch[4:6], dispatch[6:8], dispatch[8:10], dispatch[10:16])
	return economy.CreateMailRequest{DispatchKey: dispatchKey, Title: "업데이트 선물", Body: "무료 다이아와 모듈권입니다.", FreeDiamonds: 100, ModuleTickets: 2, Audience: "all", StartsAt: now.Add(-time.Hour), EligibilityCutoff: now, ExpiresAt: now.Add(time.Hour), CreatedBy: "integration-test"}
}
func TestMailboxConcurrentClaimAndRetry(t *testing.T) {
	ctx, pool := openTestPool(t)
	service := economy.NewService(pool)
	account := mailAccount(t, ctx, pool)
	id := createTestMail(t, ctx, pool, service, testMailRequest())
	if count, err := service.MailSummary(ctx, account); err != nil || count != 1 {
		t.Fatalf("summary %d %v", count, err)
	}
	for i := 0; i < 2; i++ {
		if err := service.ReadMail(ctx, account, id); err != nil {
			t.Fatal(err)
		}
	}
	if count, err := service.MailSummary(ctx, account); err != nil || count != 1 {
		t.Fatalf("read must not claim %d %v", count, err)
	}
	var group sync.WaitGroup
	failures := make(chan error, 16)
	for i := 0; i < 16; i++ {
		group.Add(1)
		go func(i int) {
			defer group.Done()
			result, err := service.ClaimMail(ctx, account, economy.MailClaimRequest{IdempotencyKey: fmt.Sprintf("00000000-0000-4000-8000-%012d", i+1), RawBody: []byte(`{"clientCompatibilityVersion":3}`), MailID: id})
			if err != nil {
				failures <- err
				return
			}
			if result.Snapshot.Wallet.FreeDiamonds != 100 || result.Snapshot.EconomyRevision != 1 {
				failures <- fmt.Errorf("duplicate payout: %+v", result.Snapshot)
			}
		}(i)
	}
	group.Wait()
	close(failures)
	for err := range failures {
		t.Error(err)
	}
	var claims, commands, ledger int
	if err := pool.QueryRow(ctx, `SELECT (SELECT count(*) FROM economy_reward_claims WHERE account_id=$1),(SELECT count(*) FROM economy_commands WHERE account_id=$1),(SELECT count(*) FROM economy_ledger_entries l JOIN economy_commands c ON c.id=l.command_id WHERE c.account_id=$1)`, account).Scan(&claims, &commands, &ledger); err != nil {
		t.Fatal(err)
	}
	if claims != 1 || commands != 1 || ledger != 2 {
		t.Fatalf("claims=%d commands=%d ledger=%d", claims, commands, ledger)
	}
	page, err := service.ListMail(ctx, account, "")
	if err != nil {
		t.Fatal(err)
	}
	if len(page.Mails) != 1 || page.Mails[0].ReadAt == nil || page.Mails[0].ClaimedAt == nil {
		t.Fatalf("state %+v", page)
	}
	if count, err := service.MailSummary(ctx, account); err != nil || count != 0 {
		t.Fatalf("summary after claim %d %v", count, err)
	}
	if _, err := service.ClaimMail(ctx, account, economy.MailClaimRequest{IdempotencyKey: "00000000-0000-4000-8000-000000000080", MailID: strings.ToUpper(id)}); err != nil {
		t.Fatal(err)
	}
	snapshot, err := service.Get(ctx, account)
	if err != nil {
		t.Fatal(err)
	}
	if snapshot.Wallet.FreeDiamonds != 100 {
		t.Fatal("UUID case bypassed duplicate reward protection")
	}
	for _, key := range snapshot.ClaimedRewardKeys {
		if key == "mail:"+id {
			t.Fatal("mail claim leaked into growing general economy snapshot")
		}
	}
	// 성공한 요청의 exact 재시도는 중지·만료 뒤에도 지급 영수증 복구.
	var key string
	if err := pool.QueryRow(ctx, `SELECT idempotency_key::text FROM economy_commands WHERE account_id=$1`, account).Scan(&key); err != nil {
		t.Fatal(err)
	}
	if err := service.DisableMail(ctx, id, "test-operator"); err != nil {
		t.Fatal(err)
	}
	retry := economy.MailClaimRequest{IdempotencyKey: key, RawBody: []byte(`{"clientCompatibilityVersion":3}`), MailID: id}
	if _, err := service.ClaimMail(ctx, account, retry); err != nil {
		t.Fatal(err)
	}
	retry.RawBody = []byte(`{"clientCompatibilityVersion":4}`)
	if _, err := service.ClaimMail(ctx, account, retry); !errors.Is(err, economy.ErrIdempotencyKeyReused) {
		t.Fatalf("reused key error %v", err)
	}
}

func TestMailboxEligibilityPaginationAndBatch(t *testing.T) {
	ctx, pool := openTestPool(t)
	service := economy.NewService(pool)
	account := mailAccount(t, ctx, pool)
	other := mailAccount(t, ctx, pool)
	request := testMailRequest()
	request.Audience = "targeted"
	request.TargetAccountIDs = []string{account}
	ids := []string{}
	for i := 0; i < 23; i++ {
		request.DispatchKey = testMailRequest().DispatchKey
		ids = append(ids, createTestMail(t, ctx, pool, service, request))
	}
	if count, err := service.MailSummary(ctx, other); err != nil || count != 0 {
		t.Fatalf("target isolation %d %v", count, err)
	}
	if err := service.ReadMail(ctx, other, ids[0]); !errors.Is(err, economy.ErrMailUnavailable) {
		t.Fatalf("unauthorized read %v", err)
	}
	if _, err := service.ClaimMail(ctx, other, economy.MailClaimRequest{IdempotencyKey: "00000000-0000-4000-8000-000000000001", MailID: ids[0]}); !errors.Is(err, economy.ErrMailUnavailable) {
		t.Fatalf("unauthorized claim %v", err)
	}
	first, err := service.ListMail(ctx, account, "")
	if err != nil || len(first.Mails) != 20 || first.NextCursor == nil {
		t.Fatalf("first page %+v %v", first, err)
	}
	second, err := service.ListMail(ctx, account, *first.NextCursor)
	if err != nil || len(second.Mails) != 3 || second.NextCursor != nil {
		t.Fatalf("second page %+v %v", second, err)
	}
	seen := map[string]bool{}
	for _, mail := range append(first.Mails, second.Mails...) {
		if seen[mail.ID] {
			t.Fatal("duplicate page item")
		}
		seen[mail.ID] = true
	}
	if _, err := service.ListMail(ctx, account, "invalid"); !errors.Is(err, economy.ErrInvalidMailRequest) {
		t.Fatalf("invalid cursor %v", err)
	}
	if err := service.DisableMail(ctx, ids[1], "test-operator"); err != nil {
		t.Fatal(err)
	}
	batchIDs := []string{ids[0], ids[1], ids[2]}
	key := "00000000-0000-4000-8000-000000000022"
	batch, err := service.ClaimAllMail(ctx, account, key, []byte(`{"mailIds":[]}`), batchIDs)
	if err != nil {
		t.Fatal(err)
	}
	if len(batch.Results) != 3 || !batch.Results[0].Claimed || batch.Results[1].Code != "MAIL_UNAVAILABLE" || !batch.Results[2].Claimed || batch.Snapshot.Wallet.FreeDiamonds != 200 {
		t.Fatalf("batch %+v", batch)
	}
	retry, err := service.ClaimAllMail(ctx, account, key, []byte(`{"mailIds":[]}`), batchIDs)
	if err != nil || retry.Snapshot.Wallet.FreeDiamonds != 200 {
		t.Fatalf("batch retry %+v %v", retry, err)
	}
	if _, err := service.ClaimAllMail(ctx, account, key, []byte(`{"mailIds":["changed"]}`), []string{ids[3]}); !errors.Is(err, economy.ErrIdempotencyKeyReused) {
		t.Fatalf("changed batch accepted %v", err)
	}
	for _, invalid := range [][]string{ids[:21], {ids[0], strings.ToUpper(ids[0])}, {"invalid"}, {}} {
		if _, err := service.ClaimAllMail(ctx, account, key, nil, invalid); !errors.Is(err, economy.ErrInvalidMailRequest) {
			t.Fatalf("invalid batch accepted %v", err)
		}
	}
	// 발송 시 가입 기준, 예약, 만료는 읽음과 실제 수령 모두에 적용.
	for _, mode := range []string{"cutoff", "scheduled", "expired"} {
		request := testMailRequest()
		switch mode {
		case "cutoff":
			request.EligibilityCutoff = time.Now().Add(-24 * time.Hour)
		case "scheduled":
			request.StartsAt = time.Now().Add(time.Minute)
		case "expired":
			request.ExpiresAt = time.Now().Add(-time.Minute)
		}
		id := createTestMail(t, ctx, pool, service, request)
		if err := service.ReadMail(ctx, account, id); !errors.Is(err, economy.ErrMailUnavailable) {
			t.Fatalf("%s read %v", mode, err)
		}
		if _, err := service.ClaimMail(ctx, account, economy.MailClaimRequest{IdempotencyKey: "00000000-0000-4000-8000-000000000099", MailID: id}); !errors.Is(err, economy.ErrMailUnavailable) {
			t.Fatalf("%s claim %v", mode, err)
		}
	}
}

func TestMailboxThreeThousandAccountsSparseRecords(t *testing.T) {
	ctx, pool := openTestPool(t)
	service := economy.NewService(pool)
	rows, err := pool.Query(ctx, `INSERT INTO accounts(created_at) SELECT now()-interval '1 day' FROM generate_series(1,3000) RETURNING id::text`)
	if err != nil {
		t.Fatal(err)
	}
	ids := []string{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			t.Fatal(err)
		}
		ids = append(ids, id)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _, _ = pool.Exec(context.Background(), `DELETE FROM accounts WHERE id=ANY($1::uuid[])`, ids) })
	mailID := createTestMail(t, ctx, pool, service, testMailRequest())
	var records int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM mail_reads WHERE mail_id=$1`, mailID).Scan(&records); err != nil || records != 0 {
		t.Fatalf("eager personal records %d %v", records, err)
	}
	started := time.Now()
	var group sync.WaitGroup
	failures := make(chan error, 8)
	for worker := 0; worker < 8; worker++ {
		group.Add(1)
		go func(worker int) {
			defer group.Done()
			for i := worker; i < len(ids); i += 8 {
				count, err := service.MailSummary(ctx, ids[i])
				if err != nil || count != 1 {
					failures <- fmt.Errorf("summary %d: %d %v", i, count, err)
					return
				}
			}
		}(worker)
	}
	group.Wait()
	close(failures)
	for err := range failures {
		t.Error(err)
	}
	t.Logf("3000 account summary requests / 8 workers / pool 4: %s", time.Since(started))
	if err := service.ReadMail(ctx, ids[0], mailID); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM mail_reads WHERE mail_id=$1`, mailID).Scan(&records); err != nil || records != 1 {
		t.Fatalf("sparse records %d %v", records, err)
	}
}

func TestMailboxDispatchRetryAndValidation(t *testing.T) {
	ctx, pool := openTestPool(t)
	service := economy.NewService(pool)
	account := mailAccount(t, ctx, pool)
	other := mailAccount(t, ctx, pool)
	request := testMailRequest()
	request.Audience = "targeted"
	request.TargetAccountIDs = []string{account, other}
	id := createTestMail(t, ctx, pool, service, request)
	request.TargetAccountIDs = []string{strings.ToUpper(other), account}
	retry, err := service.CreateMail(ctx, request)
	if err != nil || retry != id {
		t.Fatalf("dispatch retry %s %v", retry, err)
	}
	request.FreeDiamonds++
	if _, err := service.CreateMail(ctx, request); !errors.Is(err, economy.ErrIdempotencyKeyReused) {
		t.Fatalf("changed dispatch accepted %v", err)
	}
	request = testMailRequest()
	request.Audience = "targeted"
	request.TargetAccountIDs = []string{account, strings.ToUpper(account)}
	if _, err := service.CreateMail(ctx, request); !errors.Is(err, economy.ErrInvalidMailRequest) {
		t.Fatalf("case duplicate target accepted %v", err)
	}
	request = testMailRequest()
	request.Audience = "targeted"
	request.TargetAccountIDs = []string{"00000000-0000-4000-8000-000000000000"}
	if _, err := service.CreateMail(ctx, request); err == nil {
		t.Fatal("nonexistent target accepted")
	}
	var count int
	if err := pool.QueryRow(ctx, `SELECT count(*) FROM mails WHERE dispatch_key=$1`, request.DispatchKey).Scan(&count); err != nil || count != 0 {
		t.Fatalf("failed target creation left partial mail %d %v", count, err)
	}
}
