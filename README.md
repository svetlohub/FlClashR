<div align="center">

<h1>
  FlClashR
</h1>

<p><strong>Свободный, открытый VPN-клиент для Android со смарт-маршрутизацией</strong></p>
<p><em>A free, open-source VPN client for Android with smart routing.</em></p>

<p>
  <a href="https://github.com/your-org/FlClashR/actions">
    <img src="https://img.shields.io/github/actions/workflow/status/your-org/FlClashR/build.yml?style=flat-square&label=build" alt="Build Status" />
  </a>
  <a href="https://github.com/your-org/FlClashR/releases">
    <img src="https://img.shields.io/github/v/release/your-org/FlClashR?style=flat-square&color=00703C" alt="Release" />
  </a>
  <img src="https://img.shields.io/badge/platform-Android%206%2B-00ADEE?style=flat-square" alt="Platform: Android 6+" />
  <img src="https://img.shields.io/badge/flutter-3.32%2B-A0E720?style=flat-square" alt="Flutter 3.32+" />
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-GPL--3.0-42E3B4?style=flat-square" alt="GPL-3.0" />
  </a>
</p>

<hr/>

</div>

## ✨ Возможности / Features

| Функция | Описание |
|---|---|
| 📥 **Импорт подписок** | Поддержка Clash YAML, Base64, VMess/VLess/SS/Trojan URI |
| 🌍 **Авто-выбор сервера** | Пинг всех прокси при запуске, автоматически подключается к самому быстрому |
| 🔄 **Авто-обновление** | Фоновое обновление подписки раз в 24 часа |
| 🇷🇺 **Россия-пресет** | Умная маршрутизация: Telegram, YouTube, WhatsApp, Instagram — через VPN; остальное — напрямую |
| 🚫 **QUIC-блокировка** | Форсирует TCP для прокси-трафика (QUIC/HTTP3 режется на UDP:443) |
| 🌙 **Тёмная / светлая тема** | Авто-следует настройке устройства, кастомная палитра (Emerald, Spring, Sky, Arctic) |
| 🔋 **Экономия батареи** | Маршрутизирует только нужный трафик; 95% соединений идут напрямую |
| 🔔 **Уведомление** | "Интернет сейчас свободнее" с кнопками **Отключить** и **Переподключить** |

---

## 🚀 Быстрый старт / Quick Start

### Установить APK (Release)

1. Скачайте последний APK из [Releases](https://github.com/your-org/FlClashR/releases).
2. Разрешите установку из неизвестных источников в настройках Android.
3. Установите APK, откройте приложение.
4. Нажмите **«Импорт»** и вставьте ссылку на подписку (Clash YAML URL или URI).
5. Нажмите большую кнопку — VPN запустится и выберет быстрейший сервер автоматически.

### Собрать из исходников / Build from Source

**Требования:**
- Flutter ≥ 3.32.0
- Android NDK 27.0.12077973
- Java 17
- Go 1.22+ (для пересборки `libclash.so`, опционально)

```bash
# 1. Клонировать
git clone https://github.com/your-org/FlClashR.git
cd FlClashR

# 2. Зависимости
flutter pub get

# 3. Собрать APK
flutter build apk --release

# 4. Установить на устройство
adb install build/app/outputs/flutter-apk/app-release.apk
```

> **Примечание:** `libclash.so` включён в репозиторий предсобранным. Если вы меняете Go-ядро (`core/`), пересоберите `.so` командой `make android` и скопируйте в `android/app/src/main/jniLibs/`.

---

## ⚙️ Настройка / Configuration

### Форматы подписок

FlClashR поддерживает несколько форматов:

- **Clash YAML** — прямой URL на файл конфигурации
- **Base64-список** — стандартный формат большинства платных VPN-сервисов
- **Одиночные URI** — `vmess://...`, `vless://...`, `ss://...`, `trojan://...`, `hysteria2://...`

---

## 🏗 Архитектура / Architecture

```
┌─────────────────────────────────┐
│       Flutter UI (Dart)         │
│  SimpleHomeView, SettingsView   │
│  Riverpod providers             │
└──────────┬──────────────────────┘
           │ FFI (lib/clash/lib.dart)
           ▼
┌─────────────────────────────────┐
│    Clash/Mihomo Go Core         │
│  libclash.so (prebuilt)         │
│  core/*.go — DO NOT MODIFY      │
└──────────┬──────────────────────┘
           │ TUN fd via VpnService
           ▼
┌─────────────────────────────────┐
│   Android VpnService (Kotlin)   │
│  FlClashXVpnService             │
│  VpnPlugin, ServicePlugin       │
└─────────────────────────────────┘
```

**Ключевые принципы:**
- FFI вызовы только через `_MainFFIHandler` в главном движке
- Сервисный изолят (`_service()`) минимален — никакого FFI
- Порядок правил: специфичные → QUIC-блок → `MATCH,DIRECT` (всегда последним)
- Авто-выбор сервера: batch ping 20 прокси, fallback при таймауте 7с

---

## 🤝 Участие / Contributing

1. Форкните репозиторий
2. Создайте ветку: `git checkout -b feature/my-feature`
3. Прочитайте `.claude/RULES.md` — там описаны критические ограничения архитектуры
4. Сделайте коммит: `git commit -m 'feat: my feature'`
5. Пуш: `git push origin feature/my-feature`
6. Откройте Pull Request

**Важно:** Не трогайте `core/*.go`, `lib/main.dart _service()`, `lib/clash/lib.dart` FFI-архитектуру без обсуждения в issue.

---

## 📄 Лицензия / License

Распространяется под лицензией **GNU GPL v3**. Подробности в файле [LICENSE](LICENSE).

---

## 🙏 Благодарности / Credits

- **[FlClashX](https://github.com/chen08209/FlClash)** — оригинальный Flutter Clash клиент
- **[Mihomo (Clash Meta)](https://github.com/MetaCubeX/mihomo)** — Go VPN ядро
- **[RoscomVPN](https://github.com/roscomvpn)** — правила маршрутизации для российских блокировок
- Сообщество разработчиков open-source VPN-инструментов

---

<div align="center">

Made with ❤️ for free internet

<sub>FlClashR — потому что свободный интернет должен быть у каждого</sub>

</div>
