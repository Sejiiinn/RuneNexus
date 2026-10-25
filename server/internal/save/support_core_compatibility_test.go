package save

import (
	"errors"
	"testing"
)

func TestSupportCoreRequiresCurrentClient(t *testing.T) {
	for _, tc := range []struct {
		name   string
		run    string
		client int
		reject bool
	}{
		{"core old client", `{"supportCores":[{"x":1,"y":2,"family":"damage","consumedGem":"range","investedGold":150}]}`, 13, true},
		{"consumed gem old client", `{"supportCores":[],"gemDeckLog":[{"kind":"wave","wave":5,"rerolls":0,"choice":"range"},{"kind":"consume","choice":"range"}]}`, 13, true},
		{"core current client", `{"supportCores":[{"x":1,"y":2,"family":"damage","consumedGem":"range","investedGold":150}],"gemDeckLog":[{"kind":"consume","choice":"range"}]}`, 14, false},
		{"no core old client", `{"supportCores":[],"gemDeckLog":[{"kind":"wave","wave":5,"rerolls":0,"choice":"range"}]}`, 13, false},
		{"no run", `null`, 13, false},
	} {
		if err := ValidateContentClient([]byte(`{}`), []byte(tc.run), tc.client); errors.Is(err, ErrClientUpdateRequired) != tc.reject {
			t.Fatalf("%s: reject=%v err=%v", tc.name, tc.reject, err)
		}
	}
	if CurrentClientCompatibilityVersion != SupportCoreClientCompatibilityVersion {
		t.Fatalf("current client generation %d", CurrentClientCompatibilityVersion)
	}
}
