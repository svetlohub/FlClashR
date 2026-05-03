# FlClashR — SESSION CONTEXT
Дата: 2026-05-03
Билд: ✅ проходит
VPN: ✅ работает (трафик через прокси, dnsleaktest ок)
Статус: ⚠️ YouTube/Telegram/WhatsApp через VPN — ожидает проверки

## Последние изменения
- stub_fixes.zip: `window.dart`, `windows.dart`, `tray.dart` — убраны dead imports
- controller.dart: setupClashConfig() bypass homeScaffoldKey
- lib.dart: _MainFFIHandler для прямого FFI вместо IPC

## Ключевые сигнатуры
- `ClashLib.sendMessage(String action, [Map?])` → _MainFFIHandler.invokeAction()
- `setupClashConfig()` → `_setupClashConfig()` (прямой вызов)
- `_service()` entrypoint: только initApp(0) + порт + signalServiceReady
- `initNativeApiBridge()`: guarded with `dartApiInitialized` flag

## Файлы НЕ трогать без явного разрешения
- core/lib.go (Go guards)
- core/lib_android.go (nil-guard)
- lib/main.dart (_service entrypoint)

## Что требует проверки
- Проходят ли YouTube/Telegram/WhatsApp через VPN
- Не сломался ли импорт подписки после stub-фиксов
