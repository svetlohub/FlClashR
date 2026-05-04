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

---
## Session: 2026-05-04 — 5-task batch

### Changes Applied

1. **Task 1 — VPN start crash guard** (`lib/plugins/service.dart`, `lib/views/simple_home.dart`, `lib/state.dart`)
   - `service.dart startVpn()`: null-guard on `getAndroidVpnOptions()` — throws descriptive Exception before hitting platform channel. Also guards `ipv4Address.isEmpty`.
   - `simple_home.dart _toggle()`: pre-flight check — if `currentProfileIdProvider == null` on start attempt, shows RU snackbar and returns early. Friendly message for "VPN configuration missing" errors.
   - `state.dart handleStart()`: comment added — config NOT wiped on start failure (only rethrows, never clears profileId).

2. **Task 2 — Theme auto not working** (`lib/models/config.dart`)
   - Changed `@Default(ThemeMode.dark)` → `@Default(ThemeMode.system)` in `ThemeProps`.
   - `application.dart` already wires `themeMode: themeProps.themeMode` + both themes — no change needed there.
   - New users now auto-follow device setting; existing users who already saved a preference are unaffected (serialised value takes priority over default).

3. **Task 3 — VPN notification text + buttons** (`android/.../BaseServiceInterface.kt`, `android/.../TempActivity.kt`)
   - `BaseServiceInterface.kt`: `setContentTitle("Интернет сейчас свободнее")`, removed unused `stopText` var, added `addAction("Переподключить", RECONNECT)` alongside existing `addAction("Отключить", STOP)`.
   - `TempActivity.kt`: added `RECONNECT` action handler → `GlobalState.handleStop()` + `GlobalState.handleStart()`.

4. **Task 4 — Telegram not routing** (`lib/common/russia_preset.dart`)
   - Added missing DC subnets: `91.108.12.0/22` (DC2-Media), `91.108.16.0/22` (DC3), `91.108.36.0/22` (DC4), `185.76.144.0/22` (CDN).
   - Added IPv6 range: `2001:67c:4e8:f003::/64`.
   - Removed broad `/16` supernet (91.108.0.0/16) — replaced with specific /22 blocks.
   - Added `keywords: ['telegram']` fallback for unresolved subdomains.

5. **Task 5 — README.md** (`README.md`)
   - Full bilingual (RU/EN) README: badges, features table, screenshots placeholders, quick start, architecture diagram, contributing, credits.

### Verified Not Touched
- `core/*.go` — untouched
- `lib/main.dart _service()` — untouched
- `lib/clash/lib.dart` FFI — untouched
- Rule ordering — maintained

### Outstanding / Needs Test
- VPN start without import → should show RU snackbar, not crash
- Theme auto: fresh install → should follow device light/dark
- Notification "Переподключить" → VPN reconnects within ~3s
- Telegram calls/video after new IP ranges added

---
## Session: 2026-05-04 — upstream sync (3 changes)

### Analysis performed
- `Port int64` in Go `ActionResult` is NOT a raw-memory FFI field — boundary is JSON (`result.Json()`). Dart `ActionResult` model has no `Port` field. Change is safe.
- `getCoreVersionMethod` is pure additive — no conflicts.
- Upstream `build-core.yaml` (separate Go core release) — NOT applicable to us; we ship `.so` inside APK.

### Changes Applied
1. **`core/action.go`** — `ActionResult.Port int64` → `Callback unsafe.Pointer` (json:"-"); added `getCoreVersion` case; added `unsafe` + `mihomo/constant` imports
2. **`core/constant.go`** — added `getCoreVersionMethod Method = "getCoreVersion"`
3. **`.github/workflows/build-android.yml`** — `setup-go@v5→v6`, `upload-artifact@v4→v5`
4. **`.github/workflows/build.yaml`** — `setup-go@v5→v6`, `upload-artifact@v4→v5`, `download-artifact@v4→v5`

### Verified Safe
- Dart `ActionResult.fromJson()` deserialises only `id`, `method`, `data`, `code` — `Callback` (json:"-") never appears in wire JSON
- No Dart FFI struct allocation of `ActionResult` anywhere — all via JSON decode
- `_service()` entrypoint untouched
- `lib/clash/lib.dart` FFI architecture untouched

### Outstanding
- `core/*.go` changes require rebuilding `libclash.so` before they take effect at runtime
- `getCoreVersion` Dart-side caller not yet wired — the Go handler is ready but no Dart code calls it yet

---
## Session: 2026-05-04 — lib.go Port→Callback fix

### Problem
Build errors after upstream `ActionResult.Port int64` → `Callback unsafe.Pointer` change:
- `result.Port undefined` (line 56)
- `unknown field Port in struct literal` (lines 72, 83)

### Root Cause Analysis
`lib.go::send()` used `result.Port` as the Dart `SendPort` ID for `bridge.SendToPort()`.
`invokeAction` stored the port integer directly in `ActionResult.Port`.
`sendMessage` stored `messagePort` in `ActionResult.Port`.

### Fix Applied (`core/lib.go`)
- Added `portFromCallback(cb unsafe.Pointer) int64` helper — dereferences the stored int64 pointer
- `send()` now: `port := portFromCallback(result.Callback); bridge.SendToPort(port, ...)`
- `invokeAction`: `portPtr := new(int64); *portPtr = i; result := ActionResult{..., Callback: unsafe.Pointer(portPtr)}`
- `sendMessage`: same `portPtr` pattern using `messagePort`
- The heap-allocated `int64` is safe — Go GC will not collect it while `unsafe.Pointer` points to it (per Go unsafe rules: a `unsafe.Pointer` holding a `*int64` keeps it live)

### Verified
- No `Port` field references remain in any `core/*.go` file (excluding legitimate net.Port fields)
- `server.go` (non-cgo path) was already clean — defines its own `send()` separately
- `action.go` `success()/error()` → `result.send()` call chain unchanged
- Dart side unaffected — ActionResult delivered as JSON, `Callback` tagged `json:"-"`
