# Разработка MeshPad

MeshPad **1.0** — LAN sync + опциональный Git. Архитектура: [ARCHITECTURE.md](ARCHITECTURE.md). История изменений: [CHANGELOG.md](../CHANGELOG.md).

**Поддерживаемые платформы:** Windows, Android, Linux (Ubuntu) — [PLATFORMS.md](PLATFORMS.md). iOS, macOS и Web-клиент **не поддерживаются**.

## Требования

| Инструмент | Версия / примечание |
|------------|---------------------|
| Git | 2.x |
| Flutter | stable (см. `.fvmrc`) |
| Dart | идёт с Flutter |
| Android Studio / SDK | для Android |
| Visual Studio 2022+ | Workload **Desktop development with C++** + **C++ ATL** (`atlstr.h` для `flutter_secure_storage_windows`) |
| clang/cmake | для `linux` desktop (Ubuntu в CI) |

Rust toolchain **не нужен** для обычной разработки (libp2p archived, ADR 0003).

## Быстрый старт

**Первый раз:**

```powershell
cd D:\Documents\Projects\MeshPad
.\scripts\setup.ps1
.\scripts\bootstrap.ps1
```

**Ежедневно** (из корня репозитория):

| Цель | Команда |
|------|---------|
| Запуск (Windows) | `.\dev.ps1` |
| Release (Windows) | `.\dev.ps1 -Release` |
| Тестовый прогон | `.\dev.ps1 -Test` |
| Android | `.\dev.ps1 -Device android` |
| Win + Android (LAN) | `.\dev.ps1 -Device dual` |

`dev.ps1` при первом запуске вызывает `melos bootstrap` и Drift codegen.

## Запуск (детально)

| Цель | Команда |
|------|---------|
| Windows | `.\dev.ps1` или `.\scripts\run.ps1 -Device windows` |
| Android release APK | `.\scripts\build-android.ps1` → `meshpad.apk` + `meshpad-<version>.apk` |
| Windows release | `.\scripts\build-windows.ps1` → exe, zip, `meshpad-<version>-windows-x64-setup.exe` |
| Install APK on phone | `.\scripts\install-android-apk.ps1 -Build` |
| Linux | `cd apps/meshpad && flutter run -d linux` |
| Dual (Win+Android) | `.\dev.ps1 -Device dual` |
| Headless server (dev) | `.\scripts\run-server.ps1` — не продуктовая платформа |

После изменений native-плагинов:

```powershell
cd apps\meshpad; flutter clean; flutter run -d windows
```

## Тестовый прогон

```powershell
.\dev.ps1 -Test
# или
dart run melos run check
```

`dev.ps1 -Test` выполняет: `melos analyze` → `melos test` (пакеты) → `flutter test` (приложение).

Бенчмарк reconcile (opt-in): `cd packages/meshpad_core && dart test --tags benchmark`

## Monorepo

| Путь | Назначение |
|------|------------|
| `apps/meshpad` | Flutter UI |
| `apps/meshpad_server` | REST + SSE (dev/experimental) |
| `packages/meshpad_core` | домен, FS, Drift, sync, Git |
| `packages/meshpad_p2p` | LAN transport |
| `packages/meshpad_api_client` | HTTP client (Web dev) |
| `native/meshpad_p2p_sidecar` | libp2p sidecar (archived) |
| `native/meshpad_p2p_native` | Rust scaffold (archived) |

### Локальная очистка

Сборки и логи **не в git**, но копятся на диске (~100+ MB):

```powershell
.\scripts\clean-local.ps1          # logs/, dist/, data/, meshpad-*.apk/zip/exe в корне
.\scripts\clean-local.ps1 -Build # + melos clean (нужен повторный bootstrap)
```

После `melos clean`: `dart run melos bootstrap`.

**Не удалять вручную** (нужны проекту, см. [AGENTS.md](../AGENTS.md)): `native/`, `packages/meshpad_api_client`, `apps/meshpad/web/`, libp2p-код в `meshpad_p2p` — archived, но используется тестами.

## Поведение приложения

### UI

- Chat-лента: `FeedScreen`, `NoteBubble`, composer внизу
- Навигация через шапку: sync, устройства, настройки, корзина, Git pull/push
- Заголовок заметки по умолчанию — дата/время
- Тема ru/en, тёмная/светлая/системная — в настройках
- Теги: меню заметки → «Теги» (фильтр в ленте убран в 1.0)

### Sync (LAN)

| Порт | Назначение |
|------|------------|
| 45837 | UDP discovery |
| 45838 | HTTP pairing + sync |
| 45840 | HTTPS sync (pinned cert после PIN) |

- Discovery: mDNS `_meshpad._tcp` + UDP
- Pairing: **только PIN**; auth token в secure storage
- Payload encryption: HKDF + AES-GCM при наличии pairing token
- Auto-sync: debounce ~400 ms + периодический таймер (настройки)
- Android: `connectivity_plus`, SSID allowlist, WorkManager background sync

Wire format: [SYNC_WIRE.md](SYNC_WIRE.md).

### Git sync (desktop)

Приватный GitHub repo, зеркало `notes/<id>/` без вложений. OAuth Device Flow — [GIT_SYNC.md](GIT_SYNC.md).

### Данные

- FS — источник истины; Drift — индекс. Структура: [DATA_LAYOUT.md](DATA_LAYOUT.md)
- «Проверить данные» → reconcile + rebuild thumbnails + LRU eviction
- Корзина: 7 дней, purge при maintenance
- Экспорт/импорт zip; автобэкап (настройки)
- Логи: `<dataDir>/meshpad.log`, `.\scripts\collect-logs.ps1`, или dual+logs: `.\dev.ps1 -Device dual -CollectLogs` → `logs/latest-dual.log`

### libp2p (archived)

Не используется в production. Код и sidecar — [LIBP2P.md](LIBP2P.md).

## Headless HTTP API

Спецификация: [openapi.yaml](openapi.yaml). Запуск: `.\scripts\run-server.ps1`.

## Устранение неполадок

### Flutter / Melos

```powershell
$env:Path = "$env:LOCALAPPDATA\flutter\bin;" + $env:Path
flutter doctor -v
dart pub global activate melos
```

### Windows Developer Mode

`start ms-settings:developers` → режим разработчика (symlinks для плагинов).

### Windows release: `atlstr.h`

При `.\dev.ps1 -Release` нужен компонент **C++ ATL** в Visual Studio Build Tools:

```powershell
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe" modify --installPath "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools" --add Microsoft.VisualStudio.Component.VC.ATL --passive --norestart
```

Или: `.\scripts\install-vs-atl.ps1` (от администратора).

### LAN sync не работает

1. Оба устройства в **одной Wi‑Fi** (без «изоляции клиентов» на роутере)
2. Откройте **Устройства** — повторный mDNS/UDP browse
3. Firewall (Windows): `.\scripts\allow-meshpad-firewall.ps1`
4. PIN-pairing у обнаруженного устройства
5. Логи: `.\scripts\collect-logs.ps1` или `.\dev.ps1 -Device dual -CollectLogs` (файл `logs/latest-dual.log`)

## Ручные чеклисты

### LAN sync (Win + Android)

1. Оба устройства в одной Wi‑Fi; PIN-pairing
2. Создать заметку на A → sync → видна на B
3. Удаление → корзина → sync → восстановление
4. (Android) SSID allowlist: sync только в выбранных сетях

### Git sync (desktop)

1. Приватный repo на GitHub; `git` в PATH
2. Settings → Git sync + OAuth Client ID → «Войти через GitHub»
3. Push с одного ПК → Pull на втором

См. [GIT_SYNC.md](GIT_SYNC.md).

### Лента и вложения

- [ ] Markdown, вложения (изображение, видео Win, аудио)
- [ ] Прокрутка вверх подгружает старые заметки
- [ ] Android Share-to → новая заметка
- [ ] «Проверить данные» после ручного изменения FS
- [ ] Экспорт/импорт zip

## CI / CD

| Workflow | Когда | Результат |
|----------|-------|-----------|
| **Build Release** (`.github/workflows/build-release.yml`) | тег `v*` или `workflow_dispatch` | analyze, format, test, `build-linux`, APK + Windows zip + Inno Setup |

```powershell
git tag v0.2.0
git push origin v0.2.0
```

### Release checklist

1. Версия в `apps/meshpad/pubspec.yaml` = `kAppVersion` — `flutter test test/app_version_test.dart`
2. [CHANGELOG.md](../CHANGELOG.md): секция `[Unreleased]` → `[x.y.z]`
3. `.\dev.ps1 -Test`
4. Smoke: заметка, LAN sync, корзина
5. Тег → дождаться Build Release → проверить APK/zip/setup.exe

### Локальная сборка

```powershell
.\scripts\build-android.ps1
.\scripts\build-windows.ps1
```

Версия: `.\scripts\read-app-version.ps1`

## VS Code / Cursor

Расширения: `.vscode/extensions.json`.

## Codegen (Drift)

```powershell
cd packages/meshpad_core
dart run build_runner build --delete-conflicting-outputs
```

## Локализация

ARB: `apps/meshpad/lib/l10n/app_ru.arb`, `app_en.arb`. Генерация: `cd apps/meshpad && flutter gen-l10n`.
