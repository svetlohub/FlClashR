import 'package:flclashx/common/common.dart';
import 'package:flclashx/enum/enum.dart';
import 'package:flutter/scheduler.dart';

/// Pauses/resumes Flutter's render loop on desktop when idle.
/// On mobile this is always null — no-op.
class Render {
  factory Render() => _instance ??= Render._();
  Render._();
  static Render? _instance;

  bool _paused = false;
  final _dispatcher = SchedulerBinding.instance.platformDispatcher;
  FrameCallback? _savedBeginFrame;
  VoidCallback?  _savedDrawFrame;

  /// Call when activity detected — resets the pause timer.
  void active() {
    resume();
    _schedulePause();
  }

  void resume() {
    throttler.cancel(FunctionTag.renderPause);
    _doResume();
  }

  // ─── Private ────────────────────────────────────────────────────────────────

  void _schedulePause() {
    throttler.call(
      FunctionTag.renderPause,
      _doPause,
      duration: const Duration(seconds: 5),
    );
  }

  void _doPause() {
    if (_paused) return;
    _paused = true;
    _savedBeginFrame = _dispatcher.onBeginFrame;
    _savedDrawFrame  = _dispatcher.onDrawFrame;
    _dispatcher.onBeginFrame = null;
    _dispatcher.onDrawFrame  = null;
    commonPrint.log('render: paused');
  }

  void _doResume() {
    if (!_paused) return;
    _paused = false;
    _dispatcher.onBeginFrame = _savedBeginFrame;
    _dispatcher.onDrawFrame  = _savedDrawFrame;
    _dispatcher.scheduleFrame();
    commonPrint.log('render: resumed');
  }
}

// Only active on desktop; null on Android/iOS avoids overhead entirely.
final Render? render = system.isDesktop ? Render() : null;
