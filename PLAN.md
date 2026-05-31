# MeshPad — план разработки

> **Приоритет документов:** фактическая реализация MVP (код + раздел §5) **доминирует** над ранними черновиками и HTML-референсом `ref/`. Если текст расходится с приложением — верьте коду и §5.

Референс UI (не целевой): `ref/chat.html`, `ref/chat-layout.css`.

---

## 1. Продуктовая идея

Local-first Markdown-блокнот в формате **одной ленты**: каждая заметка — «сообщение» в чате. Хранение — файлы на диске + Drift-индекс; синхронизация — между **доверенными** устройствами.

**Принцип:** `Local-first + FS + sync engine (LWW + tombstones) + P2P transport + thin UI shell`.

---

## 2. Зафиксированные требования

| Область | MVP (реализовано) | Post-MVP |
|--------|-------------------|----------|
| Платформы | Android, Linux, Windows, Web | macOS |
| UI | Flutter, тёмная тема, русский | i18n, светлая тема |
| Сеть | **LAN:** mDNS + UDP + HTTP sync | libp2p, relay, TLS/Noise |
| Pairing | PIN over LAN + auth token | — |
| Конфликты | LWW по `updated_at` | vector clock (опционально) |
| Корзина | 7 дней → purge + tombstone | — |
| Web | Thin client → `meshpad_server` | WebSocket push |
| Вне scope | — | теги, версии, экспорт |

---

## 3. Модель данных

### 3.1. Файловая структура (источник истины)

```text
<dataDir>/
  notes/<uuid>/
    note.md
    meta.json
    attachments/
    .thumbs/              # JPEG превью изображений (локально)
  devices/
    local_identity.json
    trusted/<peer_id>.json
```

### 3.2. Drift-индекс

- `notes`, `note_fts` (тело + **title** + имена вложений), `attachments`, `sync_outbox`, `devices`
- FS побеждает; rebuild: старт, «Проверить данные», WorkManager

---

## 4. UI (целевой дизайн vs ref)

HTML-референс содержит **боковую панель** — в приложении **не реализована** и не планируется в текущем UX.

Токены темы: `#0f1419`, header 52px, chat-max 820px — `meshpad_theme.dart`.

---

## 5. Реализованное MVP (0.1.0)

**Этот раздел — источник истины по поведению приложения.**

### 5.1. Навигация и шапка

- Единая **шапка** на Windows, Android, Web (без sidebar).
- В режиме ленты **нет** заголовка «MeshPad» (только иконки действий).
- В режиме корзины: «←» + «Корзина».
- Элементы шапки: сортировка (desktop), **sync**, поиск, устройства, настройки, **корзина**.
- **Sync:** кнопка на всех native; при активном sync иконка `sync` **вращается против часовой**, цвет primary; badge = число outbox. **Не** `CircularProgressIndicator`.
- **Sync на карточках заметок — нет** (только шапка). Не возвращать без явного запроса.
- **Корзина — в шапке**, не FAB.

### 5.2. Лента и заметки

- Сортировка: `created_at` (по умолчанию) / `updated_at`; сохраняется (native: `app_settings.json`, Web: `SharedPreferences`).
- Ленивая подгрузка: последние ~40 заметок, scroll up → `listNotesSlice`.
- Inline edit в `NoteBubble`; auto-title из Markdown (`# heading` или первая строка).
- **«_Пустая заметка_»** — только если нет текста **и** нет вложений.
- Auto-sync после локальных изменений (debounce ~400 ms).

### 5.3. Вложения и медиа

| Тип | Поведение |
|-----|-----------|
| Изображения | `.thumbs/` JPEG до 240px; lightbox по tap |
| Видео mobile | Inline player в ленте |
| Видео Win/Linux | Постер (кадр на 1/3 длительности), tap → fullscreen dialog; `video_player_win` |
| Аудио | Inline player (audioplayers) |
| Прочие файлы | Chip + open externally |
| Composer DnD | Windows + Linux (`desktop_drop`) |
| Большие файлы | Progress UI при копировании |

### 5.4. Sync и устройства

- Transport: **`LanSyncTransport`** (mDNS `_meshpad._tcp`, UDP fallback, HTTP `/meshpad/p2p/*`).
- Pairing: **только PIN** — кнопки «Доверять» без PIN **нет**; у обнаруженных peer — «PIN».
- PIN-диалог: live-список из `discoveredPeersProvider`.
- Sync: LWW, outbox, retry; stale LAN endpoint сбрасывается при недоступности peer.
- Корзина purge: старт, reconcile, **auto-sync tick**, WorkManager, headless `--p2p`.
- Headless server: `onRemoteTrusted` для обратного доверия при PIN.
- Revoke trust + `forgetPeer`; purge exhausted outbox в настройках.
- Иконки устройств: preset + цвет по `peer_id`.

### 5.5. Платформы

| Платформа | Особенности |
|-----------|-------------|
| Windows | Tray; `nuget.config` для audioplayers; window state ini |
| Linux | Tray; DnD в composer |
| Android | Share-to; WorkManager (мин. 15 мин); compact devices UI |
| Web | API client; paginated notes; sync/devices скрыты |

### 5.6. Поиск

FTS: тело `note.md`, `title`, имена вложений.

### 5.7. Windows-сборка

`apps/meshpad/windows/nuget.config` — fix для `audioplayers_windows` (NuGet primarySources).

---

## 6. MVP — краткий итог

Monorepo Flutter + pure Dart core. Local-first заметки, chat-лента, вложения с превью, корзина 7 дней, FTS, LAN sync с PIN, Android share-to, desktop tray, Web через headless API. Спринты 0–6 **закрыты**. Interim LAN transport вместо libp2p — **осознанное решение MVP**.

---

## 7. Технологический стек

Flutter 3.x, Riverpod, Drift, `flutter_markdown`, `meshpad_core` / `meshpad_p2p` / `meshpad_api_client`, Melos, CI.

Подробности установки: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

---

## 8. Структура репозитория

```text
MeshPad/
  apps/meshpad/           # Flutter UI
  apps/meshpad_server/    # Headless REST + optional --p2p
  packages/meshpad_core/
  packages/meshpad_p2p/
  packages/meshpad_api_client/
  docs/  scripts/  ref/
```

---

## 9. Тестирование

- CI: `melos run check` (analyze + unit + widget).
- Core: LWW, tombstone, outbox, thumbnails, pagination, LAN sync tests.
- Widget: header, note bubble (attachment-only).
- Ручной чеклист: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

---

## 10. Риски

| Риск | Митигация |
|------|-----------|
| libp2p сложность | Узкий `SyncTransport` API; LAN MVP уже работает |
| LWW + часы | Логирование аномалий `updated_at` |
| LAN без auth | Post-MVP: token в trusted/ |
| Web масштаб | API pagination (реализовано) |

---

## 11. Ссылки

- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [CHANGELOG.md](CHANGELOG.md)

---

## 12. Post-MVP — план развития

### Фаза A — Безопасность LAN sync (приоритет)

**Цель:** закрыть дыры interim HTTP transport до/параллельно libp2p.

| Задача | Описание | Файлы |
|--------|----------|-------|
| A.1 Auth token | Shared secret в `trusted/<peer_id>.json`; заголовок на все `/meshpad/p2p/*` кроме pairing | ✅ `lan_peer_server.dart`, `http_remote_sync_gateway.dart`, `device_identity_store.dart` |
| A.2 Reject revoked | 403 для отозванных peer; server-side ignore | ✅ |
| A.3 Pairing hardening | TTL PIN offer; rate limit confirm | ✅ `lan_peer_server.dart`, `pairing_protocol.dart` |

**DoD:** два desktop в LAN; без token sync = 401; после revoke — отказ. ✅

### Фаза B — Native libp2p

**Цель:** заменить LAN HTTP/UDP на libp2p, сохранив `SyncTransport`.

| Задача | Описание |
|--------|----------|
| B.1 Native crate | Rust `rust-libp2p` или Go; API: `start`, `discover`, `pair`, `push`, `pull` |
| B.2 FFI bridge | `flutter_rust_bridge` / gRPC localhost |
| B.3 Feature flag | `LanSyncTransport` ↔ `Libp2pSyncTransport` через provider |
| B.4 Noise/TLS | Транспортное шифрование (PLAN §2) |

**DoD:** LAN sync через libp2p; те же UI flows; CI — fake transport.

### Фаза C — Sync reliability

| Задача | Описание |
|--------|----------|
| C.1 Per-entry outbox retry | Не bump all on batch fail | ✅ transport failures; partial push — follow-up |
| C.2 Partial sync ack | Ack после успешной передачи вложений |
| C.3 Resume upload | Chunked + sha256 verify |
| C.4 Android background sync | WorkManager + LAN sync (ограничения OS) |

### Фаза D — Web и server

| Задача | Описание |
|--------|----------|
| D.1 WebSocket/SSE | Push обновлений ленты |
| D.2 Server-side thumbs | Превью для Web без local `.thumbs/` |
| D.3 Auth для API | API key / session (опционально) |
| D.4 macOS client | Discovery + tray |

### Фаза E — Продукт (вне текущего scope)

Теги, история версий, экспорт/импорт, светлая тема, i18n, in-app updates.

### Рекомендуемый порядок

```
A (security) → C.1–C.2 (reliability) → B (libp2p) → D (web scale) → E
```

**Следующий спринт:** **C.2** (partial sync ack) или **B.1** (libp2p native crate).

---

## 13. История спринтов (архив)

<details>
<summary>Спринты 0–6 (выполнены)</summary>

- **0:** monorepo, CI, melos
- **1:** FS + Drift + models
- **2:** theme, feed, composer, trash
- **3:** attachments, lightbox, FTS, outbox, trash TTL
- **4:** identity, SyncEngine, LAN transport, PIN, mDNS, header sync
- **5:** Android share, tray, headless server, Web client, settings
- **6:** lazy feed, errors, attachment progress, update check, `.thumbs`, media preview, API pagination, MVP polish

</details>
