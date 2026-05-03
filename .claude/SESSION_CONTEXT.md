# FlClashR — Session Context
> Last updated: 2026-05-03
> Build: ✅ PASSING
> VPN: ✅ WORKING (traffic proxied, dnsleaktest OK)
> Test status: ⚠️ YouTube/Telegram/WhatsApp over VPN — awaiting verification after stub fixes

---

## Quick Status

| Component | Status | Note |
|-----------|--------|------|
| Build (flutter build apk) | ✅ | NDK 27.0.12077973, compileSdk=36 |
| App launch | ✅ | No crash on start |
| Subscription import | ✅ | Two-stage import: Profile.update() → fix + converter |
| VPN start | ✅ | Button turns green |
| VPN traffic routing | ✅ | dnsleaktest confirms proxy |
| Telegram via VPN | ⚠️ | Needs testing |
| YouTube via VPN | ⚠️ | Needs testing |
| WhatsApp via VPN | ⚠️ | Needs testing |

---

## Last 3 Changes

### Change #1 (2026-05-03): Stub fixes
- **Files**: `lib/common/window.dart`, `lib/common/windows.dart`, `lib/common/tray.dart`
- **What**: Removed dead imports that broke the build
- **Status**: ✅ Fixed, delivered in `stub_fixes.zip`
- **Risk**: None — these are platform stubs, not used on Android

### Change #2 (2026-05-02): VPN init crash fix
- **Files**: `lib/clash/lib.dart`, `lib/main.dart`
- **What**: Switched from IPC (IsolateNameServer) to direct FFI via `_MainFFIHandler`
- **Why**: Two FlutterEngine = two Dart VMs = IsolateNameServer doesn't work cross-VM
- **Status**: ✅ Fixed
- **Risk**: HIGH if someone tries to add IPC back. Read RULES.md.

### Change #3 (2026-05-02): setupClashConfig guard bypass
- **Files**: `lib/controller.dart`
- **What**: `setupClashConfig()` now calls `_setupClashConfig()` directly
- **Why**: `homeScaffoldKey` guard always returned null (no CommonScaffold in SimpleHomeView)
- **Status**: ✅ Fixed
- **Risk**: If CommonScaffold is ever added back, remove this bypass

---

## Key Function Signatures
