import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Writes errors and debug info to flclashr_debug.log.
/// All I/O is fire-and-forget with silent failure — never crashes the app.
class CrashLogger {
  CrashLogger._();
  static final instance = CrashLogger._();

  File? _file;

  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/flclashr_debug.log');
      await _append(
        '\n=== Raketa started: ${DateTime.now()} ===\n'
        'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n',
      );
    } catch (_) {}
  }

  Future<void> log(String message, {String level = 'INFO'}) async {
    await _append('[${_ts()}] [$level] $message\n');
  }

  Future<void> logError(Object error, StackTrace? stack, {String? context}) async {
    final buf = StringBuffer()
      ..writeln('━━━ ERROR${context != null ? ' [$context]' : ''} ━━━')
      ..writeln('Time:  ${_ts()}')
      ..writeln('Error: $error');
    if (stack != null) {
      buf
        ..writeln('Stack:')
        ..writeln(stack.toString().split('\n').take(20).join('\n'));
    }
    buf.writeln('━━━ END ━━━\n');
    await _append(buf.toString());
  }

  Future<String> readLogs() async {
    try {
      if (_file == null || !await _file!.exists()) return '';
      return await _file!.readAsString();
    } catch (_) {
      return '';
    }
  }

  String getLogPath() => _file?.path ?? 'not initialised';

  Future<void> clearLogs() async {
    try {
      await _file?.writeAsString('');
    } catch (_) {}
  }

  // ─── Internal ───────────────────────────────────────────────────────────────

  String _ts() => DateTime.now().toIso8601String();

  Future<void> _append(String text) async {
    try {
      await _file?.writeAsString(text, mode: FileMode.append);
    } catch (_) {}
  }
}
