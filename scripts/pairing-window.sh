#!/usr/bin/env bash
set -euo pipefail
readonly WINDOW_SECONDS="${PAIRING_WINDOW_SECONDS:-180}"
readonly STATE_DIR=/run/snapserver-pi
readonly FLAG="${STATE_DIR}/pairing-open"
cleanup() {
  rm -f "$FLAG"
  bluetoothctl discoverable off >/dev/null 2>&1 || true
  bluetoothctl pairable off >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM
install -d -m0755 "$STATE_DIR"
touch "$FLAG"
rfkill unblock bluetooth || true
for _ in {1..20}; do bluetoothctl show >/dev/null 2>&1 && break; sleep 1; done
bluetoothctl show >/dev/null 2>&1 || { echo "No Bluetooth controller" >&2; exit 1; }
bluetoothctl power on || true
bluetoothctl system-alias Snapserver-Pi
bluetoothctl pairable on
bluetoothctl discoverable on
echo "Pairing window open for ${WINDOW_SECONDS} seconds"
sleep "$WINDOW_SECONDS"
echo "Pairing window closed; bonded devices may still reconnect"
