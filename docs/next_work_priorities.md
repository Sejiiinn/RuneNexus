# Rune Nexus 다음 작업 우선순위

마지막 정리 기준: 2026-09-05 인증 세션 복원 반영. 콘텐츠 백로그는 기존 기준 유지.

## 목적

이 문서는 새 세션에서도 현재 개발 트랙과 독립적인 콘텐츠 백로그를 구분해 이어받기
위한 기준 문서다.

현재 Rune Nexus는 기본 게임 MVP와 로컬 저장을 유지하면서 Google 웹 로그인,
Go/PostgreSQL 인증·저장 API와 Flutter 온라인 저장 전송 worker를 실제 계정 플레이의
라운드 체크포인트까지 연결했다. exact in-flight 우선 복구, 단일 canonical Outbox와 실제
다중 기기 충돌의 원격 revision 자동 적용, save writer generation까지 구현했다. 현재
최초 연결의 사용자 선택형 UX는 원격 account 우선 자동 bootstrap으로 교체했다. 현재
writer 획득·PUT 공통 client compatibility gate까지 적용했다. 최우선 트랙은 공개
HTTPS API와 same-site Web 도메인을 준비하고 Android와 공유할 계정 저장·세션 복원 경로를
검증하는 것이다. 세션 복원 구현은 완료됐으며 운영 적용과 실제 계정 E2E가 남아 있다.
그다음 트랙은 다이아·모듈권·소유 모듈을 서버 권위 경제 영역으로 전환하는 것이다.
구현 계약은 `docs/server_authoritative_economy_design.md`를 따른다.
콘텐츠 작업은 이 연결 작업과 책임 경계가 겹치지 않는 경우 병행할 수 있다.

기존 카카오 인앱 브라우저 테스터용 일회용 진행 이전은 구현돼 있다. Google 연결을
먼저 완료한 기존 테스터에 한해 현재 account snapshot을 백업한 뒤 카카오 진행으로
교체하는 임시 예외도 허용하지만 정식 기능으로 유지하지 않는다. **정식 배포 게이트에는
`docs/legacy_local_save_transfer.md`의 제거 체크리스트 완료를 반드시 포함한다.**

## 현재 판단

계정·온라인 저장 기반에서 완료된 항목은 다음과 같다.

- `GameSaveData` v2 영역 분리와 guest/account별 로컬 슬롯
- 배포된 legacy v1 원본 보존 마이그레이션과 canonical v2 primary/backup 복구
- Go `net/http`, PostgreSQL, pgx/sqlc/tern 서버 기반
- Google 웹 로그인, 자체 access/refresh 세션과 로그아웃
- Android Credential Manager Google 로그인, Keystore 암호화 저장과 native HTTP transport
- Web HttpOnly 쿠키·앱 시작 영속 세션 복원과 account 전용 자동 bootstrap
- 무만료 DB 세션·10분 암호화 갱신 receipt·동일 요청 재시도와 logout 의도 복구
- 인증 요청 제한, 세션 single-flight 갱신과 401 1회 재시도
- 인증된 `GET/PUT /v1/save`, revision, 멱등성과 DB 트랜잭션
- 계정당 단일 in-flight 온라인 저장 worker와 최신 pending 병합
- SHA-256 기반 계정별 단일 canonical Outbox, 재시작 복구와 backoff
- exact in-flight 우선 복구, 별도 충돌 backup과 단계별 자동 rebase
- revision ETag 조건부 조회와 원격 적용 뒤 계정 게임 재로딩
- 원격 account 우선 자동 bootstrap과 선택형 저장 UI 제거
- 기존 Outbox 우선 복구, guest/account 원본 backup과 account 슬롯 자동 적용
- 자동 연결된 account 슬롯 재로딩과 로그아웃 시 guest 슬롯 복귀
- 연결된 account에 `OnlineSaveCoordinator` 주입과 중요 체크포인트 전송
- 동기화 중·오프라인 재시도·완료·충돌·차단 상태와 마지막 동기화 시각 표시
- Caddy 기반 자체 운영 HTTPS 배포 구성
- writer claim 영수증·generation DB/API와 이전 writer의 새 저장 거부
- Flutter writer claim exact 복구, generation 포함 PUT과 foreground 재획득
- writer 교체 후 로컬 저장·게임 입력 정지와 최신 진행 복구 overlay
- Web Locks exclusive local writer와 두 번째 탭 부팅 차단
- writer claim·PUT 공통 client compatibility gate, 426 저장 정지와 업데이트 안내 UX
- 업데이트 뒤 이전 호환 버전 Outbox의 claim 재획득과 exact PUT 영수증 hit/miss 전환
- GitHub Pages 배포물의 Web Git SHA build ID 주입

아직 실제 게임 연결에서 해결해야 하는 항목은 다음과 같다.

- Web 다중 탭 종료 알림용 BroadcastChannel
- 007 마이그레이션·고정 영수증 키·same-site 도메인 적용 후 Google 계정 E2E 검증
- Web 새로고침·Android 재시작 복원과 실제 쿠키/Keystore·Google 계정 선택 QA
- 로그인 필수화는 아직 미적용이며 인증 복원과 별도 후속 범위
- Android PGS v2와 기존 account identity 연결

콘텐츠 측에서는 최근 작업으로 다음 약점이 상당 부분 해소됐다.

- 결과 화면의 신기록/신규 해금 강조
- 진행 종료 시 예상 룬 보상 확인
- 릴리즈 빌드의 디버그 패널 기본 비노출
- 전투 중 환불과 환불 확인 팝업
- 화면 크기 기반 사거리/속도 보정
- 스테이지별 적 체력 보정
- 스테이지 1~5별 맵 정의 분리
- 스테이지 1~5 생명력 기반 웨이브, 스테이지 6~10 보호막 웨이브, 스테이지 11~15 장갑/탱커 웨이브 분리
- 스테이지 선택 화면의 1스테이지 경제 강화, 2스테이지 연구, 3스테이지 저격/조준경, 10스테이지 장갑 관통 보상 표시
- 포탑별 1차/2차 특성 선택과 전투 효과
- 특성 후보 첫 선택 상태와 같은 후보 재선택 확정 흐름
- 저격 포탑 1차/2차 특성 선택지
- 포탑별 공격 명령 우선순위와 `전술 명령` 연구 게이트
- 보스 웨이브 순서, 호위 몹, 보스 수 정리
- 공통 게임 UI 컴포넌트 기반의 주요 화면 정리
- 메인 메뉴 스테이지/강화/연구 화면의 모바일 폭 대응
- 저장된 진행 카드와 이어서 진행 버튼의 과도한 색상 강조 완화
- 전투 하단 포탑/업그레이드/젬 탭의 금속 프레임형 버튼화
- 배속 버튼 라벨 중앙 정렬
- 포탑 모듈 탭, 선택 포탑 대상 1회/5회 뽑기, 3부위 장착, 랜덤 옵션, 분해와 저장/복구

남은 콘텐츠 핵심 약점은 다음과 같다.

- 포탑 모듈의 기본 성장 루프는 구현됐지만, 모듈권 수급과 다이아 보충 비용, 등급/옵션 확률, 분해 환급이 실제 반복 플레이에서 적절한지는 아직 검증이 부족하다.
- 챕터 2~3 클리어 보상과 연구 조건의 1차 연결은 들어갔다. 다음 최우선 과제는 실제 플레이에서 해금 체감, 연구 비용, 젬 등장 타이밍이 맞는지 검증하는 것이다.
- 스테이지 2~5는 챕터 1 후반 구간으로 묶어도 된다. 신규 몹이나 신규 기믹 없이 스테이지 3~5의 웨이브만 억지로 갈라봤자 체감 차이가 작다.
- 영구 업그레이드는 정비 보급, 기초 화력 훈련, 처치 보상, 긴급 매각까지 확장됐지만, 해금 단계와 젬/링크 계열 선택지는 아직 얕다.
- 젬 파편과 포탑 특성 시스템은 구현됐지만, 수급량과 비용 곡선은 아직 장기 검증이 부족하다.
- 젬 선택지가 빌드와 맞지 않을 때 대체 선택지는 생겼지만, 특정 빌드를 장기적으로 밀어주는 영구 성장 축은 아직 얕다.
- 후반 골드 인플레를 받아줄 상위 포탑 해금과 포탑 계열 연구 트리의 장기 구조가 아직 없다.
- 보스 호위 웨이브로 기본 압박은 생겼지만, 보스 전용 피드백과 긴장감은 아직 약하다.
- 40라운드 장기 진행 기준 보상/난이도 곡선은 더 검증해야 한다.
- `RuneNexusGame`이 입력, 전투, 저장, 선택 상태, 진행 정산을 함께 담당해 장기적으로 커질 위험이 있다.

## 현재 개발 트랙: 계정·온라인 저장 연결

### 1. 최초 로그인 자동 bootstrap과 backup — 구현 완료

Google 로그인 뒤 사용자의 저장 선택 없이 account 진행을 자동 확정한다.

작업 범위:

- [x] 기존 Outbox가 있으면 원격 조회·로컬 교체 전에 coordinator 복구를 우선
- [x] 원격 account 저장이 있으면 account 슬롯에 자동 적용
- [x] 원격 저장이 없으면 guest 진행을 최초 account 진행으로 자동 이전
- [x] guest가 없고 account cache만 남아 있으면 account cache를 보존형 복구
- [x] 복사·적용 전에 guest와 기존 account 원본 backup 생성
- [x] 연결 실패 시 guest 진행과 기존 Outbox를 변경하지 않는 복구 경로
- [x] 연결 진행 상태 overlay와 account 슬롯 자동 재로딩
- [x] 사용자 저장 선택 dialog와 선택 전용 문구·분기 제거

성공 기준:

- 원격 account 저장이 있으면 항상 가장 최신 account 진행을 사용한다.
- 원격 저장이 없는 최초 연결에서만 guest 진행을 account로 이전한다.
- 기존 Outbox와 exact in-flight가 새 bootstrap 기준으로 덮이지 않는다.
- 실패해도 guest 원본을 잃지 않고 계정 화면에서 다시 시도할 수 있다.

정상 로그인 경로에는 로컬·원격 저장 선택이 없다. 연결 중에는 현재 진행 저장, 최신
계정 진행 조회, account 게임 준비 상태만 표시한다.

### 2. 실제 게임 저장 연결과 다중 기기 자동 복구 — 단계 A 기술 경로 완료

자동 bootstrap이 완료된 account에 `OnlineSaveCoordinator`를 생성하고 기존 로컬
체크포인트 뒤에 비동기 전송을 연결한다.

작업 범위:

- [x] account ID에 결속된 Outbox repository와 원격 revision 초기화
- [x] 로컬 저장 성공 뒤 coordinator에 최신 체크포인트 전달
- [x] 전송 중, 재시도 대기, 동기화 완료, 충돌, 차단 상태를 계정 화면에 표시
- [x] `SAVE_REVISION_CONFLICT`에서 클라이언트 로컬의 원격 덮어쓰기 금지
- [x] exact in-flight 요청의 동일 본문·멱등성 key 우선 재전송
- [x] 원격 revision이 앞선 실제 충돌의 별도 backup·자동 rebase
- [x] rebase journal, 강제 종료 복구와 계정 게임 상태 재로딩
- [x] SHA-256 payload hash와 배포 전 중간 형식을 제거한 단일 canonical Outbox
- [x] revision ETag와 `If-None-Match` 조건부 조회
- [x] 단일 save writer generation API·DB
- [x] Web 다중 탭 local writer 잠금
- [x] writer claim·PUT 공통 client compatibility gate와 업데이트 필요 UX
- [x] 업데이트 뒤 이전 Outbox의 writer 재획득과 exact PUT 영수증 hit/miss 롤오버
- [x] 로그아웃·계정 변경 시 coordinator 종료와 account별 Outbox 격리

기존 Outbox에 exact in-flight가 있으면 새 기준을 만들기 전에 같은 요청을 먼저
재전송한다. 이후 원격 revision이 앞서면 현재 account 로컬을 일반 backup과 분리된
충돌 backup에 보존하고, 단계별 rebase journal을 거쳐 원격 데이터를 적용한다. rebase
확정 즉시 기존 게임의 로컬 저장 writer와 입력을 정지시키고 완료 뒤 같은 account 슬롯에서
게임 상태를 다시 만든다. 상세 계약은 `docs/multi_device_save_sync_design.md`를 따른다.

성공 기준:

- 오프라인·느린 연결에서도 플레이와 로컬 저장이 막히지 않는다.
- 같은 요청의 timeout 재시도는 본문과 idempotency key를 유지한다.
- 재시작 후 미전송 저장이 복구되며 다른 계정으로 전송되지 않는다.
- 실제 충돌이면 사용자 선택 없이 원격 revision이 적용된다.
- 이전 writer나 오래된 revision이 현재 원격 저장을 덮어쓰지 않는다.

### 3. 공개 환경 E2E와 운영 안전장치

자체 운영 HTTPS API와 같은 사이트의 Web(예: Pages 커스텀 도메인)을 연결해 Google 계정
하나로 로그인·저장·새로고침 뒤 자동 복원·저장 재조회까지 검증한다. 기본 `github.io`와
`duckdns.org` 조합은 현재 쿠키 정책과 맞지 않으므로 CORS만으로 통과 처리하지 않는다.

작업 범위:

- [x] DuckDNS secret 기반 공인 IPv4 자동 갱신·재시도와 상태 감시
- [x] Caddy, ipTIME 포트 포워딩, 실제 DNS 응답과 TLS 인증서 확인
- [x] Google OAuth Authorized JavaScript origin과 서버 CORS exact origin 확인
- [x] GitHub Actions Variables의 Web Client ID와 API base URL 확인
- [x] 로컬 세션 복원·응답 유실·시작 실패 경계 테스트와 Web/APK 빌드
- 007 적용, `AUTH_SESSION_RECEIPT_KEY` 고정 보관, same-site 도메인·최종 OAuth/CORS 재확인
- Android applicationId·서명 SHA·Web server client ID 확인과 실제 로그인·재시작 복원
- 로그인, refresh, logout, `GET/PUT /v1/save` 실제 네트워크 검증
- 지원 버전의 writer/PUT 성공과 구버전 426 차단 실제 네트워크 검증
- 호환 버전 강제 상승 뒤 기존 Outbox의 영수증 hit/miss 롤오버 검증
- 느린 네트워크, API 재시작, DB 재시작과 Outbox 복구 검증
- DB backup·restore 절차와 계정·원격 데이터 삭제 경로 마련

### 4. Android PGS와 다중 identity 연결

Web·Android 일반 Google 로그인과 영속 세션의 공개 검증 뒤 Android PGS v2를 추가한다.
현재 Credential Manager 구현을 PGS 구현 완료로 간주하지 않는다.

작업 범위:

- 출시 Application ID·서명 확정
- Kotlin PGS v2 로그인과 Flutter MethodChannel
- server auth code 교환과 PGS Player ID 검증
- 기존 account에 Google/PGS identity를 명시적으로 추가하는 연결 API
- 이미 다른 account에 연결된 identity의 충돌 처리
- Android 내부 테스트 배포와 실제 계정 QA

### 5. 서버 권위 경제 — 주간 보상 수령 판정 1차 구현

일반 전투와 진행은 계속 로컬에서 처리한다. 다이아·모듈권·뽑기 횟수·소유 모듈과
관련 보상 수령만 별도 economy revision과 명령 API로 처리한다.

선행 조건:

- save 자동 rebase와 writer generation
- 구버전 client compatibility gate — 완료
- 공개 HTTPS 인증·저장 기본 E2E

구현 범위:

- [x] 최신 account 저장과 서버 주차를 검증하는 주간 보상 claim 영수증
- authority epoch, `player_economies`, `player_modules`, 명령 영수증·원장·보상 수령
  스키마
- 기존 account snapshot의 계정당 1회 bootstrap
- 가챠·분해·연구 다이아 소비와 보상 claim API
- Flutter economy cache, exact 소비 in-flight, progression effect journal과 reward claim
  outbox
- 저장 v3의 economy cache와 모듈 장착 ID 분리
- 모든 경제 경로 완성 뒤 account 단위 일괄 전환

가챠만 먼저 서버 권위로 켜지 않는다. 전환 중 같은 잔액에 로컬·서버 writer가 동시에
존재하지 않도록 전체 기능을 플래그 뒤에서 완성한 다음 한 번에 활성화한다.

## 콘텐츠 백로그 우선순위

### 1. 포탑 모듈 획득/성장 곡선 검증

가장 먼저 추천하는 작업이다. 기본 기능은 구현되어 있으므로 새 시스템 추가보다 실제 획득 속도와 유효 보상 체감을 먼저 확인한다.
설계와 현재 규칙은 `docs/turret_module_design.md`에 유지한다.

작업 후보:

- 스테이지 11 최초 클리어 모듈권 5장과 주간 임무 보상의 실제 수급 속도 점검
- 모듈권 부족분 1장당 다이아 40개 보충 비용 점검
- 현재 선택한 포탑만 뽑히는 규칙이 목표 포탑 육성 의도를 충분히 보장하는지 확인
- 선택 포탑 안에서 무작위로 결정되는 코어/포신/프레임 부위 분포와 체감 점검
- 일반/마법/희귀/유니크 등급 확률과 옵션 개수·수치 분포 점검
- 낮은 등급과 비유효 옵션이 연속될 때 분해 환급만으로 실패 체감이 완화되는지 확인
- 필요성이 확인될 때만 천장, 등급 보정, 부위 지정 같은 후속 안전장치 검토

이유:

- 포탑 종류까지 무작위였던 것으로 잘못 가정하면 실제보다 목표 육성 통제감을 낮게 평가하게 된다.
- 현재 구조의 핵심 무작위성은 포탑 종류가 아니라 부위, 등급, 옵션에 있으므로 검증 초점을 그 구간에 맞춰야 한다.
- 새 기능을 더하기 전에 현재 수급과 분해 경제를 확인해야 과도한 보정이나 재화 인플레를 피할 수 있다.

관련 파일:

- `docs/turret_module_design.md`
- `lib/ui/menu/main_menu_turret_modules.dart`
- `lib/game/rune_nexus_game.dart`
- `lib/game/systems/run_progression.dart`
- `lib/data/definitions/game_turret_module_data.dart`
- `lib/data/save/game_save_data.dart`
- `test/turret_module_test.dart`
- `test/main_menu_turret_module_test.dart`

### 2. 챕터 2~3 보상·연구 흐름 검증과 보완

설계 기준은 `docs/chapter2_wave_enemy_design.md`에 유지한다.
보호막병 시각/역할 기준은 `docs/prototypes/shielded_enemy_design_preview.html`에 정리했다.
챕터 3의 맵/웨이브 범위는 `docs/chapter3_forge_design.md`에 유지한다.

작업 후보:

- 스테이지 7~9와 15에 연결된 연구·영구 강화 해금의 실제 체감 점검
- 챕터 2 첫 클리어부터 기존 스테이지별 해금까지 안내 흐름 점검
- 챕터 3 첫 클리어 또는 최종 클리어 보상에서 비어 있는 장기 성장 목표만 보완
- 보호막병이 기존 포탑, 젬, 링크, 특성 선택을 어떻게 다르게 요구하는지 실제 플레이로 검증
- 장갑/탱커 압축 웨이브가 중화기, 장갑 관통, 링크 확장 선택지를 충분히 요구하는지 실제 플레이로 검증
- 챕터 1 스테이지 2~5는 맵, 스테이지 보정, 해금/연구 조건 중심으로 유지
- 챕터 2~3 스테이지 6~15의 보상 흐름과 연구 안내를 정리

이유:

- 신규 몹 없이 스테이지 3~5 웨이브만 바꾸면 비율과 간격 조정에 머물 가능성이 크다.
- 플레이어가 새 구간에 들어왔다는 체감은 챕터별 몹 역할과 웨이브 압박이 보상/연구 목표와 이어질 때 더 분명하다.
- 스테이지 2~5를 챕터 1 후반 구간으로 유지하면 현재 콘텐츠를 억지로 벌리지 않고, 다음 큰 변화를 더 선명하게 준비할 수 있다.

관련 파일:

- `docs/chapter2_wave_enemy_design.md`
- `docs/chapter3_forge_design.md`
- `docs/prototypes/shielded_enemy_design_preview.html`
- `lib/data/definitions/game_stage_data.dart`
- `lib/data/definitions/game_stage_waves.dart`
- `lib/data/definitions/game_enemy_data.dart`
- `lib/domain/enemy/enemy_type.dart`
- `lib/domain/stage/stage_definition.dart`
- `lib/ui/menu/main_menu_screen.dart`
- `test/game_balance_test.dart`
- `test/main_menu_stage_detail_test.dart`

### 3. 연구/영구 성장 해금 단계 정리

작업 후보:

- 현재 연구 6종의 해금 스테이지, 룬 비용, 연구 시간 검토
- 젬 파편 수급량과 젬 구매/포탑 특성 비용 곡선 점검
- 채굴 자원, 자원 타일, 포탑 계열 연구 트리 설계
- 후반 상위 포탑 해금 구조 설계
- 영구 업그레이드 Lv1/Lv2 목록 구조 설계
- 첫 링크 확장 비용 감소
- 특정 포탑 비용 감소
- 보상 룬 증가
- 첫 젬 보상 개선
- 시작 시 랜덤 젬 1개 지급
- 기존 정비 보급/기초 화력 훈련 비용 곡선 검토

이유:

- 실패 후 다음 판의 선택을 바꾸게 만드는 메타 성장 축이 필요하다.
- 현재는 직접 수치 보정 위주라 젬/링크 선택을 바꾸는 성장 축이 부족하다.
- 챕터 2 진입 전 연구와 영구 성장의 역할을 정리해야 신규 몹/웨이브 변화가 해금 구조와 자연스럽게 이어진다.
- 젬 파편/포탑 특성 초안은 `docs/gem_shard_trait_design.md`를 기준으로 한다.
- 장기 성장, 채굴 자원, 상위 포탑 해금 방향은 `docs/long_term_progression_direction.md`를 기준으로 한다.

관련 파일:

- `lib/game/systems/run_progression.dart`
- `lib/ui/menu/main_menu_screen.dart`
- `lib/data/save/game_save_data.dart`
- `test/run_progression_research_test.dart`
- `test/run_progression_permanent_upgrade_test.dart`
- `test/main_menu_research_test.dart`
- `test/main_menu_permanent_upgrade_test.dart`

### 4. 40라운드 보상/난이도 곡선 재점검

작업 후보:

- 10/20/30/40라운드 보스 체감 점검
- 스테이지 체력 보정과 라운드 체력 보정 중첩 확인
- 룬 지급량과 영구 업그레이드 비용 곡선 검토
- 40라운드 클리어 기준 룬 획득량 재검토
- 테스트 가능한 밸런스 기준을 `docs/gameplay_balance_reference.md`에 유지

이유:

- 여러 밸런스 변경이 누적되어 장기 진행 곡선 검증이 필요하다.
- 수치 조정만으로도 체감이 크게 바뀔 수 있다.
- 챕터 1 후반 스테이지를 비슷한 웨이브로 유지하려면 스테이지 보정과 룬 보상이 지루함보다 성장 목표를 만들고 있는지 확인해야 한다.

관련 파일:

- `lib/domain/enemy/enemy_scaling.dart`
- `lib/data/definitions/game_stage_data.dart`
- `lib/game/systems/run_progression.dart`
- `test/game_balance_test.dart`
- `docs/gameplay_balance_reference.md`

### 5. 보스 웨이브 연출과 피드백 강화

작업 후보:

- 보스 등장 전 경고 UI 또는 짧은 표시
- 보스 HP 바 시각 차별화
- 보스 처치 보상 피드백 강화
- 10라운드 단위 웨이브 예고 문구 개선

이유:

- 보스가 호위 몹과 함께 등장하도록 정리됐지만, 현재는 전용 연출이 부족해 일반 웨이브의 확장처럼 보일 가능성이 있다.
- 큰 구조 변경 없이 전투 체감과 클리어 만족도를 높일 수 있다.

관련 파일:

- `lib/ui/hud/bottom_bar.dart`
- `lib/game/components/enemy_component.dart`
- `lib/game/rendering/enemy_shape_renderer.dart`
- `lib/data/definitions/game_stage_data.dart`
- `test/combat_hud_widget_test.dart`

### 6. 보호형 적 후속 설계

작업 후보:

- 방벽 수호병처럼 주변 적을 보호하는 후속 적의 필요성 검토
- 기존 공격 명령 5종으로 보호형 적 대응이 충분한지 플레이 검증
- 필요하면 `지원 적 우선`, `보호막 우선` 같은 특수 명령을 별도 후보로 설계
- 보호 범위와 보호 대상의 전투 화면 표시 방식 검토

이유:

- 포탑 공격 명령 우선순위는 이미 구현됐으므로, 다음 판단 지점은 그 기능이 보호형 적과 섞였을 때 충분한지다.
- 주변 보호형 적은 자동 타겟팅 게임에서 불쾌감이 생기기 쉬워, 새 적 구현보다 플레이어 통제감 검증을 먼저 해야 한다.

관련 파일:

- `docs/chapter2_wave_enemy_design.md`
- `docs/turret_target_priority_design.md`
- `lib/game/components/turret_component.dart`
- `lib/ui/hud/gem_equip_panel.dart`
- `test/game_balance_test.dart`

### 7. `RuneNexusGame` 책임 분리 리팩토링

작업 후보:

- 선택 상태와 입력 처리를 별도 협력 객체로 분리
- 저장/복구 변환 로직을 별도 모듈로 분리
- 런 정산과 진행 기록 처리를 `RunProgression` 쪽으로 더 모으기
- 전투 처리와 렌더링 보조 메서드 경계를 정리

이유:

- `lib/game/rune_nexus_game.dart`가 계속 커지고 있다.
- 콘텐츠가 늘면 변경 충돌과 회귀 위험이 커진다.
- 다만 즉시 대규모 분리는 비추천이다. 스테이지/영구 업그레이드 확장 뒤 변경이 잦은 경계가 더 선명해졌을 때 작게 나누는 편이 안전하다.

관련 파일:

- `lib/game/rune_nexus_game.dart`
- `lib/game/game_snapshot.dart`
- `lib/game/systems/`
- `test/game_balance_test.dart`

## 추천 실행 순서

현재 브랜치에서는 다음 순서를 따른다.

1. 영속 인증 운영 설정·same-site 도메인 준비 후 Web/Android 로그인·복원·저장 E2E
2. Android PGS와 기존 Google account identity 연결
3. 서버 권위 경제 DB·조회·legacy bootstrap
4. 가챠·분해·연구 소비·보상 claim과 Flutter economy coordinator
5. 저장 v3 migration과 account 단위 경제 전환 E2E
6. DB backup·restore와 계정 데이터 삭제
7. Web BroadcastChannel 종료 알림과 재획득 안내
8. 정식 배포 직전 기존 카카오 로컬 이전 endpoint·UX·DB 보관소 제거

콘텐츠 트랙을 진행할 때는 다음 순서를 따른다.

1. 포탑 모듈 획득/성장 곡선 검증
2. 챕터 2~3 보상·연구 흐름 검증과 보완
3. 연구/영구 성장 해금 단계 정리
4. 40라운드 보상/난이도 곡선 재점검
5. 보스 웨이브 연출과 피드백 강화
6. 보호형 적 후속 설계
7. `RuneNexusGame` 책임 분리 리팩토링

## 보류 기준

다음 작업은 당장 우선순위를 낮춘다.

- 고급 픽셀 아트 교체
- 사운드/효과음
- 대규모 저장 포맷 변경
- 스테이지 3~5의 억지 웨이브 차별화
- 포탑/젬/적 종류 대량 추가
- 앱 패키지 배포 자동화
- 실제 구매가 없는 상태의 Google Play·Apple 결제 검증
- WebSocket과 서버 권위형 전투 시뮬레이션

## 다음 세션 시작 가이드

새 세션에서 바로 작업을 시작한다면 다음 문장이 적합하다.

```text
docs/next_work_priorities.md의 공개 환경 E2E를 진행해줘.
```

온라인 저장 연결과 독립적으로 콘텐츠를 진행하려면 다음 문장이 적합하다.

```text
docs/next_work_priorities.md의 콘텐츠 백로그 1순위인 포탑 모듈 획득/성장 곡선 검증을 진행해줘.
```
