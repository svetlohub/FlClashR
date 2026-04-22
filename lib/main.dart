import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  // Все Riverpod-провайдеры обращаются к нему при первом build().
  // Без этого → LateInitializationError → серый экран в release.
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
// Kotlin вызывает этот entry point из DartExecutor.executeDartEntrypoint("_service").
//
// Что делает эта функция:
// 1. Помечает isolate как сервисный (не UI)
// 2. Инициализирует globalState
// 3. Создаёт RawReceivePort — канал входящих сообщений от main isolate
// 4. Регистрирует его имя в IsolateNameServer под serviceIsolate
// 5. Отправляет свой SendPort в main isolate (ClashLib.receiverPort)
//    → ClashLib.sendMessage() разблокируется (_canSendCompleter.complete)
// 6. Инициализирует ClashLibHandler (открывает libclash.so)
// 7. Подключает native message port к libclash для получения результатов
// 8. Сигнализирует Kotlin что Dart готов принимать VPN-команды
@pragma('vm:entry-point')
void _service() async {
  WidgetsFlutterBinding.ensureInitialized();
  globalState.isService = true;
  await globalState.initApp(0);

  // Создаём порт для получения сообщений от main isolate
  final rPort = RawReceivePort();

  // Регистрируем под serviceIsolate чтобы main мог нас найти
  IsolateNameServer.removePortNameMapping(serviceIsolate);
  IsolateNameServer.registerPortWithName(rPort.sendPort, serviceIsolate);

  // Отправляем наш SendPort в ClashLib.receiverPort (main isolate)
  // Это разблокирует ClashLib._canSendCompleter → sendMessage() начинает работать
  final mainPort = IsolateNameServer.lookupPortByName(mainIsolate);
  mainPort?.send(rPort.sendPort);

  // Инициализируем ClashLibHandler — открывает libclash.so
  final handler = clashLibHandler;

  // Подключаем native message port: libclash сможет присылать ответы
  // в этот isolate через rPort
  if (handler != null) {
    handler.attachMessagePort(rPort.sendPort.nativePort);
  }

  // Обрабатываем входящие сообщения от main isolate
  rPort.handler = (dynamic message) {
    if (handler != null && message is String) {
      handler.invokeAction(message);
    }
  };

  // Сигнализируем Kotlin: Dart-сторона готова, можно выполнять отложенные VPN-команды
  await tile?.signalServiceReady();
}
