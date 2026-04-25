#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/.tool"
DOWNLOADS_DIR="$TOOLS_DIR/downloads"

FLUTTER_DIR="$TOOLS_DIR/flutter"
ANDROID_SDK_DIR="$TOOLS_DIR/android-sdk"
JDK_DIR="$TOOLS_DIR/jdk"
ANDROID_AVD_DIR="$TOOLS_DIR/android-avd"

ANDROID_CMDLINE_TOOLS_VERSION="${ANDROID_CMDLINE_TOOLS_VERSION:-13114758}"
ANDROID_PLATFORM="${ANDROID_PLATFORM:-android-36}"
ANDROID_BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-36.0.0}"
ANDROID_SYSTEM_IMAGE="${ANDROID_SYSTEM_IMAGE:-system-images;android-36;google_apis;x86_64}"
AVD_NAME="${AVD_NAME:-genba_note_api_36}"
AVD_DEVICE="${AVD_DEVICE:-pixel_6}"

FLUTTER_DOWNLOAD_URL="${FLUTTER_DOWNLOAD_URL:-https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.41.6-stable.zip}"
ANDROID_CMDLINE_TOOLS_URL="${ANDROID_CMDLINE_TOOLS_URL:-https://dl.google.com/android/repository/commandlinetools-mac-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip}"
JDK_DOWNLOAD_URL="${JDK_DOWNLOAD_URL:-https://api.adoptium.net/v3/binary/latest/17/ga/mac/x64/jdk/hotspot/normal/eclipse}"

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$1"
}

fail() {
  printf '\n[error] %s\n' "$1" >&2
  exit 1
}

# Flutter / cmdline / JDK の既定 URL はすべて macOS 向け。Windows や Linux で実行すると
# 展開後の dart 等が動かず Error 9009 や symlink error になる。
UNAME_S="$(uname -s 2>/dev/null || echo unknown)"
if [[ "$UNAME_S" != "Darwin" ]]; then
  fail "このスクリプトは macOS 専用です (検出: ${UNAME_S})。OS 用の SDK は https://docs.flutter.dev/get-started/install から導入してください。誤って入れた .tool/ はフォルダごと削除して構いません。"
fi

need_command() {
  command -v "$1" >/dev/null 2>&1 || fail "必要なコマンドが見つかりません: $1"
}

download_if_missing() {
  local url="$1"
  local output="$2"

  if [[ -f "$output" ]]; then
    log "既存のダウンロードを再利用します: $(basename "$output")"
    return
  fi

  log "ダウンロードしています: $(basename "$output")"
  curl -L "$url" -o "$output"
}

setup_directories() {
  mkdir -p "$TOOLS_DIR" "$DOWNLOADS_DIR" "$ANDROID_AVD_DIR"
}

install_flutter() {
  if [[ -x "$FLUTTER_DIR/bin/flutter" ]]; then
    log "Flutter SDK はセットアップ済みです"
    return
  fi

  local flutter_zip="$DOWNLOADS_DIR/flutter_macos_stable.zip"
  download_if_missing "$FLUTTER_DOWNLOAD_URL" "$flutter_zip"

  log "Flutter SDK を展開しています"
  rm -rf "$FLUTTER_DIR"
  unzip -q "$flutter_zip" -d "$TOOLS_DIR"
}

install_jdk() {
  if find "$JDK_DIR" -path '*/Contents/Home' -type d | grep -q .; then
    log "JDK はセットアップ済みです"
    return
  fi

  local jdk_archive="$DOWNLOADS_DIR/jdk17-macos-x64.tar.gz"
  download_if_missing "$JDK_DOWNLOAD_URL" "$jdk_archive"

  log "JDK を展開しています"
  rm -rf "$JDK_DIR"
  mkdir -p "$JDK_DIR"
  tar -xzf "$jdk_archive" -C "$JDK_DIR"
}

install_android_cmdline_tools() {
  if [[ -x "$ANDROID_SDK_DIR/cmdline-tools/latest/bin/sdkmanager" ]]; then
    log "Android command-line tools はセットアップ済みです"
    return
  fi

  local tools_zip="$DOWNLOADS_DIR/commandlinetools-mac-latest.zip"
  download_if_missing "$ANDROID_CMDLINE_TOOLS_URL" "$tools_zip"

  log "Android command-line tools を展開しています"
  rm -rf "$ANDROID_SDK_DIR/cmdline-tools"
  mkdir -p "$ANDROID_SDK_DIR/cmdline-tools"
  unzip -q "$tools_zip" -d "$ANDROID_SDK_DIR/cmdline-tools"
  mv "$ANDROID_SDK_DIR/cmdline-tools/cmdline-tools" "$ANDROID_SDK_DIR/cmdline-tools/latest"
}

find_jdk_home() {
  find "$JDK_DIR" -path '*/Contents/Home' -type d | head -n 1
}

accept_android_licenses() {
  local jdk_home="$1"

  log "Android SDK ライセンスに同意します"
  yes | JAVA_HOME="$jdk_home" "$ANDROID_SDK_DIR/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_SDK_DIR" --licenses >/dev/null
}

install_android_packages() {
  local jdk_home="$1"

  log "Android SDK パッケージを導入しています"
  JAVA_HOME="$jdk_home" "$ANDROID_SDK_DIR/cmdline-tools/latest/bin/sdkmanager" \
    --sdk_root="$ANDROID_SDK_DIR" \
    "platform-tools" \
    "emulator" \
    "platforms;$ANDROID_PLATFORM" \
    "build-tools;$ANDROID_BUILD_TOOLS" \
    "$ANDROID_SYSTEM_IMAGE"
}

create_avd() {
  local jdk_home="$1"

  if JAVA_HOME="$jdk_home" ANDROID_SDK_ROOT="$ANDROID_SDK_DIR" ANDROID_AVD_HOME="$ANDROID_AVD_DIR" \
    "$ANDROID_SDK_DIR/cmdline-tools/latest/bin/avdmanager" list avd | grep -q "Name: $AVD_NAME"; then
    log "AVD $AVD_NAME は作成済みです"
    return
  fi

  log "AVD $AVD_NAME を作成しています"
  JAVA_HOME="$jdk_home" ANDROID_SDK_ROOT="$ANDROID_SDK_DIR" ANDROID_AVD_HOME="$ANDROID_AVD_DIR" \
    "$ANDROID_SDK_DIR/cmdline-tools/latest/bin/avdmanager" create avd \
    -n "$AVD_NAME" \
    -k "$ANDROID_SYSTEM_IMAGE" \
    -d "$AVD_DEVICE" \
    --force
}

warm_up_flutter() {
  log "Flutter の初回セットアップを行います"
  "$FLUTTER_DIR/bin/flutter" --version >/dev/null
}

main() {
  need_command curl
  need_command unzip
  need_command tar
  need_command find
  need_command yes

  setup_directories
  install_flutter
  install_jdk
  install_android_cmdline_tools

  local jdk_home
  jdk_home="$(find_jdk_home)"
  [[ -n "$jdk_home" ]] || fail "JDK Home を検出できませんでした"

  warm_up_flutter
  accept_android_licenses "$jdk_home"
  install_android_packages "$jdk_home"
  create_avd "$jdk_home"

  log "セットアップ完了"
  cat <<EOF

次のコマンドで実行できます:
  ./scripts/run_android.sh

必要に応じて headless 実行:
  HEADLESS=1 ./scripts/run_android.sh
EOF
}

main "$@"
