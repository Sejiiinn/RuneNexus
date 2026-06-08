# Rune Nexus 다음 작업 우선순위

마지막 정리 기준: 최근 `main` 브랜치 작업 기준.

## 목적

이 문서는 새 세션에서도 다음 작업 후보와 우선순위를 빠르게 이어받기 위한 기준 문서다.

현재 Rune Nexus는 기본 MVP 루프를 넘어 전투, 젬, 링크, 저장, 스테이지 선택, 결과 화면, 환불, 영구 업그레이드 기초까지 동작한다. 이후 작업은 단순 기능 추가보다 "반복 플레이 이유를 강화하는 것"에 초점을 둔다.

## 현재 판단

최근 작업으로 다음 약점은 상당 부분 해소됐다.

- 결과 화면의 신기록/신규 해금 강조
- 진행 종료 시 예상 룬 보상 확인
- 릴리즈 빌드의 디버그 패널 기본 비노출
- 전투 중 환불과 환불 확인 팝업
- 화면 크기 기반 사거리/속도 보정
- 스테이지별 적 체력 보정
- 스테이지 1~5별 맵 정의 분리
- 스테이지 1 기본 웨이브와 스테이지 2~5 장갑병 중심 웨이브 분리
- 스테이지 선택 화면의 1스테이지 저격 포탑 보상, 2스테이지 경제 해금 표시
- 포탑별 1차/2차 특성 선택과 전투 효과
- 특성 후보 첫 선택 상태와 같은 후보 재선택 확정 흐름
- 저격 포탑 1차/2차 특성 선택지
- 보스 웨이브 순서, 호위 몹, 보스 수 정리
- 공통 게임 UI 컴포넌트 기반의 주요 화면 정리
- 메인 메뉴 스테이지/강화/연구 화면의 모바일 폭 대응
- 저장된 진행 카드와 이어서 진행 버튼의 과도한 색상 강조 완화
- 전투 하단 포탑/업그레이드/젬 탭의 금속 프레임형 버튼화
- 배속 버튼 라벨 중앙 정렬

남은 핵심 약점은 다음과 같다.

- 최우선 과제는 챕터 2 클리어 보상과 연구 조건 연결이다. 챕터 2는 스테이지 6~10이며, 보호막병 웨이브 MVP와 챕터 2 타일 테마는 해당 구간에 들어갔으므로 이제 반복 동기를 만들어야 한다.
- 스테이지 2~5는 챕터 1 후반 구간으로 묶어도 된다. 신규 몹이나 신규 기믹 없이 스테이지 3~5의 웨이브만 억지로 갈라봤자 체감 차이가 작다.
- 영구 업그레이드는 정비 보급, 기초 화력 훈련, 처치 보상, 긴급 매각까지 확장됐지만, 해금 단계와 젬/링크 계열 선택지는 아직 얕다.
- 젬 파편과 포탑 특성 시스템은 구현됐지만, 수급량과 비용 곡선은 아직 장기 검증이 부족하다.
- 젬 선택지가 빌드와 맞지 않을 때 대체 선택지는 생겼지만, 특정 빌드를 장기적으로 밀어주는 영구 성장 축은 아직 얕다.
- 후반 골드 인플레를 받아줄 상위 포탑 해금과 포탑 계열 연구 트리의 장기 구조가 아직 없다.
- 보스 호위 웨이브로 기본 압박은 생겼지만, 보스 전용 피드백과 긴장감은 아직 약하다.
- 50라운드 장기 진행 기준 보상/난이도 곡선은 더 검증해야 한다.
- `RuneNexusGame`이 입력, 전투, 저장, 선택 상태, 진행 정산을 함께 담당해 장기적으로 커질 위험이 있다.

## 권장 우선순위

### 1. 챕터 2 보상과 연구 조건 연결

가장 먼저 추천하는 작업이다.
설계 기준은 `docs/chapter2_wave_enemy_design.md`에 유지한다.
보호막병 시각/역할 기준은 `docs/prototypes/shielded_enemy_design_preview.html`에 정리했다.

작업 후보:

- 챕터 2 첫 클리어 보상을 연구 조건과 연결
- 보호막병이 기존 포탑, 젬, 링크, 특성 선택을 어떻게 다르게 요구하는지 실제 플레이로 검증
- 챕터 1 스테이지 2~5는 맵, 스테이지 보정, 해금/연구 조건 중심으로 유지
- 챕터 2 스테이지 6~10의 보상 흐름과 연구 안내를 정리

이유:

- 신규 몹 없이 스테이지 3~5 웨이브만 바꾸면 비율과 간격 조정에 머물 가능성이 크다.
- 플레이어가 새 구간에 들어왔다는 체감은 챕터 2에서 몹 역할과 웨이브 압박이 함께 바뀔 때 더 분명하다.
- 스테이지 2~5를 챕터 1 후반 구간으로 유지하면 현재 콘텐츠를 억지로 벌리지 않고, 다음 큰 변화를 더 선명하게 준비할 수 있다.

관련 파일:

- `docs/chapter2_wave_enemy_design.md`
- `docs/prototypes/shielded_enemy_design_preview.html`
- `lib/data/definitions/game_stage_data.dart`
- `lib/data/definitions/game_stage_waves.dart`
- `lib/data/definitions/game_enemy_data.dart`
- `lib/domain/enemy/enemy_type.dart`
- `lib/domain/stage/stage_definition.dart`
- `lib/ui/menu/main_menu_screen.dart`
- `test/game_balance_test.dart`
- `test/widget_test.dart`

### 2. 연구/영구 성장 해금 단계 정리

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
- `test/game_balance_test.dart`
- `test/widget_test.dart`

### 3. 포탑 공격 명령 우선순위 구현

작업 후보:

- `docs/turret_target_priority_design.md` 기준으로 포탑별 공격 명령 저장/복구 추가
- 선두, 후방, 강한 적, 약한 적, 근접 명령 지원
- 선택 포탑 상세 패널에 명령 선택 UI 추가
- 저격 포탑 조준 유지 규칙과 충돌하지 않는지 테스트

이유:

- 주변 보호형 적을 추가하기 전에 플레이어가 타겟 우선순위를 조정할 수 있어야 한다.
- 보호막병, 장갑병, 보스가 섞이는 챕터 2에서 포탑별 역할 지정이 더 중요해진다.
- 내부적으로 `first`, `last`, `nearest` 기반이 이미 있어 신규 시스템보다 확장 작업에 가깝다.

관련 파일:

- `docs/turret_target_priority_design.md`
- `lib/game/components/turret_component.dart`
- `lib/data/save/game_save_data.dart`
- `lib/game/game_snapshot.dart`
- `lib/ui/hud/gem_equip_panel.dart`
- `test/game_balance_test.dart`
- `test/widget_test.dart`

### 4. 50라운드 보상/난이도 곡선 재점검

작업 후보:

- 10/20/30/40/50라운드 보스 체감 점검
- 스테이지 체력 보정과 라운드 체력 보정 중첩 확인
- 룬 지급량과 영구 업그레이드 비용 곡선 검토
- 50라운드 클리어 기준 룬 획득량 재검토
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
- `test/widget_test.dart`

### 6. `RuneNexusGame` 책임 분리 리팩토링

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

1. 챕터 2 보상과 연구 조건 연결
2. 연구/영구 성장 해금 단계 정리
3. 포탑 공격 명령 우선순위 구현
4. 50라운드 보상/난이도 곡선 재점검
5. 보스 웨이브 연출과 피드백 강화
6. `RuneNexusGame` 책임 분리 리팩토링

## 보류 기준

다음 작업은 당장 우선순위를 낮춘다.

- 고급 픽셀 아트 교체
- 사운드/효과음
- 온라인 저장 실제 연동
- 대규모 저장 포맷 변경
- 스테이지 3~5의 억지 웨이브 차별화
- 포탑/젬/적 종류 대량 추가
- 앱 패키지 배포 자동화

## 다음 세션 시작 가이드

새 세션에서 바로 작업을 시작한다면 다음 문장이 적합하다.

```text
docs/next_work_priorities.md 기준으로 최우선 과제인 챕터 2 보상과 연구 조건 연결을 진행해줘.
```

영구 성장부터 확장하려면 다음 문장이 적합하다.

```text
docs/next_work_priorities.md 기준으로 3순위인 연구/영구 성장 해금 단계 정리를 진행해줘.
```
