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

남은 핵심 약점은 다음과 같다.

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

## 권장 우선순위

### 1. 포탑 모듈 획득/성장 곡선 검증

가장 먼저 추천하는 작업이다. 기본 기능은 구현되어 있으므로 새 시스템 추가보다 실제 획득 속도와 유효 보상 체감을 먼저 확인한다.
설계와 현재 규칙은 `docs/turret_module_design.md`에 유지한다.

작업 후보:

- 스테이지 11 최초 클리어 모듈권 5장과 주간 임무 보상의 실제 수급 속도 점검
- 모듈권 부족분 1장당 다이아 80개 보충 비용 점검
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

### 2. 챕터 2~3 보상과 연구 조건 연결

설계 기준은 `docs/chapter2_wave_enemy_design.md`에 유지한다.
보호막병 시각/역할 기준은 `docs/prototypes/shielded_enemy_design_preview.html`에 정리했다.
챕터 3의 맵/웨이브 범위는 `docs/chapter3_forge_design.md`에 유지한다.

작업 후보:

- 챕터 2 첫 클리어 보상을 연구 조건과 연결
- 챕터 3 첫 클리어 또는 최종 클리어 보상을 장기 성장 목표와 연결
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

1. 포탑 모듈 획득/성장 곡선 검증
2. 챕터 2~3 보상과 연구 조건 연결
3. 연구/영구 성장 해금 단계 정리
4. 40라운드 보상/난이도 곡선 재점검
5. 보스 웨이브 연출과 피드백 강화
6. 보호형 적 후속 설계
7. `RuneNexusGame` 책임 분리 리팩토링

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
docs/next_work_priorities.md 기준으로 최우선 과제인 포탑 모듈 획득/성장 곡선 검증을 진행해줘.
```

영구 성장부터 확장하려면 다음 문장이 적합하다.

```text
docs/next_work_priorities.md 기준으로 3순위인 연구/영구 성장 해금 단계 정리를 진행해줘.
```
