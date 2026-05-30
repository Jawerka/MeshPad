# Архитектура MeshPad

## Слои

```mermaid
flowchart TB
  subgraph ui [apps/meshpad]
    Widgets[Widgets]
    Providers[Riverpod Providers]
  end
  subgraph core [packages/meshpad_core]
    Domain[Domain Models]
    FS[File Note Repository]
    DB[Drift Index]
    Sync[Sync Engine + Outbox]
  end
  subgraph p2p [packages/meshpad_p2p]
    Transport[Sync Transport API]
    Native[libp2p Native - later]
    Fake[Fake Transport]
  end
  Widgets --> Providers
  Providers --> Domain
  Providers --> Sync
  Sync --> FS
  Sync --> DB
  Sync --> Transport
  Transport --> Fake
  Transport --> Native
```

## Поток записи заметки

1. UI сохраняет `note.md` + `meta.json` в `notes/<uuid>/`.
2. `NoteRepository` обновляет Drift.
3. `SyncEngine` кладёт запись в `sync_outbox`.
4. `SyncTransport` отправляет дельту доверенным пирам (или откладывает).

## Поток чтения ленты

1. UI запрашивает список у `NotesListNotifier`.
2. Notifier читает из Drift (быстро), при cold start — reconcile с FS.
3. Карточки строятся из `NoteSummary` + путь к превью вложений.

## Границы пакетов

- `meshpad_core` **не зависит** от Flutter.
- `meshpad_p2p` зависит только от `meshpad_core` (модели событий).
- `apps/meshpad` — единственное место с `dart:ui` и platform channels.

## Web / Linux server

Headless-процесс на Linux:

- тот же `meshpad_core` + HTTP API;
- Web-клиент (Flutter web) ходит в API, P2P остаётся на сервере.

Детали API — отдельная спецификация после MVP desktop/mobile.
