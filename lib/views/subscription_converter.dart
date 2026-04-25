/// Converts various subscription formats to Clash YAML.
///
/// Supported inputs:
///   • Clash YAML (pass-through)
///   • Base64-encoded proxy list (vmess://, vless://, ss://, trojan://)
///   • Single proxy URI
///
/// Returns a valid Clash YAML string or throws a descriptive error.
library subscription_converter;

import 'dart:convert';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────
String convertSubscriptionToClashYaml(String raw) {
  final trimmed = raw.trim();

  // 1. Already Clash YAML?
  if (_looksLikeClashYaml(trimmed)) return trimmed;

  // 2. Single proxy URI?
  if (_isProxyUri(trimmed)) {
    final proxy = _parseProxyUri(trimmed);
    if (proxy != null) return _buildClashYaml([proxy]);
    throw 'Не удалось разобрать прокси-ссылку: $trimmed';
  }

  // 3. Base64 encoded?
  final decoded = _tryBase64Decode(trimmed);
  if (decoded != null) {
    // 3a. Decoded is Clash YAML?
    if (_looksLikeClashYaml(decoded)) return decoded;

    // 3b. Decoded is list of proxy URIs?
    final proxies = _parseProxyList(decoded);
    if (proxies.isNotEmpty) return _buildClashYaml(proxies);
  }

  // 4. Multi-line proxy list without base64?
  if (trimmed.contains('\n')) {
    final proxies = _parseProxyList(trimmed);
    if (proxies.isNotEmpty) return _buildClashYaml(proxies);
  }

  throw 'Неизвестный формат подписки. Убедитесь что ссылка ведёт на Clash-подписку (YAML).';
}

// ─────────────────────────────────────────────────────────────────────────────
// Detection helpers
// ─────────────────────────────────────────────────────────────────────────────
bool _looksLikeClashYaml(String s) {
  return s.contains('proxies:') ||
      s.contains('proxy-groups:') ||
      s.contains('mixed-port:') ||
      s.contains('port:') && s.contains('mode:');
}

bool _isProxyUri(String s) {
  return s.startsWith('vmess://') ||
      s.startsWith('vless://') ||
      s.startsWith('ss://') ||
      s.startsWith('trojan://') ||
      s.startsWith('hy2://') ||
      s.startsWith('hysteria2://');
}

String? _tryBase64Decode(String s) {
  // Remove whitespace (some servers add newlines inside base64)
  final clean = s.replaceAll(RegExp(r'\s'), '');
  // Pad if needed
  final padded = clean.padRight((clean.length + 3) ~/ 4 * 4, '=');
  try {
    final bytes = base64Decode(padded);
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    // Try url-safe base64
    try {
      final bytes = base64Url.decode(padded);
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }
}

List<Map<String, dynamic>> _parseProxyList(String text) {
  final proxies = <Map<String, dynamic>>[];
  for (final line in text.split(RegExp(r'[\r\n]+'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final proxy = _parseProxyUri(trimmed);
    if (proxy != null) proxies.add(proxy);
  }
  return proxies;
}

// ─────────────────────────────────────────────────────────────────────────────
// Proxy URI parsers
// ─────────────────────────────────────────────────────────────────────────────
Map<String, dynamic>? _parseProxyUri(String uri) {
  try {
    if (uri.startsWith('vmess://'))    return _parseVmess(uri);
    if (uri.startsWith('vless://'))    return _parseVless(uri);
    if (uri.startsWith('ss://'))       return _parseSS(uri);
    if (uri.startsWith('trojan://'))   return _parseTrojan(uri);
    if (uri.startsWith('hy2://') || uri.startsWith('hysteria2://')) {
      return _parseHysteria2(uri);
    }
  } catch (_) {}
  return null;
}

// vmess://BASE64(json)
Map<String, dynamic>? _parseVmess(String uri) {
  final b64 = uri.substring('vmess://'.length);
  final decoded = _tryBase64Decode(b64);
  if (decoded == null) return null;
  final j = json.decode(decoded) as Map<String, dynamic>;

  final name = (j['ps'] ?? j['add'] ?? 'vmess').toString();
  final server = j['add']?.toString() ?? '';
  final port = int.tryParse(j['port']?.toString() ?? '443') ?? 443;
  final uuid = j['id']?.toString() ?? '';
  final alterId = int.tryParse(j['aid']?.toString() ?? '0') ?? 0;
  final network = j['net']?.toString() ?? 'tcp';
  final tls = j['tls']?.toString() == 'tls';
  final sni = j['sni']?.toString() ?? j['host']?.toString() ?? '';
  final path = j['path']?.toString() ?? '';
  final host = j['host']?.toString() ?? '';

  final proxy = <String, dynamic>{
    'name': name,
    'type': 'vmess',
    'server': server,
    'port': port,
    'uuid': uuid,
    'alterId': alterId,
    'cipher': 'auto',
    'network': network,
    'tls': tls,
  };

  if (sni.isNotEmpty) proxy['servername'] = sni;

  if (network == 'ws') {
    proxy['ws-opts'] = <String, dynamic>{
      if (path.isNotEmpty) 'path': path,
      if (host.isNotEmpty) 'headers': {'Host': host},
    };
  } else if (network == 'grpc') {
    proxy['grpc-opts'] = <String, dynamic>{
      if (path.isNotEmpty) 'grpc-service-name': path,
    };
  } else if (network == 'h2') {
    proxy['h2-opts'] = <String, dynamic>{
      if (path.isNotEmpty) 'path': path,
      if (host.isNotEmpty) 'host': [host],
    };
  }

  return proxy;
}

// vless://UUID@host:port?params#name
Map<String, dynamic>? _parseVless(String uri) {
  final noScheme = uri.substring('vless://'.length);
  final hashIdx = noScheme.indexOf('#');
  final name = hashIdx >= 0
      ? Uri.decodeComponent(noScheme.substring(hashIdx + 1))
      : 'vless';
  final withoutName = hashIdx >= 0 ? noScheme.substring(0, hashIdx) : noScheme;

  final atIdx = withoutName.indexOf('@');
  if (atIdx < 0) return null;
  final uuid = withoutName.substring(0, atIdx);
  final rest = withoutName.substring(atIdx + 1);

  final qIdx = rest.indexOf('?');
  final hostPort = qIdx >= 0 ? rest.substring(0, qIdx) : rest;
  final queryStr = qIdx >= 0 ? rest.substring(qIdx + 1) : '';

  final (server, port) = _splitHostPort(hostPort);
  final params = Uri.splitQueryString(queryStr);

  final network = params['type'] ?? 'tcp';
  final security = params['security'] ?? 'none';
  final sni = params['sni'] ?? params['peer'] ?? server;
  final fp = params['fp'] ?? '';
  final pbk = params['pbk'] ?? '';
  final sid = params['sid'] ?? '';
  final path = params['path'] ?? '';
  final host = params['host'] ?? '';
  final serviceName = params['serviceName'] ?? '';

  final proxy = <String, dynamic>{
    'name': name,
    'type': 'vless',
    'server': server,
    'port': port,
    'uuid': uuid,
    'network': network,
    'tls': security == 'tls' || security == 'reality',
  };

  if (security == 'reality') {
    proxy['reality-opts'] = <String, dynamic>{
      'public-key': pbk,
      if (sid.isNotEmpty) 'short-id': sid,
    };
    proxy['servername'] = sni;
  } else if (security == 'tls') {
    proxy['servername'] = sni;
  }

  if (fp.isNotEmpty) proxy['client-fingerprint'] = fp;

  if (network == 'ws') {
    proxy['ws-opts'] = <String, dynamic>{
      if (path.isNotEmpty) 'path': path,
      if (host.isNotEmpty) 'headers': {'Host': host},
    };
  } else if (network == 'grpc') {
    proxy['grpc-opts'] = <String, dynamic>{
      if (serviceName.isNotEmpty) 'grpc-service-name': serviceName,
    };
  } else if (network == 'h2') {
    proxy['h2-opts'] = <String, dynamic>{
      if (path.isNotEmpty) 'path': path,
      if (host.isNotEmpty) 'host': [host],
    };
  }

  return proxy;
}

// ss://BASE64(method:password)@host:port#name
// ss://BASE64(method:password@host:port)#name  (legacy)
Map<String, dynamic>? _parseSS(String uri) {
  final noScheme = uri.substring('ss://'.length);
  final hashIdx = noScheme.lastIndexOf('#');
  final name = hashIdx >= 0
      ? Uri.decodeComponent(noScheme.substring(hashIdx + 1))
      : 'ss';
  final withoutName = hashIdx >= 0 ? noScheme.substring(0, hashIdx) : noScheme;

  String method, password, server;
  int port;

  final atIdx = withoutName.lastIndexOf('@');
  if (atIdx > 0) {
    // Modern: BASE64(method:password)@host:port
    final credB64 = withoutName.substring(0, atIdx);
    final hostPort = withoutName.substring(atIdx + 1);
    final cred = _tryBase64Decode(credB64) ?? credB64;
    final colonIdx = cred.indexOf(':');
    if (colonIdx < 0) return null;
    method = cred.substring(0, colonIdx);
    password = cred.substring(colonIdx + 1);
    (server, port) = _splitHostPort(hostPort);
  } else {
    // Legacy: BASE64(method:password@host:port)
    final decoded = _tryBase64Decode(withoutName);
    if (decoded == null) return null;
    final atIdx2 = decoded.lastIndexOf('@');
    if (atIdx2 < 0) return null;
    final cred = decoded.substring(0, atIdx2);
    final hostPort = decoded.substring(atIdx2 + 1);
    final colonIdx = cred.indexOf(':');
    if (colonIdx < 0) return null;
    method = cred.substring(0, colonIdx);
    password = cred.substring(colonIdx + 1);
    (server, port) = _splitHostPort(hostPort);
  }

  return {
    'name': name,
    'type': 'ss',
    'server': server,
    'port': port,
    'cipher': method,
    'password': password,
  };
}

// trojan://password@host:port?params#name
Map<String, dynamic>? _parseTrojan(String uri) {
  final noScheme = uri.substring('trojan://'.length);
  final hashIdx = noScheme.indexOf('#');
  final name = hashIdx >= 0
      ? Uri.decodeComponent(noScheme.substring(hashIdx + 1))
      : 'trojan';
  final withoutName = hashIdx >= 0 ? noScheme.substring(0, hashIdx) : noScheme;

  final atIdx = withoutName.indexOf('@');
  if (atIdx < 0) return null;
  final password = withoutName.substring(0, atIdx);
  final rest = withoutName.substring(atIdx + 1);

  final qIdx = rest.indexOf('?');
  final hostPort = qIdx >= 0 ? rest.substring(0, qIdx) : rest;
  final queryStr = qIdx >= 0 ? rest.substring(qIdx + 1) : '';
  final params = Uri.splitQueryString(queryStr);

  final (server, port) = _splitHostPort(hostPort);
  final sni = params['sni'] ?? params['peer'] ?? server;
  final network = params['type'] ?? 'tcp';

  final proxy = <String, dynamic>{
    'name': name,
    'type': 'trojan',
    'server': server,
    'port': port,
    'password': password,
    'sni': sni,
  };

  if (network == 'ws') {
    proxy['network'] = 'ws';
    proxy['ws-opts'] = <String, dynamic>{
      if (params['path'] != null) 'path': params['path']!,
      if (params['host'] != null) 'headers': {'Host': params['host']!},
    };
  } else if (network == 'grpc') {
    proxy['network'] = 'grpc';
    proxy['grpc-opts'] = <String, dynamic>{
      if (params['serviceName'] != null)
        'grpc-service-name': params['serviceName']!,
    };
  }

  return proxy;
}

// hy2://password@host:port?params#name
Map<String, dynamic>? _parseHysteria2(String uri) {
  final noScheme = uri.startsWith('hysteria2://')
      ? uri.substring('hysteria2://'.length)
      : uri.substring('hy2://'.length);
  final hashIdx = noScheme.indexOf('#');
  final name = hashIdx >= 0
      ? Uri.decodeComponent(noScheme.substring(hashIdx + 1))
      : 'hy2';
  final withoutName = hashIdx >= 0 ? noScheme.substring(0, hashIdx) : noScheme;

  final atIdx = withoutName.indexOf('@');
  if (atIdx < 0) return null;
  final password = withoutName.substring(0, atIdx);
  final rest = withoutName.substring(atIdx + 1);

  final qIdx = rest.indexOf('?');
  final hostPort = qIdx >= 0 ? rest.substring(0, qIdx) : rest;
  final queryStr = qIdx >= 0 ? rest.substring(qIdx + 1) : '';
  final params = Uri.splitQueryString(queryStr);

  final (server, port) = _splitHostPort(hostPort);
  final sni = params['sni'] ?? server;

  return {
    'name': name,
    'type': 'hysteria2',
    'server': server,
    'port': port,
    'password': password,
    'sni': sni,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// YAML builder
// ─────────────────────────────────────────────────────────────────────────────
String _buildClashYaml(List<Map<String, dynamic>> proxies) {
  if (proxies.isEmpty) throw 'Список прокси пуст';

  final names = proxies.map((p) => p['name'].toString()).toList();

  final buf = StringBuffer();
  buf.writeln('mixed-port: 7890');
  buf.writeln('allow-lan: false');
  buf.writeln('mode: rule');
  buf.writeln('log-level: warning');
  buf.writeln('ipv6: false');
  buf.writeln();
  buf.writeln('dns:');
  buf.writeln('  enable: true');
  buf.writeln('  ipv6: false');
  buf.writeln('  nameserver:');
  buf.writeln('    - 8.8.8.8');
  buf.writeln('    - 1.1.1.1');
  buf.writeln('  enhanced-mode: fake-ip');
  buf.writeln('  fake-ip-range: 198.18.0.1/16');
  buf.writeln('  fake-ip-filter:');
  buf.writeln('    - "*.lan"');
  buf.writeln();
  buf.writeln('proxies:');
  for (final p in proxies) {
    buf.writeln(_proxyToYaml(p));
  }
  buf.writeln();
  buf.writeln('proxy-groups:');
  buf.writeln('  - name: "\u{1F680} Автовыбор"');
  buf.writeln('    type: url-test');
  buf.writeln('    proxies:');
  for (final n in names) {
    buf.writeln('      - "${_yamlEscape(n)}"');
  }
  buf.writeln("    url: 'http://www.gstatic.com/generate_204'");
  buf.writeln('    interval: 300');
  buf.writeln('    tolerance: 50');
  buf.writeln('  - name: "\u{1F530} Основной"');
  buf.writeln('    type: select');
  buf.writeln('    proxies:');
  buf.writeln('      - "\u{1F680} Автовыбор"');
  for (final n in names) {
    buf.writeln('      - "${_yamlEscape(n)}"');
  }
  buf.writeln();
  buf.writeln('rules:');
  buf.writeln('  - DOMAIN-SUFFIX,instagram.com,\u{1F530} Основной');
  buf.writeln('  - DOMAIN-SUFFIX,facebook.com,\u{1F530} Основной');
  buf.writeln('  - DOMAIN-SUFFIX,twitter.com,\u{1F530} Основной');
  buf.writeln('  - DOMAIN-SUFFIX,x.com,\u{1F530} Основной');
  buf.writeln('  - DOMAIN-SUFFIX,youtube.com,\u{1F530} Основной');
  buf.writeln('  - DOMAIN-SUFFIX,youtu.be,\u{1F530} Основной');
  buf.writeln('  - DOMAIN-SUFFIX,tiktok.com,\u{1F530} Основной');
  buf.writeln('  - DOMAIN-SUFFIX,discord.com,\u{1F530} Основной');
  buf.writeln('  - DOMAIN-SUFFIX,spotify.com,\u{1F530} Основной');
  buf.writeln('  - DOMAIN-SUFFIX,telegram.org,\u{1F530} Основной');
  buf.writeln('  - DOMAIN-SUFFIX,github.com,\u{1F530} Основной');
  buf.writeln('  - DOMAIN-SUFFIX,openai.com,\u{1F530} Основной');
  buf.writeln('  - DOMAIN-SUFFIX,anthropic.com,\u{1F530} Основной');
  buf.writeln('  - DOMAIN-SUFFIX,claude.ai,\u{1F530} Основной');
  buf.writeln('  - GEOIP,RU,DIRECT');
  buf.writeln('  - MATCH,\u{1F530} Основной');

  return buf.toString();
}

String _proxyToYaml(Map<String, dynamic> proxy) {
  final buf = StringBuffer();
  buf.writeln('  - name: "${_yamlEscape(proxy['name'].toString())}"');
  buf.writeln('    type: ${proxy['type']}');
  buf.writeln('    server: ${proxy['server']}');
  buf.writeln('    port: ${proxy['port']}');

  for (final key in proxy.keys) {
    if (const {'name', 'type', 'server', 'port'}.contains(key)) continue;
    final val = proxy[key];
    if (val is Map) {
      if (val.isEmpty) continue;
      buf.writeln('    $key:');
      val.forEach((k, v) {
        if (v is Map) {
          buf.writeln('      $k:');
          (v as Map).forEach((k2, v2) {
            buf.writeln('        $k2: ${_yamlValue(v2)}');
          });
        } else if (v is List) {
          buf.writeln('      $k:');
          for (final item in v) {
            buf.writeln('        - ${_yamlValue(item)}');
          }
        } else {
          buf.writeln('      $k: ${_yamlValue(v)}');
        }
      });
    } else if (val is bool) {
      buf.write('    $key: $val');
      buf.writeln();
    } else if (val is String && val.isNotEmpty) {
      buf.writeln('    $key: "${_yamlEscape(val)}"');
    } else if (val is int || val is double) {
      buf.writeln('    $key: $val');
    }
  }
  return buf.toString().trimRight();
}

String _yamlValue(dynamic v) {
  if (v is String) return '"${_yamlEscape(v)}"';
  if (v is bool || v is int || v is double) return v.toString();
  return v.toString();
}

String _yamlEscape(String s) =>
    s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

(String server, int port) _splitHostPort(String hostPort) {
  // Handle IPv6: [::1]:443
  if (hostPort.startsWith('[')) {
    final end = hostPort.indexOf(']');
    final server = hostPort.substring(1, end);
    final portStr = hostPort.substring(end + 2);
    return (server, int.tryParse(portStr) ?? 443);
  }
  final lastColon = hostPort.lastIndexOf(':');
  if (lastColon < 0) return (hostPort, 443);
  final server = hostPort.substring(0, lastColon);
  final port = int.tryParse(hostPort.substring(lastColon + 1)) ?? 443;
  return (server, port);
}
