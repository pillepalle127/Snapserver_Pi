#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo "Run as normal user, not with sudo" >&2; exit 1; }
C=${AP_CONNECTION:-ESP-Mesh-Lite-AP}; I=${AP_INTERFACE:-wlan0}; S=${AP_SSID:-ESP-Mesh-Lite}; A=${AP_ADDRESS:-192.168.4.1/24}; K=${AP_CHANNEL:-6}
sudo raspi-config nonint do_wifi_country DE
sudo rfkill unblock wifi; sudo nmcli radio wifi on; sudo nmcli device set "$I" managed yes
sudo systemctl restart NetworkManager; sleep 3
read -r -s -p "WPA2 password for '$S' (8-63 characters): " P; echo
(( ${#P} >= 8 && ${#P} <= 63 )) || { echo "Invalid password length" >&2; exit 2; }
nmcli -t -f NAME con show | grep -Fxq "$C" && sudo nmcli con delete "$C" || true
sudo nmcli con add type wifi ifname "$I" con-name "$C" ssid "$S"
sudo nmcli con mod "$C" connection.interface-name "$I" connection.autoconnect yes connection.autoconnect-priority 100 802-11-wireless.mode ap 802-11-wireless.band bg 802-11-wireless.channel "$K" wifi-sec.key-mgmt wpa-psk wifi-sec.proto rsn wifi-sec.pairwise ccmp wifi-sec.psk "$P" ipv4.method shared ipv4.addresses "$A" ipv6.method disabled
unset P
sudo nmcli con up "$C" ifname "$I"
nmcli -f NAME,TYPE,DEVICE con show --active
ip -brief address show "$I"
