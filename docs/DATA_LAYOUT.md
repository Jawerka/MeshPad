# MeshPad — файловая структура данных

Дополнение к [ARCHITECTURE.md](ARCHITECTURE.md). Источник истины — **файлы на диске**; Drift — индекс.

## Корень `<dataDir>/`

```text
<dataDir>/
  notes/<uuid>/
    note.md
    meta.json
    attachments/
    .thumbs/
    history/<revision>/     # снимки текста (волна 7.2)
      meta.json
      note.md
  operations/<yyyy-mm>/   # журнал операций (волна 7.1)
    <op-uuid>.jsonl
  devices/
    local_identity.json       # signing_public_key (Ed25519), без приватного ключа
    .device_signing_key       # base64 приватный ключ (headless/tests; native → secure storage)
    trusted/<peer_id>.json
    tls/
  index/
    meshpad.db
  app_settings.json
  meshpad.log
```

## Заметка `notes/<uuid>/`

| Файл | Назначение |
|------|------------|
| `note.md` | Markdown-тело |
| `meta.json` | `schema_version`, `id`, `title`, `created_at`, `updated_at`, `author`, `deleted`, `deleted_at`, `attachments[]`, `tags[]`, `revision`, опционально `vector_clock` |
| `attachments/` | Бинарные вложения |
| `.thumbs/` | JPEG-превью изображений |

## История версий `history/<revision>/` (PLAN 7.2)

- Создаётся **каждые 10** локальных сохранений (`revision % 10 == 0`, `revision > 0`).
- В снимке только **`meta.json`** и **`note.md`** (вложения остаются в `attachments/` текущей заметки).
- Номер каталога = значение `revision` в `meta.json` на момент снимка.
- Восстановление: `NoteRepository.restoreNoteHistoryRevision` (7.4) — подменяет title/markdown/tags; вложения не откатываются.

## Журнал операций `operations/` (PLAN 7.1)

Один JSON на файл, одна строка:

```json
{"type":"edit_note","note_id":"…","device":"…","ts":"2026-06-01T12:00:00.000Z","revision":10,"deleted":false}
```

Типы: `create_note`, `edit_note`, `delete_note`, `restore_note`, `purge_note`.

Синхронизация журнала между устройствами — **не в 7.x** (см. PLAN 7.5).
