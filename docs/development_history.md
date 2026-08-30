# Rune Nexus 개발 히스토리

마지막 갱신 기준: 2026-08-30 `codex/server-authoritative-economy` 브랜치 작업 기준.

## 목적

이 문서는 README에 넣기에는 세부적인 최근 구현 흐름을 남기는 기록이다. 현재 규칙과 수치는 `docs/gameplay_balance_reference.md`, 구현 완료 여부는 `docs/implementation_status.md`를 기준으로 한다.

### 서버 권위 경제 MVP 전환

- PostgreSQL에 account별 경제 상태, economy revision·authority epoch, 소유 모듈,
  명령 영수증, 자산 원장, 보상 수령과 연구 progression effect를 추가했다.
- 기존 account 저장은 최초 경제 연결 때 한 번만 bootstrap하고 구매 다이아를 무료
  다이아로 합산하며, 원문과 거부된 모듈 진단을 backup으로 남긴다.
- 로그인 account의 가챠·분해, 연구 즉시 완료·두 번째 슬롯, 일·주간 보상과 런 종료
  보상을 서버 명령으로 전환했다. 런 보상은 stable run ID와 durable draft로 중복·유실을
  막고 최신 저장 진행을 근거로 정산한다.
- Flutter `EconomyCoordinator`와 별도 영속 Outbox를 추가해 경제 명령을 직렬화하고,
  같은 idempotency key·본문으로 응답 유실을 복구한 뒤 authoritative snapshot을 로컬
  cache에 overlay한다.
- 일반 save 호환성 세대를 2로 올리고, 서버 권위로 전환된 account는 구버전 save PUT으로
  경제 cache나 진행을 덮지 못하게 했다. 마이그레이션과 DB 통합 테스트를 통과했다.
- 독립 리뷰에서 확인된 rebase 뒤 경제 delegate 분리, 정상 패배 정산 누락, 연구 응답
  유실 뒤 중복 차감, 스테이지 11 최초 보상 유실을 수정했다. coordinator 재결속,
  progression effect 우선 복구, 저장 재연결 drain과 run별 최초 보상 증거를 회귀
  테스트로 고정했다.
- 경제 조회는 repeatable-read snapshot으로 묶고, 모든 경제 변경 API는 호환성 세대 2를
  요구한다. 유니크 모듈 분해 금지와 일간 수령 기록이 존재하는 006 rollback도 실제
  PostgreSQL에서 검증했다.

## 최근 구현 흐름

### 기존 카카오 인앱 브라우저 진행의 일회용 이전

- 카카오 WebView에 격리된 guest 저장을 15분짜리 URL fragment 토큰으로 외부
  Chrome/Safari에 전달하고 Google account에 귀속하는 임시 이행 흐름을 추가했다.
- 생성 요청은 canonical v2 저장 구조, 구매 다이아 0, 무료 재화·모듈 상한을 검사한다.
  기존 account 진행이 있으면 구매 다이아 0을 확인하고 현재 snapshot을 백업한 뒤
  writer generation을 교체해 오래된 PUT을 차단한다.
- 소비된 카카오 원문은 즉시 삭제하고 token/payload 해시와 결과 revision을 남긴다.
  기존 account를 교체한 영수증에는 복구용 이전 snapshot도 보존한다.
- 로컬 저장의 위변조·복제를 완전히 증명할 수 없는 구조적 한계 때문에 정식 배포 전
  제거 대상으로 확정했다. 제거 절차는 `docs/legacy_local_save_transfer.md`에 기록했다.

### 주간 보상 수령 서버 판정

- 주간 임무·전체 완료·주간 출석 수령을 클라이언트 직접 증가에서 인증된
  `POST /v1/economy/rewards/claim`으로 교체했다.
- 서버는 현재 save writer와 최신 account 저장을 같은 잠금 순서로 확인하고, 저장된
  주간 진행량·수령 표시와 KST 월요일 05:00 기준 서버 주차를 검증한다.
- 보상량과 모듈권 수는 클라이언트 요청에서 받지 않고 서버 고정 보상표로 결정한다.
- PostgreSQL `reward_claims`에 reward key, idempotency key, 요청 hash, writer
  generation, source save revision과 검증 증거를 보존한다. 같은 보상은 다른 기기나
  다른 key로 다시 요청해도 최초 영수증만 복구한다.
- Flutter는 수령 전 account 체크포인트 업로드와 idle 확인을 끝내고, 서버 영수증을
  받은 뒤에만 로컬 다이아·모듈권·수령 상태를 저장한다. guest와 오프라인 상태에서는
  보상을 확정하지 않는다.
- 이 구현은 주간 보상의 수령 판정만 서버화한 첫 수직 기능이다. 전체 지갑 원본,
  economy revision, legacy bootstrap과 나머지 다이아 증감 경로는 후속 범위다.

### 백엔드·인증·온라인 저장 설계 확정

- 게임 플레이와 로컬 저장은 서버 응답에 의존하지 않는 로컬 우선 구조로 결정했다.
- 클라이언트는 트랜잭션과 복구 단순성을 위해 `GameSaveData` 통파일을 유지하고,
  서버만 `preferences`, `progression`, `turretModules`, `activeRun` 영역으로 분리해
  PostgreSQL에 저장하도록 정했다.
- 서버는 Go 표준 `net/http`, `pgx/v5`, `sqlc`, `tern`, PostgreSQL 18을 채택했다.
- 스냅샷 저장은 HTTPS JSON API, revision 낙관적 동시성, idempotency key와 계정별
  단일 in-flight 전송을 사용한다. WebSocket과 서버 권위형 전투는 범위에서 제외했다.
- 다이아·결제·중요 일회성 보상은 실제 기능 도입 시 별도 명령 API와 원장으로
  승격하고, 일반 플레이 저장은 동기화 스냅샷으로 취급한다.

### 로컬 저장 v2와 배포 안전성

- 큰 저장 모델을 파일 단위로 분리하되 직렬화 결과는 v2 JSON 통파일로 유지했다.
- 최상위 저장 영역을 `preferences`, `progression`, `turretModules`, `activeRun`으로
  분리하고 포탑 모듈을 런 진행과 독립된 영역으로 이동했다.
- guest/account별 로컬 슬롯, v2 primary/backup, Web Local Storage와 application
  support 파일 저장을 추가했다.
- 배포된 legacy v1만 원본 보존 후 canonical v2로 이전하고, 미배포 중간
  v2 호환 경로는 제거했다. IO 저장은 원자적 교체를 사용한다.
- 일반 저장과 라운드 체크포인트 쓰기를 `LocalSaveCoordinator` 하나로 직렬화했다.
- `progression.totalPlayTimeMillis`에 배속과 무관한 실제 플레이 경과를 누적한다.
- account 로컬 저장과 원격 저장을 별도 사용자 진행으로 노출하지 않고, 하나의 Google
  계정 기록과 그 로컬 캐시로 취급한다.

### Go API와 PostgreSQL 저장 기반

- Docker Compose 기반 PostgreSQL, migrate, Go API 실행 환경과 health endpoint를
  추가했다.
- 계정, 외부 identity, session, refresh token, 영역별 온라인 저장과 요청 영수증
  스키마를 추가했다.
- `sqlc` 쿼리와 생성 코드, 실제 PostgreSQL 스키마·인증·저장 통합 테스트를
  구성했다.
- 인증된 `GET /v1/save`, `PUT /v1/save`에서 revision 검증, 멱등 요청 재생,
  영역별 저장을 하나의 DB 트랜잭션으로 처리하도록 구현했다.

### Google 웹 인증과 자체 세션

- GitHub Pages에서도 사용할 수 있도록 Google Identity Services 공식 버튼을 계정
  화면의 인게임 모달 안에 연결했다.
- Go 서버에서 Google ID token의 서명, audience와 만료를 검증하고 내부 account와
  Google identity를 생성·조회하도록 구현했다.
- opaque access/refresh token, refresh token 단일 사용 회전, 재사용 감지와 logout을
  추가했다. DB에는 토큰 원문 대신 SHA-256 해시만 저장한다.
- Flutter에는 메모리 세션, 만료 전 자동 갱신, single-flight와 인증 실패 시 401
  1회 재시도를 구현했다.
- Google 로그인과 refresh endpoint에 클라이언트별 token bucket 요청 제한과
  `Retry-After` 처리를 추가했다.

### Flutter 온라인 저장 worker와 영속 Outbox

- 원격 저장 요청을 `GameSaveData` 전체 스냅샷으로 직렬화하는 Flutter API
  클라이언트를 추가했다.
- 계정당 하나의 요청만 전송하고 대기 중 변경은 최신 체크포인트 하나로 합치는
  `OnlineSaveCoordinator`를 구현했다.
- timeout과 일시적 서버 오류는 같은 본문·idempotency key로 backoff 재시도하며,
  revision 충돌과 복구 불가능 오류는 자동 덮어쓰기 없이 정지한다.
- 계정 ID에 결속된 Outbox를 IO/Web 저장소에 영속화하고, HTTP 요청 전에 Outbox
  기록을 완료하며, 앱 재시작 뒤 in-flight와 retry 상태를 복구하도록 했다.
- 자동 연결된 account 슬롯에는 coordinator를 실제 게임에 주입하고, 라운드 종료
  체크포인트를 로컬 저장 성공 뒤 durable enqueue하도록 연결했다.
- 전송 중·재시도 대기·완료·충돌·차단 상태와 마지막 동기화 시각, 대기 저장 건수를
  계정 화면에 반영한다. 로그아웃이나 세션 종료 시 coordinator를 먼저 격리한다.
- 원격 진행을 적용하면 revision과 payload fingerprint를 초기 기준으로 사용해 같은
  스냅샷을 다시 올리지 않는다. 기존 미전송 Outbox는 새 기준으로 덮지 않고 coordinator가
  exact 요청부터 복구한다.

### 최초 로그인 자동 bootstrap과 슬롯 전환

- Google 로그인 직후 계정별 영속 Outbox를 먼저 확인하고, 있으면 원격 조회나 로컬
  교체보다 exact 요청·rebase 복구를 우선한다.
- 새 연결에서 원격 account 기록이 있으면 account 슬롯에 자동 적용하고, guest와 기존
  account primary는 backup에 명시적으로 보존한다.
- 원격 기록이 없으면 현재 guest 진행을 최초 account 진행으로 자동 이전한다. guest가
  없고 account cache만 남은 중단 복구 상황에서는 cache를 유지한다.
- 로컬·원격 저장 선택 dialog와 새 진행·나중에 연동 분기를 제거하고, 현재 진행 저장,
  최신 계정 진행 조회, account 게임 준비의 단계별 overlay만 표시한다.
- bootstrap이 끝나면 account 슬롯을 다시 로드한 새 게임 상태로 교체하고, 저장이 전혀
  없는 신규 account만 초기 저장을 생성한다.
- 원격 조회나 적용이 실패하면 guest 진행을 유지하고 계정 화면에서 다시 시도할 수
  있다. 로그아웃이나 세션 종료 시 account 저장을 보존한 뒤 guest 슬롯으로 복귀한다.

### 다중 기기 저장 정책 전환

- 영구적인 계정당 1기기 제한 대신 여러 기기 로그인을 허용하기로 했다.
- 기존의 로컬·원격 저장 사용자 선택과 충돌 해결 UI 방향은 폐기하고, exact in-flight
  요청을 먼저 확인한 뒤 실제 충돌이면 서버 최신 revision을 자동 적용하기로 했다.
- 여러 기기의 반복 저장 충돌을 줄이기 위해 한 번에 한 인증 session만 save writer
  generation을 가지도록 설계했다. 새 기기가 writer를 획득하면 이전 기기는 다음 서버
  접점의 안전 지점에서 원격 진행을 복구한다.
- 원격 적용 전 로컬 backup, crash-safe rebase journal, Web 다중 탭 잠금, 구버전
  전체 snapshot 덮어쓰기 방지를 필수 안전장치로 확정했다.
- API, PostgreSQL, canonical Outbox, 상태 전이와 테스트 계약은
  `docs/multi_device_save_sync_design.md`에 상세화했다.

### Canonical Outbox와 다중 기기 자동 재기준화

- 기존 빠른 payload fingerprint를 canonical 저장 JSON의 SHA-256으로 교체하고,
  IO/Web Outbox에 exact in-flight와 rebase journal을 함께 영속화했다. 이 기능은 원격에
  배포된 적이 없으므로 작업 브랜치 안에서만 존재하던 v1→v2 호환 분기와 버전별 저장
  위치는 제거하고 `outbox.json`/단일 Web key의 최초 공개 형식 하나로 정리했다.
- 앱 시작·재개 시 exact in-flight를 원격 조회보다 먼저 같은 본문과 idempotency key로
  재전송한다. 그 뒤 기준 revision과 원격 revision을 비교해 로컬 변경 업로드 또는 원격
  자동 rebase를 결정한다.
- 원격 revision이 앞서면 일반 순환 backup과 분리된 충돌 backup을 먼저 만들고,
  `prepared → backupPreserved → payloadApplied` rebase journal을 영속화한다. 종료 시점에
  따라 다음 실행에서 같은 단계를 안전하게 이어간다.
- 원격 rebase 확정 즉시 기존 게임의 로컬 저장 scheduler와 게임 입력을 정지시키고,
  적용 완료 뒤 같은
  account 슬롯에서 게임 상태를 다시 생성해 메모리와 파일 기준이 어긋나지 않게 했다.
- Go `GET /v1/save`에 revision ETag와 304 응답을 추가하고 Flutter 시작 판정은
  `If-None-Match` 조건부 조회를 사용한다.

### 단일 save writer generation

- PostgreSQL `save_writer_states`, `save_writer_claims`와 save receipt의 generation을 기존
  미배포 온라인 저장 스키마에 통합했다.
- `POST /v1/save/writer`는 claim key·본문을 영수증으로 보존하고, `PUT /v1/save`는 인증
  session과 `Rune-Nexus-Save-Writer`가 현재 generation인지 revision 검사 전에 확인한다.
- 이미 성공한 exact PUT은 writer 교체 뒤에도 영수증 성공을 반환하지만 이전 writer의
  새 PUT은 `SAVE_WRITER_REPLACED`로 거부한다.
- Flutter는 claim 요청도 Outbox에 먼저 기록하며 교체 시 자동 탈환하지 않고
  `suspended`로 전환한다. 실제 foreground 복귀에서만 새 generation을 얻고 원격을 다시
  확인한다.
- writer 교체가 확인되면 로컬 저장과 게임 입력을 멈추고, 새 generation과 최신
  원격 진행 확인이 끝날 때까지 복구 overlay를 표시한다.
- Web 앱 진입 전에 exclusive Web Lock을 획득하며 두 번째 탭은 게임과 저장소를 만들지
  않고 안내 화면을 표시한다.

### 저장 클라이언트 호환성 게이트

- writer claim과 저장 PUT에 정수 `clientCompatibilityVersion`을 포함한다. 서버 최소
  버전 미만 claim은 service·DB 호출 전에 차단하고, PUT은 과거 exact 성공 영수증만
  조회한 뒤 영수증이 없을 때 `426 CLIENT_UPDATE_REQUIRED`로 차단한다.
- writer claim만 검사하면 이미 실행 중인 구버전 writer가 계속 저장할 수 있으므로
  실제 PUT에도 같은 검사를 적용했다. 서버가 현재 지원하는 세대보다 미래 버전인 요청도
  별도 422 오류로 거부한다.
- Flutter는 426을 받으면 exact writer claim 또는 in-flight 저장을 Outbox에 보존하고
  로컬 저장·계정 플레이를 멈춘 뒤 업데이트 안내를 표시한다.
- 업데이트된 Flutter는 이전 호환 버전 Outbox도 읽는다. 과거 claim은 현재 버전으로
  다시 획득하고, 과거 in-flight는 exact 영수증을 먼저 확인한다. 미처리 요청이면
  로컬 진행을 유지한 채 최신 원격 revision에 재기준화하여 새 key·본문으로 저장한다.
- GitHub Pages 빌드에는 진단용 `web:<git-sha>` build ID를 주입하며 실제 허용 여부는
  문자열이 아닌 호환 버전 정수로 판정한다.

### 서버 권위 경제 경계 확정

- 전투와 일반 진행은 로컬 우선으로 유지하고, 다이아·모듈권·뽑기 횟수·소유 모듈과
  관련 보상 수령만 하나의 서버 권위 경제 영역으로 묶기로 했다.
- 가챠 RNG만 서버화하는 방식은 퀘스트·출석·다이아 운반 적·분해·연구 소비 같은
  로컬 우회 경로를 남기므로 채택하지 않았다.
- 일반 save revision과 economy revision을 분리하고, 가챠·분해는 계정 DB 잠금과
  멱등 영수증으로 처리한다. 소비 명령은 오프라인 예약하지 않고 전송 결과가 불명확한
  exact 요청만 복구한다.
- 기존 플레이테스트 데이터는 서버의 최신 account snapshot에서 계정당 한 번만
  bootstrap한다. 구매 증명이 없는 기존 paid 값은 무료 다이아로 이전한다.
- 서버 경제 구현은 save 자동 rebase와 writer generation을 먼저 완성한 뒤 기능 플래그
  뒤에서 진행하고, 모든 다이아 변이 경로가 준비된 시점에 account 단위로 전환한다.
- DB, API, Flutter coordinator, 저장 v3 migration과 테스트 계약은
  `docs/server_authoritative_economy_design.md`에 상세화했다.
- 독립 검증에서 확인된 필수 위험을 반영해 런 보상은 종료 시 1회 정산으로 제한하고,
  reward claim에는 expected economy revision을 쓰지 않으며, bootstrap/save PUT의 전역
  잠금 순서를 고정했다. 연구 즉시 완료는 서버 pending effect와 save ack로 복구하고,
  writer 교체 분기·catalog version·DB restore authority epoch 계약도 추가했다.

### 자체 운영 HTTPS 배포 기반

- 무료 관리형 서비스에 의존하지 않고 ipTIME 공유기 뒤의 자체 서버를 공개하는
  방향을 채택했다.
- Caddy reverse proxy, production Compose overlay, 보안 헤더와 인증 endpoint 요청
  제한 구성을 추가했다.
- DuckDNS token을 Docker secret으로 격리하고 공인 IPv4 갱신·재시도·상태 감시를
  production Compose에 통합했다. 갱신기 장애는 Caddy 재시작을 차단하지 않는다.
- DNS, 80/443 포트 포워딩, CGNAT 확인, Google OAuth origin, GitHub Pages CORS와
  Actions Variables 설정 절차를 문서화했다.
- `runenexus-api.duckdns.org`의 실제 DNS, Caddy 공개 인증서, API 준비 상태와 GitHub
  Pages CORS를 확인하고 Google OAuth Web Client·본인 테스트 사용자·Actions
  Variables를 연결했다.
- 운영 전 남은 항목은 실제 Google 계정 로그인·저장 공개 E2E, DB backup·restore
  자동화, 계정 데이터 삭제와 Android PGS 인증이다.

### 디버그 맵 에디터

- 디버그 플래그가 켜진 빌드에서만 접근 가능한 맵 에디터 화면을 추가했다.
- 메인 화면의 일반 탭과 분리해 별도 화면으로 진입하고, 뒤로가기 버튼으로 메인 화면으로 복귀한다.
- 에디터에서는 스테이지 선택, 맵 가로/세로 크기 조절, 타일 브러시, 경로 편집, export 표시를 제공한다.
- 스테이지 선택은 챕터 탭을 먼저 고른 뒤 해당 챕터의 5개 스테이지 범위만 수정하는 방식이다. 챕터 1은 스테이지 1~5, 챕터 2는 스테이지 6~10, 챕터 3은 스테이지 11~15다.
- 에디터 보드와 브러시 미리보기는 선택한 스테이지의 `MapTileTheme`를 따라 실제 배치 타일에 가까운 색과 장식을 보여준다.
- 스테이지를 오가도 같은 에디터 세션 안에서는 각 스테이지의 미저장 드래프트를 유지한다.
- 경로 편집은 `path`, `spawn`, `core` 타일 위에만 waypoint를 찍을 수 있다.
- 한 칸씩 모두 찍지 않아도 같은 행 또는 같은 열의 비인접 waypoint를 허용한다.
- 대각선 waypoint 구간은 적이 대각선으로 이동하지 않도록 추가와 검증 단계에서 차단한다.
- export는 저장 파일을 직접 쓰지 않고 `MapDefinition` Dart 코드 텍스트를 표시하는 방식으로 정리했다.

### 메인 메뉴 테스트 패널

- 디버그 플래그가 켜진 빌드에서만 접근 가능한 메인 메뉴 테스트 패널을 추가했다.
- 메뉴 상태에서 룬 추가/초기화, 클리어 스테이지 범위 변경, 연구 초기화를 바로 실행할 수 있다.
- 클리어 스테이지 변경은 `1~N` 스테이지를 클리어 처리하고 다음 스테이지를 해금하는 테스트용 흐름이다.

### 챕터 2 맵 변형

- 스테이지 6~10은 스테이지 1~5의 크기감과 타일 밀도를 참고하되, 경로가 동일하지 않도록 별도 맵 정의를 사용한다.
- 챕터 2 맵은 모두 균열 장막 `MapTileTheme`를 유지하며, 스폰과 코어 위치 및 경로 흐름을 각 스테이지별로 다르게 구성했다.

### 챕터 3 공명 용광로 추가

- 스테이지 11~15는 공명 용광로 구간으로 분리하고, 검은 금속과 과열 균열을 쓰는 `chapterThreeForgeTileTheme`를 적용했다.
- 챕터 3 맵은 신규 적 타입 없이 장갑병, 탱커, 보호막병, 빠른 적, 보스 조합만으로 압박 축이 달라지도록 별도 구조를 사용한다.
- 스테이지 11은 입문, 12는 긴 직선, 13은 좁은 목, 14는 급회전, 15는 코어 앞 압축 역할로 나눴다.
- 메인 메뉴 챕터 배너와 맵 에디터 export도 챕터 3 용광로 테마를 반영한다.

### 스테이지 맵과 저장 마이그레이션

- 스테이지 1 맵을 새 `8 x 10` 정의로 교체했다.
- 스테이지 2는 별도 맵 정의를 사용하도록 분리했다.
- 저장 데이터에 현재 맵의 지문값을 함께 저장한다.
- 활성 런 저장 데이터의 맵 지문이 현재 스테이지 맵과 다르면 기존 포탑을 복원하지 않는다.
- 맵 변경으로 복원되지 않는 포탑은 설치/레벨업/링크 확장 비용을 100% 골드로 환불한다.
- 장착 젬과 선택 특성에 사용한 젬 파편도 함께 복구한다.
- 맵 변경 감지 후에는 전투 상태를 준비 단계로 되돌리고 즉시 저장해 같은 마이그레이션이 반복되지 않도록 했다.

### 전투 거리와 화면 크기 보정

- 포탑 사거리, 적 이동속도, 투사체 속도, 폭발 반경을 보드 타일 크기 기준으로 보정했다.
- 작은 화면에서 포탑 사거리가 맵을 과도하게 덮거나, 이동속도 체감이 달라지는 문제를 줄였다.
- 선택한 포탑과 설치 후보 타일의 사거리 표시를 강화했다.

### 포탑 성장과 젬 효과 정리

- 포탑 레벨업의 피해와 연사 속도 성장을 곱연산으로 정리했다.
- 사거리 성장은 레벨 기준 합산 배율로 적용하고, 사거리 젬은 20% 증폭으로 정리했다.
- 젬 문구에서 곱연산 효과는 `증폭` 표현을 사용하도록 맞췄다.
- 폭발 젬은 기존 폭발 포탑의 피해 배율을 낮추지 않고 폭발 반경을 강화하도록 조정했다.
- 일반 포탑에 폭발 젬을 장착하면 작은 폭발 범위와 시각 이펙트를 부여했다.

### 환불 기능

- 선택한 포탑을 환불하는 기능을 추가했다.
- 설치 비용, 레벨업 비용, 링크 확장 비용을 포함한 투자 골드의 75%를 반환한다.
- 환불 전 확인 팝업을 띄운다.
- 장착 젬은 인벤토리로 반환한다.
- 전투 중 환불도 허용하되, 화상 지속피해 소유 연결과 피해 집계가 꼬이지 않도록 정리했다.

### 스테이지와 웨이브 조정

- 스테이지 증가에 따른 적 체력 보정을 추가했다.
- 실제 스폰 체력과 하단 적 미리보기 체력이 같은 계산식을 사용하도록 맞췄다.
- 보스는 10라운드마다 등장하되 모든 보스 웨이브에서 1마리만 등장하도록 정리했다.
- 보스 웨이브 순서를 `탱커 -> 빠른 적 -> 보스`로 바꿔 보스가 마지막 압박으로 등장하게 했다.

### 전투 감각 조정

- 포탑 발사 후 다음 쿨타임에 `-5% ~ +5%` 랜덤 배율을 적용했다.
- 첫 발은 즉시 발사 가능하도록 유지해 조작 반응성을 유지했다.
- 같은 연사 속도의 포탑들이 지나치게 동시에 발사되는 느낌을 완화했다.

### 결과와 진행 루프

- 결과 화면에서 신기록과 신규 스테이지 해금 정보를 강조했다.
- 최고 피해 포탑과 획득 룬을 결과 화면에 표시했다.
- 스테이지 메뉴에서 진행 종료 시 예상 룬 보상을 보여주고 확인을 받도록 했다.
- 디버그 젬 패널은 환경 플래그가 켜진 빌드에서만 노출되도록 정리했다.

### 문서 구조 정리

- README는 게임 소개와 개발 진입점 중심으로 정리했다.
- 현재 구현 세부는 `docs/implementation_status.md`에 유지한다.
- 현재 규칙과 밸런스 수치는 `docs/gameplay_balance_reference.md`로 분리했다.
- 초기 계획과 향후 방향은 `docs/mvp_work_plan.md`에 남겼다.
- 다음 작업 후보는 `docs/next_work_priorities.md`에 정리했다.
