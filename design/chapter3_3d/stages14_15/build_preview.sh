#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
ORG_GRADLE_PROJECT_runeNexusGodotPreview=true WORK_DIR="$PWD" \
 scripts/in_app_server_macos.sh flutter build apk --release \
 --target-platform=android-arm64 --split-per-abi \
 --target=design/chapter3_3d/stages14_15/android_preview.dart \
 --build-number=4015 \
 --no-tree-shake-icons
