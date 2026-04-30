import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/config.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Модель сервиса ───────────────────────────────────────────────────────────
class RussiaService {
  final String id;
  final String name;
  final String emoji;
  // Домены для DOMAIN-SUFFIX правил
  final List<String> domains;
  // Ключевые слова для DOMAIN-KEYWORD правил (например youtube для CDN)
  final List<String> keywords;
  // IP-CIDR правила вида '91.108.0.0/16' (без PROXY суффикса, добавим сами)
  final List<String> ipCidrs;
  final bool defaultOn;

  const RussiaService({
    required this.id,
    required this.name,
    required this.emoji,
    required this.domains,
    this.keywords = const [],
    this.ipCidrs = const [],
    required this.defaultOn,
  });
}

const russiaServices = [
  // ── По умолчанию включены (3 сервиса) ───────────────────────────────────
  RussiaService(
    id: 'youtube',
    name: 'YouTube',
    emoji: '▶️',
    domains: [
      'youtube.com', 'youtu.be', 'ytimg.com',
      'googlevideo.com', 'yt3.ggpht.com',
      'youtube-nocookie.com', 'youtubeembeddedplayer.googleapis.com',
    ],
    keywords: ['youtube'],          // CDN поддомены непредсказуемы
    defaultOn: true,
  ),
  RussiaService(
    id: 'telegram',
    name: 'Telegram',
    emoji: '✈️',
    domains: [
      't.me', 'telegram.org', 'telegram.me',
      'core.telegram.org', 'cdn.telegram.org',
      'tdesktop.com',
    ],
    // Telegram IP-диапазоны — DPI режет именно по IP
    ipCidrs: [
      '91.108.0.0/16',
      '91.108.4.0/22',
      '91.108.8.0/22',
      '91.108.56.0/22',
      '149.154.160.0/20',
      '149.154.164.0/22',
    ],
    defaultOn: true,
  ),
  RussiaService(
    id: 'whatsapp',
    name: 'WhatsApp',
    emoji: '💬',
    // WhatsApp работает на инфраструктуре Meta — нужны fbcdn/fbsbx
    domains: [
      'whatsapp.com', 'whatsapp.net', 'wa.me',
      'fbcdn.net', 'fbsbx.com',          // WhatsApp медиа-CDN
      'facebook.com', 'fb.com',           // авторизация
    ],
    defaultOn: true,
  ),

  // ── Выключены по умолчанию ───────────────────────────────────────────────
  RussiaService(
    id: 'instagram',
    name: 'Instagram',
    emoji: '📸',
    domains: ['instagram.com', 'cdninstagram.com'],
    defaultOn: false,
  ),
  RussiaService(
    id: 'twitter',
    name: 'X (Twitter)',
    emoji: '🐦',
    domains: ['twitter.com', 'x.com', 't.co', 'twimg.com'],
    defaultOn: false,
  ),
  RussiaService(
    id: 'tiktok',
    name: 'TikTok',
    emoji: '🎵',
    domains: [
      'tiktok.com', 'tiktokcdn.com', 'tiktokcdn-us.com',
      'muscdn.com', 'byteoversea.com', 'tiktokv.com',
    ],
    defaultOn: false,
  ),
  RussiaService(
    id: 'discord',
    name: 'Discord',
    emoji: '🎮',
    domains: [
      'discord.com', 'discord.gg', 'discordapp.com',
      'discordapp.net', 'discord.media',
    ],
    defaultOn: false,
  ),
  RussiaService(
    id: 'spotify',
    name: 'Spotify',
    emoji: '🎧',
    domains: ['spotify.com', 'scdn.co', 'spotifycdn.com'],
    defaultOn: false,
  ),
  RussiaService(
    id: 'openai',
    name: 'ChatGPT / OpenAI',
    emoji: '🤖',
    domains: [
      'openai.com', 'chatgpt.com', 'oaistatic.com',
      'oaiusercontent.com', 'auth0.openai.com',
    ],
    defaultOn: false,
  ),
  RussiaService(
    id: 'github',
    name: 'GitHub',
    emoji: '🐙',
    domains: [
      'github.com', 'githubusercontent.com',
      'github.io', 'githubassets.com', 'ghcr.io',
    ],
    defaultOn: false,
  ),
  RussiaService(
    id: 'linkedin',
    name: 'LinkedIn',
    emoji: '💼',
    domains: ['linkedin.com', 'licdn.com'],
    defaultOn: false,
  ),
];

// ─── DNS ──────────────────────────────────────────────────────────────────────
// respectRules: false — DNS-запросы не идут через правила маршрутизации,
// иначе DNS петля при fake-ip режиме
const _presetDns = Dns(
  enable: true,
  preferH3: false,
  useHosts: false,
  useSystemHosts: false,
  respectRules: false,
  ipv6: false,
  defaultNameserver: ['1.1.1.1', '8.8.8.8'],
  enhancedMode: DnsMode.fakeIp,   // скрывает DNS-запросы от DPI
  fakeIpRange: '198.18.0.1/16',
  fakeIpFilter: [],
  nameserverPolicy: {},
  nameserver: [
    'https://1.1.1.1/dns-query',
    'https://8.8.8.8/dns-query',
  ],
  fallback: ['1.0.0.1', '8.8.4.4'],
  proxyServerNameserver: ['https://1.1.1.1/dns-query'],
  fallbackFilter: FallbackFilter(
    geoip: false,
    geoipCode: 'RU',
    geosite: [],
    ipcidr: ['240.0.0.0/4'],
    domain: [],
  ),
);

// ─── TUN ──────────────────────────────────────────────────────────────────────
// gvisor stack лучше System для stealth (меньше сигнатур)
const _presetTun = Tun(
  enable: true,
  stack: TunStack.gvisor,
  dnsHijack: ['any:53'],
  autoRoute: false,
);

// ─── Построение правил ────────────────────────────────────────────────────────
List<String> buildRulesFromServices(Map<String, bool> serviceStates) {
  final rules = <String>[];

  // Блокировка QUIC/HTTP3 через UDP:443 — заставляет приложения
  // откатиться на TCP, который лучше работает через прокси
  rules.add('DST-PORT,443,REJECT,udp');

  // Правила для каждого включённого сервиса
  for (final svc in russiaServices) {
    final isOn = serviceStates[svc.id] ?? svc.defaultOn;
    if (!isOn) continue;

    // IP-CIDR правила первыми (приоритет над доменными)
    for (final cidr in svc.ipCidrs) {
      rules.add('IP-CIDR,$cidr,PROXY,no-resolve');
    }
    // Доменные правила
    for (final domain in svc.domains) {
      rules.add('DOMAIN-SUFFIX,$domain,PROXY');
    }
    // Ключевые слова (для CDN с непредсказуемыми поддоменами)
    for (final kw in svc.keywords) {
      rules.add('DOMAIN-KEYWORD,$kw,PROXY');
    }
  }

  // Российские ресурсы — всегда напрямую
  rules.addAll([
    'GEOIP,RU,DIRECT',
    'DOMAIN-SUFFIX,ru,DIRECT',
    'DOMAIN-SUFFIX,xn--p1ai,DIRECT',
    'DOMAIN-SUFFIX,su,DIRECT',
  ]);

  // MATCH → DIRECT: 95% трафика идёт как обычно.
  // DPI видит обычного пользователя, а не VPN-пользователя.
  // Только явно указанные сервисы проходят через прокси.
  rules.add('MATCH,DIRECT');

  return rules;
}

// ─── Применить пресет ─────────────────────────────────────────────────────────
void applyRussia2026Preset(WidgetRef ref, {Map<String, bool>? serviceStates}) {
  ref.read(patchClashConfigProvider.notifier).updateState(
    (state) => state.copyWith(
      dns: _presetDns,
      tun: _presetTun,
      mode: Mode.rule,
      allowLan: false,
      logLevel: LogLevel.warning,
      ipv6: false,
      unifiedDelay: true,
      tcpConcurrent: false,
    ),
  );
  ref.read(overrideDnsProvider.notifier).value = true;
  ref.read(vpnSettingProvider.notifier).updateState(
    (state) => state.copyWith(
      enable: true,
      systemProxy: false,
      ipv6: false,
      allowBypass: true,
    ),
  );
  ref.read(networkSettingProvider.notifier).updateState(
    (state) => state.copyWith(systemProxy: false),
  );

  final currentId = ref.read(currentProfileIdProvider);
  if (currentId == null) return;

  final states = serviceStates ?? {
    for (final s in russiaServices) s.id: s.defaultOn,
  };

  final ruleStrings = buildRulesFromServices(states);
  final rules = ruleStrings.map((r) => Rule.value(r)).toList();

  ref.read(profilesProvider.notifier).updateProfile(
    currentId,
    (profile) => profile.copyWith(
      overrideData: OverrideData(
        enable: true,
        rule: OverrideRule(
          type: OverrideRuleType.override,
          overrideRules: rules,
          addedRules: const [],
        ),
      ),
    ),
  );

  globalState.appController.applyProfileDebounce(silence: true);
}
