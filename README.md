# MeshPad

[![Build Release](https://github.com/Jawerka/MeshPad/actions/workflows/build-release.yml/badge.svg)](https://github.com/Jawerka/MeshPad/actions/workflows/build-release.yml)

Local-first Markdown-блокнот в формате chat-ленты с синхронизацией между **доверенными** устройствами.

**Статус:** MeshPad **1.0** — LAN sync + опциональный Git ([ADR 0003](docs/ADR/0003-simplicity-lan-git.md)).

## Синхронизация

| Канал | Роль |
|-------|------|
| **LAN** (mDNS + UDP + HTTP/HTTPS, PIN-pairing) | Основной, автоматический |
| **Git** (GitHub, приватный repo) | Вторичный, ручной (desktop) |

Подробнее: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/GIT_SYNC.md](docs/GIT_SYNC.md).

## Поддерживаемые платформы

| Платформа | Клиент | Sync |
|-----------|--------|------|
| **Windows** | Flutter (`apps/meshpad`) | LAN + Git |
| **Android** | Flutter (`apps/meshpad`) | LAN |
| **Linux (Ubuntu)** | Flutter (`apps/meshpad`) | LAN + Git (CI compile) |
| **Linux (Hub)** | Headless AOT (`apps/meshpad_server --hub`) | LAN store-and-forward |

**Не поддерживаются:** iOS, macOS, Web-браузер. См. [docs/PLATFORMS.md](docs/PLATFORMS.md).

## Сервер / LAN Hub

Опциональный **headless peer** для постоянной синхронизации в сети (store-and-forward): телефоны и ПК подключаются к хабу в разное время, хаб хранит копии заметок на диске.

| Компонент | Путь / команда |
|-----------|----------------|
| Приложение | `apps/meshpad_server` — `dart run bin/meshpad_server.dart --hub` |
| Документация | [docs/HUB.md](docs/HUB.md) |
| Установка Ubuntu | `scripts/install-hub-ubuntu.sh` |
| Деплой на сервер | `.\scripts\deploy-hub.ps1` |
| CI | GitHub Release → артефакт `meshpad-hub-<version>-linux-x64` |
| Локальная сборка AOT | `dart run melos run build:hub` |

Порты: **8787** (веб PIN/QR), **45838** (sync), **45837/udp** (discovery). Хаб использует тот же LAN-протокол, что и клиенты ([docs/SYNC_WIRE.md](docs/SYNC_WIRE.md)).

## Документация

| Документ | Содержание |
|----------|------------|
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Установка, запуск, тесты, troubleshooting |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Слои, потоки данных |
| [docs/SYNC_WIRE.md](docs/SYNC_WIRE.md) | Wire format LAN |
| [docs/GIT_SYNC.md](docs/GIT_SYNC.md) | Git sync (GitHub OAuth) |
| [docs/DATA_LAYOUT.md](docs/DATA_LAYOUT.md) | Файловая структура данных |
| [docs/SECURITY.md](docs/SECURITY.md) | Threat model |
| [docs/PLATFORMS.md](docs/PLATFORMS.md) | Платформы |
| [docs/ADR/](docs/ADR/) | Architecture Decision Records |
| [CHANGELOG.md](CHANGELOG.md) | История релизов |

> **Источник истины по поведению** — код и [CHANGELOG.md](CHANGELOG.md).

## Быстрый старт

```powershell
cd MeshPad
.\scripts\setup.ps1      # один раз: Flutter + melos
.\scripts\bootstrap.ps1  # один раз: зависимости
.\dev.ps1                # запуск на Windows
.\dev.ps1 -Test          # тестовый прогон (analyze + tests)
```

| Цель | Команда |
|------|---------|
| Запуск (Windows) | `.\dev.ps1` |
| Release (Windows) | `.\dev.ps1 -Release` |
| Тестовый прогон | `.\dev.ps1 -Test` |
| Android | `.\scripts\launch-emulator.ps1` → `.\dev.ps1 -Device android` |
| Win + Android (LAN) | `.\dev.ps1 -Device dual` |

Проверка как в CI: `.\dev.ps1 -Test` или `dart run melos run check`

## Релизы (CI/CD)

GitHub Actions на тег `v*`:

| Артефакт | Job |
|----------|-----|
| Android APK | `build-android` |
| Windows zip + Inno Setup | `build-windows` |
| Linux hub AOT | `build-hub-linux` |
| Linux Flutter compile | `build-linux` (compile-only) |

```powershell
git tag v0.2.0
git push origin v0.2.0
```

См. [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) — CI/CD и release checklist.
