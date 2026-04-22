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

// ── Main UI entry point ───────────────────────────────────────────────────────
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

  // CRITICAL: инициализирует globalState.appState (объявлен как `late`).
  // Без этого Riverpod-провайдеры падают с LateInitializationError → серый экран.
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

// ── VPN background service entry point (Android) ─────────────────────────────
// Вызывается Kotlin через DartExecutor.executeDartEntrypoint("_service").
// dart:ffi — нужен для SendPort.nativePort
// dart:ui  — нужен для IsolateNameServer
@pragma('vm:entry-point')
void _service() async {
  WidgetsFlutterBinding.ensureInitialized();
  globalState.isService = true;
  await globalState.initApp(0);

  final rPort = ReceivePort();

  IsolateNameServer.removePortNameMapping(serviceIsolate);
  IsolateNameServer.registerPortWithName(rPort.sendPort, serviceIsolate);

  // Отправляем sendPort в ClashLib.receiverPort (main isolate)
  // → _canSendCompleter.complete(true) → sendMessage() разблокируется
  final mainPort = IsolateNameServer.lookupPortByName(mainIsolate);
  mainPort?.send(rPort.sendPort);

  // Инициализируем ClashLibHandler: открывает libclash.so
  final handler = clashLibHandler;

  // nativePort доступен благодаря import 'dart:ffi'
  if (handler != null) {
    handler.attachMessagePort(rPort.sendPort.nativePort);
  }

  // Слушаем входящие invoke-запросы от main isolate
  rPort.listen((message) {
    if (handler != null && message is String) {
      handler.invokeAction(message);
    }
  });

  // Сигнализируем Kotlin: Dart готов → выполнить отложенный START/STOP
  await tile?.signalServiceReady();
}
