# meshpad (Flutter app)

Точка входа UI. Зависит от `meshpad_core`, `meshpad_p2p`.

## Запуск

```powershell
flutter pub get
flutter run -d windows
flutter test
```

Из корня monorepo: `.\dev.ps1` или `.\scripts\run.ps1`

## Платформы

| Платформа | Режим |
|-----------|--------|
| Windows / Linux / Android | Local-first + LAN sync (+ Git на desktop) |

Web-режим (`kIsWeb`) и `meshpad_api_client` остаются в репозитории для разработки, но **не** входят в поддерживаемые платформы — см. [docs/PLATFORMS.md](../../docs/PLATFORMS.md).

## Ключевые экраны

- **Лента** — `lib/features/feed/`
- **Шапка** — sync, Git, поиск, устройства, настройки, корзина
- **Устройства** — PIN-pairing, mDNS discovery
- **Настройки** — данные, Git sync, автосинхронизация

Подробности — [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md).
