//go:build integration

package dbtest_test

import (
	"encoding/json"
	"errors"
	"testing"

	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

func TestCoreTreeMigrationProtectsWriterAndPreservesLegacyReceipts(t *testing.T) {
	ctx, f, account := openSaveService(t)
	legacy := gamesave.UpdateRequest{
		IdempotencyKey:firstSaveKey, ClientCompatibilityVersion:9,
		RawBody:[]byte(`{"clientCompatibilityVersion":9,"legacyCoreTree":true}`),
		Data:gamesave.Data{Version:2,Preferences:json.RawMessage(`{}`),TurretModules:json.RawMessage(`{"tickets":0,"items":[]}`),
			Progression:json.RawMessage(`{"corePassiveTreeRevision":4,"totalCorePoints":90,"corePassiveNodeRanks":{"attackHaste":3,"attackPrecompute":1}}`)},
	}
	first,err:=f.Update(ctx,account,legacy)
	if err != nil {t.Fatal(err)}
	migrated:=legacy
	migrated.IdempotencyKey=secondSaveKey
	migrated.ExpectedRevision=first.Revision
	migrated.ClientCompatibilityVersion=10
	migrated.RawBody=[]byte(`{"clientCompatibilityVersion":10,"coreTreeMigration":true}`)
	migrated.Data.Progression=json.RawMessage(`{"corePassiveTreeRevision":5,"totalCorePoints":92,"corePassiveNodeRanks":{"S1":3,"A03":1},"corePassiveLegacyAllocation":{"revision":4,"ranks":{"attackHaste":3,"attackPrecompute":1},"refundedPoints":5}}`)
	second,err:=f.Update(ctx,account,migrated)
	if err != nil {t.Fatal(err)}
	// An old exact body still resolves before all new content validation.
	replayed,err:=f.Update(ctx,account,legacy)
	if err != nil || replayed.Revision != first.Revision {t.Fatalf("historical receipt: %+v %v",replayed,err)}
	stale:=legacy
	stale.IdempotencyKey="0198b955-3656-7c40-b3cb-87f427b90bfa"
	stale.ExpectedRevision=second.Revision
	stale.RawBody=[]byte(`{"clientCompatibilityVersion":9,"stale":true}`)
	if _,err:=f.Update(ctx,account,stale); !errors.Is(err,gamesave.ErrClientUpdateRequired) {t.Fatalf("old generation write: %v",err)}
	stale.ClientCompatibilityVersion=10
	stale.RawBody=[]byte(`{"clientCompatibilityVersion":10,"stale":true}`)
	if _,err:=f.Update(ctx,account,stale); !errors.Is(err,gamesave.ErrClientUpdateRequired) {t.Fatalf("new generation stale allocation: %v",err)}
	if _,err:=f.service.ClaimWriter(ctx,account,f.sessionID,gamesave.ClaimWriterRequest{IdempotencyKey:secondClaimKey,ClientInstanceID:secondClientID,ClientCompatibilityVersion:9,RawBody:[]byte(`{"clientCompatibilityVersion":9}`)}); !errors.Is(err,gamesave.ErrClientUpdateRequired) {t.Fatalf("old generation writer claim: %v",err)}
	snapshot,err:=f.Get(ctx,account)
	if err != nil || snapshot.Revision != second.Revision {t.Fatalf("failed writes changed save: %+v %v",snapshot,err)}
	assertGemOfferJSONEqual(t,snapshot.Data.Progression,migrated.Data.Progression)
}

func TestCoreTreeMigrationDefersLiveLegacyRunAndKeepsTerminalFreeze(t *testing.T) {
	ctx,f,account:=openSaveService(t)
	data:=gamesave.Data{Version:2,Preferences:json.RawMessage(`{}`),TurretModules:json.RawMessage(`{"tickets":0,"items":[]}`),
		Progression:json.RawMessage(`{"corePassiveTreeRevision":4,"totalCorePoints":90,"corePassiveNodeRanks":{"attackHaste":3}}`),
		ActiveRun:json.RawMessage(`{"economyRunId":"0198b955-3656-7c40-b3cb-87f427b90bfa","stageNumber":1,"phase":"wave","completedRounds":0,"gemRerollsUsed":0,"gemInventory":{},"gemShards":0,"turrets":[],"runCorePassiveTreeRevision":4,"runCorePassiveNodeRanks":{"attackHaste":3}}`)}
	seeded:=seedPreAuthoritySave(t,f,account,data)
	request:=gamesave.UpdateRequest{IdempotencyKey:firstSaveKey,ExpectedRevision:seeded.Revision,ClientCompatibilityVersion:10,RawBody:[]byte(`{"clientCompatibilityVersion":10,"migration":"live"}`),Data:data}
	request.Data.Progression=json.RawMessage(`{"corePassiveTreeRevision":5,"totalCorePoints":90,"corePassiveNodeRanks":{},"corePassiveLegacyAllocation":{"revision":4,"ranks":{"attackHaste":3},"refundedPoints":4}}`)
	if _,err:=f.Update(ctx,account,request); !errors.Is(err,gamesave.ErrCoreTreeConflict) {t.Fatalf("live run migrated: %v",err)}
	request.Data.ActiveRun=json.RawMessage(`{"economyRunId":"0198b955-3656-7c40-b3cb-87f427b90bfa","stageNumber":1,"phase":"success","completedRounds":1,"gemRerollsUsed":0,"gemInventory":{},"gemShards":0,"turrets":[],"runCorePassiveTreeRevision":4,"runCorePassiveNodeRanks":{"attackHaste":3}}`)
	request.RawBody=[]byte(`{"clientCompatibilityVersion":10,"migration":"terminal"}`)
	if _,err:=f.Update(ctx,account,request); err != nil {t.Fatal(err)}
	snapshot,err:=f.Get(ctx,account)
	if err != nil {t.Fatal(err)}
	var run struct {Revision int `json:"runCorePassiveTreeRevision"`; Ranks map[string]int `json:"runCorePassiveNodeRanks"`}
	if err=json.Unmarshal(snapshot.Data.ActiveRun,&run); err != nil || run.Revision != 4 || run.Ranks["attackHaste"] != 3 {t.Fatalf("terminal legacy freeze: %+v %v",run,err)}
}
