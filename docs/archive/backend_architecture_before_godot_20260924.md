# 백엔드 아키텍처의 Godot 전환 전 검증·구현 기록

역할: [백엔드 아키텍처](../backend_architecture.md)에서 2026-10-27 KST에 분리한 Flutter·Web 시절의 검증 전략, 단계별 구현 순서, `main` 통합 전 배포 게이트, 당시 구현 상태의 보존본. 아래의 “현재”, “아직”, 체크 표시는 당시(대부분 2026-09 초) 기준이며 현재 작업 지시나 상태가 아니다. 현행 검증 진입점과 상태는 원본 문서의 [검증과 구현 현황](../backend_architecture.md#검증과-구현-현황)을 따른다.

## 검증 전략

### Flutter 단위·통합 테스트

- system temp legacy v1을 application support의 account/guest v2 슬롯으로 이관
- legacy v1을 별도 v2 위치로 이관하고 v1을 보존
- 손상된 기본 v2에서 v2 backup, 이후 v1 순서로 fallback
- v1 위치의 v1과 v2 위치의 canonical v2 엄격 구분
- 로드 실패 후 기존 저장을 빈 게임으로 덮어쓰지 않음
- IO 임시 파일 교체 실패 시 직전 저장 보존
- 통파일 API 직렬화 왕복
- save outbox 단일 in-flight 보장
- 모든 로컬 쓰기의 단일 coordinator 직렬화
- 여러 pending 저장을 최신 하나로 병합
- payload 저장과 dirty 기록 사이 강제 종료 후 hash 기반 복구
- timeout 후 동일 bytes/key 재시도
- 앱 재시작 후 in-flight 복구
- stale 응답 무시
- `401` refresh 후 동일 요청 재시도
- `409` 충돌에서 exact in-flight 확인 후 원격 revision 자동 rebase
- rebase 단계별 강제 종료와 다음 실행 복구
- writer 교체 뒤 백그라운드 자동 탈환 방지
- 같은 브라우저 두 탭의 단일 로컬 writer 잠금
- 온라인 실패가 게임 진행을 막지 않음

### Go 단위 테스트

- 설정 검증
- opaque token 생성과 SHA-256 해시
- refresh 회전과 재사용 탐지
- 동시 동일 key refresh의 단일 회전과 동일 응답 재생
- refresh 응답 유실·서버 재시작 후 부모/자식 token 재시도, 장기 중단·access 만료 복구와 이후 회전의 옛 응답 거부 구분
- PGS 응답 파싱과 오류 매핑
- 저장 크기, 버전, 구조 검증
- 동일 idempotency key 재응답
- 같은 key의 다른 body 거부
- 공통 API 오류 형식

### PostgreSQL 통합 테스트

- 최초 account와 identity 동시 생성
- 같은 PGS Player ID의 동시 가입 중복 방지
- refresh 회전 후 허용되지 않은 이전 token 재사용 시 session 폐기
- 최초 revision 0 저장
- 영역 전체 upsert
- 중간 오류 전체 rollback
- 동시에 저장한 요청 중 하나만 성공
- 응답 유실을 가정한 같은 요청 재처리
- 동일 key와 body의 동시 2요청이 같은 resulting revision 성공
- 동일 key와 다른 body의 동시 요청이 key 재사용 오류
- 다른 body의 key 재사용 거부
- writer claim 멱등 재시도와 generation 단조 증가
- 이전 writer의 새 저장 거부와 이미 성공한 요청 영수증 복구
- unsupported client가 기존 writer를 교체하지 않음
- `activeRun: null` 행 삭제
- account 삭제 cascade

### 실제 통합 검증

- PGS 테스트 계정 로그인
- 앱 재설치 후 원격 저장 복원
- 느린 네트워크와 응답 유실 시 저장 순서 보장
- 앱 강제 종료 후 outbox 복구
- 두 기기 revision 충돌, 로컬 backup과 원격 자동 복구
- writer 교체, 응답 유실과 실제 미반영 요청 구분
- 같은 브라우저 두 탭의 저장 writer 제한
- Web legacy 저장 실제 마이그레이션
- PostgreSQL 백업 파일 복원

## 구현 순서

### 1단계: 서버 기반

- [x] Go와 도구 버전 고정
- [x] `server/` 모듈과 HTTP 서버
- [x] Dockerfile과 Compose API 서비스
- [x] PostgreSQL 연결과 health check
- [x] `tern` 실행 기반

### 2단계: 로컬 저장 배포 안전성

- [x] system temp 저장을 application support 영속 위치로 이전
- [x] guest/account별 로컬 슬롯 분리
- [x] v2 전용 키·파일과 legacy v1 fallback
- [x] canonical v2 validator와 v1/v2 저장 위치 격리
- [x] 원자적 IO 저장과 v2 backup
- [x] 모든 로컬 쓰기의 단일 coordinator 통합
- [x] legacy v1 마이그레이션과 미배포 중간 v2 거부 테스트
- [x] 전체 Flutter analyze/test와 Web·Android 빌드 검증

### 3단계: 계정·저장 DB

- [x] account, identity, session, refresh token 마이그레이션
- [x] 영역별 저장과 save request 마이그레이션
- [x] `sqlc.yaml`, 쿼리와 생성 코드
- [x] 실제 PostgreSQL 통합 테스트

### 4단계: PGS·Google 인증과 계정 UX

- Android Application ID를 `com.runenexus.game`으로 변경
- 출시 서명과 PGS/OAuth 설정
- Kotlin PGS v2와 Flutter MethodChannel
- [x] Google Identity Services 웹 로그인과 허용 origin 설정
- [x] Google ID token 검증과 account/session 발급 API
- [x] refresh 회전·재사용 감지·로그아웃·Bearer 인증 기반
- [x] Flutter 메모리 세션 자동 갱신과 401 1회 재시도
- [x] Web HttpOnly 쿠키·Android Keystore 저장과 앱 시작 세션 복원
- [x] Android Credential Manager Google 로그인과 native HTTP transport
- [x] 요청 key 영속화·암호화 receipt·응답 유실 재시도와 logout 의도 복구
- Go PGS auth code 교환과 Player ID 검증
- identity 연결 API와 중복 account 충돌 처리
- [x] 계정 상태 모델과 계정·저장 진입 UI

### 5단계: 온라인 저장

- [x] 인증된 `GET/PUT /v1/save`
- [x] revision, 멱등성과 저장 트랜잭션
- [x] Flutter 원격 저장 API 클라이언트와 단일 전송 worker
- [x] Flutter 영속 save outbox와 동기화 상태 기계
- [x] 최초 로그인 기존 Outbox 우선 복구·backup·원격 account 우선 자동 bootstrap
- [x] SHA-256 canonical Outbox와 exact in-flight 우선 복구
- [x] 별도 충돌 backup·rebase journal과 revision 기반 자동 rebase
- [x] `GET /v1/save` ETag 조건부 조회와 계정 게임 재로딩
- [x] writer generation API·DB와 이전 writer 저장 거부
- [x] Web 다중 탭 local writer 잠금
- [x] writer claim·PUT 공통 client compatibility gate와 업데이트 필요 UX
- [x] 업데이트 뒤 이전 Outbox의 writer 재획득과 exact PUT 영수증 hit/miss 롤오버
- 느린 네트워크·재시작 통합 검증

### 6단계: 중요 경제 확장

- [x] 서버 권위 경제 상세 설계
- [x] 저장 writer generation과 구버전 client compatibility gate 선행
- [x] 주간 임무·전체 완료·주간 출석 claim의 서버 판정과 중복 영수증
- 경제 DB·조회·legacy bootstrap을 기능 플래그 뒤에 구현
- 가챠·분해·연구 소비와 나머지 보상 claim 명령 API
- authority epoch, 소비 exact in-flight, progression effect journal과 보상 claim outbox
- account 단위 일괄 전환과 다중 기기 E2E
- 실제 결제 시점에 Google Play 구매 검증 추가

### 7단계: 출시 안전장치

- [x] HTTPS reverse proxy, 인증 요청 제한과 보안 헤더
- 계정·원격 데이터 삭제
- [x] DB 정기 백업과 격리 복원 확인 자동화([운영 절차](../self_hosted_api_deployment.md#api-반영과-db-백업))
- 개인정보 처리방침과 스토어 데이터 공개 항목

## main 통합 전 배포 게이트

`main` push는 GitHub Pages 자동 배포로 이어진다. 저장 v2 변경은 다음 조건을
모두 만족하기 전 `main`에 통합하지 않는다.

- legacy v1 저장을 덮어쓰지 않는 v2 위치 분리
- system temp legacy 저장의 영속 위치 이전
- v1 -> v2, v2 backup, 손상 v2 fallback 테스트
- canonical v2 validator와 v1/v2 저장 위치 격리
- 모든 로컬 저장 경로의 단일 직렬화
- 로컬 저장 실패 시 기존 데이터 보존
- 전체 Flutter analyze/test 통과
- 실제 Chrome Web Local Storage fixture 자동 검증
- 이전 배포로 되돌렸을 때 legacy v1을 읽을 수 있음

Go 서버, Compose와 문서처럼 클라이언트 저장 형식을 바꾸지 않는 변경은 별도
커밋으로 통합할 수 있다.

## 현재 구현 상태

- 인증 구현 기준은 2026-09-05 작업 트리이며 운영 적용 완료를 의미하지 않는다.
- 현재 브랜치에는 `GameSaveData` v2 영역 분리와 v1 -> v2 변환 코드가 있다.
- Web과 IO 모두 guest/account별 v2 primary와 backup 위치를 사용한다.
- guest legacy 저장은 원본을 보존한 채 신규 v2 위치로 이전한다.
- IO 저장은 application support를 사용하며 원자적 교체 중단도 복구한다.
- 일반 저장과 체크포인트는 단일 `LocalSaveCoordinator`를 거친다.
- Go 1.26.5, pgx 5.10.0, sqlc 1.31.1, tern 2.4.1을 고정했다.
- PostgreSQL, migrate, API Compose 실행 기반이 있다.
- 계정·session과 영역별 온라인 저장 스키마 및 `sqlc` 쿼리가 구현되어 있다.
- `/health/live`, `/health/ready`가 구현되어 있다.
- Google Identity Services 웹 로그인, ID token 검증과 account/session 발급 API가
  구현되어 있다.
- refresh token 회전·재사용 감지·logout과 Bearer 인증이 구현되어 있다.
- Google 로그인·refresh 요청 제한과 Flutter 메모리 세션 자동 갱신이 구현되어 있다.
- 인증된 `GET/PUT /v1/save`, revision·멱등성·영역별 저장 트랜잭션이 구현되어 있다.
- Flutter 원격 저장 API 클라이언트와 단일 in-flight 전송 worker가 구현되어 있다.
- 계정별 영속 Outbox, 최신 pending 병합, backoff와 재시작 복구가 구현되어 있다.
- 최초 로그인 기존 Outbox 우선 복구, 원본 backup과 원격 account 우선 자동
  bootstrap이 구현되어 있다. account 로컬 저장은 독립 진행이 아닌 계정 기록의 캐시다.
- account 자동 연결 시 해당 슬롯을 게임에 다시 로드하고, 로그아웃 시 account 저장을
  보존한 뒤 guest 슬롯으로 복귀한다.
- 게스트·연결·오프라인·확인 필요 상태를 표시하는 계정·저장 UI 기반이 구현되어 있다.
- Caddy HTTPS reverse proxy와 production Compose 배포 골격이 구현되어 있다.
- 자동 연결 account에는 `OnlineSaveCoordinator`가 주입되며, 중요 체크포인트가 로컬
  저장된 뒤 계정별 Outbox를 통해 비동기 전송된다.
- 다중 기기 충돌은 사용자 선택 없이 원격 revision을 적용하는 방향으로 설계를
  변경했다. exact in-flight 우선 복구, 자동 rebase, writer generation과 Web 다중 탭
  잠금까지 구현되어 있다.
- 주간 임무·전체 완료·주간 출석의 수령 판정은 인증된
  `POST /v1/economy/rewards/claim`으로 구현되어 있다. 서버가 현재 writer와 최신 저장
  진행을 검증하고 서버 주차·고정 보상표·계정별 reward key로 한 번만 영수증을 만든다.
  Flutter는 수령 전 account 체크포인트 동기화 후 영수증만 로컬 캐시에 반영한다.
- Web 새로고침·Android 앱 재시작 뒤 영속 세션 복원이 구현되어 있다. 일시적인 복원
  실패는 게스트로 전환하지 않고 재시도한다. 로그인 필수화는 별도 후속 범위다.
- Android Application ID는 아직 `com.example.rune_nexus`다.
- release 빌드는 아직 debug signing을 사용한다.
- PGS 인증, identity 연결 API, 운영 DB backup·restore와 계정 데이터 삭제는 아직
  구현되지 않았다.
- 다이아·모듈권·소유 모듈을 하나의 서버 권위 경제 영역으로 전환하는 상세 설계가
  확정됐다. 주간 보상 claim의 DB·API·Flutter 연결은 구현됐지만 전체 지갑 DB,
  economy revision, bootstrap과 경제 coordinator는 아직 구현되지 않았다.

## Flutter 클라이언트 코드 통합 제약

원본의 「클라이언트 동기화 상태 기계 → 현재 코드 통합 제약」에서 2026-10-27 KST에 옮긴 Flutter 클래스 기준 설명과 변경 계획이다. 같은 절의 자동 복구·writer generation 원칙과 네트워크 비대기 원칙은 원본의 「클라이언트 통합 원칙」에 남아 있다.

현재 `OnlineSaveApi`는 원격 조회·조건부 갱신 계약을 구현하고,
`OnlineSaveCoordinator`는 계정별 영속 Outbox, 단일 in-flight, 최신 pending 병합,
동일 본문·멱등성 key 재시도, 재시작 복구와 충돌 중단을 담당한다. Web Local Storage와
IO application support 경로 모두 primary·backup 복구를 제공한다. 최초 로그인 시에는
기존 Outbox를 먼저 확인하고, 새 연결이면 원격 account 진행을 우선해 account 슬롯을
자동 준비한다. 원격이 없을 때만 guest 진행을 이전하며 원본은 backup한다. account 로컬
저장은 독립 후보가 아니라 계정 기록의 캐시다. 자동 연결된 account 슬롯에는
coordinator를 실제 게임에 주입한다. 라운드 종료 같은
중요 체크포인트는 로컬 저장 성공 뒤 영속 Outbox에 등록하고, 전송 완료를 기다리지
않는다. 원격 기록 자동 적용은 현재 revision과 payload fingerprint를 초기 동기화
기준으로 삼는다. 기존 Outbox에 미전송·충돌·차단 상태가 있으면 새 기준으로
재기준화하지 않고 coordinator가 exact 요청과 rebase journal을 우선 복구한다.

현재 `SaveScheduler`는 `_writeLocalSave`만 직렬화하고 `_saveRoundCheckpoint`는
직접 파일 쓰기와 온라인 호출을 수행한다. 최종 구현에서는 다음처럼 바꾼다.

- 모든 로컬 파일 쓰기는 하나의 `LocalSaveCoordinator` 직렬화 경로를 사용한다.
- 체크포인트도 직접 `_writeLocalSaveData`를 호출하지 않는다.
- 로컬 저장 완료 후 outbox enqueue까지 성공해야 온라인 동기화를 예약한다.
- 로컬 저장 실패는 플레이를 막지 않지만 내부 결과로 실패를 전달해 outbox가
  저장되지 않은 스냅샷을 전송하지 않게 한다.
- `OnlineSaveRepository`의 Future는 HTTP 완료가 아니라 durable enqueue 완료를
  뜻한다.
- `_saveRoundCheckpoint`는 durable enqueue까지만 기다리고 HTTP는 기다리지 않는다.
- 여러 곳의 `unawaited(_saveRoundCheckpoint())`가 네트워크 병렬 요청을 만들지
  않도록 실제 HTTP 전송은 별도 `OnlineSaveCoordinator` 한 곳에서만 수행한다.
