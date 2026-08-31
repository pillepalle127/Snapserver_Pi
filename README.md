# Snapserver Pi

Standalone Raspberry Pi audio appliance for [this repository](https://github.com/pillepalle127/Snapserver_Pi):

- receives music from iOS/Android through Bluetooth A2DP
- feeds audio through PipeWire into Snapserver
- exposes a dedicated 2.4 GHz access point for ESP-Mesh-Lite Snapclients
- needs no external Wi-Fi router during normal operation
- handles pairing, reconnect and A2DP recovery without entering a phone MAC address

## Architecture

```text
Phone -> Bluetooth A2DP -> PipeWire -> /tmp/snapfifo -> Snapserver
                                                        |
ESP-Mesh-Lite root -> Wi-Fi AP 192.168.4.1 ------------+
```

## Target

- Raspberry Pi OS Trixie ARM64 Lite
- Raspberry Pi with Bluetooth and AP-capable Wi-Fi
- installation through Ethernet or local console

## Quick start

```bash
chmod +x scripts/*.sh
./scripts/install.sh
./scripts/configure-ap.sh
sudo reboot
```

Run scripts as the normal installation user, not with `sudo`. They request elevated rights only where required. Running `configure-ap.sh` changes `wlan0` into an AP and therefore cuts an SSH session carried by Wi-Fi. Ethernet SSH remains available.

## Bluetooth behavior

The Pi advertises as `Snapserver-Pi`. At every boot a **three-minute pairing window** opens:

```text
0 to 180 seconds: Discoverable=yes, Pairable=yes
After 180 seconds: Discoverable=no, Pairable=no
```

Already bonded devices can reconnect after the window closes. The custom system-wide BlueZ `Agent1` continues to authorize services for paired devices. A disconnect does not delete the bond.

Open another three-minute window:

```bash
./scripts/open-pairing-window.sh
```

Pairing uses `NoInputNoOutput`, equivalent to a speaker without display or keyboard. This is Bluetooth Just Works pairing and does not provide numeric-comparison MITM protection.

## Automatic A2DP recovery

The user service `snapserver-pi-audio-watch.service`:

1. finds connected devices offering `Audio Source`
2. marks them trusted
3. checks for a matching PipeWire BlueZ node
4. sets `Snapcast Multiroom` as default sink
5. if missing, restarts WirePlumber and reconnects that concrete device
6. limits recovery to three attempts per device with a 60-second cooldown

No phone MAC address is required during normal operation.

## ESP-Mesh-Lite access point

`configure-ap.sh` creates:

```text
SSID: ESP-Mesh-Lite
Address: 192.168.4.1/24
Band: 2.4 GHz
Channel: 6
Security: WPA2-PSK, RSN, CCMP
Snapcast stream: 192.168.4.1:1704
Snapcast control: 192.168.4.1:1705
```

The password is requested without echo and stored only in NetworkManager's root-protected profile. The script sets Wi-Fi country `DE`, unblocks rfkill, enables NetworkManager management of `wlan0`, removes a stale same-name AP profile and recreates it correctly.

Override non-secret settings:

```bash
AP_SSID='My-Mesh' AP_ADDRESS='192.168.50.1/24' AP_CHANNEL=11 ./scripts/configure-ap.sh
```

## Configuration locations

```text
/etc/snapserver.conf
/etc/bluetooth/main.conf
~/.config/pipewire/pipewire.conf.d/90-snapserver.conf
~/.config/wireplumber/wireplumber.conf.d/80-headless-bluetooth.conf
/etc/systemd/system/snapserver-pi-agent.service
/etc/systemd/system/snapserver-pi-pairing-window.service
~/.config/systemd/user/snapserver-pi-audio-watch.service
```

BlueZ bonding data is maintained by BlueZ under `/var/lib/bluetooth`; do not publish that directory.

## Verification

```bash
./scripts/diagnose.sh
```

Or individually:

```bash
sudo systemctl status bluetooth snapserver snapserver-pi-agent snapserver-pi-pairing-window --no-pager
systemctl --user status pipewire wireplumber snapserver-pi-audio-watch --no-pager
bluetoothctl show
bluetoothctl devices Paired
wpctl status
nmcli -f DEVICE,TYPE,STATE,CONNECTION device status
ss -lnt | grep -E ':(1704|1705|1780)\b'
```

## Logs

```bash
sudo journalctl -u snapserver -f
sudo journalctl -u snapserver-pi-agent -u snapserver-pi-pairing-window -f
journalctl --user -u snapserver-pi-audio-watch -f
```

## Maintenance

Re-run `install.sh` after pulling an update. Existing Snapserver and BlueZ configuration files are backed up with timestamps. Existing BlueZ bonds are not deleted.

If a phone was explicitly removed with iOS **Forget This Device**, open a new pairing window and pair again. A normal disconnect requires no new pairing.

## Security

- no credentials, real MAC addresses or private LAN details belong in Git
- AP password is never embedded in the repository
- pairing is limited to three minutes after boot or a manual window request
- known devices remain reconnectable without keeping the Pi discoverable

## Repository layout

```text
config/       Snapserver, BlueZ, PipeWire and WirePlumber configuration
scripts/      installer, AP setup, Agent1, pairing window and diagnostics
systemd/      system and user services
LICENSE       MIT license
README.md     installation and operating guide
CHANGELOG.md  release history
```

## Rollback

Timestamped backups are created in `/etc`:

```text
/etc/snapserver.conf.backup-YYYYMMDD-HHMMSS
/etc/bluetooth/main.conf.backup-YYYYMMDD-HHMMSS
```

Restore a selected backup, then restart the respective service.

## License

MIT. See [LICENSE](LICENSE).
