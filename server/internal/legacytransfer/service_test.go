package legacytransfer

import (
	"encoding/json"
	"errors"
	"testing"

	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

func TestValidateImportedDataAcceptsBoundedLegacySave(t *testing.T) {
	data := validImportedData(t)
	if err := validateImportedData(data); err != nil {
		t.Fatalf("validate imported data: %v", err)
	}
}

func TestValidateImportedDataRejectsPaidDiamonds(t *testing.T) {
	data := validImportedData(t)
	data.Progression = json.RawMessage(`{"runes":10,"freeDiamonds":20,"paidDiamonds":1}`)
	if err := validateImportedData(data); !errors.Is(err, ErrUnsupportedPaidFunds) {
		t.Fatalf("error = %v", err)
	}
}

func TestValidateImportedDataRejectsUnboundedLegacyFunds(t *testing.T) {
	data := validImportedData(t)
	data.Progression = json.RawMessage(`{"runes":10,"freeDiamonds":1000001,"paidDiamonds":0}`)
	if err := validateImportedData(data); !errors.Is(err, ErrInvalidData) {
		t.Fatalf("error = %v", err)
	}
}

func validImportedData(t *testing.T) gamesave.Data {
	t.Helper()
	return gamesave.Data{
		Version:       gamesave.CurrentSchemaVersion,
		SavedAtMillis: 1,
		Preferences:   json.RawMessage(`{}`),
		Progression:   json.RawMessage(`{"runes":10,"freeDiamonds":20,"paidDiamonds":0}`),
		TurretModules: json.RawMessage(`{"tickets":1,"items":[]}`),
	}
}
