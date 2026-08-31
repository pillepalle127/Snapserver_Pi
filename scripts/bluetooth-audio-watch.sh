#!/usr/bin/env bash
set -u
readonly POLL_SECONDS=5 MAX_RETRIES=3 RETRY_COOLDOWN=60
declare -A retries=() last_try=()
log(){ echo "snapserver-pi-audio: $*"; }
connected_sources(){
  bluetoothctl devices Connected 2>/dev/null | awk '/^Device /{print $2}' | while read -r mac; do
    bluetoothctl info "$mac" 2>/dev/null | grep -q 'Audio Source' && echo "$mac"
  done
}
node_exists(){
  local id="${1//:/_}"
  wpctl status -n 2>/dev/null | grep -Eiq "bluez_(input|card).*${id}"
}
set_default(){
  local id
  id=$(wpctl status -n 2>/dev/null | awk '/snapserver/{for(i=1;i<=NF;i++)if($i~/^[0-9]+\.$/){gsub(/\./,"",$i);print $i;exit}}')
  [[ -n "$id" ]] && wpctl set-default "$id" >/dev/null 2>&1 || true
}
recover(){
  local mac="$1" now=$(date +%s)
  (( ${retries[$mac]:-0} < MAX_RETRIES )) || return 0
  (( now - ${last_try[$mac]:-0} >= RETRY_COOLDOWN )) || return 0
  retries[$mac]=$(( ${retries[$mac]:-0} + 1 )); last_try[$mac]=$now
  log "Missing A2DP node for $mac, recovery ${retries[$mac]}/${MAX_RETRIES}"
  systemctl --user restart wireplumber.service || return 0
  sleep 3; bluetoothctl disconnect "$mac" >/dev/null 2>&1 || true
  sleep 2; bluetoothctl connect "$mac" >/dev/null 2>&1 || true
  sleep 5; set_default
}
set_default
while sleep "$POLL_SECONDS"; do
  mapfile -t devices < <(connected_sources)
  for mac in "${devices[@]}"; do
    bluetoothctl trust "$mac" >/dev/null 2>&1 || true
    if node_exists "$mac"; then retries[$mac]=0; set_default; else recover "$mac"; fi
  done
done
