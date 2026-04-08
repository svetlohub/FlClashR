import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flclashx/application.dart'; // Проверь правильность импорта твоего App
import 'core/crash_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация логгера
  await CrashLogger.instance.init();

  // Перехват ошибок UI
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    CrashLogger.instance.logError(details.exception, details.stack);
  };

  // Перехват асинхронных ошибок
  PlatformDispatcher.instance.onError = (error, stack) {
    CrashLogger.instance.logError(error, stack);
    return true; 
  };

  runZonedGuarded(() {
    runApp(
      const ProviderScope(
        child: FlClashApp(), // Убедись, что твой главный класс называется так
      ),
    );
  }, (error, stack) {
    CrashLogger.instance.logError(error, stack);
  });
}
