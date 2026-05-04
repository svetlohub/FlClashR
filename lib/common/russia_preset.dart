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
      // RoscomVPN additions: YouTube TV, Studio, Music
      'youtubei.googleapis.com', 'youtube.googleapis.com',
      'youtubekids.com', 'yt.be',
      // Google Video CDN nodes used by YouTube
      'video.google.com',
    ],
    keywords: ['youtube', 'googlevideo'],   // CDN поддомены непредсказуемы
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
      // RoscomVPN additions: WebK, Telegram fragments, CDN2
      'web.telegram.org', 'telegram.dog',
      'cdn1.telegram.org', 'cdn2.telegram.org',
    ],
    // Telegram IP-диапазоны — DPI режет именно по IP
    // Source: https://core.telegram.org/resources/cidr.txt (May 2026)
    ipCidrs: [
      // Primary Telegram DC subnets (from core.telegram.org/resources/cidr.txt)
      '91.108.4.0/22',   // DC1-MTProto
      '91.108.8.0/22',   // DC2-MTProto
      '91.108.12.0/22',  // DC2-Media (was missing — causes media/calls to fail)
      '91.108.16.0/22',  // DC3-MTProto (was missing)
      '91.108.36.0/22',  // DC4 (was missing)
      '91.108.56.0/22',  // DC5-MTProto
      '149.154.160.0/20', // Legacy /20 block (covers 160-175)
      '149.154.164.0/22', // DC4-MTProto (explicit)
      // RoscomVPN additional ranges
      '185.76.144.0/22', // Telegram CDN (was missing)
      // IPv6 — use IP-CIDR6 rule (handled in buildRulesFromServices)
      '2001:b28:f23d::/48',
      '2001:b28:f23f::/48',
      '2001:67c:4e8::/48',
      '2001:67c:4e8:f003::/64',
    ],
    keywords: ['telegram'],  // keyword fallback for subdomains not listed above
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
      // RoscomVPN additions: WhatsApp Business, graph API
      'whatsapp.business',
      'graph.facebook.com',
      'connect.facebook.net',
    ],
    defaultOn: true,
  ),

  // ── Выключены по умолчанию ───────────────────────────────────────────────
  RussiaService(
    id: 'instagram',
    name: 'Instagram',
    emoji: '📸',
    domains: [
      'instagram.com', 'cdninstagram.com',
      'www.instagram.com', 'i.instagram.com',
      'graph.instagram.com',
      // Threads (Instagram's Twitter alternative)
      'threads.net',
      // Meta/Facebook CDN — required for Instagram media (stories, reels, photos)
      // Same infrastructure as WhatsApp; without these, media loads blank
      'fbcdn.net', 'fbsbx.com',
      'facebook.com', 'fb.com',
      'connect.facebook.net',
    ],
    keywords: ['cdninstagram', 'fbcdn'],
    defaultOn: false,
  ),
  RussiaService(
    id: 'twitter',
    name: 'X (Twitter)',
    emoji: '🐦',
    domains: ['twitter.com', 'x.com', 't.co', 'twimg.com', 'abs.twimg.com',
        'video.twimg.com', 'pbs.twimg.com'],
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

  // ── 1. Service proxy rules (MUST come first) ────────────────────────────────
  for (final svc in russiaServices) {
    final isOn = serviceStates[svc.id] ?? svc.defaultOn;
    if (!isOn) continue;

    // IP-CIDR правила первыми (приоритет над доменными)
    // IPv6 CIDRs (contain ':') require IP-CIDR6 rule type in Mihomo
    for (final cidr in svc.ipCidrs) {
      final ruleType = cidr.contains(':') ? 'IP-CIDR6' : 'IP-CIDR';
      rules.add('$ruleType,$cidr,PROXY,no-resolve');
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

  // ── 2. Российские ресурсы — всегда напрямую ─────────────────────────────────
  rules.addAll([
    'GEOIP,RU,DIRECT',
    'DOMAIN-SUFFIX,ru,DIRECT',
    'DOMAIN-SUFFIX,xn--p1ai,DIRECT',
    'DOMAIN-SUFFIX,su,DIRECT',
  ]);

  // ── 3. Блокировка QUIC/HTTP3 через UDP:443 — ПОСЛЕ сервисных правил ─────────
  // Размещаем здесь: сначала явные proxy-правила срабатывают по домену/IP,
  // затем для остального UDP:443 — REJECT (форсируем TCP для прокси).
  // Если поставить выше — QUIC-трафик Telegram/YouTube будет заблокирован
  // до того как сервисные правила его перехватят.
  rules.add('DST-PORT,443,REJECT,udp');

  // ── 4. MATCH,DIRECT — всегда последним ──────────────────────────────────────
  // 95% трафика идёт напрямую. DPI видит обычного пользователя.
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
