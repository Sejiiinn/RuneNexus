package economy

import "github.com/Sejiiinn/RuneNexus/server/internal/dbgen"

// New gem/run receipts contain only a bounded immutable outcome. Recovering a
// receipt never queries modules, progression effects or lifetime reward keys.
func newGemReceipt(wallet dbgen.PlayerEconomy, system dbgen.EconomySystemState) *GemCommandReceipt {
	return &GemCommandReceipt{Version: 1, EconomyRevision: wallet.Revision,
		AuthorityEpoch: formatUUID(system.AuthorityEpoch), GemResetTickets: wallet.GemResetTickets}
}
