#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -ne 0 ]] || { echo "Run as normal user, not with sudo" >&2; exit 1; }
D=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd); U=${XDG_CONFIG_HOME:-$HOME/.config}; T=$(date +%Y%m%d-%H%M%S)
sudo raspi-config nonint do_wifi_country DE; sudo timedatectl set-timezone Europe/Berlin
sudo sed -i 's/^# *de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen; sudo locale-gen de_DE.UTF-8; sudo update-locale LANG=de_DE.UTF-8
sudo apt-get update; sudo apt-get install -y snapserver bluez rfkill python3-dbus python3-gi pipewire pipewire-pulse wireplumber libspa-0.2-bluetooth network-manager dnsmasq-base iw
[[ -f /etc/snapserver.conf ]] && sudo cp -a /etc/snapserver.conf "/etc/snapserver.conf.backup-$T"
[[ -f /etc/bluetooth/main.conf ]] && sudo cp -a /etc/bluetooth/main.conf "/etc/bluetooth/main.conf.backup-$T"
sudo install -m0644 "$D/config/snapserver.conf" /etc/snapserver.conf
install -d -m0755 "$U/pipewire/pipewire.conf.d" "$U/wireplumber/wireplumber.conf.d" "$U/systemd/user" "$HOME/.local/lib/snapserver-pi"
install -m0644 "$D/config/pipewire/90-snapserver.conf" "$U/pipewire/pipewire.conf.d/"
install -m0644 "$D/config/wireplumber/80-headless-bluetooth.conf" "$U/wireplumber/wireplumber.conf.d/"
sudo python3 - "$D/config/bluez/general.conf" <<'PYBLUEZ'
from pathlib import Path
import sys
p=Path('/etc/bluetooth/main.conf'); vals={}
for line in Path(sys.argv[1]).read_text().splitlines():
 line=line.strip()
 if line and not line.startswith('#'): k,v=line.split('=',1);vals[k.strip()]=v.strip()
lines=p.read_text().splitlines() if p.exists() else [];out=[];inside=found=written=False
for line in lines:
 t=line.strip()
 if t.startswith('[') and t.endswith(']'):
  if inside and not written: out.extend(f'{k}={v}' for k,v in vals.items());written=True
  inside=t.lower()=='[general]';found|=inside;out.append(line);continue
 if inside and t.lstrip('#').split('=',1)[0].strip() in vals: continue
 out.append(line)
if inside and not written: out.extend(f'{k}={v}' for k,v in vals.items())
if not found: out.extend(['','[General]']+[f'{k}={v}' for k,v in vals.items()])
p.write_text(chr(10).join(out)+chr(10))
PYBLUEZ
sudo install -d -m0755 /usr/local/lib/snapserver-pi
sudo install -m0755 "$D/scripts/bluez-agent.py" "$D/scripts/pairing-window.sh" /usr/local/lib/snapserver-pi/
sudo install -m0644 "$D/systemd/system/"*.service /etc/systemd/system/
install -m0755 "$D/scripts/bluetooth-audio-watch.sh" "$HOME/.local/lib/snapserver-pi/"
install -m0644 "$D/systemd/user/snapserver-pi-audio-watch.service" "$U/systemd/user/"
sudo loginctl enable-linger "$USER"; sudo systemctl daemon-reload; systemctl --user daemon-reload
sudo rfkill unblock bluetooth; sudo systemctl restart bluetooth; sleep 3
sudo systemctl enable --now snapserver-pi-agent.service
systemctl --user enable --now pipewire wireplumber snapserver-pi-audio-watch
systemctl --user restart pipewire; sleep 2; systemctl --user restart wireplumber; sleep 3
sudo systemctl enable --now snapserver; sudo systemctl restart snapserver
sudo systemctl enable snapserver-pi-pairing-window.service
sudo systemctl restart --no-block snapserver-pi-pairing-window.service
printf '%s
' 'Installed. Pairing is open for three minutes.' 'Configure AP: ./scripts/configure-ap.sh' 'Open pairing later: ./scripts/open-pairing-window.sh'
