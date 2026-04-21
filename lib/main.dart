import 'dart:async';
import 'dart:isolate';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application.dart';
import 'clash/lib.dart';
import 'core/crash_logger.dart';
import 'state.dart';

// ─── Main UI entry point ──────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CrashLogger.instance.init();
  await CrashLogger.instance.log('App starting...');

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    CrashLogger.instance.logError(
      details.exception,
      details.stack,
      context: 'FlutterError: ${details.context}',
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    CrashLogger.instance.logError(error, stack, context: 'PlatformDispatcher');
    return false;
  };

  // CRITICAL: initialize globalState.appState BEFORE runApp.
  // All Riverpod providers access globalState.appState (declared `late`).
  // Without this call every provider throws LateInitializationError,
  // which Flutter swallows silently in release mode → grey screen.
  await globalState.initApp(0);

  runZonedGuarded(
    () {
      runApp(
        const ProviderScope(
          child: Application(),
        ),
      );
    },
    (error, stack) {
      CrashLogger.instance.logError(error, stack, context: 'runZonedGuarded');
    },
  );
}

// ─── Background VPN-service entry point (Android only) ───────────────────────
// Called by Kotlin GlobalState.initServiceEngine() via DartExecutor with
// entrypoint name "_service". MUST NOT BE REMOVED — without it the VPN tile
// and background service cannot start.
@pragma('vm:entry-point')
void _service() async {
  WidgetsFlutterBinding.ensureInitialized();

  globalState.isService = true;
  await globalState.initApp(0);

  // Register this isolate's receive port so the main isolate (ClashLib)
  // can send it messages through IsolateNameServer.
  final receiver = ReceivePort();
  IsolateNameServer.removePortNameMapping('FlClashXServiceIsolate');
  IsolateNameServer.registerPortWithName(receiver.sendPort, 'FlClashXServiceIsolate');

  // Connect to the Clash native library in this service isolate.
  clashLibHandler?.attachMessagePort(receiver.sendPort.nativePort);

  // Signal Kotlin that Dart-side service is ready to receive VPN commands.
  // TilePlugin.handleServiceReady() will fire any pending START/STOP action.
  await tile?.signalServiceReady();
}
