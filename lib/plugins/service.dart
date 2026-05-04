import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flclashx/state.dart';
import 'package:flutter/services.dart';

import '../clash/lib.dart';

class Service {

  factory Service() {
    _instance ??= Service._internal();
    return _instance!;
  }

  Service._internal() {
    methodChannel = const MethodChannel("service");
  }
  static Service? _instance;
  late MethodChannel methodChannel;
  ReceivePort? receiver;

  Future<bool?> init() async => methodChannel.invokeMethod<bool>("init");

  Future<bool?> destroy() async => methodChannel.invokeMethod<bool>("destroy");

  Future<bool?> startVpn() async {
    final options = await clashLib?.getAndroidVpnOptions();
    // Guard: if options is null, Kotlin throws "VPN options data is null or empty"
    // which crashes with a confusing PlatformException. Throw early with a clear message.
    if (options == null) {
      throw Exception(
        'VPN configuration is missing. '
        'Please import a subscription first, then try again. '
        '(getAndroidVpnOptions returned null — config may not be loaded into core yet)',
      );
    }
    // Sanity check: ipv4Address must be non-empty for TUN to establish
    if (options.ipv4Address.isEmpty) {
      throw Exception(
        'VPN configuration is incomplete (no TUN address). '
        'Try re-importing your subscription.',
      );
    }
    return methodChannel.invokeMethod<bool>("startVpn", {
      'data': json.encode(options),
    });
  }

  Future<bool?> stopVpn() async => methodChannel.invokeMethod<bool>("stopVpn");
}

Service? get service => Platform.isAndroid && !globalState.isService ? Service() : null;
