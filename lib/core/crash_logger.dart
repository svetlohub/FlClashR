import 'package:flclashx/core/crash_logger.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class CrashLogger {
  CrashLogger._();
  static final CrashLogger instance = CrashLogger._();

  static const _logFileName = 'flclashr_debug.log';
  static const _maxLogSizeBytes = 2 * 1024 * 1024; // 2MB

  File? _logFile;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/$_logFileName');

      if (_logFile!.existsSync()) {
        final size = await _logFile!.length();
        if (size > _maxLogSizeBytes) {
          await _logFile!.writeAsString('');
        }
      }

      await _write('=== FlClashR CrashLogger started: ${DateTime.now()} ===');
      await _write('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
      _initialized = true;

      debugPrint('[CrashLogger] Log file: ${_logFile!.path}');
    } catch (e) {
      debugPrint('[CrashLogger] init failed: $e');
    }
  }

  Future<void> log(String message, {String level = 'INFO'}) async {
    final entry = '[${DateTime.now().toIso8601String()}] [$level] $message';
    debugPrint(entry);
    await _write(entry);
  }

  Future<void> logError(dynamic error, StackTrace? stack, {String context = ''}) async {
    final msg = StringBuffer();
    msg.writeln('━━━ ERROR ${context.isNotEmpty ? "[$context]" : ""} ━━━');
    msg.writeln('Time:  ${DateTime.now().toIso8601String()}');
    msg.writeln('Error: $error');
    if (stack != null) {
      msg.writeln('Stack:');
      msg.writeln(stack.toString().split('\n').take(30).join('\n'));
    }
    msg.writeln('━━━ END ERROR ━━━');

    debugPrint(msg.toString());
    await _write(msg.toString());
  }

  Future<void> _write(String content) async {
    if (_logFile == null) return;
    try {
      await _logFile!.writeAsString(
        '$content\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  Future<String> getLogPath() async {
    if (_logFile != null) return _logFile!.path;
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_logFileName';
  }

  Future<String> readLogs() async {
    try {
      if (_logFile != null && _logFile!.existsSync()) {
        return await _logFile!.readAsString();
      }
    } catch (e) {
      return 'Failed to read logs: $e';
    }
    return 'No logs found';
  }

  Future<void> clearLogs() async {
    try {
      await _logFile?.writeAsString('');
      await log('Logs cleared by user');
    } catch (_) {}
  }
}
