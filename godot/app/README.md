# Godot 앱·저장 계약

역할: Godot 앱의 런 수명주기와 로컬 저장 계약. 2026-09-24에 소스 경로와 SDK 독립 검사 진입점을 확인했다. Android 실기기·계정·배포 완료 여부는 [이관 로드맵](../../docs/godot_unified_app_roadmap.md)과 [배포 현황](../../docs/deployment_status.md)을 따른다. 초기 저장 이관의 검증 결과는 [당시 기록](../../docs/analysis/godot_save_foundation_20260921/README.md)이다.

| 모듈 | 역할 |
| --- | --- |
| `app_lifecycle.gd` | 정식 `--app`의 시작·정지 복원, 10초 및 동작 시 저장, 로비·전투 전환·종료 |
| `save_json.gd` | signed int64를 정밀도 손실 없이 읽고 문자열·실수 타입을 구분 |
| `save_codec.gd` | 기존 `GameSaveData` v2 정규화·기본값·enum·모듈 ID 및 v1 이전 |
| `local_save_slot.gd`, `local_save_store.gd` | guest/UUID 계정 슬롯, v2 원본·백업·충돌 백업, v1 가져오기와 중단된 쓰기 복구 |
| `run_save_adapter.gd`, `content_run_save.gd` | 확정된 전투 스냅샷과 콘텐츠·성장 값을 v2 저장으로 조립·복원 |
| `quest_progress.gd`, `reward_outbox.gd`, `reward_settlement.gd`, `reward_snapshot.gd` | 퀘스트·런 보상 증거·영속 큐·서버 정산 및 snapshot 반영 |
| `device_preferences.gd` | 계정 저장과 분리한 기기 그래픽 설정 |
| `res://services/app_services.gd` | 계정 전환·온라인 저장·경제·업데이트의 수명주기와 플레이 차단 |

Android에서 `RuneNexusPlatform.application_support_path()`가 이전 앱의 `filesDir`를 반환하므로 같은 패키지·서명으로 업데이트할 때 기존 `saves/guest`와 `saves/accounts/<uuid>` 경로를 사용한다. `legacy_save_path()`는 guest v1 임시 파일에만 적용한다. 정식 앱은 저장 원본을 다른 위치로 일괄 복사하거나 기존 파일을 초기화하지 않는다. 다른 플랫폼의 개발 `user://standalone-session` 저장은 Android 설치 데이터와 분리된다.

```gdscript
const Store = preload("res://app/local_save_store.gd")
const Slot = preload("res://app/local_save_slot.gd")
var platform = Engine.get_singleton("RuneNexusPlatform")
var store = Store.new(platform.application_support_path(), Slot.guest(), platform.legacy_save_path())
var saved = store.load_save()
if store.last_error != OK:
    push_error(store.last_error_message)
# store.save_save(canonical_v2) -> Error; OK를 확인한 뒤 저장 완료로 취급
```

읽기의 null은 저장 없음과 I/O 오류를 모두 뜻할 수 있으므로 `last_error`를 확인한다. 쓰기에는 `Codec.decode()`와 동등하게 정규화된 v2 값·타입을 전달한다. 정수 필드의 문자열·실수, NaN/Infinity 또는 엔진 객체를 넣으면 `ERR_INVALID_DATA`를 반환하고 기존 원본·백업을 변경하지 않는다. 계정 UUID가 유효하지 않으면 `Slot.account(uuid)`는 null을 반환한다. 이를 Store 생성자에 넘기면 guest 슬롯이 선택되므로 호출자가 먼저 중단한다.

저장 API는 동기식이며 앱 서비스가 슬롯·소유권 전환과 쓰기를 직렬화한다. `capture(envelope, snapshot, turret_templates, saved_at)`는 도메인이 경제·보상 이벤트를 반영하고 ACK한 뒤 호출한다. 전투 상태로 성장·중요 재화를 추론하거나 v2에 없는 투사체·코어 시계를 저장하지 않는다. 진행 중 웨이브는 정지 상태로 복원한다. 런 종료 체크포인트와 영속 보상 Outbox를 먼저 기록하고, 쓰기 실패 시 Stage·재시도 전환을 차단한다. 게스트 큐는 계정으로 자동 이전하지 않으며 서버 재화를 로컬에서 확정하지 않는다.

계정 세션은 Android Keystore 기반 보안 저장에 보관하고, 온라인 저장·경제 요청은 `res://services/`가 담당한다. `res://app_config.json`의 API·Google·업데이트 주소는 빌드 시 환경값으로 생성한다. 공백인 개발 설정에서는 운영 API를 임의 호출하지 않는다. 인증·온라인 저장·앱 업데이트의 실제 기기 결과는 자동 회귀와 구분해 기록한다.

## 검사

```sh
python3 scripts/verify_godot_content.py
GODOT_BIN=/path/to/godot python3 scripts/run_godot_native_regressions.py
```

네이티브 회귀 실행기는 임시 Godot 프로젝트에 저장 codec fixture·파일 복구·체크포인트·전투와 UI 스크립트를 복사한다. Godot 실행 파일이 없으면 실패한다. 보관된 Dart 기반 기대 fixture는 기존 저장 계약과의 비교 입력이며, 수치나 스키마를 의도적으로 변경할 때 차이를 검토해 갱신한다. 실제 Android 저장 인계·계정·수명주기 검증은 [인앱 가이드](../../.agents/in_app_test_guide.md)를 따른다.
