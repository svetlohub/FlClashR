import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CrashLogger {
  CrashLogger._();
  static final CrashLogger instance = CrashLogger._();

  File? _logFile;

  Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/flclashr_debug_log.txt');
      
      if (!await _logFile!.exists()) {
        await _logFile!.create();
      }
      
      logInfo("=== ЗАПУСК СЕССИИ: ${DateTime.now().toIso8601String()} ===");
    } catch (e) {
      debugPrint("Ошибка инициализации CrashLogger: $e");
    }
  }

  Future<void> logError(dynamic error, StackTrace? stackTrace) async {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '''
[ОШИБКА] [$timestamp]
Исключение: $error
Стек:
${stackTrace ?? 'нет стека'}
----------------------------------------
''';

    debugPrint(logMessage);
    if (_logFile != null) {
      try {
        await _logFile!.writeAsString(logMessage, mode: FileMode.append);
      } catch (e) {
        debugPrint("Ошибка записи в файл: $e");
      }
    }
  }

  Future<void> logInfo(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[ИНФО] [$timestamp] $message\n';
    
    debugPrint(logMessage);
    if (_logFile != null) {
      try {
        await _logFile!.writeAsString(logMessage, mode: FileMode.append);
      } catch (e) {
        debugPrint("Ошибка записи: $e");
      }
    }
  }

  String? get logFilePath => _logFile?.path;
}
