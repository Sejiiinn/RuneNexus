#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_ROOT"
GODOT_EXECUTABLE="${GODOT_EXECUTABLE:-$REPO_ROOT/build/godot-preview/tools/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$GODOT_EXECUTABLE" ]]; then
  echo 'Godot 4.7.2 실행 파일을 GODOT_EXECUTABLE로 지정하세요.' >&2
  exit 1
fi
if [[ "$("$GODOT_EXECUTABLE" --version)" != 4.7.2.stable.* ]]; then
  echo 'Android AAR와 동일한 Godot 4.7.2가 필요합니다.' >&2
  exit 1
fi
GODOT_EXECUTABLE="$GODOT_EXECUTABLE" python3 scripts/build_godot_pack.py
ORG_GRADLE_PROJECT_runeNexusGodotPreview=true WORK_DIR="$REPO_ROOT" \
  scripts/in_app_server_macos.sh flutter build apk --release \
  --target-platform=android-arm64 --split-per-abi \
  --target=design/stage1_3d/godot_preview/main.dart \
  --dart-define=RUNE_NEXUS_DEBUG_PANEL=true --no-tree-shake-icons
mkdir -p build/apk-preview
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk build/apk-preview/rune-nexus-godot-cannon-arm64.apk
echo "$REPO_ROOT/build/apk-preview/rune-nexus-godot-cannon-arm64.apk"
