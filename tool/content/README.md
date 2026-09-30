# Godot 콘텐츠 원본

전투 콘텐츠는 [Godot 원본·전개 계약](../../godot/content/README.md#원본에서-실행-입력으로-전개)을 따른다. `godot/content/source/`를 수정하고 `scripts/content_compiler.py`로 추적 중인 실행 입력을 생성한다. `growth_content.json`은 성장 수치의 수정 원본이다. 이전 Dart/Flutter 생성기는 사용하지 않는다. 관련 회귀 fixture와 네이티브 Godot 검사로 실제 계약을 확인한다.

SDK 없이 아래 검사로 JSON 구조·참조·fixture 정합성과 기존 Godot 회귀 사례를 확인한다.

```sh
python3 scripts/content_compiler.py --check
python3 scripts/verify_godot_content.py
python3 scripts/run_godot_native_regressions.py
```

회귀 실행은 임시 Godot 프로젝트에 검사 스크립트와 fixture를 복사하므로 사용자 저장이나 편집기 캐시에 접근하지 않는다. `GODOT_BIN` 또는 `GODOT_EXECUTABLE`로 Godot 실행 파일을 지정할 수 있으며 없으면 검사를 실패로 처리한다.
