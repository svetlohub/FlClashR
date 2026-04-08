import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/crash_logger.dart';

void main() async {
  // 1. Инициализация движка Flutter (обязательно перед вызовом нативных плагинов)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Инициализируем наш логгер
  await CrashLogger.instance.init();

  // 3. Перехват ошибок UI (ошибки отрисовки Flutter)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    CrashLogger.instance.logError(details.exception, details.stack);
  };

  // 4. Перехват ошибок внутри изолята (Riverpod, запросы в сеть, асинхронные функции)
  PlatformDispatcher.instance.onError = (error, stack) {
    CrashLogger.instance.logError(error, stack);
    return true; // Предотвращаем стандартный вылет (crash)
  };

  // 5. Запуск приложения в защищенной зоне
  runZonedGuarded(() {
    runApp(
      const ProviderScope(
        // ВАЖНО: Убедись, что твой главный класс называется так же. 
        // Если он называется FlClashApp, замени MyApp на FlClashApp
        child: MyApp(), 
      ),
    );
  }, (error, stack) {
    CrashLogger.instance.logError(error, stack);
  });
}

// Это заглушка корневого виджета. Если у тебя он уже есть (например, в файле app.dart),
// просто импортируй его сверху и удали этот класс.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlClashR',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const Scaffold(
        body: Center(child: Text('FlClashR Запущен')),
      ),
    );
  }
}
