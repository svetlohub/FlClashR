import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application.dart';
import 'clash/lib.dart';
import 'common/constant.dart';
import 'core/crash_logger.dart';
import 'plugins/tile.dart';
import 'state.dart';

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

@pragma('vm:entry-point')
void _service() async {
  WidgetsFlutterBinding.ensureInitialized();
  globalState.isService = true;
  await globalState.initApp(0);

  final rPort = ReceivePort();
  IsolateNameServer.removePortNameMapping(serviceIsolate);
  IsolateNameServer.registerPortWithName(rPort.sendPort, serviceIsolate);

  final mainPort = IsolateNameServer.lookupPortByName(mainIsolate);
  mainPort?.send(rPort.sendPort);

  final handler = clashLibHandler;
  if (handler != null) {
    handler.attachMessagePort(rPort.sendPort.nativePort);
  }

  rPort.listen((message) {
    if (handler != null && message is String) {
      handler.invokeAction(message);
    }
  });

  await tile?.signalServiceReady();
}
