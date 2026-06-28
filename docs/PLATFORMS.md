# Поддерживаемые платформы

MeshPad **официально поддерживает** только следующие клиентские платформы:

| Платформа | Сборка / CI | Примечания |
|-----------|-------------|------------|
| **Windows** | `flutter build windows`; CI `build-windows` + Build Release (zip + Inno Setup) | Tray, hotkeys, drag-and-drop |
| **Android** | `flutter build apk`; CI Build Release (APK) | WorkManager background sync, QR pairing |
| **Linux (Ubuntu)** | `flutter build linux`; CI `build-linux` | Tray, drag-and-drop; зависимости: GTK, clang (см. [DEVELOPMENT.md](DEVELOPMENT.md)) |

## Вне scope (не поддерживаются)

| Платформа | Статус |
|-----------|--------|
| **iOS** | Не планируется; каталог `ios/` удалён |
| **macOS** | Не планируется; каталог `macos/` удалён |
| **Web** (браузерный клиент) | Не поддерживается как продуктовая платформа |

Код `meshpad_server` и Web-режим в репозитории могут оставаться для разработки/экспериментов, но **не входят** в список поддерживаемых платформ приложения.

## Sync

На всех поддерживаемых платформах production sync — **LAN** (mDNS/UDP/HTTP/HTTPS). См. [ARCHITECTURE.md](ARCHITECTURE.md), [SYNC_WIRE.md](SYNC_WIRE.md).
