#!/usr/bin/env bash
set -u
echo '=== OS ==='; grep PRETTY_NAME /etc/os-release; uname -m
echo '=== System services ==='; sudo systemctl --no-pager status bluetooth snapserver snapserver-pi-agent snapserver-pi-pairing-window || true
echo '=== User services ==='; systemctl --user --no-pager status pipewire wireplumber snapserver-pi-audio-watch || true
echo '=== Bluetooth ==='; bluetoothctl show; bluetoothctl devices Paired; bluetoothctl devices Connected
echo '=== PipeWire ==='; wpctl status
echo '=== Network ==='; nmcli -f DEVICE,TYPE,STATE,CONNECTION device status; ip -brief address
echo '=== Snapserver ports ==='; ss -lnt | grep -E ':(1704|1705|1780)\b' || true
