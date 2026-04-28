import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Unified logger — writes to flclashr_debug.log alongside Kotlin crash log.
/// Call log() freely; logError() for exceptions with stack traces.
class CrashLogger {
  CrashLogger._();
  static final instance = CrashLogger._();

  File? _logFile;
  bool _ready = false;

  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/flclashr_debug.log');
      _ready = true;
      final header =
          '\n=== FlClashR CrashLogger started: ${DateTime.now()} ===\n'
          'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n';
      await _logFile!.writeAsString(header, mode: FileMode.append);
    } catch (e) {
      _ready = false;
    }
  }

  Future<void> log(String message, {String level = 'INFO'}) async {
    if (!_ready) return;
    final entry = '[${DateTime.now().toIso8601String()}] [$level] $message\n';
    try {
      await _logFile!.writeAsString(entry, mode: FileMode.append);
    } catch (_) {}
  }

  Future<void> logError(
    Object error,
    StackTrace? stack, {
    String? context,
  }) async {
    if (!_ready) return;
    final buf = StringBuffer();
    buf.writeln('━━━ ERROR${context != null ? ' [$context]' : ''} ━━━');
    buf.writeln('Time:  ${DateTime.now().toIso8601String()}');
    buf.writeln('Error: $error');
    if (stack != null) {
      buf.writeln('Stack:');
      buf.writeln(stack.toString().split('\n').take(20).join('\n'));
    }
    buf.writeln('━━━ END ERROR ━━━\n');
    try {
      await _logFile!.writeAsString(buf.toString(), mode: FileMode.append);
    } catch (_) {}
  }

  Future<String> readLogs() async {
    try {
      if (_logFile == null || !await _logFile!.exists()) return '';
      return await _logFile!.readAsString();
    } catch (_) {
      return '';
    }
  }

  Future<String> getLogPath() async =>
      _logFile?.path ?? 'log not initialized';

  Future<void> clearLogs() async {
    try {
      await _logFile?.writeAsString('');
    } catch (_) {}
  }
}
