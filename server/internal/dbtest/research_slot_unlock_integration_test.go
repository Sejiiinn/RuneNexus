//go:build integration

package dbtest_test

import (
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/economy"
)

func TestResearchSlotTwoUnlockSpendsDiamondsAndKeepsOtherBalances(t *testing.T) {
	ctx, fixture, accountID, service := openChallengeClaim(t, `{"clearedStageNumbers":[10,25]}`)
	if _, err := fixture.pool.Exec(ctx, `UPDATE player_economies
		SET free_diamonds = 400, paid_diamonds = 300, module_tickets = 7, module_draw_count = 11,
		    module_ticket_purchase_count = 13, module_item_sequence = 17, gem_reset_tickets = 19
		WHERE account_id = $1`, accountID); err != nil {
		t.Fatal(err)
	}
	before, err := service.Get(ctx, accountID)
	if err != nil {
		t.Fatal(err)
	}

	result, err := service.UnlockResearchSlotTwo(ctx, accountID, fixture.sessionID, economy.ResearchSlotUnlockRequest{
		IdempotencyKey:   "0198b955-3656-7c40-b3cb-87f427b90c11",
		RawBody:          []byte(`{"expectedEconomyRevision":` + itoa(int(before.EconomyRevision)) + `,"clientCompatibilityVersion":16}`),
		ExpectedRevision: before.EconomyRevision, ExpectedCatalogVersion: economy.CatalogVersion,
		WriterGeneration: fixture.writerGeneration, SourceSaveRevision: 2,
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.Snapshot.EconomyRevision != before.EconomyRevision+1 {
		t.Fatalf("revision = %d, want %d", result.Snapshot.EconomyRevision, before.EconomyRevision+1)
	}

	var free, paid, tickets, draws, purchases, sequence, gemTickets int64
	var unlocked bool
	if err := fixture.pool.QueryRow(ctx, `SELECT free_diamonds, paid_diamonds, module_tickets, module_draw_count,
		module_ticket_purchase_count, module_item_sequence, gem_reset_tickets, research_slot_two_unlocked
		FROM player_economies WHERE account_id = $1`, accountID).Scan(&free, &paid, &tickets, &draws, &purchases, &sequence, &gemTickets, &unlocked); err != nil {
		t.Fatal(err)
	}
	// The 600 diamond cost spends all 400 free diamonds before 200 paid ones.
	if free != 0 || paid != 100 || !unlocked {
		t.Fatalf("free=%d paid=%d unlocked=%t", free, paid, unlocked)
	}
	if tickets != 7 || draws != 11 || purchases != 13 || sequence != 17 || gemTickets != 19 {
		t.Fatalf("tickets=%d draws=%d purchases=%d sequence=%d gemTickets=%d", tickets, draws, purchases, sequence, gemTickets)
	}
}
