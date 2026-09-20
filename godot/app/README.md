# Godot 앱 저장 기반

Flutter 제거 2단계의 첫 구현이다. **본게임의 Dart 런·성장·저장 호출을 대체한 상태는 아니다.** 구현된 계약과 검증 범위는 [검증 기록](../../docs/analysis/godot_save_foundation_20260921/README.md)에 정리한다.

| 모듈 | 역할 |
| --- | --- |
| `save_json.gd` | JSON의 signed int64 숫자를 정밀도 손실 없이 읽음. 문자열·실수 구분 유지 |
| `save_codec.gd` | Dart `GameSaveData`와 같은 v2 정규화·기본값·enum·모듈 ID, v1 이전 |
| `local_save_slot.gd` | guest 및 소문자로 정규화한 UUID 계정 슬롯 |
| `local_save_store.gd` | v2 원본/백업, v1 가져오기, `.tmp`·`.replace` 복구, 충돌 백업 |
| `web_save_store.gd` | 같은 origin의 기존 localStorage 키와 Web Locks 계약. 실제 브라우저 연결은 미검증 |
| `run_save_adapter.gd` | 앱 소유 저장 봉투에 네이티브 전투 상태 투영. 미처리 이벤트와 누락 포탑 설정은 거절 |

```gdscript
const Codec = preload("res://app/save_codec.gd")
const Store = preload("res://app/local_save_store.gd")
const Slot = preload("res://app/local_save_slot.gd")
# 기존 설치 인계 시 실제 Flutter application-support 경로를 명시한다.
# 기본 user://가 기존 Flutter 저장 위치라고 가정하지 않는다.
var store = Store.new("user://", Slot.guest())
var saved = store.load_save()
# null은 저장 없음/잘못된 저장일 수도, I/O 오류일 수도 있으므로 last_error를 확인한다.
if store.last_error != OK:
    push_error(store.last_error_message)
# 쓰기 성공을 확인한 뒤에만 저장 완료로 취급한다.
# store.save_save(canonical_v2) -> Error
```

쓰기에는 `Codec.decode()` 결과와 동등한 정규화된 v2 값·타입을 전달한다. 정수 필드에 문자열·실수를 넣거나 NaN/Infinity·엔진 객체를 포함하면 `ERR_INVALID_DATA`를 반환하며 기존 원본·백업을 변경하지 않는다. 읽기의 기존 Dart 기본값·정규화 규칙은 유지한다.

계정 슬롯은 `Slot.account(uuid)` 결과가 null이면 중단해야 한다. null을 Store 생성자에 넘기면 기본 guest가 선택된다. v1 임시 파일 경로는 생성자의 세 번째 인자로 명시한다. 계정 슬롯은 guest v1 파일을 읽지 않는다. OS별 기존 경로 자동 검색·이동은 구현하지 않았다.

네이티브 저장 API는 동기식이다. 같은 저장소에 대한 접근은 앱 서비스 한 곳에서 직렬화하고 Flutter와 Godot의 동시 쓰기를 허용하지 않는다. `capture(envelope, snapshot, turret_templates, saved_at)`는 앱 도메인이 경제·보상 이벤트를 반영하고 ACK한 뒤 호출한다. 포탑 설정은 네이티브 ID 문자열을 키로 하는 기존 SavedTurret 형태의 사전이다. 전투 상태로 성장·중요 재화를 추론하지 않는다. 투사체·코어 사이클 시계를 새 저장 필드로 추가하지 않는다.

Web 저장은 `await store.acquire_writer_lock(get_tree())` 성공 후 사용하고 종료 시 `release_writer_lock()`을 호출한다. Web Locks 미지원 시 기존 Flutter와 동일하게 로컬 lock을 생략하므로, 향후 연결 시 서버 writer generation 방어도 유지해야 한다. 현재 온라인 서비스 이관은 미완료다.

## 검사

```sh
WORK_DIR="$PWD" scripts/in_app_server_macos.sh flutter test test/godot_save_codec_fixture_test.dart test/godot_native_regression_test.dart
```

하네스는 별도 임시 Godot 프로젝트를 준비해 codec fixture·파일 복구·체크포인트·int64 및 기존 전투 회귀를 실행한다. Godot 바이너리가 없으면 native 검사는 건너뛰므로 그 결과를 통과로 간주하지 않는다. `GODOT_BIN`으로 바이너리를 지정할 수 있다. fixture 기대값은 실제 Dart codec이 생성한다. 의도적으로 저장 계약을 바꿀 때만 `UPDATE_GODOT_SAVE_FIXTURES=1`로 갱신하고 차이를 검토한다.

별도 개발 세션은 [실행 안내](../session/README.md)를 따른다. 계정·경제·전체 콘텐츠 이관의 완료 근거로 사용하지 않는다.

## 런·성장 도메인

독립 세션의 로컬 명령은 [런·성장 모듈](run_commands_README.md)을 따른다. 실제 콘텐츠 런의 본 저장 연결은 후속이며 기존 저장 codec·adapter 계약과 fixture 제한은 유지한다.
