//go:build integration

package dbtest_test

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"reflect"
	"strings"
	"sync"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

const settlementRunID = "0198b955-3656-7c40-b3cb-87f427b90bf2"

func openRunSettlement(t *testing.T) (context.Context, *claimedSaveService, string, *economy.Service, economy.RunSettlementRequest) {
	t.Helper()
	ctx, fixture, accountID := openSaveService(t)
	_, err := fixture.Update(ctx, accountID, gamesave.UpdateRequest{
		IdempotencyKey: firstSaveKey, ExpectedRevision: 0, RawBody: []byte(`{"expectedRevision":0}`),
		Data: gamesave.Data{
			Version: gamesave.CurrentSchemaVersion, Preferences: json.RawMessage(`{}`),
			Progression:   json.RawMessage(`{"freeDiamonds":0,"paidDiamonds":0}`),
			TurretModules: json.RawMessage(`{"tickets":0,"drawCount":0,"ticketPurchaseCount":0,"itemSequence":0,"items":[]}`),
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	service := economy.NewService(fixture.pool)
	_, err = service.Bootstrap(ctx, accountID, fixture.sessionID, economy.BootstrapRequest{
		IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90bea", RawBody: []byte(`{"bootstrap":true}`),
		WriterGeneration: fixture.writerGeneration, ExpectedSaveRevision: 1,
	})
	if err != nil {
		t.Fatal(err)
	}
	_, err = fixture.Update(ctx, accountID, gamesave.UpdateRequest{
		IdempotencyKey: secondSaveKey, ExpectedRevision: 1,
		ClientCompatibilityVersion: gamesave.CurrentClientCompatibilityVersion,
		RawBody:                    []byte(`{"expectedRevision":1,"clientCompatibilityVersion":4}`),
		Data: gamesave.Data{
			Version: gamesave.CurrentSchemaVersion, Preferences: json.RawMessage(`{}`),
			Progression:   json.RawMessage(`{"bestRoundsByStage":{"11":40},"clearedStageNumbers":[11]}`),
			TurretModules: json.RawMessage(`{"tickets":0,"drawCount":0,"ticketPurchaseCount":0,"itemSequence":0,"items":[]}`),
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	request := economy.RunSettlementRequest{
		IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90bf3", RunID: settlementRunID,
		RawBody: []byte(`{"runId":"` + settlementRunID + `"}`), WriterGeneration: fixture.writerGeneration,
		SourceSaveRevision: 2, StageNumber: 11, CompletedRounds: 40, Success: true,
		PendingDiamonds: 5, FirstClearModuleTickets: economy.StageElevenModuleTicketGift,
	}
	return ctx, fixture, accountID, service, request
}

func assertSingleRunSettlement(t *testing.T, ctx context.Context, fixture *claimedSaveService) {
	t.Helper()
	var revision, diamonds, tickets, claims, commands, ledger int64
	err := fixture.pool.QueryRow(ctx, `SELECT revision,free_diamonds,module_tickets,
 (SELECT count(*) FROM economy_reward_claims WHERE account_id=$1),
 (SELECT count(*) FROM economy_commands WHERE account_id=$1 AND command_type='run_settlement'),
 (SELECT count(*) FROM economy_ledger_entries l JOIN economy_commands c ON c.id=l.command_id WHERE c.account_id=$1 AND c.command_type='run_settlement')
 FROM player_economies WHERE account_id=$1`, fixture.accountUUID).Scan(&revision, &diamonds, &tickets, &claims, &commands, &ledger)
	if err != nil {
		t.Fatal(err)
	}
	if revision != 2 || diamonds != 5 || tickets != economy.StageElevenModuleTicketGift || claims != 2 || commands != 1 || ledger != 2 {
		t.Fatalf("duplicate settlement: revision=%d diamonds=%d tickets=%d claims=%d commands=%d ledger=%d", revision, diamonds, tickets, claims, commands, ledger)
	}
}

func TestRunSettlementCanonicalUUIDAndExactReplay(t *testing.T) {
	for _, firstRunID := range []string{settlementRunID, strings.ToUpper(settlementRunID), "0198B955-3656-7c40-b3Cb-87F427b90bF2"} {
		t.Run(firstRunID, func(t *testing.T) {
			ctx, fixture, accountID, service, request := openRunSettlement(t)
			request.RunID = firstRunID
			request.RawBody = []byte(`{"runId":"` + firstRunID + `"}`)
			first, err := service.SettleRun(ctx, accountID, fixture.sessionID, request)
			if err != nil {
				t.Fatal(err)
			}
			canonicalKey := "run:" + settlementRunID + ":settlement"
			if first.RewardKey != canonicalKey {
				t.Fatalf("reward key = %q, want %q", first.RewardKey, canonicalKey)
			}
			var evidenceRunID string
			if err := fixture.pool.QueryRow(ctx, `SELECT evidence->>'runId' FROM economy_reward_claims WHERE account_id=$1 AND reward_key=$2`, accountID, canonicalKey).Scan(&evidenceRunID); err != nil || evidenceRunID != settlementRunID {
				t.Fatalf("evidence run ID = %q, err=%v", evidenceRunID, err)
			}
			exact, err := service.SettleRun(ctx, accountID, fixture.sessionID, request)
			if err != nil || !reflect.DeepEqual(exact, first) {
				t.Fatalf("exact replay = %+v, err=%v", exact, err)
			}
			changedBody := request
			changedBody.RawBody = append([]byte(" "), request.RawBody...)
			if _, err := service.SettleRun(ctx, accountID, fixture.sessionID, changedBody); !errors.Is(err, economy.ErrIdempotencyKeyReused) {
				t.Fatalf("changed raw body replay error = %v", err)
			}
			for i, runID := range []string{strings.ToUpper(settlementRunID), settlementRunID, "0198B955-3656-7c40-b3Cb-87F427b90bF2"} {
				request.IdempotencyKey = fmt.Sprintf("0198b955-3656-7c40-b3cb-87f427b90b%02x", i+244)
				request.RunID = runID
				request.RawBody = []byte(`{"runId":"` + runID + `"}`)
				// 성공 영수증은 현재 writer/save 상태와 무관하게 복구된다.
				request.WriterGeneration++
				replay, err := service.SettleRun(ctx, accountID, fixture.sessionID, request)
				if err != nil || !reflect.DeepEqual(replay, first) {
					t.Fatalf("case replay = %+v, err=%v", replay, err)
				}
			}
			assertSingleRunSettlement(t, ctx, fixture)
			// 다른 UUID의 런은 다이아를 받지만 최초 클리어 모듈권은 다시 받지 않는다.
			request.RunID = "0198b955-3656-7c40-b3cb-87f427b90bf7"
			request.IdempotencyKey = "0198b955-3656-7c40-b3cb-87f427b90bf8"
			request.RawBody = []byte(`{"runId":"` + request.RunID + `"}`)
			request.WriterGeneration = fixture.writerGeneration
			next, err := service.SettleRun(ctx, accountID, fixture.sessionID, request)
			if err != nil || next.GrantedDiamonds != 5 || next.GrantedModuleTickets != 0 || next.Snapshot.Wallet.FreeDiamonds != 10 || next.Snapshot.Wallet.ModuleTickets != economy.StageElevenModuleTicketGift {
				t.Fatalf("different run = %+v, err=%v", next, err)
			}
		})
	}
}

func TestRunSettlementLegacyMixedCaseReceipt(t *testing.T) {
	ctx, fixture, accountID, service, request := openRunSettlement(t)
	legacyRunID := "0198B955-3656-7c40-b3Cb-87F427b90bF2"
	request.RunID = legacyRunID
	request.RawBody = []byte(`{"runId":"` + legacyRunID + `"}`)
	first, err := service.SettleRun(ctx, accountID, fixture.sessionID, request)
	if err != nil {
		t.Fatal(err)
	}
	legacyKey := "run:" + legacyRunID + ":settlement"
	canonicalKey := first.RewardKey
	first.RewardKey = legacyKey
	for i, key := range first.Snapshot.ClaimedRewardKeys {
		if key == canonicalKey {
			first.Snapshot.ClaimedRewardKeys[i] = legacyKey
		}
	}
	payload, err := json.Marshal(first)
	if err != nil {
		t.Fatal(err)
	}
	// 수정 이전 서버가 저장한 mixed-case claim 및 응답을 신규 테스트 계정에서 재현한다.
	if _, err := fixture.pool.Exec(ctx, `UPDATE economy_reward_claims SET reward_key=$2,evidence=jsonb_set(evidence,'{runId}',to_jsonb($3::text)) WHERE account_id=$1 AND reward_key=$4`, accountID, legacyKey, legacyRunID, canonicalKey); err != nil {
		t.Fatal(err)
	}
	if _, err := fixture.pool.Exec(ctx, `UPDATE economy_commands SET response_payload=$2 WHERE account_id=$1 AND command_type='run_settlement'`, accountID, payload); err != nil {
		t.Fatal(err)
	}
	exact, err := service.SettleRun(ctx, accountID, fixture.sessionID, request)
	if err != nil || !reflect.DeepEqual(exact, first) {
		t.Fatalf("legacy exact replay = %+v, err=%v", exact, err)
	}
	for i, runID := range []string{settlementRunID, strings.ToUpper(settlementRunID), legacyRunID} {
		request.IdempotencyKey = fmt.Sprintf("0198b955-3656-7c40-b3cb-87f427b90b%02x", i+244)
		request.RunID = runID
		request.RawBody = []byte(`{"runId":"` + runID + `"}`)
		replay, err := service.SettleRun(ctx, accountID, fixture.sessionID, request)
		if err != nil || !reflect.DeepEqual(replay, first) {
			t.Fatalf("legacy receipt replay = %+v, err=%v", replay, err)
		}
	}
	assertSingleRunSettlement(t, ctx, fixture)
	var storedKey string
	if err := fixture.pool.QueryRow(ctx, `SELECT reward_key FROM economy_reward_claims WHERE account_id=$1 AND reward_key LIKE 'run:%'`, accountID).Scan(&storedKey); err != nil || storedKey != legacyKey {
		t.Fatalf("legacy claim changed = %q, err=%v", storedKey, err)
	}
}

func TestRunSettlementConcurrentUUIDCaseVariants(t *testing.T) {
	ctx, fixture, accountID, service, request := openRunSettlement(t)
	var wg sync.WaitGroup
	errors := make(chan error, 3)
	for i, runID := range []string{settlementRunID, strings.ToUpper(settlementRunID), "0198B955-3656-7c40-b3Cb-87F427b90bF2"} {
		variant := request
		variant.IdempotencyKey = fmt.Sprintf("0198b955-3656-7c40-b3cb-87f427b90b%02x", i+244)
		variant.RunID = runID
		variant.RawBody = []byte(`{"runId":"` + runID + `"}`)
		wg.Add(1)
		go func() {
			defer wg.Done()
			result, err := service.SettleRun(ctx, accountID, fixture.sessionID, variant)
			if err == nil && (result.RewardKey != "run:"+settlementRunID+":settlement" || result.Snapshot.EconomyRevision != 2) {
				err = fmt.Errorf("concurrent settlement result = %+v", result)
			}
			errors <- err
		}()
	}
	wg.Wait()
	close(errors)
	for err := range errors {
		if err != nil {
			t.Fatal(err)
		}
	}
	assertSingleRunSettlement(t, ctx, fixture)
}
