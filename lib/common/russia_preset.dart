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
  defaultNameserver: ['1.1.1.1', '8.8.8.8'],
  enhancedMode: DnsMode.fakeIp,
  fakeIpRange: '198.18.0.1/16',
  fakeIpFilter: [],
  nameserverPolicy: {},
  nameserver: ['https://1.1.1.1/dns-query', 'tls://1.1.1.1:853'],
  fallback: ['tls://8.8.4.4', 'tls://1.1.1.1'],
  proxyServerNameserver: ['https://1.1.1.1/dns-query'],
  fallbackFilter: FallbackFilter(
    geoip: false,
    geoipCode: '',
    geosite: [],
    ipcidr: ['240.0.0.0/4'],
    domain: [],
  ),
);

const _russia2026Tun = Tun(
  enable: true,
  stack: TunStack.gvisor,
  dnsHijack: ['any:53'],
);

const _russia2026Rules = [
  'DST-PORT,443,REJECT,udp',
  'GEOSITE,google,Proxy',
  'DOMAIN-SUFFIX,gosuslugi.ru,DIRECT',
  'DOMAIN-SUFFIX,kremlin.ru,DIRECT',
  'DOMAIN-SUFFIX,government.ru,DIRECT',
  'DOMAIN-SUFFIX,gov.ru,DIRECT',
  'DOMAIN-SUFFIX,vk.com,DIRECT',
  'DOMAIN-SUFFIX,ok.ru,DIRECT',
  'DOMAIN-SUFFIX,mail.ru,DIRECT',
  'DOMAIN-SUFFIX,yandex.ru,DIRECT',
  'DOMAIN-SUFFIX,yandex.com,DIRECT',
  'DOMAIN-SUFFIX,ya.ru,DIRECT',
  'DOMAIN-SUFFIX,dzen.ru,DIRECT',
  'DOMAIN-SUFFIX,sberbank.ru,DIRECT',
  'DOMAIN-SUFFIX,vtb.ru,DIRECT',
  'DOMAIN-SUFFIX,alfabank.ru,DIRECT',
  'DOMAIN-SUFFIX,tbank.ru,DIRECT',
  'DOMAIN-SUFFIX,tinkoff.ru,DIRECT',
  'DOMAIN-SUFFIX,ozon.ru,DIRECT',
  'DOMAIN-SUFFIX,wildberries.ru,DIRECT',
  'DOMAIN-SUFFIX,avito.ru,DIRECT',
  'DOMAIN-SUFFIX,rzd.ru,DIRECT',
  'DOMAIN-SUFFIX,aeroflot.ru,DIRECT',
  'DOMAIN-SUFFIX,rutube.ru,DIRECT',
  'DOMAIN-SUFFIX,kinopoisk.ru,DIRECT',
  'GEOIP,ru,DIRECT',
  'DOMAIN-SUFFIX,ru,DIRECT',
  'DOMAIN-SUFFIX,xn--p1ai,DIRECT',
  'DOMAIN-SUFFIX,su,DIRECT',
  'DOMAIN-KEYWORD,yandex,DIRECT',
  'MATCH,Proxy',
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
}
