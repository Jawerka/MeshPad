# MeshPad

Local-first Markdown-блокнот в формате чат-ленты с синхронизацией между **доверенными** устройствами в локальной сети (LAN).

**Статус:** релиз **0.2.0** — MVP 0.1.0 + post-MVP (LAN security/TLS, надёжный sync, Web SSE, macOS, теги, экспорт/импорт, темы, ru/en i18n). Дорожная карта §12 в [PLAN.md](PLAN.md) **закрыта**; дальнейшие задачи — §13 бэклог.

**Production sync:** только **LAN** (mDNS + UDP + HTTP/HTTPS, PIN-pairing). libp2p — scaffold и sidecar; переключатель в настройках **скрыт** до Rust push/pull (B.2). См. [docs/LIBP2P.md](docs/LIBP2P.md).

| Платформа | Клиент | Sync |
|-----------|--------|------|
| Android, Windows, Linux, macOS | Flutter (`apps/meshpad`) | LAN P2P |
| Web | Thin client → `meshpad_server` | через headless `--p2p` (не в браузере) |

## Документация

| Документ | Содержание |
|----------|------------|
| [PLAN.md](PLAN.md) | Продукт, реализованное MVP (§5), итог §6, бэклог §13 |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Установка, запуск, API, чеклист, troubleshooting |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Слои, потоки данных, LAN sync, Web server |
| [docs/SYNC_WIRE.md](docs/SYNC_WIRE.md) | Wire format catalog/push/pull (LAN и будущий libp2p) |
| [docs/LIBP2P.md](docs/LIBP2P.md) | libp2p Phase B: sidecar, factory, feature flag |
| [CHANGELOG.md](CHANGELOG.md) | История релизов |

> **Источник истины по поведению** — код и [PLAN.md §5](PLAN.md#5-реализованное-mvp-010). HTML-референс `ref/` и ранние черновики могут расходиться с приложением.

## Быстрый старт

```powershell
cd MeshPad
.\scripts\setup.ps1
.\scripts\bootstrap.ps1
.\scripts\run.ps1 -Device windows
```

| Цель | Команда |
|------|---------|
| Android | `.\scripts\launch-emulator.ps1` → `.\scripts\run.ps1 -Device android` |
| macOS | `cd apps/meshpad && flutter run -d macos` (на Mac) |
| Web | `.\scripts\run-web.ps1` (сервер + Chrome) |
| Win + Android | `.\scripts\run.ps1 -Device dual` |

Проверка: `dart run melos run check`

## Релизы (CI/CD)

GitHub Actions собирает **APK** и **Windows zip** (`meshpad.exe` + runtime):

```powershell
git tag v0.2.0
git push origin v0.2.0
```

Подробности: [docs/DEVELOPMENT.md § CI/CD](docs/DEVELOPMENT.md#ci--cd).

## UI-референс

Каталог `ref/` — HTML/CSS прототип. **Sidebar из ref не реализован**; навигация только через шапку.
