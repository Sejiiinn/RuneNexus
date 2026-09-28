# Godot 앱·저장 계약

역할: Godot 앱의 런 수명주기와 로컬 저장 계약. 2026-09-24에 소스 경로와 SDK 독립 검사 진입점을 확인했다. Android 실기기·계정·배포 완료 여부는 [이관 로드맵](../../docs/godot_unified_app_roadmap.md)과 [배포 현황](../../docs/deployment_status.md)을 따른다. 초기 저장 이관의 검증 결과는 [당시 기록](../../docs/analysis/godot_save_foundation_20260921/README.md)이다.

| 모듈 | 역할 |
| --- | --- |
| `boot.gd`, `boot.tscn` | 경량 시작 화면·업데이트 게이트, 통과 후 본게임 장면 비동기 로딩 |
| `app_lifecycle.gd` | 정식 `--app`의 시작·정지 복원, 10초 및 동작 시 저장, 로비·전투 전환·종료 |
| `save_json.gd` | signed int64를 정밀도 손실 없이 읽고 문자열·실수 타입을 구분 |
| `save_codec.gd` | 기존 `GameSaveData` v2 정규화·기본값·enum·모듈 ID 및 v1 이전 |
| `local_save_slot.gd`, `local_save_store.gd` | guest/UUID 계정 슬롯, v2 원본·백업·충돌 백업, v1 가져오기와 중단된 쓰기 복구 |
| `run_save_adapter.gd`, `content_run_save.gd` | 확정된 전투 스냅샷과 콘텐츠·성장 값을 v2 저장으로 조립·복원 |
| `quest_progress.gd`, `reward_outbox.gd`, `reward_settlement.gd`, `reward_snapshot.gd` | 퀘스트·런 보상 증거·영속 큐·서버 정산 및 snapshot 반영 |
| `device_preferences.gd` | 계정 저장과 분리한 기기 그래픽 설정 |
| `res://services/app_services.gd` | 계정 전환·온라인 저장·경제·업데이트의 수명주기와 플레이 차단 |

기본 진입은 `boot.tscn`이다. 기존 배경·로고·코어를 사용하는 `res://ui/startup_screen.gd`가 업데이트 확인·재시도·선택/필수 업데이트·설치 상태를 표시한다. 업데이트를 통과한 뒤에만 `main.tscn`과 전투 리소스를 불러오고 저장·계정 복원을 시작한다. 이 준비가 끝날 때까지 같은 시작 화면을 유지하며, 업데이트 서비스는 앱 수명주기와 공유해 초기 확인을 중복 실행하지 않는다.

전투 효과 준비도 같은 시작 화면의 완료 조건이다. 기기 그래픽 설정 적용 후 [효과 준비](../presentation/effect_preparation.gd)가 별도 3D viewport에서 대포·화염·냉각과 적의 화상·성에를 실제로 렌더한다. 전투·저장·난수를 진행하지 않으며, 준비 실패 시 재시도를 제공한다. 기존에 준비한 폭발 밀도장을 재사용하고, 완료 후 대포 탄환·화염 탄환·착탄을 각각 두 개씩 기존 풀에 넘긴다. 앱의 전장 초기화는 이 소량만 숨김·정지 상태로 유지하고 전체 해제 경로는 모두 정리한다. 개발용 fixture·session 진입은 자동 준비를 생략한다.

실행 중 앱을 잠시 내렸다 돌아오는 경우에는 통과한 업데이트 검사를 다시 시작하지 않고 현재 전투·로비 하위 화면을 유지한다. 백그라운드 전환의 일시정지·저장은 유지하며 자동으로 전투를 재개하지 않는다. 이미 열린 업데이트 게이트의 설치·설정 복귀는 재확인하고, 필수 버전과 서버의 업데이트 요구도 계속 차단한다. 업데이트 화면은 기존 화면 위에 표시하며 선택 업데이트를 건너뛰거나 확인을 마쳐도 로비로 강제 이동하지 않는다. Google 인증 복귀와 계정의 foreground 동기화·권위 저장 재적용 계약은 유지한다.

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

`content_run_save.gd`의 저장 `capture()`와 불러오기 `prepare()`는 같은 체크포인트 검증을 사용한다. 저장 시에는 맵·런 단계·포탑/젬·성장 한도·코어 HP·적/남은 스폰 등을 검증하며 전투 초기 설정이나 포탑·적 복원 데이터를 만들지 않는다. 실제 복원 데이터와 대기 스폰 난수는 검증에 성공한 `prepare()`에서만 생성한다. 성공한 동일 시드 복원 결과는 유지하며, 검증에서 거부한 복원은 더 이상 난수를 소비하지 않는다. [검증·측정 근거](../../docs/analysis/save_validation_20260928/README.md).

계정 세션은 Android Keystore 기반 보안 저장에 보관하고, 온라인 저장·경제 요청은 `res://services/`가 담당한다. `res://app_config.json`의 API·Google·업데이트 주소는 빌드 시 환경값으로 생성한다. 공백인 개발 설정에서는 운영 API를 임의 호출하지 않는다. 인증·온라인 저장·앱 업데이트의 실제 기기 결과는 자동 회귀와 구분해 기록한다.

## 검사

```sh
python3 scripts/verify_godot_content.py
GODOT_BIN=/path/to/godot python3 scripts/run_godot_native_regressions.py
```

네이티브 회귀 실행기는 임시 Godot 프로젝트에 저장 codec fixture·파일 복구·체크포인트·전투와 UI 스크립트를 복사한다. Godot 실행 파일이 없으면 실패한다. 보관된 Dart 기반 기대 fixture는 기존 저장 계약과의 비교 입력이며, 수치나 스키마를 의도적으로 변경할 때 차이를 검토해 갱신한다. 실제 Android 저장 인계·계정·수명주기 검증은 [인앱 가이드](../../.agents/in_app_test_guide.md)를 따른다.

`verify_startup_screen.gd`는 효과 준비 완료·실패·재시도 게이트를 검사한다. 에셋을 준비한 프로젝트의 `verify_effect_preparation.gd`는 풀 인계·재진입·취소·중복 요청·첫 발사와 상태 효과 정리를 검사한다. GPU 준비 여부는 headless 검사로 판정하지 않고 실제 렌더러에서 별도로 확인한다.
