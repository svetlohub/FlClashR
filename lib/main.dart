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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CrashLogger.instance.init();
  await CrashLogger.instance.log('App starting...');

  // Catch all Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    CrashLogger.instance.logError(
      details.exception,
      details.stack,
      context: 'FlutterError: ${details.context}',
    );
  };

  // Catch all platform/native-bridge errors
  PlatformDispatcher.instance.onError = (error, stack) {
    CrashLogger.instance.logError(
      error,
      stack,
      context: 'PlatformDispatcher',
    );
    return false; // let default handler also run
  };

  await CrashLogger.instance.log('Calling initApp...');
  await globalState.initApp(0);
  await CrashLogger.instance.log('initApp done, starting Flutter UI');

  runZonedGuarded(
    () {
      runApp(const ProviderScope(child: Application()));
    },
    (error, stack) {
      CrashLogger.instance.logError(error, stack, context: 'runZonedGuarded');
    },
  );
}

/// VPN background service entry point — called by Kotlin DartExecutor.
///
/// CRITICAL: Do NOT call ClashLibHandler or any FFI here when main UI is
/// running. Two FlutterEngines share the same process and libclash.so.
/// Calling initNativeApiBridge from service engine overwrites the Go Dart API
/// function pointers → SendToPort uses invalid pointers → SIGSEGV.
@pragma('vm:entry-point')
void _service() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent unhandled exceptions in service engine from crashing the process
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('[_service] FlutterError: ${details.exception}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[_service] Error: $error\n$stack');
    return true; // handled — don't propagate
  };

  globalState.isService = true;
  await globalState.initApp(0);

  final rPort = ReceivePort();
  IsolateNameServer.removePortNameMapping(serviceIsolate);
  IsolateNameServer.registerPortWithName(rPort.sendPort, serviceIsolate);
  // IsolateNameServer is per-Dart-VM; cross-engine lookup returns null — expected
  final mainPort = IsolateNameServer.lookupPortByName(mainIsolate);
  mainPort?.send(rPort.sendPort);

  await tile?.signalServiceReady();

  // Keep isolate alive — returning here kills the service engine Dart side
  await rPort.first;
}
