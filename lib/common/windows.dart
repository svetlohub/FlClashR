// Windows OS helper. All methods are no-ops on Android.
class WindowsHelper {
  void enableDarkModeForApp() {}
  Future<bool?> checkService() async => null;
  Future<bool?> tryStartExistingService() async => null;
  Future<bool?> installService() async => null;
  Future<void> runas(String executable, [String args = '']) async {}
}

final WindowsHelper? windows = null;
