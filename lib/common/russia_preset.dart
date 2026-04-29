import 'package:flclashx/enum/enum.dart';
import 'package:flclashx/models/models.dart';
import 'package:flclashx/providers/config.dart';
import 'package:flclashx/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _russia2026Dns = Dns(
  enable: true,
  preferH3: false,
  useHosts: true,
  useSystemHosts: false,
  respectRules: true,
  ipv6: false,

  defaultNameserver: [
    '1.1.1.1',
    '8.8.8.8',
  ],

  enhancedMode: DnsMode.fakeIp,
  fakeIpRange: '198.18.0.1/16',

  fakeIpFilter: [
    '*.lan',
    '*.local',
    'localhost.ptlogin2.qq.com',
    '+.msftconnecttest.com',
    '+.msftncsi.com',
    'time.*.com',
    'time.*.gov',
    'time.*.edu.cn',
    'time.*.apple.com',
    'time-ios.apple.com',
    'time1.*.com',
    'time2.*.com',
    'time3.*.com',
    'time4.*.com',
    'time5.*.com',
    'time6.*.com',
    'time7.*.com',
    'ntp.*.com',
    'ntp1.*.com',
    'ntp2.*.com',
    'ntp3.*.com',
    'ntp4.*.com',
    'ntp5.*.com',
    'ntp6.*.com',
    'ntp7.*.com',
  ],

  nameserverPolicy: {
    'geosite:private': 'system',
    'geosite:ru': 'system',
    '+.ru': 'system',
    '+.xn--p1ai': 'system',
    '+.su': 'system',
  },

  nameserver: [
    'https://1.1.1.1/dns-query',
    'https://8.8.8.8/dns-query',
    'tls://1.1.1.1:853',
  ],

  fallback: [
    'https://1.0.0.1/dns-query',
    'tls://8.8.4.4:853',
  ],

  proxyServerNameserver: [
    'https://1.1.1.1/dns-query',
    'https://8.8.8.8/dns-query',
  ],

  fallbackFilter: FallbackFilter(
    geoip: false,
    geoipCode: '',
    geosite: [],
    ipcidr: [
      '240.0.0.0/4',
    ],
    domain: [],
  ),
);

const _russia2026Tun = Tun(
  enable: true,
  stack: TunStack.gvisor,
  dnsHijack: [
    'any:53',
  ],
);

const _russia2026Rules = [
  // Anti-QUIC: YouTube/Google often use UDP/443.
  // Rejecting it forces TCP/TLS path, which is usually more stable for proxy routing.
  'DST-PORT,443,REJECT,udp',

  // -------------------------
  // Telegram -> Proxy
  // -------------------------
  'DOMAIN-SUFFIX,t.me,Proxy',
  'DOMAIN-SUFFIX,telegram.org,Proxy',
  'DOMAIN-SUFFIX,telegram.me,Proxy',
  'DOMAIN-SUFFIX,telegram.dog,Proxy',
  'DOMAIN-SUFFIX,telegram.space,Proxy',
  'DOMAIN-SUFFIX,tdesktop.com,Proxy',
  'DOMAIN-SUFFIX,telegra.ph,Proxy',
  'DOMAIN-SUFFIX,legra.ph,Proxy',
  'DOMAIN-SUFFIX,graph.org,Proxy',
  'DOMAIN-SUFFIX,cdn-telegram.org,Proxy',
  'DOMAIN-SUFFIX,telesco.pe,Proxy',
  'DOMAIN-SUFFIX,tg.dev,Proxy',
  'DOMAIN-KEYWORD,telegram,Proxy',

  'IP-CIDR,5.28.195.1/32,Proxy,no-resolve',
  'IP-CIDR,5.28.195.2/32,Proxy,no-resolve',
  'IP-CIDR,91.105.192.0/23,Proxy,no-resolve',
  'IP-CIDR,91.108.4.0/22,Proxy,no-resolve',
  'IP-CIDR,91.108.8.0/21,Proxy,no-resolve',
  'IP-CIDR,91.108.16.0/21,Proxy,no-resolve',
  'IP-CIDR,91.108.56.0/22,Proxy,no-resolve',
  'IP-CIDR,95.161.64.0/20,Proxy,no-resolve',
  'IP-CIDR,149.154.160.0/20,Proxy,no-resolve',

  // -------------------------
  // WhatsApp -> Proxy
  // -------------------------
  'DOMAIN-SUFFIX,whatsapp.com,Proxy',
  'DOMAIN-SUFFIX,whatsapp.net,Proxy',
  'DOMAIN-SUFFIX,wa.me,Proxy',
  'DOMAIN-SUFFIX,whatsapp-plus.info,Proxy',
  'DOMAIN-SUFFIX,whatsappbrand.com,Proxy',

  // WhatsApp depends on Meta CDN/edge infrastructure.
  'DOMAIN-SUFFIX,fbsbx.com,Proxy',
  'DOMAIN-SUFFIX,fbcdn.net,Proxy',
  'DOMAIN-SUFFIX,facebook.net,Proxy',

  // -------------------------
  // YouTube -> Proxy
  // -------------------------
  'DOMAIN-SUFFIX,youtube.com,Proxy',
  'DOMAIN-SUFFIX,www.youtube.com,Proxy',
  'DOMAIN-SUFFIX,m.youtube.com,Proxy',
  'DOMAIN-SUFFIX,music.youtube.com,Proxy',
  'DOMAIN-SUFFIX,youtu.be,Proxy',
  'DOMAIN-SUFFIX,yt.be,Proxy',
  'DOMAIN-SUFFIX,ytimg.com,Proxy',
  'DOMAIN-SUFFIX,googlevideo.com,Proxy',
  'DOMAIN-SUFFIX,youtubei.googleapis.com,Proxy',
  'DOMAIN-SUFFIX,yt3.ggpht.com,Proxy',
  'DOMAIN-KEYWORD,youtube,Proxy',
  'DOMAIN-KEYWORD,googlevideo,Proxy',
  'DOMAIN-KEYWORD,ytimg,Proxy',

  // -------------------------
  // Local / private -> Direct
  // -------------------------
  'DOMAIN-SUFFIX,local,DIRECT',
  'DOMAIN-SUFFIX,lan,DIRECT',
  'IP-CIDR,10.0.0.0/8,DIRECT,no-resolve',
  'IP-CIDR,172.16.0.0/12,DIRECT,no-resolve',
  'IP-CIDR,192.168.0.0/16,DIRECT,no-resolve',
  'IP-CIDR,127.0.0.0/8,DIRECT,no-resolve',
  'IP-CIDR,169.254.0.0/16,DIRECT,no-resolve',
  'IP-CIDR,224.0.0.0/4,DIRECT,no-resolve',

  // -------------------------
  // Russia / domestic -> Direct
  // -------------------------
  'GEOSITE,private,DIRECT',
  'GEOSITE,ru,DIRECT',
  'GEOIP,private,DIRECT,no-resolve',
  'GEOIP,ru,DIRECT,no-resolve',

  'DOMAIN-SUFFIX,ru,DIRECT',
  'DOMAIN-SUFFIX,xn--p1ai,DIRECT',
  'DOMAIN-SUFFIX,su,DIRECT',

  // -------------------------
  // Everything else -> Direct
  // This is the key stealth change.
  // -------------------------
  'MATCH,DIRECT',
];

void applyRussia2026Preset(WidgetRef ref) {
  ref.read(patchClashConfigProvider.notifier).updateState(
    (state) => state.copyWith(
      dns: _russia2026Dns,
      tun: _russia2026Tun,
      mode: Mode.rule,
      allowLan: false,
      logLevel: LogLevel.warning,
      ipv6: false,
      unifiedDelay: true,

      // Keep false for less aggressive connection behavior.
      tcpConcurrent: false,
    ),
  );

  ref.read(overrideDnsProvider.notifier).value = true;

  ref.read(vpnSettingProvider.notifier).updateState(
    (state) => state.copyWith(
      enable: true,
      systemProxy: false,
      ipv6: false,

      // Important for Android: allow apps/system to bypass when rules say DIRECT.
      allowBypass: true,
    ),
  );

  ref.read(networkSettingProvider.notifier).updateState(
    (state) => state.copyWith(
      systemProxy: false,
    ),
  );
}
