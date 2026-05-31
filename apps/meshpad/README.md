# meshpad (Flutter app)

Точка входа UI. Зависит от `meshpad_core`, `meshpad_p2p`, `meshpad_api_client` (Web).

## Запуск

```powershell
flutter pub get
flutter run -d windows
flutter test
```

Из корня monorepo: `.\scripts\run.ps1`

## Режимы

| Платформа | Режим |
|-----------|--------|
| Windows / Linux / Android | Local-first + LAN sync |
| Web (`kIsWeb`) | Thin client → `meshpad_server` API |

## Ключевые экраны

- **Лента** — `lib/features/feed/`
- **Шапка** — sync, поиск, устройства, настройки, корзина (`feed_screen.dart`)
- **Устройства** — PIN-pairing, mDNS discovery (`devices_sheet.dart`)
- **Настройки** — путь данных, автосинхронизация, rebuild index (`settings_sheet.dart`)

Подробности UX и архитектуры — [PLAN.md](../../PLAN.md), [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md).
