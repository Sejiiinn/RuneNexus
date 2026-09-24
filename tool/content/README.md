# Godot 콘텐츠 원본

`godot/content/game_content.json`과 `godot/content/growth_content.json`은 Godot 앱의 버전 관리 원본이다. 이전 Dart/Flutter 생성기는 사용하지 않는다. 수치 변경은 이 JSON과 관련 회귀 fixture를 함께 수정하고, 네이티브 Godot 검사로 실제 계약을 확인한다.

SDK 없이 아래 검사로 JSON 구조·참조·fixture 정합성과 기존 Godot 회귀 사례를 확인한다.

```sh
python3 scripts/verify_godot_content.py
python3 scripts/run_godot_native_regressions.py
```

회귀 실행은 임시 Godot 프로젝트에 검사 스크립트와 fixture를 복사하므로 사용자 저장이나 편집기 캐시에 접근하지 않는다. `GODOT_BIN` 또는 `GODOT_EXECUTABLE`로 Godot 실행 파일을 지정할 수 있으며 없으면 검사를 실패로 처리한다.
