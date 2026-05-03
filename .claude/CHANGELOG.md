FlClashR — Changelog

[2026-05-03] Stub fixes for desktop platforms
- Author: dev
- Type: Fix
- Files: lib/common/window.dart, lib/common/windows.dart, lib/common/tray.dart
- Summary: Removed dead imports that caused build failure. These are desktop platform stubs not used on Android target.
- Build: ✅ Passing after fix
- Related: Delivered as stub_fixes.zip


[2026-05-02] VPN init crash fix — Direct FFI
- Author: dev
- Type: Critical Fix
- Files: lib/clash/lib.dart, lib/main.dart
- Summary: Replaced IsolateNameServer IPC with direct FFI through _MainFFIHandler. Two FlutterEngine bug — IsolateNameServer cannot communicate across different Dart VMs.
- Build: ✅ Passing
- Crash fixed: SIGSEGV on VPN start
- Architecture impact: Decision #1 in ARCHITECTURE.md


[2026-05-02] Controller guard bypass
- Author: dev
- Type: Fix
- Files: lib/controller.dart
- Summary: setupClashConfig() now calls _setupClashConfig() directly. Bypasses homeScaffoldKey guard which always returned null because FlClashR uses SimpleHomeView (not CommonScaffold).
- Build: ✅ Passing
- Bug fixed: VPN started without proxy configuration (green button but no routing)
- Architecture impact: Decision #2 in ARCHITECTURE.md


[2026-05-01] Russia preset implementation
- Author: dev
- Type: Feature
- Files: lib/common/russia_preset.dart
- Summary: Added 11 services with domain, IP-CIDR, and keyword rules. Default: YouTube✅, Telegram✅, WhatsApp✅. QUIC blocking rule (DST-PORT,443,REJECT,udp). Final fallback: MATCH,DIRECT.
- Build: ✅ Passing
- Architecture impact: Decision #5 in ARCHITECTURE.md (rule ordering)


[2026-04-30] Initial fork — FlClashX → FlClashR
- Author: dev
- Type: Fork
- Summary: Forked from FlClashX. Renamed package to com.follow.clashr. Changed app name to FlClashR. Green→red launcher icon with white R letter.
- Build: ✅ Passing
