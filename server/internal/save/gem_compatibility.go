package save

import "encoding/json"

const PiercingClientCompatibilityVersion = 11

// ValidateGemContentClient protects issued decks, offers and checkpoint ownership
// when an older client returns to a run started by a newer client.
// Older codecs drop gems they do not know, so each gem names the first generation that keeps it.
var gemClientCompatibilityVersions = map[string]int{
	"piercing":     PiercingClientCompatibilityVersion,
	"poisonDamage": PoisonTurretClientCompatibilityVersion,
}

func ValidateGemContentClient(raw []byte, clientVersion int) error {
	if clientVersion >= PoisonTurretClientCompatibilityVersion {
		return nil
	}
	var value any
	if json.Unmarshal(raw, &value) == nil && containsGemNewerThan(value, clientVersion) {
		return ErrClientUpdateRequired
	}
	return nil
}

func requiresNewerClient(gem string, clientVersion int) bool {
	required, known := gemClientCompatibilityVersions[gem]
	return known && clientVersion < required
}

func containsGemNewerThan(value any, clientVersion int) bool {
	switch value := value.(type) {
	case string:
		return requiresNewerClient(value, clientVersion)
	case []any:
		for _, item := range value {
			if containsGemNewerThan(item, clientVersion) {
				return true
			}
		}
	case map[string]any:
		for key, item := range value {
			if requiresNewerClient(key, clientVersion) || containsGemNewerThan(item, clientVersion) {
				return true
			}
		}
	}
	return false
}
