# Godot MCP 편집 연결

역할: 개인 Godot MCP 플러그인의 RuneNexus 개발 프로젝트 준비와 원본·배포 경계. 확인: 2026-09-12. 본게임 실행·배포 기준은 [스테이지 1 공용 런타임](../docs/stage1_3d_preview.md)을 따른다.

## 프로젝트와 원본

- 편집·MCP 연결: `build/godot/editor/project.godot`.
- 변경의 기준 원본: `godot/`의 `.gd`, `.gdshader`, `.tscn`. 편집 프로젝트는 이 파일들을 개별 symlink로 연결한다.
- 개발 에셋: helper가 준비된 `build/godot/project/assets`를 `build/godot/editor/assets`에 독립 복사한다. 공용 `.import` 파일과 `.godot` 캐시는 복사하지 않는다. 게임용 GLB의 원본 경로는 `assets/images/stage1_3d/`, Blender 제작 원본은 `design/`이다.
- 배포용 프로젝트·팩: 기존 `build/godot/project`와 `build/godot/android-assets/rune_nexus.pck`를 그대로 사용한다. 원본 `godot/project.godot` 옆에는 준비된 `assets`가 없으므로 직접 여는 경로로 사용하지 않는다.

## 준비와 연결

저장소의 공용 에셋 준비가 끝난 뒤 개인 플러그인의 helper를 실행한다. 첫 명령은 기존 생성 프로젝트만 준비하고, 두 번째 명령은 MCP 전용 편집 프로젝트만 준비한다. 어느 명령도 Godot이나 MCP 서버를 실행하지 않는다.

```sh
python3 scripts/prepare_godot_project.py
python3 /Users/sejin/plugins/godot-mcp/scripts/prepare_runenexus_editor.py --repo-root "$PWD"
```

`prepare_godot_project.py`에는 `--output` 인자가 없다. 이 스크립트의 복사·정리 대상을 symlink가 있는 `build/godot/editor`로 바꾸지 않는다. 원본과 같은 파일을 덮어쓰거나 개발 전용 addon을 삭제할 수 있다.

현재 사용하는 Godot은 공식 `4.7.2.stable`이며 실행 파일은 `build/godot-preview/tools/Godot.app/Contents/MacOS/Godot`이다. Codex에 설치된 개인 Godot MCP 서버와 함께 다음 편집 프로젝트를 연다.

```sh
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --editor --path build/godot/editor
```

helper는 `/Users/sejin/.local/share/godot-mcp/upstream/addons/godot_mcp`의 addon을 편집 프로젝트에만 복사한다. `editor_plugins/enabled`와 `MCPRuntime` autoload도 편집 프로젝트의 별도 `project.godot`에만 추가한다. 연결 여부는 편집기의 MCP 상태와 도구의 실제 응답으로 확인한다.

## 편집 결과 보존

기존 소스 파일을 저장하면 symlink가 가리키는 `godot/` 원본에 반영된다. macOS의 Godot 4.7.2는 안전 저장에서도 symlink의 대상 파일을 갱신하도록 구현되어 있다. [Godot 해당 버전의 파일 저장 구현](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/unix/file_access_unix.cpp#L110)을 기준으로 한다.

파일 경로 자체를 바꾸는 MCP의 이동·이름 변경·삭제는 symlink 이름만 바꾸거나 링크를 제거할 수 있다. 이 작업은 원본 경로와 참조 변경을 함께 확인한다. 새 코드·씬은 편집 프로젝트 안에 별도 파일로 만들어지므로 내용을 검토해 `godot/`에 반영한 뒤 연결한다. 생성 프로젝트만 바뀐 상태를 게임 반영 완료로 보고하지 않는다.

helper를 다시 실행할 때 원본과 다른 편집 파일, 편집 프로젝트에만 있는 새 코드·씬, 수정된 addon 파일은 덮어쓰지 않고 오류로 위치를 알린다. `project.godot`도 이전 helper 생성본과 일치할 때만 갱신한다. 별도로 편집한 설정은 원본과 비교해 필요한 부분을 반영하거나 별도 보관한 후 다시 준비한다. `project.godot` 전체를 원본으로 복사해 MCP 설정을 배포에 섞지 않는다. 에디터를 정리할 때도 새 파일·별도 설정 변경을 먼저 확인한다.

편집 에셋은 이전 복사본·현재 파일·새 공용 에셋의 해시를 비교한다. 현재 파일이 이전 복사본 그대로일 때만 새 에셋으로 갱신하며, 별도로 수정한 파일은 오류로 위치를 알리고 보존한다. 편집기에만 추가된 에셋과 import 산출물을 자동 삭제하지 않는다. 에셋 갱신은 편집기를 종료한 상태에서 준비한 뒤 다시 연다. 초기 helper가 만든 공용 `assets` symlink는 동일한 대상과 기존 준비 기록이 확인될 때만 독립 복사본으로 전환하며, 다른 링크는 변경하지 않는다.

## 실행과 검증 범위

2026-09-12 설치 확인: 개인 플러그인 `godot-mcp@personal` 활성화, 서버·애드온 0.6.0, MCP 도구 77개 등록과 이 편집 프로젝트의 연결을 확인했다. 편집기 import도 완료했다. `run_scene` 이후 runtime helper 연결은 확인되지 않아 런타임 조회·게임 캡처는 미검증이다. 테스트 실행은 중지했으며 설치 확인 범위에서 추가 원인 조사는 진행하지 않았다.

전장은 `main.gd`의 실행 중 초기화에서 만들어진다. `main.tscn`을 편집기로 열었을 때 로컬 씬 트리가 비어 보이는 것은 지형 누락의 근거가 아니다. F5 또는 MCP의 실행 도구로 공용 `main.tscn`을 실행하고 실제 런타임 트리·화면을 확인한다.

macOS 단독 실행은 기존 `assets/preview_frame.json`의 대포 6문·정지 표적 3기 입력을 사용한다. 추가 테스트용 게임 코드를 넣지 않는다. Space는 착탄 재생, C는 고정/드론 시점, S는 그림자, V는 체적 효과를 전환한다. 이 화면에는 Flutter HUD·저장·실제 웨이브 흐름이 없다.

MCP 연결·Godot 편집·공용 장면 검사는 개발 확인이다. UI·게임플레이·렌더링의 최종 실제 화면 검증은 기존 [인앱 검증](in_app_test_guide.md)의 Android APK 경로를 따른다. 데스크톱 검수 결과로 Android 본게임의 설치 입력·HUD·저장이나 실기기 성능을 통과했다고 보고하지 않는다.

## 배포·캐시 분리

개발 전용 addon과 autoload는 `build/godot/editor`에만 있다. 기존 패키징은 `godot/`와 `assets/images/stage1_3d/`를 입력으로 해시하고 `build/godot/project`에서 팩을 생성하므로 MCP addon이 게임 PCK/APK에 추가되지 않는다. `godot/export_presets.cfg`와 배포 스크립트는 이 연결을 위해 바꾸지 않는다.

`build/godot/editor/.godot`와 편집 에셋의 `.import`·GLB 추출 이미지는 편집기 전용 import 상태다. GUI import가 공용 `build/godot/project/assets`에 파일을 쓰지 않도록 에셋 디렉터리도 분리한다. 공용 에셋을 다시 준비해도 편집기용 addon·설정·소스 링크를 공용 생성 프로젝트로 복사하지 않는다. 편집 에셋의 별도 변경은 게임 원본에 자동 반영되지 않으며, 원본 변경 뒤의 본게임 빌드·APK 검증은 기존 절차로 진행한다.
