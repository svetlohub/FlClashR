import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application.dart';
import 'clash/lib.dart';
import 'core/crash_logger.dart';
import 'plugins/tile.dart';
import 'state.dart';

// ── Main UI entry point ──────────────────────────────────────────────────────

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
  // Без этого вызова → LateInitializationError → серый экран в release.
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

// ── Background VPN-service entry point (Android only) ───────────────────────
// Вызывается Kotlin через DartExecutor.executeDartEntrypoint("_service").
// ClashLibHandler() сам открывает libclash.so и регистрирует нативный порт.
// tile.signalServiceReady() сообщает Kotlin что Dart-сторона готова — после
// этого TilePlugin выполняет отложенный START/STOP если он был запрошен.
@pragma('vm:entry-point')
void _service() async {
  WidgetsFlutterBinding.ensureInitialized();
  globalState.isService = true;
  await globalState.initApp(0);
  // Инициализирует ClashLibHandler — загружает .so и подключает нативный порт
  clashLibHandler;
  // Сигнализируем Kotlin что изолят готов принимать VPN-команды
  await tile?.signalServiceReady();
}
