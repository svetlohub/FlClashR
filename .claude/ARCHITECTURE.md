FlClashR — Architecture Decisions (IMMUTABLE)

These decisions were made after debugging crashes. DO NOT REVERT without reading the crash history below.


Decision 1: Direct FFI, not IPC (CRASH-CRITICAL)

What
ClashLib.sendMessage() uses _MainFFIHandler for direct FFI calls to libclash.so instead of sending messages through the service engine via IsolateNameServer.

Why
FlClashR runs TWO FlutterEngine instances:
1. Main engine — UI, lib/clash/lib.dart (ClashLib)
2. Service engine — background VPN, lib/main.dart (_service())

Each FlutterEngine has its own Dart VM. IsolateNameServer does NOT work across different Dart VMs. Attempting IPC caused messages to be lost → VPN would start but never receive configuration → crash or no traffic routing.

Implementation
- _MainFFIHandler — calls initNativeApiBridge() once, then uses FFI directly
- ClashLibHandler — does NOT call initNativeApiBridge() (it runs in service engine, handles VPN lifecycle)
- sendMessage() — invokes _MainFFIHandler.invokeAction() directly

What Happens If Reverted
- Messages from UI to VPN engine will be silently lost
- VPN will start but won't receive proxy configuration
- Crash: Dart_InitializeApiDL called twice → SIGSEGV


Decision 2: No CommonScaffold guard (ARCHITECTURE)

What
setupClashConfig() in lib/controller.dart calls _setupClashConfig() directly instead of going through homeScaffoldKey.currentState?.setupClashConfig().

Why
The original FlClashX used CommonScaffold which registered with homeScaffoldKey. FlClashR uses SimpleHomeView which does NOT extend CommonScaffold and never registers with homeScaffoldKey. The guard ALWAYS returned null → setupClashConfig() was a no-op → VPN started without proper configuration.

What Happens If Reverted
- setupClashConfig() becomes a silent no-op
- VPN starts without proxy rules
- Traffic goes direct instead of through proxy
- User sees green button but no actual VPN routing


Decision 3: Single initNativeApiBridge (GO-GUARDED)

What
initNativeApiBridge in core/lib.go uses a boolean flag dartApiInitialized to ensure it runs exactly once.

Why
Calling Dart_InitializeApiDL twice in the same process causes SIGSEGV (native crash). The function can be reached from multiple code paths (main engine init, service engine init). The Go-side guard is the last line of defense.

Implementation

var dartApiInitialized bool = false

func initNativeApiBridge(api unsafe.Pointer) {
    if dartApiInitialized {
        return
    }
    // ... initialization ...
    dartApiInitialized = true
}

What Happens If Removed
- Double initialization → SIGSEGV
- App crashes immediately on VPN start
- No recoverable error, just native crash


Decision 4: _service() minimalism (CRASH-CRITICAL)

What
The _service() entrypoint in lib/main.dart is minimal: initApp(0), register ReceivePort, signal service ready, wait. It does NOT create ClashLibHandler or call any clash initialization.

Why
The service engine and main engine both link to libclash.so. If both call Dart_InitializeApiDL, the second call crashes. The service engine only handles VPN lifecycle callbacks from Android; all clash configuration is done from the main engine via direct FFI.

What Happens If initApp or ClashLibHandler is Added
- Dart_InitializeApiDL called from service engine
- Main engine also calls it → second call → SIGSEGV
- App crashes when VPN starts


Decision 5: russia_preset.dart rule ordering

What
Rules in russiaServices are applied in order, with the last rule being MATCH,DIRECT. All service-specific rules (YouTube, Telegram, WhatsApp) MUST come BEFORE the final MATCH.

Why
Clash processes rules top-to-bottom. If MATCH,DIRECT is first, ALL traffic goes direct, bypassing proxy rules. Specific rules must come first, fallback to DIRECT last.

Correct Order
1. Service-specific DOMAIN, IP-CIDR rules (with proxy)
2. DST-PORT,443,REJECT,udp (QUIC block)
3. MATCH,DIRECT (fallback — 95% of traffic)

What Happens If Reordered
- MATCH first → all traffic direct, VPN useless
- QUIC block after MATCH → never reached, QUIC leaks


File Ownership Map

| File/Dir | Owner | Rule |
|----------|-------|------|
| core/*.go | Go/FFI layer | Do not modify without Go compilation check |
| lib/clash/lib.dart | FFI bridge | Must preserve _MainFFIHandler pattern |
| lib/main.dart | App entry | _service must stay minimal |
| lib/controller.dart | VPN lifecycle | No Scaffold guards |
| lib/views/simple_home.dart | UI | Can be modified freely |
| lib/common/russia_preset.dart | Proxy rules | Rule ordering is critical |
| android/ | Platform | NDK/SDK versions calibrated |


Dependencies That Cannot Be Upgraded Lightly

- Flutter SDK (3.32.8) — tested, newer may break NDK integration
- NDK 27.0.12077973 — specific Go ABI dependency
- Go version — must match the one used to compile libclash.so
