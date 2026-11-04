package runlog

import (
	"errors"
	"testing"
)

func TestParseKeepsBodyAndChecksTableFields(t *testing.T) {
	body := []byte(`{"schemaVersion":1,"runId":"0190f5d2-6c3a-7b3e-9a5d-2f1e0c9b8a71","clientBuild":6062,"stageId":23,"turrets":[{"type":"machinegun","x":3,"y":4,"gems":["physicalDamage"]}],"extra":true}`)
	entry, err := Parse(body)
	if err != nil {
		t.Fatal(err)
	}
	if entry.StageID != 23 || entry.ClientBuild != 6062 || !entry.RunID.Valid || string(entry.Payload) != string(body) {
		t.Fatalf("entry = %+v", entry)
	}
}

func TestParseRejectsInvalidShapes(t *testing.T) {
	valid := `"runId":"0190f5d2-6c3a-7b3e-9a5d-2f1e0c9b8a71","clientBuild":1,"stageId":1`
	for name, body := range map[string]string{
		"not object":     `[]`,
		"null":           `null`,
		"trailing value": `{"schemaVersion":1,` + valid + `} {}`,
		"bad json":       `{"schemaVersion":1,`,
		"wrong schema":   `{"schemaVersion":2,` + valid + `}`,
		"missing schema": `{` + valid + `}`,
		"stage zero":     `{"schemaVersion":1,"runId":"0190f5d2-6c3a-7b3e-9a5d-2f1e0c9b8a71","clientBuild":1,"stageId":0}`,
		"stage string":   `{"schemaVersion":1,"runId":"0190f5d2-6c3a-7b3e-9a5d-2f1e0c9b8a71","clientBuild":1,"stageId":"23"}`,
		"stage fraction": `{"schemaVersion":1,"runId":"0190f5d2-6c3a-7b3e-9a5d-2f1e0c9b8a71","clientBuild":1,"stageId":2.5}`,
		"negative build": `{"schemaVersion":1,"runId":"0190f5d2-6c3a-7b3e-9a5d-2f1e0c9b8a71","clientBuild":-1,"stageId":1}`,
		"bad run id":     `{"schemaVersion":1,"runId":"not-a-uuid","clientBuild":1,"stageId":1}`,
		"compact run id": `{"schemaVersion":1,"runId":"0190f5d26c3a7b3e9a5d2f1e0c9b8a71","clientBuild":1,"stageId":1}`,
	} {
		t.Run(name, func(t *testing.T) {
			if _, err := Parse([]byte(body)); !errors.Is(err, ErrInvalid) {
				t.Fatalf("err = %v", err)
			}
		})
	}
}
