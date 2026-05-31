# MeshPad

Локальный Markdown-блокнот в виде чат-ленты с синхронизацией между доверенными устройствами в локальной сети.

**Статус:** MVP **0.1.0** — рабочее приложение на Android, Windows, Linux и Web (через headless-сервер).

## Документация

| Документ | Содержание |
|----------|------------|
| [PLAN.md](PLAN.md) | Продукт, **реализованное MVP**, план post-MVP |
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Установка, запуск, API, чеклист |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Слои, потоки данных, sync |
| [CHANGELOG.md](CHANGELOG.md) | История релизов |

> **Источник истины по поведению приложения** — код и раздел «Реализованное MVP» в PLAN.md. HTML-референс `ref/` и ранние черновики плана могут расходиться с фактической реализацией.

## Быстрый старт

```powershell
cd MeshPad
.\scripts\setup.ps1
.\scripts\bootstrap.ps1
.\scripts\run.ps1 -Device windows
```

Android: `.\scripts\launch-emulator.ps1` → `.\scripts\run.ps1 -Device android`  
Web: `.\scripts\run-web.ps1` (сервер + Chrome)

Проверка: `dart run melos run check`

## UI-референс

Каталог `ref/` — HTML/CSS прототип. **Sidebar из ref не реализован**; навигация только через шапку.
