#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/.tool"

FLUTTER_SDK_REAL="${FLUTTER_SDK_REAL:-/tmp/flutter-sdk-real}"
ANDROID_SDK_LINK="${ANDROID_SDK_LINK:-/tmp/android-sdk}"
JDK_LINK="${JDK_LINK:-/tmp/jdk17}"
RUN_DIR="${RUN_DIR:-/tmp/genba-note-run}"
DEVICE_ID="${DEVICE_ID:-emulator-5554}"
RUN_ANALYZE="${RUN_ANALYZE:-0}"
LAUNCH_APP="${LAUNCH_APP:-1}"
APP_ID="${APP_ID:-jp.genbanote.app}"
APP_ACTIVITY="${APP_ACTIVITY:-jp.genbanote.app/.MainActivity}"

SOURCE_FLUTTER_SDK="$TOOLS_DIR/flutter"
SOURCE_ANDROID_SDK="$TOOLS_DIR/android-sdk"
SOURCE_JDK_ROOT="$TOOLS_DIR/jdk"

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$1"
}

fail() {
  printf '\n[error] %s\n' "$1" >&2
  exit 1
}

require_dir() {
  local dir="$1"
  local label="$2"
  [[ -d "$dir" ]] || fail "$label が見つかりません: $dir"
}

find_jdk_home() {
  find "$SOURCE_JDK_ROOT" -path '*/Contents/Home' -type d | head -n 1
}

ensure_tools() {
  require_dir "$SOURCE_FLUTTER_SDK" "Flutter SDK"
  require_dir "$SOURCE_ANDROID_SDK" "Android SDK"
  require_dir "$SOURCE_JDK_ROOT" "JDK"

  JDK_HOME="$(find_jdk_home)"
  [[ -n "${JDK_HOME:-}" ]] || fail "JDK Home を検出できませんでした"

  export FLUTTER_SDK="$FLUTTER_SDK_REAL"
  export ANDROID_SDK_ROOT="$ANDROID_SDK_LINK"
  export JAVA_HOME="$JDK_LINK/Contents/Home"

  mkdir -p "$RUN_DIR"
  rsync -a --delete "$SOURCE_FLUTTER_SDK/" "$FLUTTER_SDK_REAL/"
  ln -sfn "$SOURCE_ANDROID_SDK" "$ANDROID_SDK_LINK"
  ln -sfn "${JDK_HOME%/Contents/Home}" "$JDK_LINK"
}

sync_project() {
  log "実行用コピーを更新しています"
  rsync -a --delete \
    --exclude '.git' \
    --exclude '.tool' \
    --exclude 'build' \
    --exclude '.dart_tool' \
    "$ROOT_DIR/" "$RUN_DIR/"

  cat > "$RUN_DIR/android/local.properties" <<EOF
sdk.dir=$ANDROID_SDK_ROOT
flutter.sdk=$FLUTTER_SDK
EOF
}

ensure_device() {
  if ! "$ANDROID_SDK_ROOT/platform-tools/adb" devices | grep -q "^$DEVICE_ID[[:space:]]"; then
    fail "対象エミュレータが起動していません: $DEVICE_ID"
  fi
}

install_app() {
  log "依存関係を取得しています"
  (
    cd "$RUN_DIR"
    "$FLUTTER_SDK/bin/flutter" pub get
  )

  if [[ "$RUN_ANALYZE" == "1" ]]; then
    log "静的解析を実行しています"
    (
      cd "$RUN_DIR"
      "$FLUTTER_SDK/bin/flutter" analyze
    )
  fi

  log "debug APK をビルドしています"
  (
    cd "$RUN_DIR"
    "$FLUTTER_SDK/bin/flutter" build apk --debug
  )

  log "起動中エミュレータへアプリを再インストールします"
  "$ANDROID_SDK_ROOT/platform-tools/adb" -s "$DEVICE_ID" install -r \
    "$RUN_DIR/build/app/outputs/flutter-apk/app-debug.apk"

  if [[ "$LAUNCH_APP" == "1" ]]; then
    log "アプリを前面起動します"
    "$ANDROID_SDK_ROOT/platform-tools/adb" -s "$DEVICE_ID" shell am start -n "$APP_ACTIVITY" >/dev/null
  else
    log "アプリ起動はスキップしました"
  fi

  log "再インストール完了: $APP_ID"
}

main() {
  ensure_tools
  sync_project
  ensure_device
  install_app
}

main "$@"
