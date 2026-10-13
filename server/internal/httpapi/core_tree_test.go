package httpapi

import (
	"bytes"
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	gamesave "github.com/Sejiiinn/RuneNexus/server/internal/save"
)

func TestExpandedCoreTreeProtocolPreservesExactSaveBody(t *testing.T) {
	body := `{"expectedRevision":0,"clientCompatibilityVersion":10,"data":{"version":2,"savedAtMillis":1234,"preferences":{},"progression":{"corePassiveTreeRevision":5,"totalCorePoints":90,"corePassiveNodeRanks":{"S1":3}},"turretModules":{},"activeRun":{"phase":"preparation","stageNumber":1,"runCorePassiveTreeRevision":5,"runCorePassiveNodeRanks":{"S1":3},"nexusAdditionalHp":0,"nexusAdditionalHpGranted":true,"indomitableUsedThisStage":false,"nexusInvulnerableRemaining":0,"turrets":[{"level":11,"stockpileCharges":0}],"enemies":[{"firstControlApplied":false,"stunRemaining":0,"freezeRemaining":0}]}}}`
	request := jsonRequest(http.MethodPut,"/v1/save",body)
	response := httptest.NewRecorder()
	decoded,err := decodeSaveUpdateRequest(response,request,4096,9)
	if err != nil {t.Fatal(err)}
	if decoded.ReceiptOnly || decoded.ClientCompatibilityVersion != 10 || !bytes.Equal(decoded.RawBody,[]byte(body)) {t.Fatalf("decoded request: %+v",decoded)}
	for _, field := range []string{"runCorePassiveTreeRevision","nexusAdditionalHpGranted","indomitableUsedThisStage","stockpileCharges","firstControlApplied","stunRemaining","freezeRemaining"} {
		if !bytes.Contains(decoded.Data.ActiveRun,[]byte(`"`+field+`"`)) {t.Fatalf("lost field %s",field)}
	}
}

func TestExpandedCoreTreeInvalidAllocationMapsToSaveError(t *testing.T) {
	handler := newSaveTestHandler(successfulAccessAuthenticator(t), saveServiceStub{update:func(context.Context,string,string,gamesave.UpdateRequest)(gamesave.UpdateResult,error){return gamesave.UpdateResult{},gamesave.ErrCoreTreeConflict}},4096)
	request := jsonRequest(http.MethodPut,"/v1/save",strings.Replace(validSaveBody,`"clientCompatibilityVersion":2`,`"clientCompatibilityVersion":10`,1))
	request.Header.Set("Authorization","Bearer access-token")
	request.Header.Set(idempotencyKeyHeader,testIdempotencyKey)
	request.Header.Set(saveWriterHeader,"3")
	response:=httptest.NewRecorder()
	handler.ServeHTTP(response,request)
	if response.Code != http.StatusUnprocessableEntity || !strings.Contains(response.Body.String(),`"code":"INVALID_SAVE_DATA"`) {t.Fatalf("status=%d body=%s",response.Code,response.Body.String())}
}

func TestGenerationNineSaveReceiptsRemainDecodable(t *testing.T) {
	body:=strings.Replace(validSaveBody,`"clientCompatibilityVersion":2`,`"clientCompatibilityVersion":9`,1)
	for _,floor:=range []int{9,10} {
		request:=jsonRequest(http.MethodPut,"/v1/save",body)
		decoded,err:=decodeSaveUpdateRequest(httptest.NewRecorder(),request,4096,floor)
		if err != nil {t.Fatal(err)}
		if decoded.ReceiptOnly != (floor==10) || !bytes.Equal(decoded.RawBody,[]byte(body)) {t.Fatalf("floor=%d decoded=%+v",floor,decoded)}
	}
}
