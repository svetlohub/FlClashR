import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flclashx/common/common.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceDetails {
  const DeviceDetails({
    this.hwid,
    this.os,
    this.osVersion,
    this.model,
    this.appVersion,
  });
  final String? hwid;
  final String? os;
  final String? osVersion;
  final String? model;
  final String? appVersion;
}

class DeviceInfoService {
  static const _hwidKey = 'app_persistent_hwid';
  static const _channel = MethodChannel('com.follow.clashx/device_id');
  static final _plugin  = DeviceInfoPlugin();

  // ─── Public ──────────────────────────────────────────────────────────────────
  Future<DeviceDetails> getDeviceDetails() async {
    final packageInfo = await PackageInfo.fromPlatform();
    String? hwid, os, osVersion, model;

    try {
      hwid = await _getOrCreateHwid();
      if (Platform.isAndroid) {
        final i = await _plugin.androidInfo;
        os = 'Android';
        osVersion = i.version.release;
        model = '${i.manufacturer} ${i.model}';
      } else if (Platform.isWindows) {
        final i = await _plugin.windowsInfo;
        os = 'Windows';
        osVersion = i.displayVersion;
        model = i.productName;
      } else if (Platform.isLinux) {
        final i = await _plugin.linuxInfo;
        os = 'Linux';
        osVersion = i.versionId;
        model = i.name;
      } else if (Platform.isMacOS) {
        final i = await _plugin.macOsInfo;
        os = 'macOS';
        osVersion = i.osRelease;
        model = i.model;
      }
    } catch (_) {}

    return DeviceDetails(
      hwid: hwid,
      os: os,
      osVersion: osVersion,
      model: model,
      appVersion: packageInfo.version,
    );
  }

  // ─── HWID ─────────────────────────────────────────────────────────────────
  Future<String?> _getOrCreateHwid() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_hwidKey);
    if (stored != null && stored.isNotEmpty) return stored;

    final raw = await _platformDeviceId();
    if (raw == null || raw.isEmpty) return null;

    // Android: use ANDROID_ID verbatim. Others: sha256→16 chars.
    final hwid = Platform.isAndroid ? raw : _compact16(raw);
    await prefs.setString(_hwidKey, hwid);
    return hwid;
  }

  Future<String?> _platformDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final id = await _channel.invokeMethod<String>('getAndroidId');
        if (id != null && id.isNotEmpty) return id;
        final i = await _plugin.androidInfo;
        return '${i.brand}-${i.device}-${i.hardware}-${i.id}';
      } else if (Platform.isWindows) {
        final i = await _plugin.windowsInfo;
        return '${i.computerName}-${i.deviceId}-${i.productId}';
      } else if (Platform.isLinux) {
        final i = await _plugin.linuxInfo;
        return i.machineId ?? '${i.id}-${i.name}';
      } else if (Platform.isMacOS) {
        final i = await _plugin.macOsInfo;
        return i.systemGUID ?? '${i.model}-${i.computerName}';
      }
    } catch (e) {
      commonPrint.log('DeviceInfoService: failed to get device ID: $e');
    }
    return null;
  }

  static String _compact16(String id) {
    final hash = sha256.convert(utf8.encode(id)).toString();
    return hash.substring(0, 16).toUpperCase();
  }
}
