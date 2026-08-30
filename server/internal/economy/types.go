package economy

import (
	"errors"
	"fmt"
	"time"
)

var (
	ErrInvalidIdempotencyKey = errors.New("economy idempotency key is invalid")
	ErrIdempotencyKeyReused  = errors.New("economy idempotency key was reused")
	ErrNotBootstrapped       = errors.New("economy is not bootstrapped")
	ErrAlreadyBootstrapped   = errors.New("economy is already bootstrapped")
	ErrRevisionConflict      = errors.New("economy revision conflict")
	ErrCatalogChanged        = errors.New("economy catalog changed")
	ErrWriterRequired        = errors.New("economy requires the active save writer")
	ErrWriterReplaced        = errors.New("economy save writer was replaced")
	ErrSaveRevisionConflict  = errors.New("economy source save revision conflict")
	ErrInsufficientDiamonds  = errors.New("insufficient diamonds")
	ErrInsufficientTickets   = errors.New("insufficient module tickets")
	ErrModuleNotOwned        = errors.New("module is not owned")
	ErrModuleNotAllowed      = errors.New("module cannot be disassembled")
	ErrInvalidCommand        = errors.New("economy command is invalid")
	ErrProgressionEffect     = errors.New("progression effect cannot be acknowledged")
)

type Wallet struct {
	FreeDiamonds  int64 `json:"freeDiamonds"`
	PaidDiamonds  int64 `json:"paidDiamonds"`
	ModuleTickets int64 `json:"moduleTickets"`
}

type Module struct {
	ID            string         `json:"id"`
	LegacyItemID  string         `json:"legacyItemId,omitempty"`
	TurretType    string         `json:"turretType"`
	Part          string         `json:"part"`
	Family        string         `json:"family"`
	Grade         string         `json:"grade"`
	Options       []moduleOption `json:"options"`
	AcquiredOrder int64          `json:"acquiredOrder"`
}

type ProgressionEffect struct {
	ID         string         `json:"id"`
	EffectType string         `json:"effectType"`
	Payload    map[string]any `json:"payload"`
}

type Snapshot struct {
	AuthorityEpoch   string    `json:"authorityEpoch"`
	AuthorityState   string    `json:"authorityState"`
	AuthorityVersion int32     `json:"authorityVersion"`
	EconomyRevision  int64     `json:"economyRevision"`
	CatalogVersion   int32     `json:"catalogVersion"`
	ServerTime       time.Time `json:"serverTime"`
	Wallet           Wallet    `json:"wallet"`
	TurretModules    struct {
		DrawCount           int64    `json:"drawCount"`
		TicketPurchaseCount int64    `json:"ticketPurchaseCount"`
		Items               []Module `json:"items"`
	} `json:"turretModules"`
	Entitlements struct {
		ResearchSlotTwoUnlocked bool `json:"researchSlotTwoUnlocked"`
	} `json:"entitlements"`
	PendingProgressionEffects []ProgressionEffect `json:"pendingProgressionEffects"`
	ClaimedRewardKeys         []string            `json:"claimedRewardKeys"`
}

type BootstrapRequest struct {
	IdempotencyKey       string
	RawBody              []byte
	WriterGeneration     int64
	ExpectedSaveRevision int64
}

type BootstrapResult struct {
	Snapshot              Snapshot          `json:"economy"`
	ImportedLegacyIDMap   map[string]string `json:"importedLegacyIdMap"`
	RejectedModules       []RejectedModule  `json:"rejectedModules"`
	ClearedEquippedIDs    []string          `json:"clearedEquippedIds"`
	BootstrapSaveRevision int64             `json:"bootstrapSaveRevision"`
}

type RejectedModule struct {
	LegacyItemID string `json:"legacyItemId"`
	Reason       string `json:"reason"`
}

type CommandResult struct {
	Snapshot             Snapshot           `json:"economy"`
	DrawnModules         []Module           `json:"drawnModules,omitempty"`
	ProgressionEffect    *ProgressionEffect `json:"progressionEffect,omitempty"`
	RewardKey            string             `json:"rewardKey,omitempty"`
	GrantedDiamonds      int64              `json:"grantedDiamonds,omitempty"`
	GrantedModuleTickets int64              `json:"grantedModuleTickets,omitempty"`
}

type DrawRequest struct {
	IdempotencyKey                string
	RawBody                       []byte
	ExpectedRevision              int64
	ExpectedCatalogVersion        int32
	SourceSaveRevision            int64
	WriterGeneration              int64
	Count                         int
	TurretType                    string
	BuyMissingTicketsWithDiamonds bool
}

type DisassembleRequest struct {
	IdempotencyKey         string
	RawBody                []byte
	ExpectedRevision       int64
	ExpectedCatalogVersion int32
	ModuleIDs              []string
}

type ResearchCompleteRequest struct {
	IdempotencyKey         string
	RawBody                []byte
	ExpectedRevision       int64
	ExpectedCatalogVersion int32
	WriterGeneration       int64
	SourceSaveRevision     int64
	ResearchType           string
}

type ResearchSlotUnlockRequest struct {
	IdempotencyKey         string
	RawBody                []byte
	ExpectedRevision       int64
	ExpectedCatalogVersion int32
	WriterGeneration       int64
	SourceSaveRevision     int64
}

type EffectAckRequest struct {
	IdempotencyKey      string
	RawBody             []byte
	EffectID            string
	AppliedSaveRevision int64
	WriterGeneration    int64
}

type RunSettlementRequest struct {
	IdempotencyKey          string
	RawBody                 []byte
	RunID                   string
	WriterGeneration        int64
	SourceSaveRevision      int64
	StageNumber             int
	CompletedRounds         int
	Success                 bool
	PendingDiamonds         int64
	FirstClearModuleTickets int64
}

type ConflictError struct {
	CurrentRevision int64
}

func (err *ConflictError) Error() string {
	return fmt.Sprintf("economy revision conflict: current revision is %d", err.CurrentRevision)
}
