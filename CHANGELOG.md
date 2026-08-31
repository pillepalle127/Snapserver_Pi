# Changelog

## 1.0.0 - 2026-08-31

- Replaced the external interactive pairing helper with a custom BlueZ Agent1.
- Reduced pairing window to three minutes.
- Preserved reconnect authorization for already bonded devices.
- Made the pairing-window service non-blocking during boot.
- Added per-device A2DP checks, bounded retries and cooldown.
- Expanded comments, README, diagnostics and GitHub publishing guidance.
- Retained the corrected NetworkManager AP setup for `wlan0`.
