# Godot 전투 세션 (Flutter 제거 1단계)

`NativeCombatRuntime.advance_session()`을 `main.gd::_process()`에서 호출한다. `session.clock=godot`인 패킷의 `dt`, `steps`, `dtSteps`는 실행하지 않는다. 기존 명시적 step 경로는 회귀 검사에 남긴다.

입력 패킷 `session`: `clock`, `phase`, `running`(디버그 전투 포함), `paused`, `loading`, `backgrounded`, `speed`. 첫 bootstrap에서 `effectTime`, `squaredSteps`로 진행 중인 효과 시계를 인계한다. 단계 2 이전의 성장·골드·저장·보상 권위는 기존 앱 도메인이다.

응답은 동일 `ackSequence`에서도 `stateRevision`이 증가한다. `session.wallElapsed`, `effectTime`, `squaredSteps`, `coreDestructionElapsed`, `nexusAlert`, `phase`가 Godot 시계의 읽기 모델이다. `events`는 클라이언트가 `ackEvent`를 보낼 때까지 유지한다. 화면 입력 `boardTap(column,row)` 및 `cameraChanged(camera,zoom)`도 같은 저널을 사용한다. 새로운 scene epoch에서는 시계·선택·이벤트가 초기화되고 과거 bootstrap을 거절한다.

Android는 `is_session_active()`로 백그라운드·뷰 분리·포커스 상실을 즉시 차단하며 복귀 시 누적 시간을 재생하지 않는다. Flutter에는 최대 10Hz 상태를 보고하고 3D와 VFX는 Godot 프레임마다 갱신한다. 화면의 논리 크기·HUD 영역이 변경될 때만 외부 frame이 필요하다. `inputBlocked`와 논리 좌표 `rewardViewport=[x,y,width,height]`는 앱 UI 경계를 전달한다.

## Flutter 없는 실행

저장소 루트에서 기존 자산 준비 후 실행한다. 에디터의 미저장 작업은 변경하지 않는다.

```sh
python3 scripts/prepare_godot_project.py
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --editor --path build/godot/project --import
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --path build/godot/project -- --session
```

`Stage`로 1~15 순환 진입, 건설칸 클릭→`Build`로 배치, `Start`로 실제 다음 웨이브를 시작한다. `Tower`로 6종 포탑 선택, `Wave +`로 비전투 중 검증할 웨이브를 선택한다. `Pause`, `1x/4x`, `Camera`, `Exit`와 네이티브 드래그·핀치·휠 조작은 유지한다. 마지막 웨이브 뒤에는 새 전투를 만들지 않는다.

기본 `--session`은 [실제 콘텐츠 로더](../content/README.md)와 [Godot 런·성장 명령](../app/run_commands_README.md)을 사용한다. 건설·강화·판매·링크·젬·특성·런 업그레이드는 실제 비용·해금·재고 규칙을 적용한다. 하단 개발 조작으로 명령을 실행하고 골드·조각·비용을 확인할 수 있다. 5웨이브 보상/젬 선택 구매에서는 전투가 멈추며 선택 후 원래 단계로 돌아간다.

처치·웨이브 이벤트는 런의 골드/조각/선택 상태에 한 번 반영한 뒤 ACK한다. 다이아는 서버 잔액에 지급하지 않고 미정산 수량으로만 기록한다. 일반 성장·연구·코어·장착 모듈은 메모리 progression 입력으로 처리하며, 연구 만료도 세션에서 반영한다. 본게임 로비 UI·계정 보상 정산·퀘스트·저장은 후속이며 스테이지 이동/종료는 저장되지 않은 검증 런을 버린다.

실제 콘텐츠의 `Save`/`Load`는 **ERR_UNAVAILABLE로 명시적으로 거절**한다. 이벤트 ACK, 슬롯 쓰기, 현재 장면 교체 전에 거절하며 기존 체크포인트를 보존한다. 새 경로의 성장·장착·적 설정 재구성과 경제 반영을 검증한 후 본게임 저장에 연결해야 한다.

기존 저장 회귀는 `--session --session-fixture` 또는 검사 스크립트의 `content_enabled=false`에서 유지한다. 이 모드에서만 기본 화살포탑/고정 일반 적 설정을 복원하고 다른 설정은 거절한다. `Save`는 v2, `Load`는 정지 상태 복원(`Pause`로 재개)이다. 저장 경로는 `user://standalone-session/saves/guest/`이며 실제 사용자 슬롯을 자동으로 읽지 않는다. [저장 기반 API](../app/README.md)를 참고한다.

`standalone_fixture.json`은 기존 Dart 지도와 기본 포탑 스탯에서 추출한 **과거 저장 회귀 자료**다. 현재 실행용 콘텐츠 원본이 아니며 실제 콘텐츠 경로는 이 파일의 고정 전투 설정을 사용하지 않는다.

실제 콘텐츠 연결·챕터별 전투/보스·저장 거절 검사는 다음과 같다. headless 없이 실행하면 `build/godot/captures/content-*.png`에 실제 독립 앱 화면을 남긴다.

```sh
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --path build/godot/project --script verify_content_session.gd
```

실제 비용·상태 명령과 전투 연결 검사는 `verify_run_session.gd`다. headless 없이 실행하면 `build/godot/captures/run-commands-combat.png`를 저장한다. 도메인 전체 Dart 비교는 [명령 모듈 안내](../app/run_commands_README.md)를 따른다.

기존 고정 설정의 시계·입력·저장 회귀:

```sh
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --path build/godot/project --script verify_native_session.gd
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --path build/godot/project --script verify_standalone_session.gd
```

두 번째 검사를 headless 없이 실행하면 같은 장면의 Metal 전투 화면을 `build/godot/captures/standalone-session.png`에 저장한다. 데스크톱 통과는 Android 본게임 HUD·실기기 성능·저장 동등성의 완료 근거가 아니다.

실제 프로세스 재시작 검사는 기존 자산 준비 후 서로 다른 프로세스로 실행한다. `<절대 임시 경로>`는 검증용 빈 디렉터리이며 본게임 저장 경로를 지정하지 않는다.

```sh
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --path build/godot/project --script verify_session_restart.gd -- write <절대 임시 경로>
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --path build/godot/project --script verify_session_restart.gd -- read <같은 절대 임시 경로>
```

실행 후 검증 디렉터리를 삭제할 수 있다. read를 headless 없이 실행하면 `build/godot/captures/save-restart.png`에 개발 세션 복원 화면을 남긴다.
