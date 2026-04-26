import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application.dart';
import 'common/constant.dart';
import 'core/crash_logger.dart';
import 'plugins/tile.dart';
import 'state.dart';

// ── Main UI entry point ───────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CrashLogger.instance.init();
  await CrashLogger.instance.log('App starting...');

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    CrashLogger.instance.logError(details.exception, details.stack,
        context: 'FlutterError: ${details.context}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    CrashLogger.instance.logError(error, stack, context: 'PlatformDispatcher');
    return false;
  };

  await globalState.initApp(0);

  runZonedGuarded(
    () { runApp(const ProviderScope(child: Application())); },
    (error, stack) {
      CrashLogger.instance.logError(error, stack, context: 'runZonedGuarded');
    },
  );
}

// ── VPN background service entry point ────────────────────────────────────────
// Called by Kotlin DartExecutor with entrypoint "_service".
//
// CRITICAL: Do NOT create ClashLibHandler or call any FFI here when main UI
// is running. Both engines share the same process and the same libclash.so.
// Creating a second ClashFFI wrapper causes:
//   1. Race conditions on Go global state (currentConfig, runLock, etc.)
//   2. Corruption of Dart_PostCObject port mappings
// The main engine's _MainFFIHandler handles all clash operations via FFI.
// The service engine is purely a signal relay for Android VPN/tile lifecycle.
@pragma('vm:entry-point')
void _service() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress unhandled errors in service isolate to prevent process crash
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('[service] FlutterError: ${details.exception}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[service] Error: $error');
    return true; // mark as handled - don't crash the process
  };

  globalState.isService = true;
  await globalState.initApp(0);

  // Register service port for optional IPC with main engine.
  // IsolateNameServer doesn't work cross-FlutterEngine (different Dart VMs)
  // so mainPort will be null here - that's expected and fine.
  final rPort = ReceivePort();
  IsolateNameServer.removePortNameMapping(serviceIsolate);
  IsolateNameServer.registerPortWithName(rPort.sendPort, serviceIsolate);
  final mainPort = IsolateNameServer.lookupPortByName(mainIsolate);
  mainPort?.send(rPort.sendPort);

  // Signal Kotlin that Dart service is ready.
  // TilePlugin.handleServiceReady() will execute any pending START/STOP action.
  await tile?.signalServiceReady();

  // Keep the isolate alive so the service engine stays running.
  // If we return here, Kotlin's service engine loses its Dart isolate.
  await rPort.first;
}
