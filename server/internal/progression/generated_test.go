package progression

import (
	"encoding/json"
	"os"
	"reflect"
	"testing"
)

func TestGeneratedRegistryMatchesAuthoringSource(t *testing.T) {
	payload, err := os.ReadFile("../../../godot/content/source/progression.json")
	if err != nil {
		t.Fatal(err)
	}
	var source struct {
		Version            int                       `json:"version"`
		LegacyStageCount   int                       `json:"legacyStageCount"`
		Order              []int32                   `json:"order"`
		Stages             []json.RawMessage         `json:"stages"`
		Requirements       map[string]map[string]int `json:"requirements"`
		LegacyRequirements map[string]map[string]int `json:"legacyRequirements"`
	}
	if err := json.Unmarshal(payload, &source); err != nil {
		t.Fatal(err)
	}
	if Version != source.Version || StageCount != len(source.Stages) || LegacyStageCount != source.LegacyStageCount {
		t.Fatal("stale generated progression versions/counts")
	}
	if !reflect.DeepEqual(OrderedIDs(), source.Order) {
		t.Fatal("stale generated stage order")
	}
	if !reflect.DeepEqual(requirements, source.Requirements) || !reflect.DeepEqual(legacyRequirements, source.LegacyRequirements) {
		t.Fatal("stale generated unlock requirements")
	}
}

func TestOrderedIDsReturnsIndependentCopy(t *testing.T) {
	first := OrderedIDs()[0]
	order := OrderedIDs()
	order[0] = -1
	if OrderedIDs()[0] != first {
		t.Fatal("consumer can mutate progression order")
	}
}
