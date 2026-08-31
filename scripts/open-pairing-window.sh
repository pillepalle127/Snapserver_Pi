#!/usr/bin/env bash
set -euo pipefail
sudo systemctl restart --no-block snapserver-pi-pairing-window.service
echo "Bluetooth pairing window opened for three minutes."
