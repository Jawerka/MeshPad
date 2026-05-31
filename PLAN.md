# MeshPad — план разработки

> **Версия плана:** 0.3-roadmap (после релиза **0.2.0**, май 2026).  
> **Приоритет документов:** фактический код + §5 (поведение) + [docs/](docs/) **доминируют** над `ref/` и черновиками.  
> **Источник аудитов:** [draft-plan.md](draft-plan.md) (несколько независимых обзоров); ниже — синтез **здравых** рекомендаций, без переноса чужих/ошибочных блоков (например, про Sketch/VBO).

Референс UI (не целевой): `ref/chat.html`, `ref/chat-layout.css`.

---

## 0. Как пользоваться этим планом

### 0.1. Формат задач

Каждая задача имеет ID, оценку и критерий готовности (DoD).

| Метка | Время (ориентир) |
|-------|------------------|
| **XS** | ≤ 1 ч |
| **S** | 2–4 ч |
| **M** | 0.5–1 день |
| **L** | 2–3 дня |
| **XL** | ≥ 1 неделя (декомпозировать перед стартом) |

**DoD по умолчанию:** код + тест или ручной шаг из [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) + запись в [CHANGELOG.md](CHANGELOG.md) при пользовательски заметном изменении.

### 0.2. Порядок волн

```text
Волна 0 (операционка) → Волна 1 (стабилизация) → Волна 2 (безопасность)
    → Волна 3 (конфликты/sync) → Волна 4 (discovery/UX)
    → Волна 5 (производительность) → Волна 6 (Web/server)
    → Волна 7 (история/операции) → Волна 8 (libp2p B.2)
    → Волна 9 (продукт)
```

**Правило:** не начинать **Волну 8 (libp2p data plane)**, пока не закрыты критичные пункты **Волн 1–3** (см. §9).

### 0.3. Production-ограничения (из docs, не обсуждаются в спринте без ADR)

| Решение | Документ | Смысл |
|---------|----------|--------|
| Sync в production = **LAN** HTTP/HTTPS | [ARCHITECTURE.md](docs/ARCHITECTURE.md), [LIBP2P.md](docs/LIBP2P.md) | libp2p — scaffold, UI скрыт |
| **FS** — источник истины для заметок | [ARCHITECTURE.md](docs/ARCHITECTURE.md) § «Файловая структура» | Drift = индекс, не замена FS |
| Навигация **только шапка** | §5.1, [DEVELOPMENT.md](docs/DEVELOPMENT.md) | Sidebar из `ref/` не планируется |
| Wire sync | [SYNC_WIRE.md](docs/SYNC_WIRE.md) | catalog / snapshot / attachments |
| CI: `melos run check` + **Build Release** | [DEVELOPMENT.md](docs/DEVELOPMENT.md) § CI/CD | APK + Windows zip на тег `v*` |

---

## 1. Продуктовая идея

Local-first Markdown-блокнот в формате **одной ленты**: каждая заметка — «сообщение» в чате. Хранение — файлы на диске + Drift-индекс; синхронизация — между **доверенными** устройствами.

**Принцип:** `Local-first + FS + sync engine + transport abstraction + thin UI shell`.

**Целевой класс продукта (долгосрочно):** приватный блокнот уровня Obsidian/Syncthing по духу, но с готовым multi-device sync «из коробки».

---

## 2. Матрица возможностей

| Область | Сделано (0.2.0) | Следующие шаги (план ниже) |
|--------|-----------------|---------------------------|
| Платформы | Android, Windows, Linux, macOS, Web | Linux CI build (опц.), iOS (бэклог) |
| UI | Темы, ru/en i18n, теги (native) | Теги Web, QR-pairing, hotkeys |
| Сеть | LAN mDNS/UDP/HTTP/HTTPS, auth token, TLS pin | Manual peer, UDP retry, optional E2EE |
| Конфликты | LWW по `updated_at` | Conflict copies → revision / vector clock |
| Корзина | 7 дней, tombstone | — |
| Web | SSE, thumbs, API key | SSE reconnect + Last-Event-ID, OpenAPI |
| Sync transport | LAN production; libp2p scaffold | B.2 Rust push/pull, затем FFI |
| Релизы | GitHub Actions APK + Win zip | Android release signing |
| Продукт | Export/import zip | Version history (E.5), in-app updates (E.6) |

---

## 3. Модель данных

### 3.1. Файловая структура (источник истины — **сохраняем**)

```text
<dataDir>/
  notes/<uuid>/
    note.md
    meta.json
    attachments/
    .thumbs/
  devices/
    local_identity.json
    trusted/<peer_id>.json
    tls/
  app_settings.json
  meshpad.log
```

### 3.2. Drift-индекс

Таблицы: `notes`, `note_fts`, `attachments`, `sync_outbox`, `devices`.  
Rebuild: старт, «Проверить данные», WorkManager.

### 3.3. Эволюция `meta.json` (запланировано, обратно совместимо)

Постепенно добавлять поля (не ломая 0.2.0):

```json
{
  "schema_version": 2,
  "id": "uuid",
  "revision": 42,
  "vector_clock": { "device_a": 18, "device_b": 5 },
  "updated_at": "2026-05-31T12:00:00.000Z",
  "tags": ["work"]
}
```

- **`revision`** — монотонный счётчик локальных правок (подготовка к E.5).
- **`vector_clock`** — опционально, для обнаружения concurrent edit без немедленного CRDT.

### 3.4. Журнал операций (будущее, Волна 7)

```text
<dataDir>/operations/<yyyy-mm>/<uuid>.jsonl
```

```json
{"type":"edit_note","note_id":"…","device":"…","ts":"…","patch":"…"}
```

Синхронизируются **операции**, а не только целые файлы — основа для истории и undo.

### 3.5. CAS для вложений (будущее, Волна 7+)

```text
<dataDir>/objects/<sha256>/
```

В `meta.json` ссылка `{ "name": "photo.jpg", "sha256": "…" }` — дедупликация и быстрый P2P (уже есть sha256 verify на LAN).

---

## 4. UI (зафиксировано)

- **Без sidebar** из `ref/` — навигация через шапку (аудит предлагал `NavigationRail` — **отложено**, см. §9.3).
- Токены: `#0f1419`, header 52px, chat-max 820px — `meshpad_theme.dart`.
- Sync только в шапке; иконка `sync` вращается **против часовой** при активном sync.
- «_Пустая заметка_» — только без текста **и** без вложений.

---

## 5. Реализованное поведение (источник истины)

> Полный чеклист: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md). Ниже — ключевые правила, которые нельзя ломать без явного запроса.

### 5.1. Навигация и шапка

- Лента без заголовка «MeshPad»; корзина — в шапке, не FAB.
- PIN-only trust; кнопки «Доверять» без PIN **нет**.

### 5.2. Лента и заметки

- Сортировка `created_at` / `updated_at` (native: `app_settings.json`, Web: `SharedPreferences`).
- Lazy load ~40, scroll up → `listNotesSlice`.
- Auto-sync debounce ~400 ms.

### 5.3. Sync и устройства (0.2.0)

| Порт | Назначение |
|------|------------|
| 45837 | UDP discovery |
| 45838 | HTTP pairing + sync fallback |
| 45839 | libp2p sidecar (dev/backlog) |
| 45840 | HTTPS sync + pinned cert |

- Discovery refresh при открытии «Устройства» и resume приложения.
- Partial sync ack, resumable uploads, Android WorkManager LAN sync.

### 5.4. Post-MVP 0.2.0

Теги, export/import, темы, i18n, Web SSE/thumbs/API key, macOS, LAN auth/TLS, libp2p scaffold (**переключатель скрыт** — `feature_flags.dart`).

---

## 6. Статус релиза

| Релиз | Содержание |
|-------|------------|
| **0.1.0** | MVP, LAN sync, Web thin client |
| **0.2.0** | Post-MVP A–E (§12 архив), CI Build Release |
| **0.3.x** | Стабилизация + конфликты + безопасность (Волны 0–3) |
| **0.4.x** | История/операции, Web parity |
| **0.5.x** | libp2p data plane (после долга Волн 1–3) |

**Сейчас:** дорожная карта post-MVP §12 **закрыта**; активная работа — **§11 (волны 0–9)**.

---

## 7. Стек и репозиторий

Flutter 3.x, Riverpod, Drift, Melos, Shelf (`meshpad_server`), Rust stub (`meshpad_p2p_native`).

```text
MeshPad/
  apps/meshpad/              # Flutter UI
  apps/meshpad_server/       # REST + --p2p
  packages/meshpad_core/
  packages/meshpad_p2p/
  packages/meshpad_api_client/
  native/meshpad_p2p_sidecar/
  native/meshpad_p2p_native/
  docs/  scripts/  ref/
```

---

## 8. Тестирование и CI/CD

| Команда / workflow | Назначение |
|--------------------|------------|
| `melos run check` | analyze + unit + flutter tests |
| `.github/workflows/ci.yml` | PR/push |
| `.github/workflows/build-release.yml` | APK + `meshpad.exe` zip на `v*` |

**Добавить в CI (план):** benchmark reconcile (Волна 5), опционально integration «два LAN peer» в docker (Волна 1).

---

## 9. Синтез аудитов ([draft-plan.md](draft-plan.md))

В черновике **несколько аудитов** с разным качеством. Ниже — что **принимаем**, что **отклоняем**, что **откладываем**.

### 9.1. Принимаем (включено в §11)

| Тема | Суть рекомендации | Наша интерпретация |
|------|-------------------|-------------------|
| **LWW ограничен** | Потеря правок при concurrent edit | Conflict copies → revision/vector clock |
| **Стабилизация** | Property/fuzz/load tests | Волна 1 |
| **Безопасность токенов** | Не plain JSON для секретов | Secure storage + оставить метаданные в FS |
| **Discovery** | mDNS ломается на гостевых Wi‑Fi | Manual peer (IP/host) + QR |
| **Replay / identity** | PIN недостаточен при утечке token | Device keypair + challenge (поэтапно) |
| **SSE/Web** | Обрыв → пропуск событий | Last-Event-ID + reconnect |
| **Производительность** | `reconcileFromFilesystem` на 10k+ | Incremental reconcile / journal |
| **Объектное хранилище** | CAS по sha256 | После журнала операций |
| **libp2p порядок** | LAN стабилен → потом P2P | Совпадает с [LIBP2P.md](docs/LIBP2P.md) |
| **Метрики sync** | `sync_duration`, `reconcile_duration` | Логи + опционально dev overlay |
| **Web gaps** | Теги только native | API + UI Web |
| **Документация API** | OpenAPI для server | Волна 6 |
| **Android signing** | Release keystore в CI | Волна 0 |
| **Единый Repository** | UI не знает local vs remote | Укрепить `NotesRepository` / сервисы |

### 9.2. Отклоняем или не делаем без ADR

| Рекомендация из аудита | Почему нет |
|------------------------|------------|
| **Drift как единственный Source of Truth** | Против [ARCHITECTURE.md](docs/ARCHITECTURE.md): FS — источник истины, экспорт, ручное правление `.md` |
| **Вернуть sidebar из ref** | Явное UX-решение §4; шапка + sheets масштабируются |
| **Сразу полный CRDT (Yjs/Automerge)** | XL-риск; сначала conflict copies + revision |
| **E2EE поверх всего (libsodium) в 0.3** | TLS + token уже есть; E2EE — отдельная волна после конфликтов |
| **Убить sidecar до готовности Rust** | Sidecar — мост B.2; цель — **FFI in-process**, не «удалить и остаться без плана» |
| **Bluetooth discovery** | Вне scope LAN-first |
| **Плагины / Obsidian import** | Волна 9+, не core |

### 9.3. Отложено (бэклог идей)

- Wiki-links `[[Note]]`, graph view  
- OCR / поиск по PDF  
- PWA / IndexedDB offline Web  
- Markdown MathJax, tables  
- `meshpad_storage` как отдельный пакет (рефакторинг после стабилизации)

### 9.4. Игнорировать в draft-plan

Блоки про **Sketch, SplitEdge, VBO, Command System** — другой проект, к MeshPad не относятся.

---

## 10. Принципы реализации

1. **Маленькие PR** — одна задача из §11 = один PR где возможно.  
2. **Обратная совместимость** `meta.json` — новые поля опциональны.  
3. **FS-first writes** — атомарная запись (temp + rename); Drift обновлять в той же логической операции:

```dart
// Целевой паттерн (packages/meshpad_core)
Future<void> saveNote(Note note) async {
  await _fs.writeNoteAtomic(note);           // note.md + meta.json
  await _db.transaction(() async {
    await _db.upsertNoteFromFs(note);
    await _outbox.enqueueNoteUpsert(note.id);
  });
}
```

4. **Transport-agnostic sync** — `SyncEngine` не знает LAN vs libp2p ([SYNC_WIRE.md](docs/SYNC_WIRE.md)).  
5. **Не показывать libp2p в UI** до B.2 DoD ([LIBP2P.md](docs/LIBP2P.md)).

---

## 11. Дорожная карта — задачи

Статусы: `⬜` todo · `🔄` in progress · `✅` done

---

### Волна 0 — Операционка и релизы

| ID | Задача | Размер | Файлы / ссылки | DoD |
|----|--------|--------|----------------|-----|
| **0.1** | Android release signing в CI (secrets) | M | `android/app/build.gradle.kts`, `build-release.yml`, [DEVELOPMENT.md](docs/DEVELOPMENT.md) | APK подписан release-ключом на теге |
| **0.2** | Версионирование: синхронизировать `pubspec` + `app_info` + CHANGELOG шаблон | XS | `app_info.dart`, `CHANGELOG.md` | Одна команда/чеклист релиза |
| **0.3** | Badge CI status в README (опц.) | XS | `README.md` | Shields.io отображает CI |
| **0.4** | Документ «Release checklist» (тег, smoke, артефакты) | S | `docs/DEVELOPMENT.md` | Чеклист 10 пунктов |

---

### Волна 1 — Стабилизация и тесты

| ID | Задача | Размер | DoD |
|----|--------|--------|-----|
| **1.1** | Property-тест: LWW merge симметрия/ассоциативность на синтетических `updated_at` | S | `packages/meshpad_core/test/` |
| **1.2** | Fuzz JSON decode catalog/snapshot ([SYNC_WIRE.md](docs/SYNC_WIRE.md)) | S | `meshpad_p2p/test/` |
| **1.3** | Тест: повреждённый Drift → recover через reconcile | S | `meshpad_core/test/` |
| **1.4** | Benchmark: 1k / 10k заметок — время `reconcileFromFilesystem` | M | script или `test/` + лог в CI artifact |
| **1.5** | Integration doc: два устройства LAN (Win+Android) — шаги | XS | `docs/DEVELOPMENT.md` |
| **1.6** | Логировать `sync_duration`, `sync_bytes`, `reconcile_duration` на уровне info | S | `meshpad_log.dart`, sync engine |
| **1.7** | Миграция `sync_transport: libp2p` → `lan` в `app_settings.json` при load | XS | `app_settings.dart`, test |

---

### Волна 2 — Безопасность

| ID | Задача | Размер | DoD |
|----|--------|--------|-----|
| **2.1** | Вынести **auth token** в `flutter_secure_storage`; в `trusted/*.json` только метаданные | M | pairing + gateway tests |
| **2.2** | Миграция существующих `trusted/` при первом запуске | S | one-time migration |
| **2.3** | Логировать аномалии часов: `updated_at` в будущем / скачок > 24h | XS | `sync_engine.dart` |
| **2.4** | Rate limit на `/api/*` (не только pairing) | S | `meshpad_server`, test |
| **2.5** | Валидация upload: max size, allowlist MIME/расширений | S | server + LAN PUT |
| **2.6** | Документ threat model (LAN, Web API key, trusted device) | S | `docs/SECURITY.md` (новый) |
| **2.7** | Подготовка device keypair в `local_identity.json` (без включения в sync) | M | model + store |
| **2.8** | Challenge-response при sync (после 2.7): ECDSA заголовок | L | pairing + gateway |

**E2EE (отдельно, после 2.8):** шифрование payload note body ключом пары — волна 2.9+, не блокирует 0.3.

---

### Волна 3 — Конфликты и sync-логика

| ID | Задача | Размер | DoD |
|----|--------|--------|-----|
| **3.1** | **Conflict copy:** при diverged edit создавать `note_id.conflict-<ts>.md` + UI badge | M | core merge + feed |
| **3.2** | Поле `revision` в `meta.json` (increment on local save) | S | schema + tests |
| **3.3** | Опциональный `vector_clock` в meta; merge helper | M | `note_meta.dart` |
| **3.4** | UI: диалог «две версии» (открыть conflict copy / оставить мою) | M | `note_bubble` / sheet |
| **3.5** | Delta sync: сравнивать catalog heads без полного pull всех тел | M | `sync_engine.dart` |
| **3.6** | Документировать стратегию merge в [SYNC_WIRE.md](docs/SYNC_WIRE.md) | XS | docs |
| **3.7** | Тест: A правит title, B правит body → conflict copy, не silent loss | S | `meshpad_core/test/` |

Пример conflict resolver (MVP 0.3):

```dart
// packages/meshpad_core/lib/src/sync/conflict_resolver.dart
enum MergeOutcome { appliedRemote, appliedLocal, createdConflictCopy }

MergeOutcome resolveNoteConflict({
  required NoteMeta local,
  required NoteMeta remote,
  required String localBody,
  required String remoteBody,
}) {
  if (localBody == remoteBody) return MergeOutcome.appliedRemote;
  if (local.updatedAt == remote.updatedAt && localBody != remoteBody) {
    return MergeOutcome.createdConflictCopy;
  }
  return remote.updatedAt.isAfter(local.updatedAt)
      ? MergeOutcome.appliedRemote
      : MergeOutcome.appliedLocal;
}
```

---

### Волна 4 — Discovery и pairing UX

| ID | Задача | Размер | DoD |
|----|--------|--------|-----|
| **4.1** | UDP discovery: retry + backoff (3 попытки) | S | `udp_lan_discovery.dart` |
| **4.2** | **Manual peer:** IP:port + «Проверить» в devices sheet | M | UI + provider |
| **4.3** | QR для PIN: показать QR на host, скан на guest (mobile) | L | `mobile_scanner` / gen QR |
| **4.4** | L10n строки discovery hint (уже частично) — audit полноты | XS | `app_*.arb` |
| **4.5** | Статус pairing: «ожидание подтверждения на …» | S | devices sheet |
| **4.6** | Лог discovery в `meshpad.log` — единый префикс `[discovery]` | XS | `meshpad_log.dart` |

---

### Волна 5 — Производительность

| ID | Задача | Размер | DoD |
|----|--------|--------|-----|
| **5.1** | Incremental reconcile: `scanned_at` / mtime cache в Drift | L | fewer FS walks |
| **5.2** | Reconcile в isolate для >500 заметок | M | no UI jank |
| **5.3** | Feed: убедиться в `ListView.builder` + ключи (audit) | S | feed_screen |
| **5.4** | Thumbnail cache eviction policy (max MB) | S | settings |
| **5.5** | gzip для LAN JSON catalog (опционально, negotiate header) | M | gateway |

---

### Волна 6 — Web и server

| ID | Задача | Размер | DoD |
|----|--------|--------|-----|
| **6.1** | SSE: `Last-Event-ID` + reconnect backoff | M | server + `api_events.dart` |
| **6.2** | Web client: после reconnect — `GET /api/notes?since=` или full reload | S | web provider |
| **6.3** | API: теги в notes CRUD + filter `?tag=` | M | server + api_client + Web chips |
| **6.4** | OpenAPI 3.0 spec для `/api/*` | M | `docs/openapi.yaml` |
| **6.5** | Web theme follow `theme_mode` (SharedPreferences) | S | web settings |
| **6.6** | CSRF не критичен для API key; документировать модель | XS | SECURITY.md |

**WebSocket вместо SSE** — только если 6.1 недостаточно; отдельная задача 6.7 (L).

---

### Волна 7 — История и операции (E.5)

| ID | Задача | Размер | DoD |
|----|--------|--------|-----|
| **7.1** | Папка `operations/` + append-only JSONL на save/delete | M | core |
| **7.2** | Snapshot раз в N операций → `notes/<id>/history/<rev>/` | M | FS layout doc |
| **7.3** | UI: «История» в меню заметки, diff preview | L | feed |
| **7.4** | Restore revision (локально, без sync v1) | M | |
| **7.5** | Sync операций — **не в 7.x**; только после 3.x и 8.x | — | ADR |

---

### Волна 8 — libp2p B.2 ([LIBP2P.md](docs/LIBP2P.md))

**Предусловия:** 1.6, 2.1, 3.1–3.2 минимум.

| ID | Задача | Размер | DoD |
|----|--------|--------|-----|
| **8.1** | Rust: `push`/`pull` batch по [SYNC_WIRE.md](docs/SYNC_WIRE.md) | XL | `meshpad_p2p_native` |
| **8.2** | Интеграционный тест: два sidecar/native peer | L | CI |
| **8.3** | `Libp2pSyncTransport`: data plane без LAN fallback на happy path | L | p2p package |
| **8.4** | FFI in-process (flutter_rust_bridge или `dart:ffi`) — **замена HTTP sidecar** | XL | mobile battery |
| **8.5** | `libp2pTransportSettingVisible = true` + миграция settings | XS | feature_flags |
| **8.6** | Hole punching / relay — **бэклог после 8.4** | XL | |

---

### Волна 9 — Продукт

| ID | Задача | Размер | DoD |
|----|--------|--------|-----|
| **9.1** | In-app update: скачать APK/asset из GitHub Release (E.6) | L | settings |
| **9.2** | Win: optional installer (MSIX/Inno) в Build Release | L | workflow |
| **9.3** | Автобэкап zip по расписанию (локальный путь) | M | settings |
| **9.4** | Hotkeys desktop: Ctrl+N, Ctrl+F, Ctrl+K | S | desktop_shell |
| **9.5** | Tag autocomplete в редакторе тегов | S | note_tags_editor |
| **9.6** | iOS target (исследование) | XL | ADR |

---

## 12. Рекомендуемый порядок спринтов (2 недели)

### Спринт A (стабильность)

`0.1` → `0.2` → `1.1`–`1.7` → `2.1`–`2.3`

### Спринт B (конфликты + UX сети)

`3.1`–`3.4` → `4.1`–`4.3` → `6.1`–`6.2`

### Спринт C (масштаб + Web)

`5.1`–`5.2` → `6.3`–`6.4` → `7.1`–`7.2`

### Спринт D (libp2p — только после C)

`8.1` → `8.3` → `8.4` → `8.5`

---

## 13. Архив: Post-MVP §12 (выполнено в 0.2.0)

<details>
<summary>Фазы A–E — сводка ✅</summary>

| Фаза | Содержание |
|------|------------|
| **A** | Auth token, revoke, PIN TTL/rate limit |
| **B** | libp2p scaffold, sidecar `:45839`, LAN TLS `:45840`, factory |
| **C** | Outbox retry, partial ack, resumable upload, Android background LAN |
| **D** | Web SSE, server thumbs, API key, macOS |
| **E** | Export/import, themes, tags, i18n |

</details>

---

## 14. Риски

| Риск | Митигация |
|------|-----------|
| LWW потеря данных | Волна 3 conflict copies |
| Dual-write FS+Drift | Атомарная запись FS + транзакция Drift (§10) |
| libp2p сложность | LAN production; B.2 только после 1–3 |
| Android Doze / OEM | WorkManager + foreground sync button; не обещать «всегда 15 мин» |
| Web SSE gap | 6.1 Last-Event-ID |
| Scope creep из аудитов | §9.2 отклонения |

---

## 15. Ссылки

| Документ | Назначение |
|----------|------------|
| [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) | Установка, чеклисты, CI/CD |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Слои, LAN, data dir |
| [docs/SYNC_WIRE.md](docs/SYNC_WIRE.md) | Wire format |
| [docs/LIBP2P.md](docs/LIBP2P.md) | libp2p Phase B |
| [CHANGELOG.md](CHANGELOG.md) | Релизы |
| [draft-plan.md](draft-plan.md) | Сырые аудиты (архив идей) |

---

## 16. История спринтов (архив)

<details>
<summary>Спринты 0–7</summary>

- **0–6:** MVP (см. старый PLAN / CHANGELOG 0.1.0)
- **7 (0.2.0):** post-MVP A–E, discovery fixes, libp2p hidden, docs, Build Release CI
- **8+:** по §11 волнам 0–9

</details>
