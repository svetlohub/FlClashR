import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CrashLogger {
  static const _logFileName = 'flclashr_debug.log';
  static const _maxLogSizeBytes = 2 * 1024 * 1024; // 2MB

  static File? _logFile;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/$_logFileName');

      // Ротация: если файл > 2MB — очищаем
      if (_logFile!.existsSync()) {
        final size = await _logFile!.length();
        if (size > _maxLogSizeBytes) {
          await _logFile!.writeAsString('');
        }
      }

      await _write('=== CrashLogger initialized: ${DateTime.now()} ===');
      _initialized = true;
    } catch (e) {
      debugPrint('[CrashLogger] init failed: $e');
    }
  }

  static Future<void> log(String message, {String level = 'INFO'}) async {
    final entry = '[${DateTime.now().toIso8601String()}] [$level] $message';
    debugPrint(entry);
    await _write(entry);
  }

  static Future<void> logError(
    dynamic error,
    StackTrace? stack, {
    String context = '',
  }) async {
    final msg = StringBuffer();
    msg.writeln('--- ERROR ${context.isNotEmpty ? "[$context]" : ""} ---');
    msg.writeln('Time: ${DateTime.now().toIso8601String()}');
    msg.writeln('Error: $error');
    if (stack != null) {
      msg.writeln('Stack:');
      msg.writeln(stack.toString().split('\n').take(20).join('\n'));
    }
    msg.writeln('--- END ERROR ---');

    debugPrint(msg.toString());
    await _write(msg.toString());
  }

  static Future<void> _write(String content) async {
    if (_logFile == null) return;
    try {
      await _logFile!.writeAsString(
        '$content\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  static Future<String> getLogPath() async {
    if (_logFile != null) return _logFile!.path;
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_logFileName';
  }

  static Future<String> readLogs() async {
    try {
      if (_logFile != null && _logFile!.existsSync()) {
        return await _logFile!.readAsString();
      }
    } catch (e) {
      return 'Failed to read logs: $e';
    }
    return 'No logs found';
  }

  static Future<void> clearLogs() async {
    try {
      await _logFile?.writeAsString('');
      await log('Logs cleared by user');
    } catch (_) {}
  }
}
