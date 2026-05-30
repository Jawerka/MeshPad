# Разработка MeshPad

## Требования

| Инструмент | Версия / примечание |
|------------|---------------------|
| Git | 2.x |
| Flutter | stable (см. `.fvmrc`) |
| Dart | идёт с Flutter |
| Android Studio / SDK | только для сборки Android |
| Visual Studio 2022 | «Desktop development with C++» — для `windows` |
| clang/cmake | для `linux` desktop (WSL или нативный Linux) |

## Устранение неполадок

### `Unable to update Dart SDK` / `storage.googleapis.com`

Первый запуск Flutter скачивает Dart SDK с Google CDN. Нужен доступ в интернет (или VPN/прокси). После успешного `flutter doctor` SDK кэшируется локально.

```powershell
$env:Path = "$env:LOCALAPPDATA\flutter\bin;" + $env:Path
flutter doctor -v
```

### Melos не в PATH

```powershell
$env:Path = "$env:LOCALAPPDATA\Pub\Cache\bin;" + $env:Path
dart pub global activate melos
```

## Быстрый старт (Windows)

```powershell
cd D:\Documents\Projects\MeshPad
.\scripts\setup.ps1
.\scripts\bootstrap.ps1
```

`setup.ps1`:

- при отсутствии Flutter клонирует stable в `%LOCALAPPDATA%\flutter`;
- добавляет Flutter в PATH **текущей сессии**;
- запускает `flutter doctor`;
- выполняет `melos bootstrap` (если monorepo уже создан).

## Git

```powershell
git clone <url> MeshPad
cd MeshPad
.\scripts\setup.ps1
```

`local.properties` (пути SDK) в `.gitignore` — не коммитится.

## Android-эмулятор

AVD **MeshPad_API36** (Pixel 7, API 36, Google Play, x86_64).

```powershell
.\scripts\launch-emulator.ps1
# или: flutter emulators --launch MeshPad_API36

cd apps\meshpad
flutter run
```

Другой AVD: Android Studio → Device Manager → Create Virtual Device.

## Команды (после bootstrap)

```powershell
melos run analyze
melos run test
melos run format

cd apps/meshpad
flutter run -d windows
```

## Структура monorepo

- `apps/meshpad` — точка входа Flutter
- `packages/meshpad_core` — домен и хранилище (unit-тесты здесь)
- `packages/meshpad_p2p` — сетевой адаптер

## Codegen (Drift)

```powershell
cd packages/meshpad_core
dart run build_runner build --delete-conflicting-outputs
```

## Ручной чеклист (UI-спринт)

- [ ] Создать заметку с заголовком и MD-текстом
- [ ] Прикрепить изображение, открыть лайтбокс
- [ ] Удалить в корзину, восстановить
- [ ] Поиск находит фрагмент текста
- [ ] Перезапуск приложения — данные на месте

## CI

Pull request → GitHub Actions: `analyze`, `format`, `test` (см. `.github/workflows/ci.yml`).

## VS Code / Cursor

Рекомендуемые расширения — `.vscode/extensions.json`.
