# Rune Nexus 다음 작업 우선순위

역할: 남은 검증·후속 후보의 백로그. 구현 완료 목록과 배포 상태를 복제하지 않는다.
정리: 2026-09-09. 경제 전환·운영 준비의 낡은 상태를 구현/배포 기록과 정합화했다.
콘텐츠 후보 전체를 이번에 재평가한 것은 아니며, 아래 순위는 기존 제안이다. 최신 사용자 요청이 우선한다.

## 현재 출발점

- 계정 저장·자동 복구·영속 세션과 서버 권위 경제 MVP는 구현되어 있다. 계약과 범위는 [구현 현황](implementation_status.md), [저장 동기화](multi_device_save_sync_design.md), [경제 설계](server_authoritative_economy_design.md)를 따른다. 이를 다시 구현할 백로그로 취급하지 않는다.
- migration 010 및 API·웹·APK 배포, DB 백업 복원 검증은 [배포 인계](deployment_status.md)에 기록돼 있다. 실제 계정·기기 E2E 완료와는 구분한다.
- 로그인 필수화, PGS, identity 연결 등은 개별 기능의 현재 코드와 아래 미검증 항목을 확인한 뒤 범위를 정한다. 닉네임 필수 설정은 [별도 정책](account_nickname_policy.md)이며 로그인 필수화와 혼동하지 않는다.
- [카카오 진행 이전](legacy_local_save_transfer.md)은 임시 이행 기능이다. 정식 출시 전 제거 체크리스트를 따른다.

## 계정·온라인 저장 후속 작업

### 1. 공개 환경 E2E와 운영 안전장치

자체 운영 HTTPS API와 같은 사이트의 Web(예: Pages 커스텀 도메인)을 연결해 Google 계정
하나로 로그인·저장·새로고침 뒤 자동 복원·저장 재조회까지 검증한다. 기본 `github.io`와
`duckdns.org` 조합은 현재 쿠키 정책과 맞지 않으므로 CORS만으로 통과 처리하지 않는다.

작업 범위:

- [x] DuckDNS secret 기반 공인 IPv4 자동 갱신·재시도와 상태 감시
- [x] Caddy, ipTIME 포트 포워딩, 실제 DNS 응답과 TLS 인증서 확인
- [x] Google OAuth Authorized JavaScript origin과 서버 CORS exact origin 확인
- [x] GitHub Actions Variables의 Web Client ID와 API base URL 확인
- [x] 로컬 세션 복원·응답 유실·시작 실패 경계 테스트와 Web/APK 빌드
- 배포 인계에 기록된 migration 적용 상태를 확인하고, `AUTH_SESSION_RECEIPT_KEY` 보관·same-site 도메인·최종 OAuth/CORS를 실제 계정 E2E에서 재확인
- Android applicationId·서명 SHA·Web server client ID 확인과 실제 로그인·재시작 복원
- 로그인, refresh, logout, `GET/PUT /v1/save` 실제 네트워크 검증
- 지원 버전의 writer/PUT 성공과 구버전 426 차단 실제 네트워크 검증
- 호환 버전 강제 상승 뒤 기존 Outbox의 영수증 hit/miss 롤오버 검증
- 느린 네트워크, API 재시작, DB 재시작과 Outbox 복구 검증
- 검증된 수동 DB backup·restore를 바탕으로 자동화·보관 정책과 계정·원격 데이터 삭제 경로 마련

### 2. Android PGS와 다중 identity 연결

Web·Android 일반 Google 로그인과 영속 세션의 공개 검증 뒤 Android PGS v2를 추가한다.
현재 Credential Manager 구현을 PGS 구현 완료로 간주하지 않는다.

작업 범위:

- 출시 Application ID·서명 확정
- Kotlin PGS v2 로그인과 Flutter MethodChannel
- server auth code 교환과 PGS Player ID 검증
- 기존 account에 Google/PGS identity를 명시적으로 추가하는 연결 API
- 이미 다른 account에 연결된 identity의 충돌 처리
- Android 내부 테스트 배포와 실제 계정 QA

### 3. 경제·저장 후속 검증

- 실제 계정의 구매·보상·오프라인 재시도·다중 기기 경제 E2E를 검증한다.
- 저장 v3의 economy cache·모듈 장착 ID 분리는 별도 후속 설계다. 현재 전환에 필요하다고 재추론하여 저장 형식을 바꾸지 않는다.
- Web 다중 탭 종료 알림용 BroadcastChannel과 큰 저장의 실제 용량을 검증한다.
- 완료 기준은 해당 환경·시나리오와 결과를 기록하는 것이다. 미실행 실기 검증을 코드·단위 테스트 통과로 대체하지 않는다.

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
