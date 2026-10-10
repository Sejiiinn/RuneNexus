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

기본 진입은 `boot.tscn`이다. 기존 배경·로고·코어를 사용하는 `res://ui/startup_screen.gd`가 업데이트 확인·재시도·선택/필수 업데이트·설치 상태를 표시한다. 업데이트를 통과한 뒤 `main.tscn`의 가벼운 앱 구성과 저장·계정 복원을 시작한다. 시작할 때 전장 모델·지형·전투 텍스처·효과 준비는 실행하지 않는다. 저장된 런은 기존 저장·경제·계정 계약에 필요한 숫자/도메인 상태만 정지 상태로 복원하고, 전장 표시는 시작 또는 이어하기에서 생성한다.

스테이지 진입의 [자원 목록](../presentation/stage_manifest.gd)은 해당 스테이지의 모든 웨이브 생성 스케줄에 있는 적, 건설/보상 UI와 같은 성장 파생값의 사용 가능 포탑, 저장된 포탑을 포함한다. 챕터·맵별 환경 자원과 효과 의존성을 합쳐 먼저 읽기 가능 여부를 확인한다. 기존 런 종료와 새 체크포인트가 영속화된 뒤에만 이전 표시 인스턴스를 정리하고 새 자원 범위를 확정한다. 종료 저장 실패 시 이전 표시·자원 범위를 유지하며, 새 런 저장 실패 시 전투를 정지한 채 재저장/이어하기를 기다린다. 자원 목록은 게임 규칙을 변경하거나 새로운 포탑 사용 권한을 주지 않는다.

[공유 자원 소유자](../presentation/stage_resources.gd)는 선택한 스테이지의 PackedScene·메시·텍스처·하늘 반사를 유지한다. 메인 화면으로 돌아오면 현재 자원을 해제하지 않고 3D viewport, 전장 노드 처리, 카메라/오버레이 갱신을 중단한다. 같은 스테이지 이어하기·재시작은 소스 자원과 준비된 효과를 재사용한다. 다른 스테이지를 열 때는 목적지와 공통인 자원만 보존하고 불필요한 환경 라이브러리, 적 상태 재질, 효과 캐시, 투사체 풀을 해제한다. 파일 단위 참조 수와 실제 GPU 메모리 사용량은 다른 지표다.

새 자원을 준비할 때는 기존 `게임 준비 중` 화면을 먼저 실제 프레임으로 그린 뒤 `ResourceLoader.load_threaded_request()`를 시작한다. 메인 스레드는 상태를 프레임별로 확인하고 완료된 요청에만 `load_threaded_get()`을 호출한다. 로딩 화면은 파일 읽기, 전장 구성, 효과 준비가 모두 끝날 때까지 유지한다. 환경·투사체 구성과 효과 종류별 준비 사이에 화면 갱신 기회를 주지만, 개별 장면 생성·텍스처 업로드·GPU 셰이더 컴파일 내부의 순간 정지까지 없앤다는 보장은 아니다. 이미 준비한 같은 스테이지 이어하기·재시작은 이 비동기 로딩 화면을 생략한다.

진입 결과를 사용하는 호출자는 `start_stage()`, `resume_run()`, `retry_stage()`를 `await`한다. 중복 진입은 첫 요청이 완료될 때까지 거부한다. 준비 중 OS 뒤로가기는 세대를 무효화하고 현재 스레드 요청을 회수한 뒤 로비로 돌아간다. 영속 전환 전 취소는 기존 런과 자원 범위를 유지하고, 전환 후 취소는 저장된 새 런을 정지 상태로 남긴다. 스테이지 준비 오류의 다시 시도는 앱·계정·체크포인트를 재생성하지 않고 실패 지점에 맞는 시작/이어하기를 재실행한다.

[효과 준비](../presentation/effect_preparation.gd)는 실제 스테이지 진입에서 선택한 적/포탑 종류만 별도 3D viewport로 렌더한다. 준비 중에는 시작 화면을 유지하고 전투 진행·입력을 차단하며, 전투·저장·난수를 진행하지 않는다. 준비 실패 시 저장된 런을 보존하고 재시도를 제공한다. 계정/세션 변경으로 준비 세대가 바뀌면 이전 작업은 풀을 인계하지 않고 취소한다. 개발용 fixture·session 진입은 자동 준비를 생략한다.

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

저장 API는 동기식이며 앱 서비스가 슬롯·소유권 전환과 쓰기를 직렬화한다. `capture(envelope, snapshot, turret_templates, saved_at)`는 도메인이 경제·보상 이벤트를 반영하고 ACK한 뒤 호출한다. 전투 상태로 성장·중요 재화를 추론하거나 v2에 없는 투사체·코어 시계를 저장하지 않는다. 진행 중 웨이브는 정지 상태로 복원한다. 메인메뉴에서 이어하기로 돌아오면 전장 준비가 끝난 뒤 웨이브 시작 대기 단계의 게임 일시정지만 해제하며, 다음 웨이브 시작은 기존 자동 진행 설정을 따른다. 고정 전투 시계의 미처리 누적 시간도 v2에 추가하지 않는다. 같은 세션의 일시정지는 누적 시간을 유지하지만 불러오기는 새 epoch의 체크포인트 재시작이며, 이전 미처리 시간을 재생하지 않는다. 따라서 저장/불러오기 전후 전체 전투의 비트 단위 동일성을 보장하지 않는다. [전투 시계 계약](../session/README.md#전투-시계)을 따른다. 런 포기·교체 전환의 종료 체크포인트와 영속 보상 Outbox를 슬롯별 `run_transition.json` 저널로 함께 확정하고, 쓰기 실패 시 Stage·재시도 전환을 차단한다. 런 포기 저장이 모두 성공하면 실제 전투의 남은 적 생성 큐도 취소해 후속 저장과 새 스테이지 진입이 가능하도록 하며, 실패하면 기존 런과 생성 큐를 보존한다. 게스트 큐는 계정으로 자동 이전하지 않으며 서버 재화를 로컬에서 확정하지 않는다.

저널의 `prepared`는 마지막 저장 여부와 관계없이 전환 직전 런·스폰 큐·성장·보상 큐를 복구하고, `committed`는 종료 체크포인트·보상 큐를 완료한다. 저장과 Outbox의 읽기·쓰기 진입은 이 복구를 먼저 수행하며, 복구 I/O 오류나 설치된 저널 손상은 양쪽 사용을 차단한다. 준비 기록이 설치되기 전에 남은 불완전한 임시 파일은 양쪽 원본을 변경하지 않았으므로 제거한다. 롤백은 체크포인트·큐의 백업도 되돌려 이후 원본 손상으로 미승인 런 종료가 복원되지 않게 한다. 확정 이후 저널 정리 실패는 전환 실패로 바꾸지 않고 다음 접근에서 정리를 재시도한다. 재시작 회귀는 각 저장·확정·정리 경계에서 별도 Godot 프로세스를 종료한 뒤 guest·계정 슬롯을 복구한다.

`content_run_save.gd`의 저장 `capture()`와 불러오기 `prepare()`는 같은 체크포인트 검증을 사용한다. 저장 시에는 맵·런 단계·포탑/젬·성장 한도·코어 HP·적/남은 스폰 등을 검증하며 전투 초기 설정이나 포탑·적 복원 데이터를 만들지 않는다. 실제 복원 데이터와 대기 스폰 난수는 검증에 성공한 `prepare()`에서만 생성한다. 성공한 동일 시드 복원 결과는 유지하며, 검증에서 거부한 복원은 더 이상 난수를 소비하지 않는다. [검증·측정 근거](../../docs/analysis/save_validation_20260928/README.md).

계정 세션은 Android Keystore 기반 보안 저장에 보관하고, 온라인 저장·경제 요청은 `res://services/`가 담당한다. `res://app_config.json`의 API·Google·업데이트 주소는 빌드 시 환경값으로 생성한다. 공백인 개발 설정에서는 운영 API를 임의 호출하지 않는다. 인증·온라인 저장·앱 업데이트의 실제 기기 결과는 자동 회귀와 구분해 기록한다.

## 확장 스테이지 저장 이관

확장 콘텐츠의 [고정 ID와 진행 순서](../content/README.md#확장-진행과-고정-id)는 저장 ID와 분리한다. v2 진행에 `progressionVersion=1`, `unlockedStageIds`, `grandfatherUnlocks`를 보존하고 payload 해시·저널에도 포함한다. 신규 기본 진행은 ID 1만 열며 보존 권한은 비어 있다. 구 저장은 원본의 클리어·접근·성장·진행 연구와 유효한 런·모듈 근거를 읽어 이미 열린 기능을 레벨 0이어도 보존한다. 같은 이관을 다시 실행해도 보상·지갑·레벨을 추가하지 않는다.

이관은 정식 앱의 저장 진입에서 원자적으로 기록한다. 구 `growthVersion=0`은 기존 치확·긴급매각 강화와 토벌 연구의 변환 계약을 함께 보존하며 성장 버전 1로 정규화한다. 완료 연구·진행 중 연구·기존 런·최초 보상 수령 기록은 새 표시 순번으로 번호를 바꾸지 않는다. 슬롯 2의 보존 구매 자격은 실제 구매 완료와 구분한다.

클라이언트 호환 세대는 4다. 서버는 아직 확장하지 않은 계정의 기존 세대를 지원하고, 확장 진행을 저장한 계정에는 세대 4를 요구한다. 현재 클라이언트라도 구 outbox가 진행 버전을 내리거나 보존 권한·접근 ID를 제거하는 쓰기는 거부한다. 이미 성공한 요청의 동일 영수증 재조회는 유지하며 서버 지갑이나 구매 권리를 로컬 플래그만으로 생성하지 않는다. 운영 API와 DB 적용은 배포 절차에서 별도로 수행한다.

## 검사

```sh
python3 scripts/verify_godot_content.py
GODOT_BIN=/path/to/godot python3 scripts/run_godot_native_regressions.py
```

네이티브 회귀 실행기는 임시 Godot 프로젝트에 저장 codec fixture·파일 복구·체크포인트·전투와 UI 스크립트를 복사한다. Godot 실행 파일이 없으면 실패한다. 보관된 Dart 기반 기대 fixture는 기존 저장 계약과의 비교 입력이며, 수치나 스키마를 의도적으로 변경할 때 차이를 검토해 갱신한다. 실제 Android 저장 인계·계정·수명주기 검증은 [인앱 가이드](../../.agents/in_app_test_guide.md)를 따른다.

`verify_startup_screen.gd`는 전투 자원 없이 시작하는 로비와 명시적 전투 준비·실패·재시도 게이트를 검사한다. `verify_stage_loading_feedback.gd`는 준비된 프로젝트에서 로딩 화면의 최초 프레임·지속 갱신, 중복 진입, 전환 전후 뒤로가기, 실패·범위 한정 재시도 및 같은 스테이지 빠른 경로를 검사한다. `RUNE_STAGE_FEEDBACK_CAPTURE_DIR`를 절대 경로로 지정하고 실제 렌더러로 실행하면 화면과 프레임 순서 근거를 저장한다. `verify_stage_resource_lifecycle.gd`는 별도 프로세스의 신규/저장 런 시작, 로비·이어하기·재시작과 챕터 전환의 자원 범위 및 저장 보존을 검사한다. `verify_environment_resource_lifetime.gd`와 `verify_stage_effect_cache.gd`는 공유 참조 유지와 불필요한 소스·재질·풀 해제를 검사한다. 에셋을 준비한 프로젝트의 `verify_effect_preparation.gd`는 풀 인계·재진입·취소·중복 요청·첫 발사와 상태 효과 정리를 검사한다. GPU 준비 여부는 headless 검사로 판정하지 않고 실제 렌더러에서 별도로 확인한다.
