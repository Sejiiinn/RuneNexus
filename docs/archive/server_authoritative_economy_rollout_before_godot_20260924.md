# 서버 권위 경제의 Godot 전환 전 구현 단계 기록

역할: [서버 권위 경제 상세 설계](../server_authoritative_economy_design.md)에서 2026-10-27 KST에 분리한 Flutter 시절의 단계별 구현 작업 분해, Flutter 클라이언트 테스트 목록, 단계별 진행 순서의 보존본. “현재 미완료”, “완료”, 예상 변경 위치와 Flutter 클래스 이름은 당시 기준이며 현재 작업 지시나 상태가 아니다. 현행 계약과 남은 후속 작업은 원본 문서를 따른다.

## 11. 구현 작업 분해

### 단계 0. 선행 저장 안전성

현재 미완료인 다음 작업을 먼저 끝낸다.

- canonical Outbox와 exact in-flight 영수증 우선 복구
- revision 기반 자동 rebase와 crash-safe backup journal
- save writer generation API·DB
- Web 다중 탭 writer 잠금
- [x] 구버전 `clientCompatibilityVersion` gate

성공 기준:

- 이전 writer의 보상은 exact 영수증 우선 확인 뒤 `remote > base`일 때만 폐기되고,
  `remote == base`이면 안전하게 suspended·재결속된다.
- 실제 다중 기기 충돌은 사용자 선택 없이 원격 진행으로 복구된다.

### 단계 1. 경제 도메인 경계와 DB 기반

예상 변경 위치:

```text
server/db/migrations/006_authoritative_economy.sql
server/db/queries/economy.sql
server/internal/economy/catalog.go
server/internal/economy/service.go
server/internal/httpapi/economy.go
```

작업:

- 위 테이블과 sqlc 쿼리 추가
- economy snapshot, command와 error 도메인 정의
- authority epoch와 DB restore 회전 절차 구현
- catalog version, 티켓 가격, 등급 확률, 옵션 범위와 분해 가격의 서버 원본 정의
- `GET /v1/economy`, bootstrap 구현
- 계정 격리, bootstrap/save PUT 경쟁, 1회성, transaction rollback 통합 테스트

성공 기준:

- bootstrap 재시도는 같은 결과를 반환한다.
- bootstrap과 legacy save PUT의 순서가 바뀌어도 최신 ack snapshot만 이전된다.
- 일반 save PUT으로 경제 행이나 모듈을 변경할 수 없다.

### 단계 2. 가챠·분해 서버 vertical slice

작업:

- 서버 뽑기와 분해 명령, 안전한 RNG와 exact 영수증 구현
- expected catalog version과 실행 catalog/RNG algorithm version 기록
- Flutter `EconomyApi`, `EconomyCoordinator`와 영속 exact in-flight 구현
- 현재 동기 `drawTurretModules`, `disassembleTurretModules` UI를 async 결과 기반으로 변경
- `RunProgression`에는 서버 snapshot 적용과 모듈 효과 계산만 남김
- 오프라인·전송 중·revision 충돌 UX 추가

성공 기준:

- 응답 유실 재시도에서 동일 모듈만 반환된다.
- 두 기기의 같은 revision 뽑기 중 하나만 성공한다.
- 저장 rollback이나 재로그인으로 뽑기 전 잔액으로 돌아갈 수 없다.
- unique 모듈 분해 정책이 개별·일괄에서 일치한다.

### 단계 3. 나머지 다이아 소비

작업:

- 연구 즉시 완료와 두 번째 연구 슬롯 해금 명령 추가
- 연구 슬롯 2 서버 entitlement와 pending progression effect 테이블·조회·ack 구현
- save rebase -> effect 적용 -> 통파일 저장 -> cloud save ack -> effect ack 순서 구현
- 무료 다이아 우선 소비를 서버·클라이언트 표시에서 동일하게 검증

성공 기준:

- 서버 차감 뒤 앱 종료가 발생해도 효과가 누락되거나 이중 차감되지 않는다.
- 명령을 보낸 기기의 로컬 저장이 사라져도 다른 기기가 pending effect를 적용한다.
- 오프라인에서 소비 버튼이 명령으로 예약되지 않는다.

### 단계 4. 모든 보상 지급 경로

작업:

- stable run ID와 런 종료 1회 pending diamond 정산 모델 추가
- run settlement와 현재 writer generation 결속
- 일·주간 퀘스트, 출석과 스테이지 최초 클리어 reward key 추가
- account별 durable reward claim outbox 구현
- 서버 기간 키와 클라이언트 표시 overlay
- release debug 지급 경로 차단

성공 기준:

- 같은 보상은 다른 기기·다른 idempotency key로도 한 번만 지급된다.
- 여러 reward claim이 같은 최초 economy revision에서 생성돼도 FIFO로 모두 처리된다.
- 오프라인 런 보상은 유실되지 않지만 승인 전 소비할 수 없다.
- writer 교체 뒤 `remote == base` 보상은 보존되고 `remote > base` 분기의 보상만 무효화된다.

### 단계 5. account 단위 전환과 저장 v3 후속 분리

작업:

- 완료: v2 snapshot 기반 bootstrap과 legacy module ID 대응
- 완료: 모든 account 경제 변이 경로의 server coordinator 경유
- 완료: `legacy_local`에서 `server_authoritative`로 account 1회 전환
- 완료: 구버전 호환 세대 차단과 장애 시 경제 read-only 처리
- 후속: `economyCache`와 `turretModuleLoadout`을 분리하는 보존형 v3 migration
- 후속: 일반 cloud save serializer에서 경제 cache 제외
- 후속: save Outbox fingerprint를 canonical `CloudSaveData` bytes 기준으로 변경

성공 기준:

- 기존 사용자 진행과 장착 모듈이 보존된다.
- 전환된 account에는 로컬 경제 writer가 하나도 남지 않는다.
- 원격 일반 저장 rebase 뒤에도 경제 상태가 낮아지지 않는다.

### 단계 6. 실제 구매

Google Play 결제가 필요할 때만 진행한다.

- Google Play purchase token 서버 검증
- provider transaction unique와 중복 지급 방지
- acknowledgement·소비 정책 확정
- paid diamond 지급과 환불·취소 처리
- Apple StoreKit 거래 검증 추가

외부 관리형 백엔드나 유료 인증·경제 서비스는 도입하지 않고 현재 Go API와
PostgreSQL 안에서 처리한다.

## 12. 테스트 계약 중 Flutter 테스트


- 인증·복구 실패 시 플레이/경제 버튼 차단과 세션·저장 보존
- 응답 유실, 앱 재시작 뒤 exact in-flight 복구
- 서버 응답 영속 전/후 강제 종료 복구
- 같은 authority epoch의 낮은 revision 응답 무시와 새 epoch 재기준화
- 저장 rebase 뒤 authoritative overlay
- rebase 뒤 pending progression effect 적용과 cloud save 성공 전 ack 금지
- 분해 뒤 장착 ID 자동 정리
- pending run 보상과 확정 잔액 분리 표시
- 다른 account outbox로 경제 명령이 전송되지 않음
- economy cache 변경만으로 CloudSaveData fingerprint가 바뀌지 않음

## 14. 최종 추천 순서

현재 형상은 1~6번을 완료했으며, 이후 검증·운영 작업은 다음 순서로 진행한다.

1. 완료: 다중 기기 save canonical Outbox·자동 rebase
2. 완료: save writer generation과 구버전 client compatibility gate
3. 완료: 경제 DB·`GET /v1/economy`·bootstrap
4. 완료: 가챠·분해 vertical slice와 Flutter exact command 복구
5. 완료: 연구 소비와 모든 다이아·모듈권 보상 경로
6. 완료: account 단위 서버 권위 전환
7. 공개 환경 두 기기 E2E와 운영 backup 검증
8. 저장 v3 `CloudSaveData` 분리
9. 필요할 때만 Google Play 구매 검증 추가

1~2번을 선행한 덕분에 보상 claim을 현재 save writer에 묶고, 오래된 기기가 로컬
진행과 보상을 함께 제출하는 경로를 차단한 상태다.
