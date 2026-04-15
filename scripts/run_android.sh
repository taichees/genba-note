#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/.tool"

FLUTTER_SDK_REAL="${FLUTTER_SDK_REAL:-/tmp/flutter-sdk-real}"
ANDROID_SDK_LINK="${ANDROID_SDK_LINK:-/tmp/android-sdk}"
JDK_LINK="${JDK_LINK:-/tmp/jdk17}"
RUN_DIR="${RUN_DIR:-/tmp/genba-note-run}"
AVD_NAME="${AVD_NAME:-genba_note_api_36}"
DEVICE_ID="${DEVICE_ID:-emulator-5554}"
HEADLESS="${HEADLESS:-0}"
REUSE_EXISTING_EMULATOR="${REUSE_EXISTING_EMULATOR:-0}"

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

ensure_emulator() {
  local emulator_args=(
    "@$AVD_NAME"
    -no-audio
    -no-snapshot
    -no-boot-anim
  )

  if [[ "$HEADLESS" == "1" ]]; then
    emulator_args+=(-no-window)
  fi

  if "$ANDROID_SDK_ROOT/platform-tools/adb" devices | grep -q "$DEVICE_ID"; then
    if [[ "$HEADLESS" == "1" || "$REUSE_EXISTING_EMULATOR" == "1" ]]; then
      log "既存のエミュレータ $DEVICE_ID を利用します"
      return
    fi

    log "既存のエミュレータ $DEVICE_ID を再起動して画面表示を有効にします"
    "$ANDROID_SDK_ROOT/platform-tools/adb" -s "$DEVICE_ID" emu kill || true

    local retries=30
    while "$ANDROID_SDK_ROOT/platform-tools/adb" devices | grep -q "$DEVICE_ID"; do
      ((retries--))
      [[ "$retries" -gt 0 ]] || fail "既存エミュレータの停止待ちでタイムアウトしました"
      sleep 1
    done
  fi

  log "エミュレータ $AVD_NAME を起動します"
  nohup "$ANDROID_SDK_ROOT/emulator/emulator" \
    "${emulator_args[@]}" \
    > /tmp/"$AVD_NAME".log 2>&1 &

  log "Android の起動完了を待っています"
  "$ANDROID_SDK_ROOT/platform-tools/adb" wait-for-device
  until [[ "$("$ANDROID_SDK_ROOT/platform-tools/adb" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; do
    sleep 2
  done
}

run_app() {
  log "依存関係を取得しています"
  (
    cd "$RUN_DIR"
    "$FLUTTER_SDK/bin/flutter" pub get
  )

  log "静的解析を実行しています"
  (
    cd "$RUN_DIR"
    "$FLUTTER_SDK/bin/flutter" analyze
  )

  log "Android エミュレータでアプリを起動します"
  (
    cd "$RUN_DIR"
    "$FLUTTER_SDK/bin/flutter" run -d "$DEVICE_ID" --device-timeout 120
  )
}

main() {
  ensure_tools
  sync_project
  ensure_emulator
  run_app
}

main "$@"
