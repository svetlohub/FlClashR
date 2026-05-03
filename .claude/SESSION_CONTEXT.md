FlClashR — Session Context
Last updated: 2026-05-03
Build: ✅ PASSING
VPN: ✅ WORKING (traffic proxied, dnsleaktest OK)
Test status: ⚠️ YouTube/Telegram/WhatsApp over VPN — awaiting verification after stub fixes


Quick Status

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


Last 3 Changes

Change #1 (2026-05-03): Stub fixes
- Files: lib/common/window.dart, lib/common/windows.dart, lib/common/tray.dart
- What: Removed dead imports that broke the build
- Status: ✅ Fixed, delivered in stub_fixes.zip
- Risk: None — these are platform stubs, not used on Android

Change #2 (2026-05-02): VPN init crash fix
- Files: lib/clash/lib.dart, lib/main.dart
- What: Switched from IPC (IsolateNameServer) to direct FFI via _MainFFIHandler
- Why: Two FlutterEngine = two Dart VMs = IsolateNameServer doesn't work cross-VM
- Status: ✅ Fixed
- Risk: HIGH if someone tries to add IPC back. Read RULES.md.

Change #3 (2026-05-02): setupClashConfig guard bypass
- Files: lib/controller.dart
- What: setupClashConfig() now calls _setupClashConfig() directly
- Why: homeScaffoldKey guard always returned null (no CommonScaffold in SimpleHomeView)
- Status: ✅ Fixed
- Risk: If CommonScaffold is ever added back, remove this bypass


Key Function Signatures
// lib/clash/lib.dart
class ClashLib extends ClashHandlerInterface {
  Future<void> sendMessage(String action, [Map? params])
    → _MainFFIHandler.invokeAction()  // direct FFI, NOT IPC
}

class _MainFFIHandler {
  // CALLS initNativeApiBridge() ONCE — guarded by dartApiInitialized flag
}

// lib/controller.dart
Future<void> setupClashConfig()
  → _setupClashConfig()  // DIRECT call, bypassed homeScaffoldKey guard

// lib/main.dart
@pragma('vm:entry-point')
void _service()
  → initApp(0) + ReceivePort + signalServiceReady + await rPort.first
  // Does NOT create ClashLibHandler — double-init killed by SIGSEGV

// core/lib.go
func initNativeApiBridge(api unsafe.Pointer) {
  // GUARD: if dartApiInitialized { return }
  // dartApiInitialized = true
}

// core/lib_android.go
func handleStartTun(...) {
  // NIL-GUARD on every pointer parameter
}

Do Not Touch (without explicit permission)

- core/lib.go — Go guards, single-init logic
- core/lib_android.go — Android VPN handles, nil-guards
- lib/main.dart — _service() entrypoint is minimal by design
- lib/clash/lib.dart — _MainFFIHandler architecture
- android/app/build.gradle.kts — NDK, SDK versions are calibrated


Build Configuration (for reference)
Flutter: 3.32.8
NDK: 27.0.12077973
compileSdk/targetSdk: 36
minSdk: 23
Java: 17
applicationId: com.follow.clashr
namespace: com.follow.clashx
isMinifyEnabled: false
Keystore alias: flclashr
Keystore pass: 123456

What Needs Verification

1. YouTube/Telegram/WhatsApp connectivity through VPN (after stub fixes)
2. Subscription import still works (after controller.dart changes)
3. No regression on VPN start/stop cycle (3x test)


Session Instructions for Claude

1. Read this file FIRST
2. Read RULES.md SECOND
3. Check if anything in this file is stale (ask user)
4. Update this file at END of session with new changes, status, and key signatures
5. Keep this file under 300 lines — archive old changes to CHANGELOG.md

---
## Session: 2026-05-03 — 4-task batch

### Changes Applied
1. **Task 1 — YAML error / infinite spinner fix** (`lib/views/simple_home.dart`)
   - Both `_runImport` methods (SimpleHomeView + SettingsView): replaced `ScaffoldMessenger.of(ctx)` with `maybeOf(ctx)?` + outer try/catch — prevents throw before try block
   - `ctrl` is now nullable `ScaffoldFeatureController?`; `ctrl?.close()` in a nested try/catch in finally — guaranteed stop
   - Error message truncated to 200 chars before display in snackbar
   - `doProfileImport` already had full error classification, HTML/JSON sniffing, YAML fix, converter fallback — no changes needed there

2. **Task 2 — Auto-refresh 24h + fastest-proxy selection** (`lib/services/auto_refresh_service.dart`)
   - Already complete from previous session; wired into `controller.dart init()` and VPN start hook
   - No changes required this session

3. **Task 3 — Russia preset RoscomVPN verification** (`lib/common/russia_preset.dart`)
   - Instagram: added `fbcdn.net`, `fbsbx.com`, `facebook.com`, `fb.com`, `connect.facebook.net` — Meta CDN required for media load
   - Added `fbcdn` keyword to Instagram keywords list
   - `buildRulesFromServices`: IPv6 CIDRs (contain `:`) now emit `IP-CIDR6` rule type instead of `IP-CIDR` — fixes Telegram IPv6 ranges
   - Rule ordering confirmed correct: service rules → GEOIP,RU,DIRECT → DST-PORT,443,REJECT,udp → MATCH,DIRECT

4. **Task 4 — Theme system** (`lib/theme/app_theme.dart`, `lib/application.dart`)
   - Already complete from previous session: `AppTheme.light()` / `AppTheme.dark()`, full `AppColors` palette, `GlassDecoration`, `AppTextStyles`
   - `simple_home.dart` already imports `app_theme.dart` and uses `AppColors` exclusively via `_ThemeX` extension
   - `application.dart` uses `themeMode: themeProps.themeMode` (system auto-detect) + both themes registered

### Verified Not Touched
- `core/*.go` — untouched
- `lib/main.dart _service()` — untouched
- `lib/clash/lib.dart` FFI — untouched
- `homeScaffoldKey` guard — untouched
- Rule ordering principle — maintained

### Outstanding / Needs Test
- YAML import: test with malformed YAML link, HTML response, valid sub
- Telegram IPv6 — verify `IP-CIDR6` rule is accepted by Clash version in use
- Instagram via Russia preset: enable in UI, verify reels/stories load
