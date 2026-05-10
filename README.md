<div align="center">

<h1>🚀 RAKETA</h1>

<p><strong>Свободный VPN для Android со смарт-маршрутизацией</strong></p>

<p>
  <a href="https://github.com/svetlohub/FlClashR/releases">
    <img src="https://img.shields.io/github/v/release/svetlohub/FlClashR?style=flat-square&color=00703C" alt="Release" />
  </a>
  <img src="https://img.shields.io/badge/Android-6.0%2B-00ADEE?style=flat-square" />
  <img src="https://img.shields.io/badge/license-GPL--3.0-42E3B4?style=flat-square" />
</p>

</div>

---

Только нужный трафик идёт через VPN. Всё остальное — напрямую. Банки, госсайты и стриминг работают без замедлений.

## Что включено по умолчанию

| Сервис | Через VPN | Почему |
|---|:---:|---|
| YouTube | ✅ | Замедление с 2024 |
| Telegram | ✅ | IP-блокировки + DPI |
| WhatsApp | ✅ | Периодические помехи |
| Instagram | ⬜ | Можно включить в настройках |
| X (Twitter) | ⬜ | Можно включить |
| TikTok | ⬜ | Можно включить |
| Discord | ⬜ | Можно включить |
| ChatGPT | ⬜ | Можно включить |
| Spotify | ⬜ | Можно включить |

Остальное — всегда **напрямую** (банки, Госуслуги, российские сайты).

## Установка

1. Скачайте APK из [Releases](https://github.com/svetlohub/FlClashR/releases)
2. Разрешите установку из неизвестных источников
3. Откройте приложение → нажмите **Импорт** → вставьте ссылку на подписку
4. Нажмите большую кнопку — VPN подключится и сам выберет быстрейший сервер

Поддерживаемые форматы: Clash YAML, Base64, `vmess://`, `vless://`, `ss://`, `trojan://`, `hysteria2://`

## Сборка из исходников

```bash
git clone https://github.com/svetlohub/FlClashR.git
cd FlClashR
flutter pub get
dart setup.dart android --out core   # собирает Go-ядро
flutter build apk --release
```

Требования: Flutter 3.32+, Go 1.22+, Java 17, NDK 27.0.12077973

## Архитектура

```
Flutter UI (Dart + Riverpod)
    ↓ FFI
Mihomo/Clash Go Core (libclash.so)
    ↓ TUN
Android VpnService (Kotlin)
```

## Лицензия

GPL-3.0 — подробности в [LICENSE](LICENSE)

---

<div align="center">
<sub>Форк <a href="https://github.com/chen08209/FlClash">FlClashX</a> · Ядро <a href="https://github.com/MetaCubeX/mihomo">Mihomo</a> · Правила <a href="https://github.com/roscomvpn">RoscomVPN</a></sub>
</div>
