package economy

import "github.com/Sejiiinn/RuneNexus/server/internal/dbgen"

// NextWalletUpdate returns the update that advances wallet by one revision and
// keeps every column as loaded. Callers overwrite only the columns they change,
// so a new wallet column cannot silently reset to zero at a call site.
func NextWalletUpdate(wallet dbgen.PlayerEconomy) dbgen.UpdatePlayerEconomyParams {
	return dbgen.UpdatePlayerEconomyParams{
		AccountID:                 wallet.AccountID,
		Revision:                  wallet.Revision + 1,
		FreeDiamonds:              wallet.FreeDiamonds,
		PaidDiamonds:              wallet.PaidDiamonds,
		ModuleTickets:             wallet.ModuleTickets,
		ModuleDrawCount:           wallet.ModuleDrawCount,
		ModuleTicketPurchaseCount: wallet.ModuleTicketPurchaseCount,
		ModuleItemSequence:        wallet.ModuleItemSequence,
		ResearchSlotTwoUnlocked:   wallet.ResearchSlotTwoUnlocked,
		Revision_2:                wallet.Revision,
	}
}
