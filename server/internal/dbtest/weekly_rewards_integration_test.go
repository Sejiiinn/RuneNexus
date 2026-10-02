//go:build integration

package dbtest_test

import (
	"encoding/json"
	"errors"
	"testing"
	"time"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
	"github.com/Sejiiinn/RuneNexus/server/internal/weeklyreward"
)

func TestAllCompleteRewardCountsAttendanceAndKeepsAtomicReceipts(t *testing.T) {
	adjustedNow := time.Now().UTC().Add(4 * time.Hour)
	dayKey := adjustedNow.UnixMilli() / int64((24*time.Hour)/time.Millisecond)
	weekKey := (dayKey + 3) / 7
	firstDay := weekKey*7 - 3
	attendanceDays := []int64{firstDay, firstDay + 1, firstDay + 2, firstDay + 3, firstDay + 4}
	for _, test := range []struct {
		name      string
		period    string
		quests    int
		days      []int64
		stale     bool
		claimed   bool
		rollback  bool
		wantError error
	}{
		{name: "daily attendance and three goals", period: "daily", quests: 3},
		{name: "daily attendance and two goals", period: "daily", quests: 2, wantError: weeklyreward.ErrNotEligible},
		{name: "daily stale attendance", period: "daily", quests: 3, stale: true, wantError: weeklyreward.ErrPeriodMismatch},
		{name: "daily already claimed", period: "daily", quests: 3, claimed: true, wantError: weeklyreward.ErrNotEligible},
		{name: "daily clock rollback", period: "daily", quests: 3, rollback: true, wantError: weeklyreward.ErrNotEligible},
		{name: "weekly attendance and three goals", period: "weekly", quests: 3, days: attendanceDays},
		{name: "weekly attendance and two goals", period: "weekly", quests: 2, days: attendanceDays, wantError: weeklyreward.ErrNotEligible},
		{name: "weekly four goals without attendance", period: "weekly", quests: 4},
		{name: "weekly duplicate attendance", period: "weekly", quests: 3, days: []int64{firstDay, firstDay + 1, firstDay + 2, firstDay + 3, firstDay + 3}, wantError: weeklyreward.ErrNotEligible},
		{name: "weekly previous week attendance", period: "weekly", quests: 3, days: []int64{firstDay - 1, firstDay, firstDay + 1, firstDay + 2, firstDay + 3}, wantError: weeklyreward.ErrNotEligible},
		{name: "weekly stale period", period: "weekly", quests: 3, days: attendanceDays, stale: true, wantError: weeklyreward.ErrPeriodMismatch},
		{name: "weekly already claimed", period: "weekly", quests: 3, days: attendanceDays, claimed: true, wantError: weeklyreward.ErrNotEligible},
		{name: "weekly clock rollback", period: "weekly", quests: 3, days: attendanceDays, rollback: true, wantError: weeklyreward.ErrNotEligible},
	} {
		t.Run(test.name, func(t *testing.T) {
			ctx, fixture, accountID := openSaveService(t)
			questTypes := []string{"clearWaves", "killBosses", "killEnemies", "buyRunUpgrades"}
			targets := []int{150, 15, 500, 25}
			if test.period == "daily" {
				targets = []int{30, 3, 100, 5}
			}
			progress := map[string]int{}
			for index := 0; index < test.quests; index++ {
				progress[questTypes[index]] = targets[index]
			}
			progression := map[string]any{
				"freeDiamonds": 0, "paidDiamonds": 0,
				"dailyQuestDayKey": dayKey, "weeklyQuestWeekKey": weekKey,
				"dailyQuestProgress": progress, "weeklyQuestProgress": progress,
				"weeklyAttendanceDayKeys":         test.days,
				"dailyQuestClockRollbackDetected": test.rollback,
			}
			if test.stale {
				progression["dailyQuestDayKey"] = dayKey - 1
				progression["weeklyQuestWeekKey"] = weekKey - 1
			}
			payload, err := json.Marshal(progression)
			if err != nil {
				t.Fatal(err)
			}
			if _, err := fixture.Update(ctx, accountID, gamesave.UpdateRequest{
				IdempotencyKey: firstSaveKey, ExpectedRevision: 0, RawBody: []byte(`{"expectedRevision":0}`),
				Data: gamesave.Data{
					Version: gamesave.CurrentSchemaVersion, Preferences: json.RawMessage(`{}`), Progression: payload,
					TurretModules: json.RawMessage(`{"tickets":0,"drawCount":0,"ticketPurchaseCount":0,"itemSequence":0,"items":[]}`),
				},
			}); err != nil {
				t.Fatalf("save reward evidence: %v", err)
			}
			if _, err := economy.NewService(fixture.pool).Bootstrap(ctx, accountID, fixture.sessionID, economy.BootstrapRequest{
				IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90bea", RawBody: []byte(`{"bootstrap":true}`),
				WriterGeneration: fixture.writerGeneration, ExpectedSaveRevision: 1,
			}); err != nil {
				t.Fatalf("bootstrap reward economy: %v", err)
			}
			if test.claimed {
				// Save-level claimed flags must still reject, independently of authoritative receipts.
				flag := "dailyQuestAllCompleteClaimed"
				if test.period == "weekly" {
					flag = "weeklyQuestAllCompleteClaimed"
				}
				if _, err := fixture.pool.Exec(ctx, `UPDATE save_progression SET payload=jsonb_set(payload,ARRAY[$2::text],'true'::jsonb) WHERE account_id=$1`, accountID, flag); err != nil {
					t.Fatalf("set existing save claim flag: %v", err)
				}
			}
			service := weeklyreward.NewService(fixture.pool)
			request := weeklyreward.ClaimRequest{
				IdempotencyKey: "0198b955-3656-7c40-b3cb-87f427b90beb",
				RawBody:        []byte(`{"period":"` + test.period + `","rewardType":"all_complete","clientCompatibilityVersion":4}`),
				Period:         test.period, RewardType: weeklyreward.RewardTypeAllComplete,
			}
			claimed, err := service.Claim(ctx, accountID, fixture.sessionID, request)
			var wantRevision, wantDiamonds, wantTickets, wantClaims, wantCommands, wantLedger int64 = 1, 0, 0, 0, 0, 0
			if test.wantError != nil {
				if !errors.Is(err, test.wantError) {
					t.Fatalf("reward claim error = %v, want %v", err, test.wantError)
				}
			} else {
				wantRevision, wantDiamonds, wantTickets, wantClaims, wantCommands, wantLedger = 2, 100, 4, 1, 1, 2
				if test.period == "daily" {
					wantDiamonds, wantTickets = 40, 1
				}
				if err != nil || int64(claimed.Diamonds) != wantDiamonds || int64(claimed.ModuleTickets) != wantTickets || claimed.EconomyRevision != wantRevision || claimed.SourceSaveRevision != 1 {
					t.Fatalf("reward claim = %+v, err=%v", claimed, err)
				}
				replayed, err := service.Claim(ctx, accountID, fixture.sessionID, request)
				if err != nil || replayed != claimed {
					t.Fatalf("exact replay = %+v, err=%v", replayed, err)
				}
				changedBody := request
				changedBody.RawBody = append([]byte(" "), request.RawBody...)
				if _, err := service.Claim(ctx, accountID, fixture.sessionID, changedBody); !errors.Is(err, weeklyreward.ErrIdempotencyKeyReused) {
					t.Fatalf("changed-body replay error = %v", err)
				}
				request.IdempotencyKey = "0198b955-3656-7c40-b3cb-87f427b90bec"
				_, err = service.Claim(ctx, accountID, fixture.sessionID, request)
				var alreadyClaimed *weeklyreward.AlreadyClaimedError
				if !errors.As(err, &alreadyClaimed) || alreadyClaimed.Result != claimed {
					t.Fatalf("duplicate claim error = %v", err)
				}
			}
			var revision, diamonds, tickets, claims, commands, ledger int64
			if err := fixture.pool.QueryRow(ctx, `SELECT revision,free_diamonds,module_tickets,
 (SELECT count(*) FROM economy_reward_claims WHERE account_id=$1),
 (SELECT count(*) FROM economy_commands WHERE account_id=$1 AND command_type='reward_claim'),
 (SELECT count(*) FROM economy_ledger_entries l JOIN economy_commands c ON c.id=l.command_id WHERE c.account_id=$1 AND c.command_type='reward_claim')
 FROM player_economies WHERE account_id=$1`, accountID).Scan(&revision, &diamonds, &tickets, &claims, &commands, &ledger); err != nil {
				t.Fatal(err)
			}
			if revision != wantRevision || diamonds != wantDiamonds || tickets != wantTickets || claims != wantClaims || commands != wantCommands || ledger != wantLedger {
				t.Fatalf("wallet/receipts = %d/%d/%d/%d/%d/%d, want %d/%d/%d/%d/%d/%d", revision, diamonds, tickets, claims, commands, ledger, wantRevision, wantDiamonds, wantTickets, wantClaims, wantCommands, wantLedger)
			}
		})
	}
}
