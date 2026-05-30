# MeshPad

Локальный Markdown-блокнот в виде чат-ленты с P2P-синхронизацией между доверенными устройствами.

## Документация

- [PLAN.md](PLAN.md) — продукт, MVP, этапы, тесты
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) — установка и команды
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — слои и потоки данных

## UI-референс

Каталог `ref/` — HTML/CSS прототип чат-интерфейса (тёмная тема).

## Быстрый старт

```powershell
git clone <url> MeshPad   # или cd в существующий клон
cd MeshPad
.\scripts\setup.ps1
.\scripts\bootstrap.ps1
cd apps\meshpad
flutter run -d windows
```

Эмулятор Android: `.\scripts\launch-emulator.ps1` → `flutter run`.

## Статус

Инфраструктура репозитория и план готовы; приложение создаётся скриптом `bootstrap.ps1` после установки Flutter.
