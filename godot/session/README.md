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

`Stage`로 1~15 순환 진입, 건설칸 클릭→`Build`로 배치, `Start`로 전투, `Pause`로 정지/재개, `1x/4x`, `Camera`, `Exit`로 종료한다. `Save`는 개발 세션을 v2로 저장하고 `Load`는 정지 상태로 복원한다(`Pause`로 재개). 드래그·핀치·휠은 네이티브 카메라 입력이다. 개발 세션은 계정·경제·전체 콘텐츠를 구현하거나 본게임 저장을 대체하지 않는다. 저장은 `user://standalone-session/saves/guest/`로 분리하며 기존 사용자 슬롯을 자동으로 읽지 않는다. 현재 기본 화살포탑/일반 적 fixture만 복원하고 다른 설정은 거절한다. [저장 기반 API](../app/README.md)를 참고한다.

`standalone_fixture.json`은 `lib/data/definitions/game_stage_maps.dart`에서 기존 `prepare_godot_project.py`가 추출한 지도/경로와 `test/fixtures/turret_stat_calculation.json`의 기본 1레벨 화살포탑 입력을 추출한 **개발 검증 자료**다. 게임 콘텐츠의 새 원본이 아니며 3D 자산은 복제하지 않는다. 스테이지 정의가 바뀌면 이 검증 자료도 해당 원본에서 갱신한다.

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
