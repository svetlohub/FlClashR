import 'dart:async';
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
  // Без этого все Riverpod-провайдеры падают с LateInitializationError
  // → Flutter молча показывает серый экран в release-сборке.
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
// Kotlin вызывает через DartExecutor.executeDartEntrypoint("_service").
//
// Протокол подключения изолятов:
// 1. Создаём RawReceivePort — канал входящих сообщений от main isolate
// 2. Регистрируем в IsolateNameServer (dart:ui) под serviceIsolate
// 3. Ищем ClashLib.receiverPort main isolate по имени mainIsolate
// 4. Отправляем ему наш sendPort → ClashLib._canSendCompleter разблокируется
// 5. Подключаем nativePort к libclash.so (ClashLibHandler.attachMessagePort)
// 6. Вешаем обработчик входящих invoke-сообщений
// 7. Сигнализируем Kotlin: tile.signalServiceReady()
@pragma('vm:entry-point')
void _service() async {
  WidgetsFlutterBinding.ensureInitialized();
  globalState.isService = true;
  await globalState.initApp(0);

  // RawReceivePort.sendPort.nativePort доступен (в отличие от ReceivePort.sendPort)
  // IsolateNameServer — из dart:ui (не dart:isolate!)
  final rPort = RawReceivePort();

  IsolateNameServer.removePortNameMapping(serviceIsolate);
  IsolateNameServer.registerPortWithName(rPort.sendPort, serviceIsolate);

  // Отправляем наш sendPort в ClashLib.receiverPort (main isolate)
  // ClashLib слушает: if (message is SendPort) -> _canSendCompleter.complete(true)
  final mainPort = IsolateNameServer.lookupPortByName(mainIsolate);
  mainPort?.send(rPort.sendPort);

  // Инициализируем ClashLibHandler: открывает libclash.so
  final handler = clashLibHandler;

  // Подключаем nativePort: libclash будет присылать ответы в этот isolate
  if (handler != null) {
    handler.attachMessagePort(rPort.sendPort.nativePort);
  }

  // Обрабатываем входящие invoke-запросы от main isolate
  rPort.handler = (dynamic message) {
    if (handler != null && message is String) {
      handler.invokeAction(message);
    }
  };

  // Kotlin ждёт этот сигнал чтобы выполнить отложенный START/STOP
  await tile?.signalServiceReady();
}
