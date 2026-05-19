import 'dart:async';
import 'dart:io';

import 'package:flclashx/common/path.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';

// ─── Constants ────────────────────────────────────────────────────────────────
const _kMaxFileBytes = 10 * 1024 * 1024; // 10 MB
const _kMaxFiles     = 7;
const _kDateFmt      = 'yyyy-MM-dd';
const _kTsFmt        = 'yyyy-MM-dd HH:mm:ss.SSS';
const _kPrefix       = 'FlClashX_';

class FileLogger {
  factory FileLogger() => _instance ??= FileLogger._();
  FileLogger._();
  static FileLogger? _instance;

  IOSink?  _sink;
  String?  _sinkPath;
  String?  _date;

  final _queue    = <String>[];
  bool  _writing  = false;
  bool  _ready    = false; // true after app bindings init

  // ─── Public API ─────────────────────────────────────────────────────────────

  void log(String message) {
    _queue.add(message);
    if (_ready) unawaited(_flush());
  }

  /// Call once after WidgetsFlutterBinding.ensureInitialized().
  void markReady() {
    _ready = true;
    if (_queue.isNotEmpty) unawaited(_flush());
  }

  Future<void> dispose() async {
    await _closeSink();
    _queue.clear();
  }

  // ─── Internals ───────────────────────────────────────────────────────────────

  Future<void> _flush() async {
    if (_writing || _queue.isEmpty) return;
    _writing = true;
    try {
      await _ensureSink();
      final ts = DateFormat(_kTsFmt).format(DateTime.now());
      for (final msg in _queue) {
        _sink?.writeln('[$ts] $msg');
      }
      _queue.clear();
      await _sink?.flush();
    } catch (_) {
      // Never crash the app over logging
    } finally {
      _writing = false;
    }
    if (_queue.isNotEmpty) unawaited(_flush());
  }

  Future<void> _ensureSink() async {
    final today = DateFormat(_kDateFmt).format(DateTime.now());
    if (_date != today || _sinkPath == null) {
      await _closeSink();
      _date = today;
      await _rotateLogs();
    }
    if (_sink != null) {
      final size = await File(_sinkPath!).length().catchError((_) => 0);
      if (size < _kMaxFileBytes) return;
      await _closeSink();
    }
    final path = await _pickPath(today);
    _sinkPath = path;
    _sink = File(path).openWrite(mode: FileMode.append);
  }

  Future<String> _pickPath(String today) async {
    final dir = await _logsDir();
    for (var i = 0; ; i++) {
      final name = i == 0 ? '$_kPrefix$today.log' : '$_kPrefix${today}_$i.log';
      final file = File(join(dir, name));
      if (!await file.exists()) return file.path;
      if (await file.length() < _kMaxFileBytes) return file.path;
    }
  }

  Future<String> _logsDir() async {
    final home = await appPath.homeDirPath;
    final dir  = Directory(join(home, 'logs'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<void> _rotateLogs() async {
    try {
      final dir   = Directory(await _logsDir());
      final files = await dir
          .list()
          .where((e) => e is File && e.path.endsWith('.log'))
          .cast<File>()
          .toList()
        ..sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
      while (files.length > _kMaxFiles) {
        await files.removeAt(0).delete().catchError((_) {});
      }
    } catch (_) {}
  }

  Future<void> _closeSink() async {
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {}
    _sink     = null;
    _sinkPath = null;
  }
}

final fileLogger = FileLogger();
