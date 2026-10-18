package save

import "encoding/json"

const PiercingClientCompatibilityVersion = 11

// ValidateGemContentClient protects issued decks, offers and checkpoint ownership
// when an older client returns to a run started by a newer client.
func ValidateGemContentClient(raw []byte, clientVersion int) error {
	if clientVersion >= PiercingClientCompatibilityVersion {
		return nil
	}
	var value any
	if json.Unmarshal(raw, &value) == nil && containsPiercing(value) {
		return ErrClientUpdateRequired
	}
	return nil
}

func containsPiercing(value any) bool {
	switch value := value.(type) {
	case string:
		return value == "piercing"
	case []any:
		for _, item := range value {
			if containsPiercing(item) {
				return true
			}
		}
	case map[string]any:
		for key, item := range value {
			if key == "piercing" || containsPiercing(item) {
				return true
			}
		}
	}
	return false
}
