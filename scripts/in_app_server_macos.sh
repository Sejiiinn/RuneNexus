#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-status}"
PORT="${PORT:-53000}"
WORK_DIR="${WORK_DIR:-/Users/sejin/Documents/RuneNexus}"
FLUTTER="${FLUTTER:-/Users/sejin/development/flutter/bin/flutter}"
DART="${DART:-/Users/sejin/development/flutter/bin/cache/dart-sdk/bin/dart}"
BUILD_DIR="$WORK_DIR/build/web"

url() {
  printf 'http://127.0.0.1:%s/?cache_bust=%s\n' "$PORT" "$(date +%Y%m%d%H%M%S)"
}

listening_pids() {
  lsof -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true
}

require_file() {
  local path="$1"
  local label="$2"
  if [[ ! -e "$path" ]]; then
    printf 'MISSING_%s=%s\n' "$label" "$path" >&2
    exit 1
  fi
}

status() {
  local pids code error_file error_text
  pids="$(listening_pids | paste -sd, -)"
  printf 'LISTENING_PIDS=%s\n' "${pids:-}"
  error_file="$(mktemp)"
  if code="$(curl -sS -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/" 2>"$error_file")"; then
    printf 'HTTP_CODE=%s\n' "${code:-000}"
  else
    error_text="$(tr '\n' ' ' < "$error_file")"
    printf 'HTTP_CODE=%s\n' "${code:-000}"
    printf 'HTTP_ERROR=%s\n' "$error_text"
  fi
  rm -f "$error_file"
  printf 'URL=%s' "$(url)"
}

stop_server() {
  local pids
  pids="$(listening_pids)"
  if [[ -z "$pids" ]]; then
    printf 'STOPPED port=%s pids=\n' "$PORT"
    return
  fi

  # 53000 is reserved for the in-app test server in this project.
  # Keep this scoped to the listening process on that exact port.
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    kill "$pid" 2>/dev/null || true
  done <<< "$pids"
  printf 'STOPPED port=%s pids=%s\n' "$PORT" "$(printf '%s\n' "$pids" | paste -sd, -)"
}

build_web() {
  require_file "$FLUTTER" FLUTTER
  cd "$WORK_DIR"
  "$FLUTTER" build web --pwa-strategy=none --no-tree-shake-icons --dart-define=RUNE_NEXUS_DEBUG_PANEL=true
}

dev_server() {
  require_file "$FLUTTER" FLUTTER
  cd "$WORK_DIR"
  printf 'DEV_READY_PENDING port=%s\n' "$PORT"
  printf 'HOT_RELOAD=type r in this terminal after Dart changes\n'
  exec "$FLUTTER" run -d web-server \
    --web-hostname=127.0.0.1 \
    --web-port="$PORT" \
    --dart-define=RUNE_NEXUS_DEBUG_PANEL=true
}

serve_foreground() {
  require_file "$BUILD_DIR/index.html" BUILD_INDEX
  cd "$WORK_DIR"
  printf 'READY port=%s\n' "$PORT"
  printf 'URL=%s' "$(url)"
  exec python3 "$WORK_DIR/scripts/no_cache_static_server.py" --port "$PORT" --host 127.0.0.1 --directory "$BUILD_DIR"
}

case "$ACTION" in
  status)
    status
    ;;
  stop)
    stop_server
    ;;
  build)
    build_web
    ;;
  start)
    if curl -sS -o /dev/null "http://127.0.0.1:$PORT/" 2>/dev/null; then
      status
    else
      serve_foreground
    fi
    ;;
  dev)
    stop_server
    dev_server
    ;;
  restart)
    stop_server
    build_web
    serve_foreground
    ;;
  url)
    url
    ;;
  dart)
    require_file "$DART" DART
    shift
    "$DART" "$@"
    ;;
  flutter)
    require_file "$FLUTTER" FLUTTER
    shift
    "$FLUTTER" "$@"
    ;;
  *)
    cat >&2 <<USAGE
Usage: scripts/in_app_server_macos.sh <action>

Actions:
  status   Show 53000 listener, HTTP status, and cache-bust URL.
  build    Build Flutter Web with --pwa-strategy=none.
  dev      Run Flutter web-server in the foreground for hot reload.
  start    Serve existing build/web in the foreground unless 53000 is already healthy.
  restart  Stop 53000, build web, then serve build/web in the foreground.
  stop     Stop the process listening on 53000.
  url      Print a cache-bust URL.
  dart     Run the pinned Dart executable with remaining args.
  flutter  Run the pinned Flutter executable with remaining args.
USAGE
    exit 2
    ;;
esac
