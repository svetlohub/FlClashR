import 'dart:io';

// Desktop-only feature. No-op on Android.
class Window {
  Future<void> show() async {}
  Future<void> hide() async {}
  Future<void> close() async {}
  Future<void> setTitle(String title) async {}
  Future<void> setTitleBarStyle({dynamic titleBarStyle}) async {}
  bool get isMobile => Platform.isAndroid;
}

final window = Window();
final windows = null;
