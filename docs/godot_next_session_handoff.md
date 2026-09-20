# 다음 세션 인계 — 실제 콘텐츠·전투 설정 이관

역할: 대화 이력 없이 다음 구현을 시작하기 위한 실행 지시와 확인된 상태. 작성일: 2026-09-21. 선행 커밋: `dab5148`. 저장 기반·재검수 수정과 이 문서는 후속 저장 기반 커밋에 함께 포함한다. 새 세션은 이 문서와 `godot/app/`이 포함된 커밋 이후에서 시작한다. 로컬 실행용 Godot 바이너리·준비된 자산·화면 캡처는 별도 산출물이므로 새 worktree에서는 준비 여부를 확인한다.

## 새 세션에 붙여 넣을 요청

> `docs/godot_next_session_handoff.md`를 읽고 여기에 정리된 다음 작업인 “실제 콘텐츠·전투 설정 이관”을 구현해줘. 현재 저장 기반과 검수 수정사항을 보존하고, 기존 코드·테스트와 결과를 대조하면서 구현·관련 검증·발견한 결함 수정까지 완료해줘. 이번 범위는 개발용 고정 전투 설정을 실제 콘텐츠 기반의 Godot 설정 경로로 대체하는 것이며, 전체 Flutter 제거 완료로 취급하지 마. 완료 후 변경 내용·검증 결과·남은 후속 작업을 기록해줘. 커밋·푸시·배포는 별도로 요청하기 전에는 하지 마.

## 확정 방향과 현재 위치

- 최종 목표는 Flutter/Dart와 Flame 의존성을 제거한 Godot 단일 앱이다. Flutter HUD 최적화만 하고 끝내는 작업이 아니다.
- [Flutter 제거 로드맵](godot_unified_app_roadmap.md)의 1단계 전투 시계·전장 입력 이관은 `dab5148 refactor: 전투 시계와 입력을 Godot 세션으로 이관`으로 커밋했다. 푸시는 하지 않았다.
- 2단계는 진행 중이다. v1/v2 저장 호환 기반과 개발 세션 저장·복원까지 구현했지만, 본게임 런·성장·정적 정의·저장 호출은 아직 Dart에 남아 있다.
- 직전 작업은 저장 값·타입 재검수였다. 스테이지 기록 키 파싱 차이를 수정했고, NaN/Infinity·엔진 객체·잘못된 필드 타입을 저장 전에 거절하도록 보완했다. 자세한 검증 건수와 로그는 [저장 기반 기록](analysis/godot_save_foundation_20260921/README.md#추가-저장타입-재검수)을 단일 근거로 사용한다.
- 현재 독립 세션은 실제 지도와 개발용 기본 화살포탑, 고정 일반 적 편성을 사용한다. 이를 본게임 콘텐츠가 이관된 상태로 오해하지 않는다.

## 다음 구현의 목표와 경계

**Godot이 실제 스테이지·웨이브·적·포탑 정의를 읽어 전투 설정을 만들도록 하고, 개발용 고정 편성에 의존하는 실행 경로를 대체한다.**

이번에 수행할 일:

1. Dart의 콘텐츠 정의와 본게임 전투 설정 조립 경로를 확인한다. 스테이지별 지도·경로·웨이브 편성·스폰 지연·적 스탯·보스 특성·포탑 기본값과 성장 보정의 입력 경계를 정리한다.
2. 정적 콘텐츠를 단일 원본으로 정리하고 Godot 콘텐츠 로더/설정 조립기를 구현한다. 파일 형식은 현재 코드와 검증 결과를 보고 정하되, 양쪽 수동 편집이 필요한 중복 원본을 만들지 않는다. 임시 Dart 추출기가 필요하면 원본·생성물·재생성 명령을 명시한다. 최종 실행에 Dart가 필요하지 않게 하고, 최종 빌드의 Dart 생성 도구 의존 제거 여부도 별도로 기록한다.
3. 기존 Godot 전투 런타임과 포탑 스탯 계산기를 재사용한다. 일반 성장·장착 상태는 명시적인 입력으로 받아 동일 설정을 만들고, 이 작업에서 성장 구매·보상·서버 재화의 소유권까지 옮기지 않는다.
4. 독립 세션에서 실제 콘텐츠의 스테이지/웨이브를 시작하고 진행할 수 있도록 연결한다. 일반 적 12마리·고정 HP 등의 개발 상수를 실제 정의로 대체한다. 검증용 조작은 기존 개발 UI를 최소한으로 확장할 수 있다.
5. 동일 입력으로 Dart가 만든 설정과 Godot 설정의 값·타입·순서·단위를 비교한다. 발견한 차이는 밸런스 변경으로 덮지 말고 원인을 수정한다.
6. 설정 변경에 영향을 받는 기존 저장/재시작 검사도 유지한다. 개발용 `session_checkpoint.gd`의 지원 제한을 단순 삭제해서 일반 저장을 허용하지 않는다. 새 콘텐츠 경로에서 저장을 노출하려면 해당 설정을 정확히 재구성하고 왕복 검증한다. 아직 미지원이면 기존 저장을 유지하며 명시적으로 거절하고 경계를 문서화한다.

후속으로 남길 일:

- 건설 비용·강화·판매·젬·특성·런 업그레이드·일반 성장 명령 전체의 Godot 소유권 이전.
- 본게임 저장 호출 연결, Android 기존 설치 저장 디렉터리 인계와 실제 업그레이드 검증.
- 실제 브라우저 다중 탭/Web Locks 및 Windows 파일 교체 검증.
- 3단계 Flutter HUD·패널·보상·결과 화면 대체, 이후 인증·온라인 서비스·로비·패키징 제거.

## 우선 읽을 코드와 문서

모든 문서를 순회하지 말고 루트 `AGENTS.md`와 아래 관련 경로부터 확인한다. 구조·호출 관계 탐색은 `.codegraph/`가 있으면 프로젝트 지침대로 그래프를 우선 활용하고, 정확한 경로·문구는 직접 읽기/검색한다.

| 목적 | 경로 |
| --- | --- |
| 목표·단계·책임 경계 | [실행 로드맵](godot_unified_app_roadmap.md), [현행 전투 책임](godot_combat_migration_boundaries.md) |
| 지도·스테이지·웨이브 | `lib/data/definitions/game_stage_maps.dart`, `game_stage_data.dart`, `game_stage_waves.dart`, `game_stage_wave_helpers.dart`, `game_stage_wave_spawn_groups.dart` |
| 적·포탑·성장 입력 원본 | `lib/data/definitions/game_enemy_data.dart`, `game_turret_data.dart`, `game_run_upgrade_data.dart` 및 필요한 젬·연구·코어·모듈 정의 |
| 본게임 설정 조립·상태 | `lib/game/rune_nexus_game.dart`, `lib/game/systems/`, `test/native_combat_game_test.dart`, `test/native_wave_game_test.dart` |
| 재사용할 Godot 전투 | `godot/combat/native_combat_runtime.gd`, `native_wave_state.gd`, `turret_stat_calculation.gd` |
| 현재 개발 세션과 저장 제한 | `godot/session/standalone.gd`, `standalone_fixture.json`, `session_checkpoint.gd`, [세션 안내](../godot/session/README.md) |
| 호환 저장 기반 | `godot/app/` 전체, [API·쓰기 계약](../godot/app/README.md), `lib/data/save/` |
| 프로젝트 준비·생성 경로 | `scripts/prepare_godot_project.py`, `scripts/test_prepare_godot_project.py` |
| 비교·회귀 검사 | `test/godot_native_regression_test.dart`, `test/turret_stat_calculation_test.dart`, `test/fixtures/turret_stat_calculation.json`, `godot/verify_native_wave_core.gd` |
| 저장·재시작 회귀 | `test/godot_save_codec_fixture_test.dart`, `godot/verify_save_roundtrip.gd`, `godot/verify_standalone_session.gd`, `godot/verify_session_restart.gd` |

## 시작 시 확인과 작업 트리 보호

1. 작업 위치는 `/Users/sejin/Documents/Codex/RuneNexus`다. `git status --short`와 `git log -1 --oneline`으로 새 변경을 확인한 뒤 시작한다.
2. `godot/app/`·저장 관련 검증 파일·fixture·저장 기반 문서가 존재하고 직전 타입 검사가 남아 있는지 확인한다. 파일이 없다면 저장 기반 커밋을 포함한 checkout을 사용한다. 저장 기반을 추측해서 재구현하지 않는다.
3. 기존 design/이미지/로그의 대량 삭제·미추적 산출물과 `android/gradle.properties` 변경이 있다. 이번 변경에 섞지 않으며 reset/clean/일괄 stage를 하지 않는다.
4. `godot/`이 소스이고 `build/godot/project/`는 준비된 실행용 복사본이다. build 안에서만 수정하고 끝내지 않는다. 기존 Godot/Blender 편집기의 미저장 작업을 보존한다.
5. 실제 사용자 저장·온라인 API·운영 데이터를 검증에 사용하지 않고 격리된 임시 슬롯을 사용한다. 커밋·푸시·APK 공개는 별도 요청이 없으면 하지 않는다.

## 보존할 계약

- 저장 v2·v1 이전·기본값·ID·null 젬 슬롯·배열 순서·정수/실수 타입을 유지한다. 새 v3나 탄환 저장을 도입하지 않는다.
- `save_json.gd`의 signed int64 보존과 `save_codec.gd`의 타입 검사를 우회하지 않는다. 잘못된 런타임 값을 먼저 정규화해 오류를 숨기는 방식으로 저장 거절을 회피하지 않는다.
- 전투 HP·판정·웨이브 권위는 기존 Godot 런타임에 둔다. 피해 공식을 중복 구현하거나 이관 과정에서 밸런스를 바꾸지 않는다. 수치 작업은 [데미지 계층 규칙](damage_calculation_rules.md)을 따른다.
- Godot 내부 시계·배속·정지·재개·scene epoch·이벤트 ACK 계약을 유지한다. 경제 이벤트를 반영하기 전에 ACK하거나 저장하지 않는다.
- 타일 좌표와 월드 좌표, `tileSize`·`boardDistanceScale`, 시간 단위를 기존 계약과 대조한다. 수치가 비슷해 보이는 것만으로 동등성을 인정하지 않는다.
- 기존 승인된 3D 에셋·외형을 유지한다. 개발 조작 UI 외 본게임 디자인 변경은 이번 범위가 아니다.

## 완료와 검증 기준

- 실제 콘텐츠 전 범위를 로더가 읽고, 전체 스테이지·웨이브 정의의 누락/중복 ID/순서/스폰 시간/수치/숫자 타입을 Dart 기준과 비교한다. 일부 대표 전투의 시각 확인만으로 전체 콘텐츠 동등성을 주장하지 않는다.
- 독립 Godot 실행에서 챕터별 대표 스테이지와 특수 적/보스, 실제 웨이브 편성을 확인한다. 지도·경로·공격·코어 피해·웨이브 종료가 맞는지 검증하고 마지막에 대표 인게임 화면을 확인한다.
- 기존 전투·스탯·저장 회귀를 영향 범위에 맞게 실행한다. Dart 수정 시 포맷·분석, 준비 스크립트 수정 시 해당 Python 검사도 수행한다. 같은 입력만 반복하는 테스트 대신 실제 Dart 결과를 비교 기준으로 사용한다.
- 저장 관련 실패를 새 fixture 기대값 갱신만으로 덮지 않는다. 별도 프로세스 저장/복원을 유지하고, 새 경로에서 미지원인 저장 상태는 명시한다.
- 완료 기록에는 원본/생성물, 실행 경로, 비교 범위, 시각 결과, 저장 지원 범위, 남은 Dart 의존성을 구분한다. 전체 2단계나 Flutter 제거 완료로 보고하지 않는다.

기본 명령(저장소 루트, macOS):

```sh
WORK_DIR="$PWD" scripts/in_app_server_macos.sh flutter analyze
WORK_DIR="$PWD" scripts/in_app_server_macos.sh flutter test test/godot_save_codec_fixture_test.dart test/godot_native_regression_test.dart test/turret_stat_calculation_test.dart
python3 scripts/prepare_godot_project.py
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --editor --path build/godot/project --import --quit
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --path build/godot/project -- --session
```

작성 환경의 Godot은 4.7.2였다. 바이너리가 없으면 임의의 테스트 skip을 성공으로 보고하지 말고 경로를 확인한다. 재시작 검사의 정확한 write/read 명령은 [세션 안내](../godot/session/README.md)에 있다. 새 로더 검사는 구현에 맞게 추가한다.

중간 규모 이상의 독립 구현은 `AGENTS.md`에 따라 하위 에이전트 위임을 검토한다. 콘텐츠 추출/동등성 검사와 Godot 로더/세션 연결처럼 파일 소유권을 나누고, 부모는 통합·최종 실행 확인을 담당한다.

완료 후 [실행 로드맵](godot_unified_app_roadmap.md)의 2단계 상태와 다음 구현 항목, 관련 모듈 README 및 검증 기록을 갱신한다. 이 인계 문서는 해당 작업 완료 시 역사 기록으로 표시하거나 다음 인계 문서로 연결한다.
