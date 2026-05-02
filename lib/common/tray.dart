// Desktop-only system tray. All methods are no-ops on Android.
class Tray {
  // trayState parameter accepted but ignored on Android
  void update({dynamic trayState, bool? force}) {}
}

// tray is a non-null instance so tray.update() works without ?. check
final Tray tray = Tray();
