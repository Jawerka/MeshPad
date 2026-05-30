# MeshPad — план разработки (MVP)

Документ объединяет продуктовые требования, архитектуру, этапы, тестирование и настройку окружения. Референс UI: `ref/chat.html`, `ref/chat-layout.css`, `ref/chat-messages.js`.

---

## 1. Продуктовая идея

Локальный Markdown-блокнот в формате **одной общей ленты**: каждая заметка — отдельное «сообщение» в чате. У заметки есть имя, даты, автор, метаданные и папка вложений. Хранение — **local-first** на каждом устройстве; синхронизация — **P2P** между доверенными устройствами. UI — чатовый shell: боковая панель, тёмная тема, карточки, инлайн-редактирование, превью изображений, лайтбокс.

**Главный архитектурный принцип:** `Local-first + file-based storage + sync engine (tombstones + LWW) + P2P transport + thin UI shell`.

---

## 2. Зафиксированные требования

| Область | Решение |
|--------|---------|
| Платформы | Android, Linux, Windows, Web |
| UI-стек | Flutter (единый код) |
| Сеть | libp2p, LAN discovery — mDNS/Bonjour |
| Шифрование | **Транспорт** (TLS/noise поверх libp2p) — да; **контентное E2E** заметок — нет |
| Офлайн | Всё пишется локально, sync при появлении пиров |
| Конфликты | Last-write-wins по `updated_at` (UTC, монотонные часы — см. риски) |
| Удаление | Корзина **7 дней**, затем физическое удаление + tombstone propagation |
| Вложения | Любые файлы, без лимитов на размер/количество |
| UI | Только тёмная тема, только русский |
| Android | Share-to (текст, ссылки, изображения, файлы), фоновая синхронизация |
| Desktop | Системный трей, сворачивание в трей, фоновый sync loop |
| Web | Тонкий клиент к **серверной Linux-версии** (не автономный offline-P2P) |
| Масштаб | Сотни заметок с вложениями |
| Вне MVP | Теги, история версий, экспорт/импорт, светлая тема, i18n |

---

## 3. Модель данных

### 3.1. Файловая структура (источник истины)

```text
<dataDir>/
  notes/
    <uuid>/
      note.md
      meta.json
      attachments/
        <filename>
      .thumbs/          # опционально, генерируется локально
  devices/
    local_identity.json
    trusted/<peer_id>.json
  sync/
    outbox/             # очередь исходящих дельт (опционально на FS)
```

### 3.2. `meta.json` (схема v1)

```json
{
  "schema_version": 1,
  "id": "uuid-v4",
  "title": "string",
  "created_at": "2026-05-29T12:00:00.000Z",
  "updated_at": "2026-05-29T12:00:00.000Z",
  "author": "device-display-name",
  "deleted": false,
  "deleted_at": null,
  "attachments": [
    { "name": "photo.jpg", "size": 12345, "mime": "image/jpeg", "sha256": "..." }
  ],
  "sync": {
    "vector_clock": null,
    "last_pushed_at": null
  }
}
```

- `note.md` — только Markdown; ссылки на вложения — относительные (`attachments/...`).
- Идентификатор заметки — **UUID при создании**, не меняется.
- Tombstone: `deleted: true`, `deleted_at` установлен; папка может оставаться до TTL.

### 3.3. SQLite-индекс (производное, пересобираемое)

Таблицы (Drift):

- `notes` — id, title, created_at, updated_at, author, deleted, deleted_at, preview_snippet
- `note_fts` — FTS5 по телу Markdown (и позже — по title)
- `attachments` — note_id, name, mime, size, sha256
- `sync_outbox` — entity_type, entity_id, op, payload, created_at, retry_count
- `devices` — peer_id, name, icon, trusted, last_seen_at

**Правило:** при расхождении FS и БД — FS побеждает; индекс пересобирается командой «Проверить данные» (dev/MVP) или при старте по mtime.

---

## 4. UI и дизайн-система

### 4.1. Экраны MVP

| Экран | Содержание |
|-------|------------|
| Лента | Сортировка по `created_at` (основной режим) / переключатель на `updated_at`; пузыри заметок |
| Редактирование | Inline в ленте; сохранение → обновление `updated_at` + outbox |
| Боковая панель | Поиск, «новая заметка», корзина, устройства, настройки |
| Корзина | Список удалённых, восстановление, дата автоудаления |
| Устройства | Это устройство, доверенные, обнаруженные, PIN-pairing |
| Настройки | Путь данных, проверка обновлений, о приложении |

### 4.2. Перенос токенов из `ref/`

Зафиксировать в `lib/core/theme/meshpad_theme.dart`:

- Фон: `#0f1419` (`theme-color` из ref)
- `--sidebar-width: 280`, `--header-h: 52`, `--chat-max: 820`
- Радиусы, тени composer, focus-ring — из `chat-layout.css`
- Компоненты: `NoteBubble`, `AttachmentGrid`, `Lightbox`, `ComposerBar`, `ConvSidebar`

### 4.3. Поведение

- Удалённая заметка сразу скрывается из ленты на всех устройствах (после sync).
- Статус синхронизации на карточке: локально / в очереди / синхронизировано / ошибка.
- Иконки устройств — предустановленный набор + цвет по hash(peer_id).

---

## 5. Синхронизация и сеть

### 5.1. Протокол MVP (упрощённо)

1. **Discovery:** mDNS в LAN; вне LAN — relay + bootstrap (libp2p).
2. **Pairing:** оба устройства показывают PIN → взаимное подтверждение → запись в `trusted/`.
3. **Sync:** после trust — обмен каталогом заметок (id + updated_at + deleted).
4. **Дельта:** для изменённых id — передача `meta.json`, `note.md`, изменённых вложений (по sha256/size).
5. **Merge:** если remote `updated_at` > local → заменить; иначе пропустить.
6. **Delete:** tombstone с `deleted_at`; через 7 дней — удаление файлов и запись в outbox «purge».

### 5.2. P2P-слой (реализация)

| Слой | Технология | Примечание |
|------|------------|------------|
| Транспорт | libp2p (Rust: `rust-libp2p` или Go) | Отдельный процесс/библиотека, не во Flutter UI isolate |
| Мост | `flutter_rust_bridge` / gRPC localhost / FFI | Стабильный API: `start`, `discover`, `pair`, `push`, `pull` |
| Flutter | `meshpad_p2p` package | Только адаптер + модели событий |

На **этапе 1–3** sync — заглушка (`FakeSyncTransport`) с тем же интерфейсом, чтобы UI и outbox тестировались без сети.

### 5.3. Безопасность

- Парный обмен только после PIN.
- Транспорт: шифрование канала libp2p (Noise/TLS).
- Отзыв доверия: удаление из `trusted/`, разрыв соединений, игнор новых push.

---

## 6. Технологический стек (зафиксировано)

| Назначение | Выбор |
|------------|--------|
| UI | Flutter 3.x stable |
| Состояние | **Riverpod** + `riverpod_annotation` где уместно |
| Навигация | `go_router` |
| Локальный индекс | **Drift** + `sqlite3` |
| Markdown | `markdown_widget` или `flutter_markdown` + кастом builders для вложений |
| Логи | `logging` + уровни по flavor |
| DI | Riverpod providers |
| Версии SDK | `.fvmrc` → Flutter stable (см. `docs/DEVELOPMENT.md`) |

---

## 7. Структура репозитория (простая поддержка)

```text
MeshPad/
  apps/meshpad/              # Flutter-приложение (UI + platform channels)
  packages/
    meshpad_core/            # домен, FS, индекс, sync engine (чистый Dart)
    meshpad_p2p/             # интерфейс + fake + будущий FFI
  ref/                       # HTML/CSS референс (не в сборке)
  docs/
    DEVELOPMENT.md
    ARCHITECTURE.md
  scripts/
    setup.ps1
    bootstrap.ps1
  .github/workflows/ci.yml
  PLAN.md
```

**Правила:**

- Бизнес-логика — только в `meshpad_core` (тестируется без Flutter).
- Виджеты — тонкие, читают state из providers.
- Один формат ошибок: `MeshPadException` + код для UI.

---

## 8. Тестирование

### 8.1. Пирамида

| Уровень | Что | Инструменты |
|---------|-----|-------------|
| Unit | LWW merge, tombstone TTL, meta.json (de)serialize, outbox | `test`, `meshpad_core` |
| Widget | NoteBubble, корзина, пустые состояния | `flutter_test` |
| Integration | CRUD заметки → FS + Drift согласованы | `integration_test` |
| Golden | Тема, карточка заметки | `golden_toolkit` / встроенные goldens |
| E2E (позже) | Два fake-пира | `FakeSyncTransport` + integration |

### 8.2. Политика

- Каждый PR: `dart analyze`, `dart format`, unit + widget tests.
- Покрытие: не гнаться за %; обязательны тесты на **sync merge**, **корзину**, **запись meta**.
- Фикстуры: `packages/meshpad_core/test/fixtures/notes/<uuid>/`.
- CI без секретов; P2P в CI — только fake.

### 8.3. Definition of Done (этап)

- [ ] Код + тесты на новую логику в `meshpad_core`
- [ ] `melos`/`dart analyze` без ошибок
- [ ] Ручной чеклист из `docs/DEVELOPMENT.md` (если UI)
- [ ] Обновлён `CHANGELOG.md` для релизных веток

---

## 9. Инструменты и окружение

Подробная установка: **`docs/DEVELOPMENT.md`**.

Кратко:

1. Git, Flutter (stable), Android SDK (для Android), Visual Studio Build Tools (Windows desktop).
2. `.\scripts\setup.ps1` — проверка зависимостей, `flutter doctor`, `pub get`.
3. `.\scripts\bootstrap.ps1` — `melos bootstrap`, codegen (Drift).
4. IDE: VS Code / Cursor + расширения из `.vscode/extensions.json`.
5. CI: GitHub Actions — analyze, test, format check.

---

## 10. MVP — объём

### Включено

1. Локальные заметки (MD + папка)
2. Лента в чат-стиле, inline edit
3. Вложения + превью изображений
4. Корзина 7 дней
5. Поиск по Markdown (FTS)
6. P2P sync LAN + PIN trust (после готовности native слоя; до этого — fake)
7. Android share-to
8. Desktop tray
9. Web → API Linux-сервера (минимальный REST/WebSocket позже)

### Не включено

Теги, версионирование, экспорт, светлая тема, мультиязычность.

---

## 11. Этапы и спринты

Зависимости: `1 → 2 → 3 → 4 → 5`; Web-сервер может идти параллельно с `5` после стабильного `meshpad_core`.

### Спринт 0 — Инфраструктура

- [x] PLAN.md, docs, scripts, CI skeleton
- [x] Monorepo: `apps/meshpad`, `packages/meshpad_core`
- [x] FVM / версия Flutter, analyze_options, melos
- [x] Первый `flutter test` (smoke)

### Спринт 1 — Данные

- [x] Модели Note, Attachment, Device, SyncEvent
- [x] FS repository: read/write note folder
- [x] Drift schema + миграция v1
- [x] Unit-тесты round-trip FS ↔ DB

### Спринт 2 — UI каркас

- [x] Theme из ref
- [x] Лента + карточка + composer
- [x] Создание и редактирование
- [x] Корзина UI

### Спринт 3 — Локальная логика

- [x] Вложения (FS + индекс)
- [x] Превью изображений и лайтбокс
- [x] Поиск FTS по телу note.md
- [x] Outbox (локальный) + индикатор в UI
- [x] Автоочистка корзины (7 дней)

### Спринт 4 — Sync (в работе)

- [x] Device identity (`local_identity.json`, trusted/)
- [x] SyncEngine + LWW/tombstone + outbox ack
- [x] FakeSyncTransport + FakeSyncHub + тесты двух пиров
- [x] LAN discovery заглушка (демо-пиры до libp2p/mDNS)
- [ ] libp2p MVP (LAN + PIN)
- [x] UI: устройства, PIN-заглушка, «Синхронизировать»
- [x] Outbox retry + статусы на карточках (pending / error)

### Спринт 5 — Платформы (в работе)

- [ ] Android share + WorkManager
- [x] Windows/Linux tray (свернуть в трей, меню)
- [ ] Linux headless + Web client
- [x] Настройки: путь данных, автосинхронизация, проверка данных
- [x] Android Share-to (текст и файлы)
- [x] WorkManager фоновое обслуживание (reconcile + purge)

### Спринт 6 — Полировка (в работе)

- Ленивая лента, прогресс файлов
- [x] Проверка обновлений (ручная загрузка)
- Обработка ошибок сети

---

## 12. Обновления приложения

- Android / Windows / Linux: экран «О приложении» → проверка URL манифеста версий → ссылка на скачивание.
- Web: деплой серверной сборки.
- Без in-app auto-update в MVP.

---

## 13. Риски и митигация

| Риск | Митигация |
|------|-----------|
| libp2p сложно встроить во Flutter | Отдельный native crate + узкий API; fake transport до готовности |
| LWW при расхождении часов | Хранить `updated_at` от автора + опционально `device_id`; логировать аномалии |
| Большие вложения | Потоковая передача, progress UI, resume по sha256 |
| Web без P2P | Явно: только клиент к Linux API |
| Потеря данных | FS — источник истины; периодический «Rebuild index» |

---

## 14. Поиск (зафиксировано)

- MVP: FTS по телу `note.md`.
- Позже: индекс имён вложений и `title` без смены схемы FS.

---

## 15. Ссылки

- UI-референс: `ref/chat.html`
- Окружение: `docs/DEVELOPMENT.md`
- Архитектура слоёв: `docs/ARCHITECTURE.md`
- История изменений плана: git log `PLAN.md`
