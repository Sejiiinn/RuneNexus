package save

import "encoding/json"

// Growth progression is stored in schema v2. Version 1 requires generation 3
// clients; generation 2 remains usable until this account first migrates.
const (
	EconomyClientCompatibilityVersion = 2
	GrowthClientCompatibilityVersion  = 3
	CurrentGrowthVersion              = 1
)

func GrowthVersion(progression []byte) int {
	var value struct {
		GrowthVersion int `json:"growthVersion"`
	}
	if json.Unmarshal(progression, &value) != nil {
		return 0
	}
	return value.GrowthVersion
}

func ClientCompatibilityFromBody(raw []byte) int {
	var value struct {
		Version int `json:"clientCompatibilityVersion"`
	}
	if json.Unmarshal(raw, &value) != nil {
		return 0
	}
	return value.Version
}

func ValidateGrowthClient(progression []byte, clientVersion int) error {
	if GrowthVersion(progression) >= CurrentGrowthVersion && clientVersion < GrowthClientCompatibilityVersion {
		return ErrClientUpdateRequired
	}
	return nil
}

// Even a current client must not overwrite an upgraded save with an old outbox.
func ValidateGrowthUpdate(current, incoming []byte, clientVersion int) error {
	if err := ValidateGrowthClient(current, clientVersion); err != nil {
		return err
	}
	if err := ValidateGrowthClient(incoming, clientVersion); err != nil {
		return err
	}
	if GrowthVersion(incoming) < GrowthVersion(current) || GrowthVersion(incoming) > CurrentGrowthVersion {
		return ErrClientUpdateRequired
	}
	return nil
}
