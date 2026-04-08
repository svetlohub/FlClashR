import 'import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CrashLogger {
  CrashLogger._();
  static final CrashLogger instance = CrashLogger._();

  File? _logFile;

  /// Инициализируем логгер при старте приложения
  Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      // Файл будет доступен в папке приложения на устройстве
      _logFile = File('${directory.path}/flclashr_crash_log.txt');
      
      if (!await _logFile!.exists()) {
        await _logFile!.create();
      }
      
      logInfo("=== Application Started: ${DateTime.now().toIso8601String()} ===");
    } catch (e) {
      debugPrint("Failed to initialize CrashLogger: $e");
    }
  }

  /// Запись ошибки с StackTrace
  Future<void> logError(dynamic error, StackTrace? stackTrace) async {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '''
[ERROR] [$timestamp]
Exception: $error
StackTrace:
${stackTrace ?? 'No StackTrace provided'}
----------------------------------------
''';

    debugPrint(logMessage); // Оставляем в консоли для удобства
    if (_logFile != null) {
      try {
        await _logFile!.writeAsString(logMessage, mode: FileMode.append);
      } catch (e) {
        debugPrint("Failed to write to log file: $e");
      }
    }
  }

  /// Запись обычной информации (например, этапы запуска VPN)
  Future<void> logInfo(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[INFO] [$timestamp] $message\n';
    
    debugPrint(logMessage);
    if (_logFile != null) {
      try {
        await _logFile!.writeAsString(logMessage, mode: FileMode.append);
      } catch (e) {
        debugPrint("Failed to write info to log file: $e");
      }
    }
  }

  /// Получить путь к файлу (чтобы можно было вывести его на UI для пенсионеров/отладки)
  String? get logFilePath => _logFile?.path;
}
