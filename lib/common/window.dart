// Desktop-only window management. All methods are no-ops on Android.
class Window {
  Future<void> show() async {}
  Future<void> hide() async {}
  Future<void> close() async {}
  Future<void> setTitle(String title) async {}
  Future<void> setTitleBarStyle({dynamic titleBarStyle}) async {}
  bool get isVisible => false;
  bool get isMobile => true;
}

final Window? window = null;
// Note: 'windows' (Windows OS helper) is defined in windows.dart
