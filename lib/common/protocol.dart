import 'dart:io';

// Windows-only feature: register URL protocol handler in registry.
// No-op on Android.
Future<void> registerProtocol(String protocol) async {}
Future<void> unregisterProtocol(String protocol) async {}