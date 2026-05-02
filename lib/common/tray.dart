// Desktop-only feature. Tray is not available on Android.
class Tray {
  Future<void> update({bool? force}) async {}
}

final Tray? tray = null;
