#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADB_BIN="${ADB_BIN:-$ROOT_DIR/.tool/android-sdk/platform-tools/adb}"
DEVICE_ID="${DEVICE_ID:-emulator-5554}"
CENTER_LAT="${CENTER_LAT:-35.6809591}"
CENTER_LON="${CENTER_LON:-139.7673068}"
RADIUS_KM="${RADIUS_KM:-10}"
INTERVAL_SEC="${INTERVAL_SEC:-10}"
SIMULATOR_PID_FILE="${SIMULATOR_PID_FILE:-/tmp/genba-note-location-simulator.pid}"
SELF_TEST="${SELF_TEST:-0}"
MAX_ITERATIONS="${MAX_ITERATIONS:-0}"

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$1"
}

fail() {
  printf '[error] %s\n' "$1" >&2
  exit 1
}

is_number() {
  [[ "$1" =~ ^-?[0-9]+([.][0-9]+)?$ ]]
}

cleanup_pid_file() {
  if [[ -f "$SIMULATOR_PID_FILE" ]] && [[ "$(cat "$SIMULATOR_PID_FILE" 2>/dev/null || true)" == "$$" ]]; then
    rm -f "$SIMULATOR_PID_FILE"
  fi
}

[[ -x "$ADB_BIN" ]] || fail "adb が見つかりません: $ADB_BIN"
is_number "$CENTER_LAT" || fail "CENTER_LAT は数値で指定してください: $CENTER_LAT"
is_number "$CENTER_LON" || fail "CENTER_LON は数値で指定してください: $CENTER_LON"
is_number "$RADIUS_KM" || fail "RADIUS_KM は数値で指定してください: $RADIUS_KM"
is_number "$INTERVAL_SEC" || fail "INTERVAL_SEC は数値で指定してください: $INTERVAL_SEC"
is_number "$MAX_ITERATIONS" || fail "MAX_ITERATIONS は数値で指定してください: $MAX_ITERATIONS"

trap cleanup_pid_file EXIT

device_is_connected() {
  "$ADB_BIN" devices | grep -q "^$DEVICE_ID[[:space:]]\+device$"
}

generate_position() {
  local seed="$1"
  local now="$2"

  awk -v lat="$CENTER_LAT" -v lon="$CENTER_LON" -v radius_km="$RADIUS_KM" -v seed="$seed" -v now="$now" '
    BEGIN {
      pi = atan2(0, -1)
      srand(now + seed)

      distance = sqrt(rand()) * radius_km * 1000.0
      bearing = rand() * 2.0 * pi
      north_m = distance * cos(bearing)
      east_m = distance * sin(bearing)

      meters_per_deg_lat = 111320.0
      meters_per_deg_lon = 111320.0 * cos(lat * pi / 180.0)
      if (meters_per_deg_lon == 0) {
        meters_per_deg_lon = 0.000001
      }

      out_lat = lat + (north_m / meters_per_deg_lat)
      out_lon = lon + (east_m / meters_per_deg_lon)
      out_bearing = bearing * 180.0 / pi

      printf "%.7f %.7f %.0f %.1f\n", out_lat, out_lon, distance, out_bearing
    }
  '
}

run_self_test() {
  local base_now
  local lat1 lon1 dist1 bearing1
  local lat2 lon2 dist2 bearing2

  base_now="$(date +%s)"
  read -r lat1 lon1 dist1 bearing1 <<<"$(generate_position 1 "$base_now")"
  read -r lat2 lon2 dist2 bearing2 <<<"$(generate_position 2 "$((base_now + 1))")"

  [[ -n "$lat1" && -n "$lon1" && -n "$dist1" && -n "$bearing1" ]] || fail "自己診断に失敗しました: 1回目の座標生成が空です"
  [[ -n "$lat2" && -n "$lon2" && -n "$dist2" && -n "$bearing2" ]] || fail "自己診断に失敗しました: 2回目の座標生成が空です"

  if [[ "$lat1" == "$lat2" && "$lon1" == "$lon2" ]]; then
    fail "自己診断に失敗しました: 連続生成した座標が同一です"
  fi

  log "自己診断 OK"
  log "1回目: lat=$lat1 lon=$lon1 距離=${dist1}m 方位=${bearing1}deg"
  log "2回目: lat=$lat2 lon=$lon2 距離=${dist2}m 方位=${bearing2}deg"
}

if [[ "$SELF_TEST" == "1" ]]; then
  run_self_test
  exit 0
fi

if ! device_is_connected; then
  fail "対象エミュレータが接続されていません: $DEVICE_ID"
fi

log "ランダム位置シミュレーションを開始します"
log "中心: lat=$CENTER_LAT lon=$CENTER_LON / 半径=${RADIUS_KM}km / 間隔=${INTERVAL_SEC}s"
log "停止するには Ctrl+C を押してください"

iteration=0
while true; do
  if ! device_is_connected; then
    log "対象エミュレータ $DEVICE_ID が未接続になったため終了します"
    exit 0
  fi

  iteration=$((iteration + 1))
  current_epoch="$(date +%s)"

  read -r next_lat next_lon distance_m bearing_deg <<<"$(generate_position "$iteration" "$current_epoch")"

  if [[ -z "$next_lat" || -z "$next_lon" ]]; then
    log "位置生成に失敗したため終了します"
    exit 1
  fi

  if ! "$ADB_BIN" -s "$DEVICE_ID" emu geo fix "$next_lon" "$next_lat" >/dev/null 2>&1; then
    log "位置送信に失敗したため終了します"
    exit 0
  fi
  log "送信: lat=$next_lat lon=$next_lon 距離=${distance_m}m 方位=${bearing_deg}deg"

  if [[ "$MAX_ITERATIONS" -gt 0 && "$iteration" -ge "$MAX_ITERATIONS" ]]; then
    log "MAX_ITERATIONS=${MAX_ITERATIONS} に達したため終了します"
    exit 0
  fi

  sleep "$INTERVAL_SEC"
done
