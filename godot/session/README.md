# Godot 전투 세션과 독립 개발 경로

`session_controller.gd`는 콘텐츠 전투 명령·이벤트 ACK·시간/연구 처리·체크포인트·정산 연결을 공유한다. 정식 `app/app_lifecycle.gd`와 개발 `standalone.gd`는 이를 각각 상속하며, 개발 툴바·진단 라벨·고정 fixture 상태와 명령은 `standalone.gd`에만 둔다. 공통 책임 회귀는 `verify_session_controller.gd`로 확인한다.


`NativeCombatRuntime.advance_session()`을 `main.gd::_process()`에서 호출한다. `session.clock=godot`인 패킷의 `dt`, `steps`, `dtSteps`는 실행하지 않는다. 기존 명시적 step 경로는 회귀 검사에 남긴다.

입력 패킷 `session`: `clock`, `phase`, `running`(디버그 전투 포함), `paused`, `loading`, `backgrounded`, `speed`. 첫 bootstrap에서 `effectTime`, `squaredSteps`로 진행 중인 효과 시계를 인계한다. 일반 Android 본게임에서 성장·골드·저장·보상 권위는 기존 Flutter/Dart 앱 도메인이다. 별도 `--session`에서는 아래 Godot 런·성장 도메인을 사용한다.

응답은 동일 `ackSequence`에서도 `stateRevision`이 증가한다. `session.wallElapsed`, `effectTime`, `squaredSteps`, `coreDestructionElapsed`, `nexusAlert`, `phase`가 Godot 시계의 읽기 모델이다. `events`는 클라이언트가 `ackEvent`를 보낼 때까지 유지한다. 화면 입력 `boardTap(column,row)` 및 `cameraChanged(camera,zoom)`도 같은 저널을 사용한다. 새로운 scene epoch에서는 시계·선택·이벤트가 초기화되고 과거 bootstrap을 거절한다.

Android는 `is_session_active()`로 백그라운드·뷰 분리·포커스 상실을 즉시 차단하며 복귀 시 누적 시간을 재생하지 않는다. Flutter에는 최대 10Hz 상태를 보고하고 3D와 VFX는 Godot 프레임마다 갱신한다. 화면의 논리 크기·HUD 영역이 변경될 때만 외부 frame이 필요하다. `inputBlocked`와 논리 좌표 `rewardViewport=[x,y,width,height]`는 앱 UI 경계를 전달한다.

## 실행 경로의 구분

일반 Android 앱은 아래 독립 세션으로 진입하지 않는다. 독립 경로에 기능을 단계적으로 구현·검증하고 저장·UI·계정·패키징 등 조건을 갖춘 뒤 본게임 진입을 교체한다. 현재 독립 경로는 개발용이며 최종 배포 앱이 아니다. 완료 범위와 후속 작업은 [실행 로드맵](../../docs/godot_unified_app_roadmap.md)을 따른다.

## 정식 로컬 앱 경로

`Godot --path build/godot/project -- --app`으로 자동 저장·시작 복원과 Godot HUD·로비를 사용한다. 복원한 전투는 로비에서 이어하기로 재개한다. 신규 사용자의 무런 성장 저장, 저장 실패 정지/재시도와 백그라운드·정상 종료 저장을 제공한다. [구현·검증·남은 서비스 경계](../../docs/analysis/godot_app_ui_20260921/README.md)를 따른다. 아래 `--session`은 기존 개발 검사용 수동 경로다.

## Flutter 없는 실행

저장소 루트에서 기존 자산 준비 후 실행한다. 에디터의 미저장 작업은 변경하지 않는다.

```sh
python3 scripts/prepare_godot_project.py
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --editor --path build/godot/project --import
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --path build/godot/project -- --session
```

`Stage`로 1~15 순환 진입, 건설칸 클릭→`Build`로 배치, `Start`로 실제 다음 웨이브를 시작한다. `Tower`로 6종 포탑 선택, `Wave +`로 비전투 중 검증할 웨이브를 선택한다. `Pause`, `1x/4x`, `Camera`, `Exit`와 네이티브 드래그·핀치·휠 조작은 유지한다. 마지막 웨이브 뒤에는 새 전투를 만들지 않는다.

기본 `--session`은 [실제 콘텐츠 로더](../content/README.md)와 [Godot 런·성장 명령](../app/run_commands_README.md)을 사용한다. 건설·강화·판매·링크·젬·특성·런 업그레이드는 실제 비용·해금·재고 규칙을 적용한다. 하단 개발 조작으로 명령을 실행하고 골드·조각·비용을 확인할 수 있다. 5웨이브 보상/젬 선택 구매에서는 전투가 멈추며 선택 후 원래 단계로 돌아간다.

독립 세션에 처치·보스·웨이브·런 강화 퀘스트, KST 일·주 초기화, 플레이 시간과 런 종료 룬·코어·최고 라운드·클리어·해금을 연결했다. 이벤트는 진행에 반영한 뒤 ACK하며, stable run UUID와 기존 `claimedEventIds`의 종료 마커로 중복 정산을 방지한다. 다이아는 서버 잔액에 지급하지 않고 미정산 수량으로 기록한다. 일반 성장·연구·코어·장착 모듈과 연구 만료도 세션에서 처리한다.

실제 콘텐츠의 `Save`/`Load`는 기존 **v2** 형식으로 런·성장·장착·전투를 저장·복원한다. `Exit`도 저장이 성공한 뒤 장면을 종료한다. 재실행 후 `Load`로 불러오며 복원은 정지 상태이고 `Pause`로 재개한다. 준비·전투·구매/자연 보상·패배·성공 상태를 보존한다. 이벤트 반영·ACK 후 저장하고, 복원 설정 검증을 마친 뒤 장면을 교체한다. 운영체제 강제 종료 직전까지 자동 저장하거나 시작할 때 자동으로 불러오는 기능은 아니다.

런 종료 v2 체크포인트와 영속 보상 Outbox를 먼저 기록한 뒤 Stage/재시도로 이동한다. 쓰기 실패 시 전환을 차단한다. 게스트 큐는 로컬에 격리하고 계정으로 자동 재바인딩하지 않으며, 서버 다이아·모듈권을 로컬에서 확정하지 않는다. `Exit` 저장 실패 시 현재 전투를 유지한다. 기본 1타일·원점 0 좌표를 저장하며 잘못된 맵·수치·지원하지 않는 설정은 거절한다.

계정 정산은 실제 HTTP 요청 경로·동일 key/본문 바이트 재시도·writer/revision 동기화 선행·snapshot 적용과 저장·단조 증가 캐시를 구현했다. 인증된 context와 실제 저장 업로드 성공을 반환하는 `sync_save`를 `app.settle_pending_rewards(context, sync_save, transport)`에 주입해야 한다. 전체 로그인·온라인 저장 업로더·자동 계정 스케줄링과 실계정 E2E는 미완료이며 운영 서버는 호출하지 않았다. 독립 `--app`에는 자동 저장·시작 시 정지 복원과 Godot HUD·로비를 연결했다. 인증·온라인 저장 업로더·서비스 전용 메뉴, 기존 설치 데이터 인계·정식 패키징·본게임 진입 전환은 남아 있다. [정산·퀘스트 구현 기록](../../docs/analysis/godot_rewards_quests_20260921/README.md)을 따른다.

이미 등장한 적의 상태와 포탑 쿨다운·피해 통계는 복원한다. 기존 v2에 없는 탄환·코어 사이클 시계는 새로 저장하지 않으며, 대기 중인 적의 무작위 값은 콘텐츠 규칙에 따라 재생성한다. [실제 런 저장 검증](../../docs/analysis/godot_content_save_20260921/README.md)을 참고한다.

기존 저장 회귀는 `--session --session-fixture` 또는 검사 스크립트의 `content_enabled=false`에서 유지한다. 이 모드에서만 기본 화살포탑/고정 일반 적 설정을 복원하고 다른 설정은 거절한다. `Save`는 v2, `Load`는 정지 상태 복원(`Pause`로 재개)이다. 저장 경로는 `user://standalone-session/saves/guest/`이며 실제 사용자 슬롯을 자동으로 읽지 않는다. [저장 기반 API](../app/README.md)를 참고한다.

`standalone_fixture.json`은 기존 Dart 지도와 기본 포탑 스탯에서 추출한 **과거 저장 회귀 자료**다. 현재 실행용 콘텐츠 원본이 아니며 실제 콘텐츠 경로는 이 파일의 고정 전투 설정을 사용하지 않는다.

실제 콘텐츠 연결·챕터별 전투/보스·저장 복원 검사는 다음과 같다. headless 없이 실행하면 `build/godot/captures/content-*.png`에 실제 독립 앱 화면을 남긴다.

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

실제 콘텐츠 프로세스 재시작 검사는 아래 스크립트를 `verify_content_restart.gd`로 지정한다. `verify_session_restart.gd`는 기존 고정 fixture 검사다. 자산 준비 후 서로 다른 프로세스로 실행한다. `<절대 임시 경로>`는 검증용 빈 디렉터리이며 본게임 저장 경로를 지정하지 않는다.

```sh
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --path build/godot/project --script verify_session_restart.gd -- write <절대 임시 경로>
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --path build/godot/project --script verify_session_restart.gd -- read <같은 절대 임시 경로>
```

실행 후 검증 디렉터리를 삭제할 수 있다. read를 headless 없이 실행하면 `build/godot/captures/save-restart.png`에 개발 세션 복원 화면을 남긴다.
