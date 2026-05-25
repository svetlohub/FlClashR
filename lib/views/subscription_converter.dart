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
      for (final entry in val.entries) {
        final k = entry.key;
        final v = entry.value;
        if (v is Map) {
          buf.writeln('      $k:');
          for (final e2 in v.entries) {
            buf.writeln('        ${e2.key}: ${_yamlValue(e2.value)}');
          }
        } else if (v is List) {
          buf.writeln('      $k:');
          for (final item in v) {
            buf.writeln('        - ${_yamlValue(item)}');
          }
        } else {
          buf.writeln('      $k: ${_yamlValue(v)}');
        }
      }
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

// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
// HTML Subscription Page Parser
// Extracts subscription URLs or data from HTML wrapper pages.
// Strategy: wall detection → inline data → meta-refresh → JS redirect → links → base64
// ─────────────────────────────────────────────────────────────────────────────

class HtmlParseResult {
  const HtmlParseResult._({
    this.subscriptionUrl,
    this.subscriptionData,
    this.errorReason,
  });

  /// A redirect URL found — caller must fetch it.
  final String? subscriptionUrl;

  /// Subscription content found inline — use directly.
  final String? subscriptionData;

  /// Human-readable failure reason.
  final String? errorReason;

  bool get hasUrl  => subscriptionUrl != null;
  bool get hasData => subscriptionData != null;
  bool get failed  => subscriptionUrl == null && subscriptionData == null;
}

/// Entry point: parse an HTML page and extract subscription content.
HtmlParseResult parseHtmlSubscriptionPage(String html, {String? pageUrl}) {
  final wall = _detectWall(html);
  if (wall != null) return HtmlParseResult._(errorReason: wall);

  final inline = _inlineData(html);
  if (inline != null) return HtmlParseResult._(subscriptionData: inline);

  final meta = _metaRefreshUrl(html, base: pageUrl);
  if (meta != null) return HtmlParseResult._(subscriptionUrl: meta);

  final js = _jsRedirectUrl(html, base: pageUrl);
  if (js != null) return HtmlParseResult._(subscriptionUrl: js);

  final link = _subscriptionLink(html, base: pageUrl);
  if (link != null) return HtmlParseResult._(subscriptionUrl: link);

  final b64 = _base64Blob(html);
  if (b64 != null) return HtmlParseResult._(subscriptionData: b64);

  return HtmlParseResult._(
    errorReason: "Сервер вернул HTML без распознаваемой подписки. "
        "Скопируйте прямую ссылку вручную.",
  );
}

// ── Wall page detection ───────────────────────────────────────────────────────
String? _detectWall(String html) {
  final l = html.toLowerCase();
  if (l.contains("checking your browser") ||
      l.contains("cf-browser-verification") ||
      l.contains("just a moment") ||
      (l.contains("cloudflare") && l.contains("challenge"))) {
    return "Cloudflare защищает эту страницу. Откройте ссылку в браузере "
        "и скопируйте прямую ссылку на подписку.";
  }
  if ((l.contains("login") || l.contains("sign in") ||
          l.contains("войти") || l.contains("авторизация")) &&
      (l.contains("<form") || l.contains("password"))) {
    return "Страница требует авторизации. Войдите в браузере "
        "и скопируйте прямую ссылку на подписку.";
  }
  if (l.contains("403 forbidden") ||
      l.contains("404 not found") ||
      l.contains("429 too many")) {
    return "Сервер вернул ошибку (403/404/429). Проверьте ссылку.";
  }
  if (l.contains("captcha") || l.contains("recaptcha")) {
    return "Сервер требует капчу. Откройте ссылку в браузере.";
  }
  return null;
}

// ── Inline data in <pre>/<textarea>/<code> ────────────────────────────────────
String? _inlineData(String html) {
  for (final tag in ["pre", "textarea", "code"]) {
    final re = RegExp("<$tag[^>]*>([\\s\\S]+?)</$tag>",
        caseSensitive: false);
    for (final m in re.allMatches(html)) {
      final inner = (m.group(1) ?? "")
          .replaceAll(RegExp("<[^>]+>"), "")
          .trim();
      if (inner.length < 20) continue;
      if (_isProxyUri(inner) ||
          _looksLikeClashYaml(inner) ||
          _looksLikeBase64Sub(inner)) {
        return inner;
      }
    }
  }
  return null;
}

// ── <meta http-equiv="refresh" content="N; url=..."> ─────────────────────────
String? _metaRefreshUrl(String html, {String? base}) {
  // Avoid single-quote in regex by matching [^;\s>]+ for url value
  // then stripping any surrounding quotes with replaceAll
  final re = RegExp(
      r"<meta[^>]+content\s*=\s*[^>]*url\s*=\s*([^\s;>]+)",
      caseSensitive: false);
  final m = re.firstMatch(html);
  if (m == null) return null;
  final raw = m.group(1)!.replaceAll('"', "").replaceAll("\x27", "");
  return _resolveUrl(raw.trim(), base);
}

// ── JS redirects: window.location / location.href / location.replace ──────────
String? _jsRedirectUrl(String html, {String? base}) {
  // Use double-quoted patterns only
  final patterns = [
    RegExp(r'window\.location(?:\.href)?\s*=\s*"([^"]+)"'),
    RegExp(r'location\.replace\s*\(\s*"([^"]+)"'),
    RegExp(r'location\.href\s*=\s*"([^"]+)"'),
    // single-quoted variants via explicit char
    RegExp("window[.]location(?:[.]href)?\s*=\s*'([^']+)'"),
    RegExp("location[.]replace\s*[(]\s*'([^']+)'"),
  ];
  for (final re in patterns) {
    final m = re.firstMatch(html);
    if (m != null) {
      final url = m.group(1)!;
      if (url.startsWith("http") || url.startsWith("/")) {
        return _resolveUrl(url, base);
      }
    }
  }
  return null;
}

// ── <a href> links ────────────────────────────────────────────────────────────
String? _subscriptionLink(String html, {String? base}) {
  const keywords = [
    "sub", "subscribe", "clash", "vmess", "vless",
    "trojan", "proxy", "config", "yaml", "token", "link",
  ];
  // Match href="..." and href='...' separately to avoid mixed-quote raw strings
  final reDouble = RegExp(r'href="([^"]+)"', caseSensitive: false);
  final reSingle = RegExp("href='([^']+)'",  caseSensitive: false);

  final high = <String>[];
  final low  = <String>[];

  for (final m in [...reDouble.allMatches(html), ...reSingle.allMatches(html)]) {
    final href = m.group(1)!.trim();
    if (!href.startsWith("http") && !href.startsWith("/")) continue;
    final l = href.toLowerCase();
    if (l.contains(".css") || l.contains(".js") ||
        l.contains("login") || l.contains("logout") ||
        l.contains("favicon")) continue;
    if (keywords.any((k) => l.contains(k))) {
      high.add(href);
    } else {
      low.add(href);
    }
  }

  final all = [...high, ...low];
  if (all.isNotEmpty) return _resolveUrl(all.first, base);
  return null;
}

// ── Long base64 blobs embedded in HTML ───────────────────────────────────────
String? _base64Blob(String html) {
  final re = RegExp(r"[A-Za-z0-9+/=]{100,}");
  for (final m in re.allMatches(html)) {
    final s = m.group(0)!;
    try {
      final padded = s.padRight((s.length + 3) ~/ 4 * 4, "=");
      final decoded = utf8.decode(base64Decode(padded), allowMalformed: true);
      if (_isProxyUri(decoded) ||
          _looksLikeClashYaml(decoded) ||
          _parseProxyList(decoded).isNotEmpty) {
        return decoded;
      }
    } catch (_) {}
  }
  return null;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

bool _looksLikeBase64Sub(String s) {
  final clean = s.replaceAll(RegExp(r"\s"), "");
  return clean.length >= 50 &&
      RegExp(r"^[A-Za-z0-9+/=]+$").hasMatch(clean);
}

/// Resolves a relative URL against an optional base URL.
String _resolveUrl(String url, String? base) {
  if (url.startsWith("http://") || url.startsWith("https://")) return url;
  if (base == null) return url;
  try {
    final b = Uri.parse(base);
    if (url.startsWith("/")) {
      return b.scheme + "://" + b.host + url;
    }
    final segs = List<String>.from(b.pathSegments);
    if (segs.isNotEmpty) segs.removeLast();
    return b.scheme + "://" + b.host + "/" + segs.join("/") + "/" + url;
  } catch (_) {
    return url;
  }
}
