package save

import (
	"bytes"
	"encoding/json"
	"errors"
	"testing"

	"github.com/Sejiiinn/RuneNexus/server/internal/coretree"
)

func TestCoreTreeContentCompatibility(t *testing.T) {
	for _, tc := range []struct { name, progression, run string; upgrade bool }{
		{"missing legacy fields", `{}`, `{"stageNumber":1,"phase":"wave"}`, false},
		{"explicit legacy", `{"corePassiveTreeRevision":4,"corePassiveNodeRanks":{"attackHaste":3}}`, `{"runCorePassiveTreeRevision":4}`, false},
		{"expanded account", `{"corePassiveTreeRevision":5}`, `null`, true},
		{"expanded frozen run", `{}`, `{"runCorePassiveTreeRevision":5}`, true},
		{"unlabeled expanded rank", `{}`, `{"runCorePassiveNodeRanks":{"S1":1}}`, true},
		{"additional pool", `{}`, `{"nexusAdditionalHp":0}`, true},
		{"second chance marker", `{}`, `{"indomitableUsedThisStage":false}`, true},
		{"stockpile", `{}`, `{"turrets":[{"stockpileCharges":0}]}`, true},
		{"first control", `{}`, `{"enemies":[{"firstControlApplied":false}]}`, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if err := ValidateContentClient([]byte(tc.progression), []byte(tc.run), 9); errors.Is(err, ErrClientUpdateRequired) != tc.upgrade { t.Fatalf("generation 9: %v", err) }
			if err := ValidateContentClient([]byte(tc.progression), []byte(tc.run), 10); err != nil { t.Fatalf("generation 10: %v", err) }
		})
	}
}

func coreJSON(t *testing.T, value any) []byte {
	t.Helper()
	raw, err := json.Marshal(value)
	if err != nil { t.Fatal(err) }
	return raw
}

func coreProgress(t *testing.T, revision int, ranks map[string]int, points int, legacy *legacyCoreAllocation) []byte {
	return coreJSON(t, coreProgression{Revision:revision, Ranks:ranks, Points:points, Legacy:legacy})
}

func frozenCoreRun(t *testing.T, revision int, ranks map[string]int, phase string) []byte {
	return coreJSON(t, map[string]any{"economyRunId":"legacy-run", "stageNumber":1, "phase":phase, "runCorePassiveTreeRevision":revision, "runCorePassiveNodeRanks":ranks})
}

func TestCoreTreeMigrationKeepsLegacyRunAndExactRefund(t *testing.T) {
	oldRanks := map[string]int{"attackHaste":3,"attackPrecompute":1}
	old := coreProgress(t, 4, oldRanks, 90, nil)
	archive := &legacyCoreAllocation{Revision:4,Ranks:oldRanks,RefundedPoints:5}
	migrated := coreProgress(t, 5, map[string]int{}, 90, archive)
	active := frozenCoreRun(t, 4, oldRanks, "wave")
	finished := frozenCoreRun(t, 4, oldRanks, "success")
	for _, tc := range []struct { name string; before, after []byte; valid bool }{
		{"suspended legacy run", active, active, false},
		{"finishing legacy run", active, finished, true},
		{"already terminal", finished, finished, true},
		{"core destruction terminal migration", active, frozenCoreRun(t, 4, oldRanks, "coreDestruction"), true},
		{"no active run", nil, nil, true},
		{"cannot silently drop active run", active, nil, false},
	} {
		t.Run(tc.name, func(t *testing.T) { if err := ValidateCoreTreeUpdate(old, tc.before, migrated, tc.after, 10); (err == nil) != tc.valid { t.Fatalf("valid=%v err=%v", tc.valid, err) } })
	}
	if err := ValidateCoreTreeUpdate(old, nil, coreProgress(t,5,map[string]int{},90,nil), nil, 10); !errors.Is(err,ErrCoreTreeConflict) { t.Fatalf("missing archive: %v",err) }
	if err := ValidateCoreTreeUpdate(old,nil,coreProgress(t,5,map[string]int{},89,archive),nil,10); !errors.Is(err,ErrCoreTreeConflict) { t.Fatalf("migration destroyed earned points: %v",err) }
	badArchive := &legacyCoreAllocation{Revision:4,Ranks:oldRanks,RefundedPoints:3}
	if err := ValidateCoreTreeUpdate(old,nil,coreProgress(t,5,map[string]int{},90,badArchive),nil,10); !errors.Is(err,ErrCoreTreeConflict) { t.Fatalf("bad refund: %v",err) }
	// Terminal earnings and the first v5 allocation can share one outbox PUT.
	coalesced := coreProgress(t,5,map[string]int{"S1":3,"A03":1},92,archive)
	if err := ValidateCoreTreeUpdate(old,active,coalesced,finished,10); err != nil { t.Fatalf("coalesced reward/allocation: %v",err) }
	if err := ValidateCoreTreeUpdate(migrated,finished,old,finished,10); !errors.Is(err,ErrClientUpdateRequired) { t.Fatalf("downgrade: %v",err) }
	if err := ValidateCoreTreeUpdate(migrated,finished,migrated,finished,9); !errors.Is(err,ErrClientUpdateRequired) { t.Fatalf("old writer: %v",err) }
	if err := ValidateCoreTreeUpdate(migrated,nil,coreProgress(t,5,map[string]int{},90,nil),nil,10); !errors.Is(err,ErrCoreTreeConflict) { t.Fatalf("archive erased: %v",err) }
}

func TestCoreTreeMigrationAcceptsCoalescedLegacyAllocation(t *testing.T) {
	before := coreProgress(t,4,map[string]int{"attackHaste":1},90,nil)
	ranks := map[string]int{"attackHaste":3,"attackPrecompute":1}
	after := coreProgress(t,5,map[string]int{},90,&legacyCoreAllocation{Revision:4,Ranks:ranks,RefundedPoints:5})
	if err := ValidateCoreTreeUpdate(before,nil,after,nil,10); err != nil { t.Fatal(err) }
	bad := coreProgress(t,5,map[string]int{},90,&legacyCoreAllocation{Revision:4,Ranks:map[string]int{"attackPrecompute":1},RefundedPoints:1})
	if err := ValidateCoreTreeUpdate(before,nil,bad,nil,10); err == nil { t.Fatal("unreachable legacy archive accepted") }
}

func TestFrozenCoreAllocationAndActualBudget(t *testing.T) {
	ranks := map[string]int{"S1":3,"A03":1}
	p := coreProgress(t,5,ranks,90,nil)
	run := frozenCoreRun(t,5,ranks,"wave")
	if err := ValidateCoreTreeUpdate(p,run,p,run,10); err != nil { t.Fatal(err) }
	nextStage := coreProgress(t,5,map[string]int{"S2":3,"A04":1},90,nil)
	if err := ValidateCoreTreeUpdate(p,run,nextStage,run,10); err != nil { t.Fatalf("next-stage allocation edit: %v",err) }
	zeroRank := frozenCoreRun(t,5,map[string]int{"S1":3,"A03":1,"S2":0},"wave")
	if err := ValidateCoreTreeUpdate(p,zeroRank,p,run,10); err != nil { t.Fatalf("omitting neutral rank: %v",err) }
	changed := frozenCoreRun(t,5,map[string]int{"S1":3,"A02":1},"wave")
	if err := ValidateCoreTreeUpdate(p,run,p,changed,10); err == nil { t.Fatal("midrun reallocation accepted") }
	missing := []byte(`{"economyRunId":"legacy-run","stageNumber":1,"phase":"wave"}`)
	if err := ValidateCoreTreeUpdate(p,run,p,missing,10); err == nil { t.Fatal("missing v5 frozen fields accepted") }
	if err := ValidateCoreTreeRunStart(p,run,10); err != nil { t.Fatal(err) }
	if err := ValidateCoreTreeRunStart(p,changed,10); err == nil { t.Fatal("new run not frozen from progression") }
	if err := ValidateCoreTreeRunStart(p,missing,10); err == nil { t.Fatal("new run missing v5 allocation") }
	all := map[string]int{}
	for id,node := range coretree.Catalogs[5].Nodes { all[id] = node.MaxRank }
	spent,_ := coretree.SpentPoints(5,all)
	if err := ValidateCoreTreeUpdate(nil,nil,coreProgress(t,5,all,spent,nil),nil,10); err != nil { t.Fatalf("budget above 60: %v",err) }
	if err := ValidateCoreTreeUpdate(nil,nil,coreProgress(t,5,all,spent-1,nil),nil,10); err == nil { t.Fatal("overspent budget accepted") }
}

func TestLegacyCoreFieldsStayAbsentAndUnchanged(t *testing.T) {
	p := []byte(`{ "totalCorePoints": 10, "corePassiveNodeRanks": {"attackHaste":3} }`)
	run := []byte(`{"phase":"wave","stageNumber":1}`)
	originalP, originalRun := bytes.Clone(p), bytes.Clone(run)
	if err := ValidateCoreTreeUpdate(p,run,p,run,9); err != nil { t.Fatal(err) }
	if !bytes.Equal(p,originalP) || !bytes.Equal(run,originalRun) { t.Fatal("validation rewrote receipt/hash bytes") }
}

func TestCoreTreeOptionalRuntimeFields(t *testing.T) {
	all := map[string]int{}
	for id,node := range coretree.Catalogs[5].Nodes { all[id] = node.MaxRank }
	for _, tc := range []struct { name, value string; valid bool }{
		{"absent", `{}`, true},
		{"valid pools", `{"nexusAdditionalHp":3.0,"nexusAdditionalHpGranted":true,"indomitableUsedThisStage":true,"nexusInvulnerableRemaining":3}`, true},
		{"pool above base hp cap", `{"nexusAdditionalHp":3.1,"nexusAdditionalHpGranted":true}`, false},
		{"negative pool", `{"nexusAdditionalHp":-1}`, false},
		{"ungranted pool", `{"nexusAdditionalHp":1}`, false},
		{"pool null", `{"nexusAdditionalHp":null}`, false},
		{"invulnerability too long", `{"indomitableUsedThisStage":true,"nexusInvulnerableRemaining":3.01}`, false},
		{"invulnerability without use", `{"nexusInvulnerableRemaining":1}`, false},
		{"bool is strict", `{"indomitableUsedThisStage":1}`, false},
		{"valid turret", `{"turrets":[{"level":11,"stockpileCharges":2}]}`, true},
		{"turret above expanded cap", `{"turrets":[{"level":12}]}`, false},
		{"turret level zero", `{"turrets":[{"level":0}]}`, false},
		{"turret fractional level", `{"turrets":[{"level":1.5}]}`, false},
		{"overflow charges", `{"turrets":[{"stockpileCharges":3}]}`, false},
		{"fractional charges", `{"turrets":[{"stockpileCharges":1.5}]}`, false},
		{"valid enemy", `{"enemies":[{"firstControlApplied":true,"stunRemaining":0.5,"freezeRemaining":1}]}`, true},
		{"negative control", `{"enemies":[{"freezeRemaining":-1}]}`, false},
		{"invalid control bool", `{"enemies":[{"firstControlApplied":"true"}]}`, false},
	} {
		t.Run(tc.name,func(t *testing.T) {
			var fields map[string]json.RawMessage
			if err := json.Unmarshal([]byte(tc.value),&fields); err != nil { t.Fatal(err) }
			if err := validateCoreRunFields(fields,5,all,0); (err==nil)!=tc.valid { t.Fatalf("valid=%v err=%v",tc.valid,err) }
		})
	}
	for _, raw := range []string{`{"indomitableUsedThisStage":true,"nexusInvulnerableRemaining":0}`,`{"turrets":[{"level":11}]}`,`{"turrets":[{"stockpileCharges":1}]}`,`{"indomitableUsedThisStage":true,"nexusInvulnerableRemaining":1}`} {
		var fields map[string]json.RawMessage
		_ = json.Unmarshal([]byte(raw),&fields)
		if err := validateCoreRunFields(fields,5,nil,0); err == nil { t.Fatalf("unallocated mechanic accepted: %s",raw) }
	}
}

func TestCoreStageOnlyStateCannotBeRegranted(t *testing.T) {
	decode := func(raw string) map[string]json.RawMessage { var result map[string]json.RawMessage; if err := json.Unmarshal([]byte(raw),&result); err != nil {t.Fatal(err)}; return result }
	old := decode(`{"nexusAdditionalHpGranted":true,"nexusAdditionalHp":10,"indomitableUsedThisStage":true,"nexusInvulnerableRemaining":2}`)
	for _, raw := range []string{
		`{"nexusAdditionalHpGranted":false,"indomitableUsedThisStage":true}`,
		`{"nexusAdditionalHpGranted":true,"nexusAdditionalHp":11,"indomitableUsedThisStage":true,"nexusInvulnerableRemaining":1}`,
		`{"nexusAdditionalHpGranted":true,"nexusAdditionalHp":9,"indomitableUsedThisStage":true,"nexusInvulnerableRemaining":3}`,
		`{"nexusAdditionalHpGranted":true,"nexusAdditionalHp":9,"indomitableUsedThisStage":false}`,
	} { if err := validateCoreRunMonotonicFields(old,decode(raw)); err == nil {t.Fatalf("stage reset accepted: %s",raw)} }
	if err := validateCoreRunMonotonicFields(old,decode(`{"nexusAdditionalHpGranted":true,"nexusAdditionalHp":0,"indomitableUsedThisStage":true,"nexusInvulnerableRemaining":0}`)); err != nil { t.Fatal(err) }
}

func TestCoreRankWireRejectsMalformedOrUnknownValues(t *testing.T) {
	for _, raw := range []string{
		`{"corePassiveTreeRevision":5,"totalCorePoints":100,"corePassiveNodeRanks":{"S1":null}}`,
		`{"corePassiveTreeRevision":5,"totalCorePoints":100,"corePassiveNodeRanks":{"S1":1.5}}`,
		`{"corePassiveTreeRevision":5,"totalCorePoints":100,"corePassiveNodeRanks":{"missing":0}}`,
		`{"corePassiveTreeRevision":null,"corePassiveNodeRanks":{}}`,
		`{"corePassiveTreeRevision":5,"totalCorePoints":100,"corePassiveNodeRanks":null}`,
		`{"corePassiveTreeRevision":5,"totalCorePoints":100,"corePassiveNodeRanks":{},"corePassiveLegacyAllocation":{"revision":4,"ranks":{"attackHaste":null},"refundedPoints":0}}`,
	} { if err := ValidateCoreTreeUpdate(nil,nil,[]byte(raw),nil,10); !errors.Is(err,ErrCoreTreeConflict) { t.Fatalf("malformed allocation accepted: %s, %v",raw,err) } }
}

func TestAdditionalCoreHPUsesBaseUpgradeCapAndFrozenRank(t *testing.T) {
	for _,tc := range []struct {rank,upgrade int; amount float64; valid bool}{
		{1,0,1,true},{1,0,1.01,false},
		{2,0,2,true},{2,0,2.01,false},
		{3,0,3,true},{3,0,3.01,false},
		{3,30,7.5,true},{3,30,7.51,false},
		{3,999,7.5,true},{3,999,7.51,false},
		{3,-1,3,true},{3,-1,3.1,false},
	} {
		var fields map[string]json.RawMessage
		_ = json.Unmarshal(coreJSON(t,map[string]any{"nexusAdditionalHp":tc.amount,"nexusAdditionalHpGranted":true}),&fields)
		if err:=validateCoreRunFields(fields,5,map[string]int{"C12":tc.rank},tc.upgrade); (err==nil)!=tc.valid {t.Fatalf("%+v: %v",tc,err)}
	}
}
