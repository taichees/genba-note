#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADB_BIN="${ADB_BIN:-$ROOT_DIR/.tool/android-sdk/platform-tools/adb}"
DEVICE_ID="${DEVICE_ID:-emulator-5554}"
PACKAGE_NAME="jp.genbanote.app"

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$1"
}

fail() {
  printf '[error] %s\n' "$1" >&2
  exit 1
}

[[ -x "$ADB_BIN" ]] || fail "adb が見つかりません: $ADB_BIN"

if ! "$ADB_BIN" devices | grep -q "^$DEVICE_ID[[:space:]]\+device$"; then
  fail "対象デバイスが接続されていません: $DEVICE_ID"
fi

log "SQLite の全テーブルをクリアします"
"$ADB_BIN" -s "$DEVICE_ID" shell "run-as $PACKAGE_NAME sqlite3 ./files/genba_note.db <<'SQL'
BEGIN TRANSACTION;
DELETE FROM work_logs;
DELETE FROM properties;
DELETE FROM clients;
DELETE FROM app_settings;
DELETE FROM sqlite_sequence WHERE name IN ('work_logs', 'properties', 'clients');
COMMIT;
VACUUM;
SQL"

log "クリア後の件数を確認します"
"$ADB_BIN" -s "$DEVICE_ID" shell "run-as $PACKAGE_NAME sqlite3 -header -column ./files/genba_note.db 'SELECT COUNT(*) AS work_logs FROM work_logs; SELECT COUNT(*) AS properties FROM properties; SELECT COUNT(*) AS clients FROM clients; SELECT COUNT(*) AS app_settings FROM app_settings;'"

log "完了しました"
