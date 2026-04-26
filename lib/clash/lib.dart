import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:ffi/ffi.dart';
import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/plugins/service.dart';
import 'package:flclashx/state.dart';

import 'generated/clash_ffi.dart';
import 'interface.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ClashLib — runs in the MAIN Flutter engine (main Dart VM).
//
// Architecture fix: two FlutterEngines = two separate Dart VMs.
// IsolateNameServer is per-VM → cross-engine port lookup always returns null
// → _canSendCompleter never completes → every invoke() hangs forever.
//
// Fix: sendMessage() now uses ClashLibHandler (direct FFI to libclash.so)
// instead of waiting for a SendPort from the service engine.
// The service engine is still started (for Android VPN lifecycle) but its
// SendPort is only used for optional IPC, not for core clash operations.
// ─────────────────────────────────────────────────────────────────────────────
class ClashLib extends ClashHandlerInterface with AndroidClashInterface {

  factory ClashLib() {
    _instance ??= ClashLib._internal();
    return _instance!;
  }

  ClashLib._internal() {
    // Start service engine for Android VPN management (tile, vpn service).
    // We do NOT wait for it before allowing FFI calls.
    _initService();
  }

  static ClashLib? _instance;

  // Direct FFI handler — works in main engine, bypasses service IPC.
  final _ffi = _MainFFIHandler();

  // Optional IPC channel for service engine messages (non-blocking).
  // Used only for foreground notification updates etc.
  Completer<bool> _canSendCompleter = Completer();
  SendPort? sendPort;
  final receiverPort = ReceivePort();

  // preload() completes immediately because FFI is available in main engine.
  @override
  Future<bool> preload() async => true;

  Future<void> _initService() async {
    await service?.destroy();
    // Register port so service engine CAN send back if it starts successfully.
    // This is best-effort; we don't block on it.
    _registerMainPort(receiverPort.sendPort);
    receiverPort.listen((message) {
      if (message is SendPort) {
        if (_canSendCompleter.isCompleted) {
          sendPort = null;
          _canSendCompleter = Completer();
        }
        sendPort = message;
        _canSendCompleter.complete(true);
      } else if (message is Map) {
        return;
      } else {
        try {
          handleResult(ActionResult.fromJson(json.decode(message as String)));
        } catch (_) {}
      }
    });
    await service?.init();
  }

  void _registerMainPort(SendPort port) {
    IsolateNameServer.removePortNameMapping(mainIsolate);
    IsolateNameServer.registerPortWithName(port, mainIsolate);
  }

  @override
  Future<bool> destroy() async {
    await service?.destroy();
    return true;
  }

  @override
  void reStart() {
    _initService();
  }

  @override
  Future<bool> shutdown() async {
    await super.shutdown();
    await destroy();
    return true;
  }

  // ── Core fix: use direct FFI instead of service IPC ──────────────────────
  // Previously this awaited _canSendCompleter (= waited for service engine's
  // SendPort via IsolateNameServer, which never works cross-VM).
  // Now: invoke libclash.so directly in the main engine and route result back
  // through handleResult() so callbackCompleterMap resolves normally.
  @override
  Future<void> sendMessage(String message) async {
    try {
      final result = await _ffi.invokeAction(message);
      if (result.isNotEmpty) {
        handleResult(ActionResult.fromJson(json.decode(result)));
      }
    } catch (e) {
      // On error, try to decode as ActionResult with empty data so
      // the waiting invoke() completes instead of hanging until timeout.
      try {
        final action = Action.fromJson(json.decode(message));
        handleResult(ActionResult(
          id: action.id,
          method: action.method,
          data: '',
        ));
      } catch (_) {}
    }
  }

  /// Optional IPC to service engine (non-blocking, best-effort).
  Future<void> sendIpcMessage(Map<String, dynamic> message) async {
    if (_canSendCompleter.isCompleted) {
      sendPort?.send(message);
    }
  }

  @override
  Future<AndroidVpnOptions?> getAndroidVpnOptions() async {
    try {
      final opts = _ffi.getAndroidVpnOptionsDirect();
      return opts;
    } catch (_) {
      final res = await invoke<String>(
        method: ActionMethod.getAndroidVpnOptions,
      );
      if (res.isEmpty) return null;
      return AndroidVpnOptions.fromJson(json.decode(res));
    }
  }

  @override
  Future<bool> updateDns(String value) => invoke<bool>(
        method: ActionMethod.updateDns,
        data: value,
      );

  @override
  Future<DateTime?> getRunTime() async {
    final runTimeString = await invoke<String>(
      method: ActionMethod.getRunTime,
    );
    if (runTimeString.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(int.parse(runTimeString));
  }

  @override
  Future<String> getCurrentProfileName() => invoke<String>(
        method: ActionMethod.getCurrentProfileName,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// _MainFFIHandler — thin FFI wrapper usable in either engine.
// Separated from ClashLibHandler so it can be instantiated in main engine.
// ─────────────────────────────────────────────────────────────────────────────
class _MainFFIHandler {
  _MainFFIHandler() {
    _lib = DynamicLibrary.open('libclash.so');
    _ffi = ClashFFI(_lib);
    _ffi.initNativeApiBridge(NativeApi.initializeApiDLData);
  }

  late final DynamicLibrary _lib;
  late final ClashFFI _ffi;

  Future<String> invokeAction(String actionParams) {
    final completer = Completer<String>();
    final receiver = ReceivePort();
    receiver.listen((message) {
      if (!completer.isCompleted) {
        completer.complete(message as String);
        receiver.close();
      }
    });
    final actionParamsChar = actionParams.toNativeUtf8().cast<Char>();
    _ffi.invokeAction(actionParamsChar, receiver.sendPort.nativePort);
    malloc.free(actionParamsChar);
    return completer.future;
  }

  AndroidVpnOptions? getAndroidVpnOptionsDirect() {
    try {
      final raw = _ffi.getAndroidVpnOptions();
      final str = raw.cast<Utf8>().toDartString();
      _ffi.freeCString(raw);
      if (str.isEmpty || str == 'null') return null;
      return AndroidVpnOptions.fromJson(json.decode(str));
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ClashLibHandler — runs in the SERVICE Flutter engine (_service() entrypoint).
// Unchanged from original; used by _service() to handle incoming actions.
// ─────────────────────────────────────────────────────────────────────────────
class ClashLibHandler {

  factory ClashLibHandler() {
    _instance ??= ClashLibHandler._internal();
    return _instance!;
  }

  ClashLibHandler._internal() {
    lib = DynamicLibrary.open('libclash.so');
    clashFFI = ClashFFI(lib);
    // Do NOT call initNativeApiBridge here.
    // ClashLibHandler runs in the SERVICE FlutterEngine (second Dart VM in same process).
    // initNativeApiBridge calls Dart_InitializeApiDL which must only be called once —
    // calling it again from service engine overwrites Go's Dart VM function pointers
    // and corrupts SendToPort → SIGSEGV crash loop when VPN starts.
    // The main engine's _MainFFIHandler already initialised the bridge.
  }

  static ClashLibHandler? _instance;

  late final ClashFFI clashFFI;
  late final DynamicLibrary lib;

  Future<String> invokeAction(String actionParams) {
    final completer = Completer<String>();
    final receiver = ReceivePort();
    receiver.listen((message) {
      if (!completer.isCompleted) {
        completer.complete(message as String);
        receiver.close();
      }
    });
    final actionParamsChar = actionParams.toNativeUtf8().cast<Char>();
    clashFFI.invokeAction(actionParamsChar, receiver.sendPort.nativePort);
    malloc.free(actionParamsChar);
    return completer.future;
  }

  void attachMessagePort(int messagePort) {
    clashFFI.attachMessagePort(messagePort);
  }

  void updateDns(String dns) {
    final dnsChar = dns.toNativeUtf8().cast<Char>();
    clashFFI.updateDns(dnsChar);
    malloc.free(dnsChar);
  }

  void setState(CoreState state) {
    final stateChar = json.encode(state).toNativeUtf8().cast<Char>();
    clashFFI.setState(stateChar);
    malloc.free(stateChar);
  }

  String getCurrentProfileName() {
    final raw = clashFFI.getCurrentProfileName();
    final result = raw.cast<Utf8>().toDartString();
    clashFFI.freeCString(raw);
    return result;
  }

  AndroidVpnOptions getAndroidVpnOptions() {
    final raw = clashFFI.getAndroidVpnOptions();
    final opts = json.decode(raw.cast<Utf8>().toDartString());
    clashFFI.freeCString(raw);
    return AndroidVpnOptions.fromJson(opts);
  }

  Traffic getTraffic() {
    final raw = clashFFI.getTraffic();
    final str = raw.cast<Utf8>().toDartString();
    clashFFI.freeCString(raw);
    if (str.isEmpty) return Traffic();
    return Traffic.fromMap(json.decode(str));
  }

  Traffic getTotalTraffic(bool value) {
    final raw = clashFFI.getTotalTraffic();
    final str = raw.cast<Utf8>().toDartString();
    clashFFI.freeCString(raw);
    if (str.isEmpty) return Traffic();
    return Traffic.fromMap(json.decode(str));
  }

  Future<bool> startListener() async {
    clashFFI.startListener();
    return true;
  }

  Future<bool> stopListener() async {
    clashFFI.stopListener();
    return true;
  }

  DateTime? getRunTime() {
    final raw = clashFFI.getRunTime();
    final str = raw.cast<Utf8>().toDartString();
    if (str.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(int.parse(str));
  }

  Future<Map<String, dynamic>> getConfig(String id) async {
    final path = await appPath.getProfilePath(id);
    final pathChar = path.toNativeUtf8().cast<Char>();
    final raw = clashFFI.getConfig(pathChar);
    final str = raw.cast<Utf8>().toDartString();
    if (str.isEmpty) return {};
    final config = json.decode(str);
    malloc.free(pathChar);
    clashFFI.freeCString(raw);
    return config;
  }

  Future<String> quickStart(
    InitParams initParams,
    SetupParams setupParams,
    CoreState state,
  ) {
    final completer = Completer<String>();
    final receiver = ReceivePort();
    receiver.listen((message) {
      if (!completer.isCompleted) {
        completer.complete(message as String);
        receiver.close();
      }
    });
    final paramsChar      = json.encode(setupParams).toNativeUtf8().cast<Char>();
    final initParamsChar  = json.encode(initParams).toNativeUtf8().cast<Char>();
    final stateParamsChar = json.encode(state).toNativeUtf8().cast<Char>();
    clashFFI.quickStart(
      initParamsChar,
      paramsChar,
      stateParamsChar,
      receiver.sendPort.nativePort,
    );
    malloc.free(initParamsChar);
    malloc.free(paramsChar);
    malloc.free(stateParamsChar);
    return completer.future;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Getters
// ─────────────────────────────────────────────────────────────────────────────
ClashLib? get clashLib =>
    Platform.isAndroid && !globalState.isService ? ClashLib() : null;

ClashLibHandler? get clashLibHandler =>
    Platform.isAndroid && globalState.isService ? ClashLibHandler() : null;
