import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/config.dart';
import 'package:flclashx/providers/providers.dart';
import 'package:flclashx/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Сервисы ──────────────────────────────────────────────────────────────────
// Каждый сервис имеет имя, список доменов и флаг включения по умолчанию.
class RussiaService {
  final String id;
  final String name;
  final String emoji;
  final List<String> domains;
  final bool defaultOn; // true = через VPN, false = DIRECT

  const RussiaService({
    required this.id,
    required this.name,
    required this.emoji,
    required this.domains,
    required this.defaultOn,
  });
}

const russiaServices = [
  // ── По умолчанию через VPN ──────────────────────────────────────────────
  RussiaService(
    id: 'youtube',
    name: 'YouTube',
    emoji: '▶️',
    domains: ['youtube.com', 'youtu.be', 'googlevideo.com', 'ytimg.com',
              'yt3.ggpht.com', 'googleapis.com'],
    defaultOn: true,
  ),
  RussiaService(
    id: 'telegram',
    name: 'Telegram',
    emoji: '✈️',
    domains: ['telegram.org', 't.me', 'telegram.me',
              'core.telegram.org', 'cdn.telegram.org'],
    defaultOn: true,
  ),
  RussiaService(
    id: 'whatsapp',
    name: 'WhatsApp',
    emoji: '💬',
    domains: ['whatsapp.com', 'whatsapp.net', 'wa.me'],
    defaultOn: true,
  ),
  // ── Выключены по умолчанию (можно включить) ─────────────────────────────
  RussiaService(
    id: 'instagram',
    name: 'Instagram',
    emoji: '📸',
    domains: ['instagram.com', 'cdninstagram.com', 'fbcdn.net'],
    defaultOn: false,
  ),
  RussiaService(
    id: 'facebook',
    name: 'Facebook',
    emoji: '👤',
    domains: ['facebook.com', 'fb.com', 'fbcdn.net', 'fbsbx.com'],
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
    domains: ['tiktok.com', 'tiktokcdn.com', 'muscdn.com', 'byteoversea.com'],
    defaultOn: false,
  ),
  RussiaService(
    id: 'discord',
    name: 'Discord',
    emoji: '🎮',
    domains: ['discord.com', 'discord.gg', 'discordapp.com', 'discordapp.net',
              'discord.media'],
    defaultOn: false,
  ),
  RussiaService(
    id: 'spotify',
    name: 'Spotify',
    emoji: '🎧',
    domains: ['spotify.com', 'scdn.co', 'spotifycdn.com', 'byspotify.com'],
    defaultOn: false,
  ),
  RussiaService(
    id: 'openai',
    name: 'ChatGPT / OpenAI',
    emoji: '🤖',
    domains: ['openai.com', 'chatgpt.com', 'oaistatic.com', 'oaiusercontent.com',
              'auth0.openai.com', 'browser.pipe.aria.microsoft.com'],
    defaultOn: false,
  ),
  RussiaService(
    id: 'github',
    name: 'GitHub',
    emoji: '🐙',
    domains: ['github.com', 'githubusercontent.com', 'github.io', 'githubassets.com',
              'ghcr.io'],
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

// ─── DNS конфигурация ─────────────────────────────────────────────────────────
const _presetDns = Dns(
  enable: true,
  preferH3: false,
  useHosts: false,
  useSystemHosts: false,
  respectRules: false,
  ipv6: false,
  defaultNameserver: ['8.8.8.8', '1.1.1.1'],
  enhancedMode: DnsMode.fakeIp,
  fakeIpRange: '198.18.0.1/16',
  fakeIpFilter: [],
  nameserverPolicy: {},
  nameserver: ['https://8.8.8.8/dns-query', 'https://1.1.1.1/dns-query'],
  fallback: ['8.8.4.4', '1.0.0.1'],
  proxyServerNameserver: ['https://1.1.1.1/dns-query'],
  fallbackFilter: FallbackFilter(
    geoip: false,
    geoipCode: 'RU',
    geosite: [],
    ipcidr: ['240.0.0.0/4'],
    domain: [],
  ),
);

const _presetTun = Tun(
  enable: true,
  stack: TunStack.gvisor,
  dnsHijack: ['any:53'],
  autoRoute: false,
);

// ─── Построение правил из списка сервисов ────────────────────────────────────
List<String> buildRulesFromServices(Map<String, bool> serviceStates) {
  final rules = <String>[];

  // Правила для включённых сервисов (через VPN)
  for (final svc in russiaServices) {
    final isOn = serviceStates[svc.id] ?? svc.defaultOn;
    if (isOn) {
      for (final domain in svc.domains) {
        rules.add('DOMAIN-SUFFIX,$domain,PROXY');
      }
    }
  }

  // Российские ресурсы всегда напрямую
  rules.addAll([
    'GEOIP,RU,DIRECT',
    'DOMAIN-SUFFIX,ru,DIRECT',
    'DOMAIN-SUFFIX,xn--p1ai,DIRECT',
    'DOMAIN-SUFFIX,su,DIRECT',
  ]);

  // Всё остальное — через VPN (безопасный дефолт для обхода блокировок)
  rules.add('MATCH,PROXY');

  return rules;
}

// ─── Применить пресет к текущему профилю ────────────────────────────────────
void applyRussia2026Preset(WidgetRef ref, {Map<String, bool>? serviceStates}) {
  // DNS + TUN настройки
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

  // Применяем правила через overrideData профиля
  final currentId = ref.read(currentProfileIdProvider);
  if (currentId == null) return;

  final states = serviceStates ?? {
    for (final s in russiaServices) s.id: s.defaultOn,
  };
  final ruleStrings = buildRulesFromServices(states);
  final rules = ruleStrings
      .map((r) => Rule.value(r))
      .toList();

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

  // Применяем изменения
  globalState.appController.applyProfileDebounce(silence: true);
}
