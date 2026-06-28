# ADR 0003: Простота — LAN + Git, без libp2p

| Поле | Значение |
|------|----------|
| Статус | **Accepted** |
| Дата | 2026-06-01 |
| Заменяет | Волна 8 (libp2p B.2) как продуктовую цель |

## Контекст

MeshPad изначально планировал libp2p data plane (relay, hole punching, Rust FFI). Пользовательский фокус сместился на **простоту и надёжность** в локальных сетях (Wi‑Fi/LAN), без необходимости связи через интернет.

## Решение

1. **Production sync = только LAN** (mDNS/UDP + HTTP/HTTPS, payload encryption ключом pairing).
2. **libp2p** выводится из production path: код остаётся в репозитории как archived, не собирается в CI release, не показывается в UI.
3. **Git sync** (GitHub, приватный repo, зеркало `notes/<id>/` без вложений) — вторичный ручной канал.
4. **Web-клиент** и **журнал операций** — заморожены, не в scope 1.0.
5. **UI** — chat-лента (заметки как сообщения), без sidebar/master-detail.
6. **Linux** — CI compile без активной разработки.

## Последствия

- Удалены из CI/release: `rust-sidecar`, `build-native-ffi*`, Android jniLibs для libp2p.
- `createSyncTransport()` всегда возвращает `LanSyncTransport`.
- Миграция `sync_transport: libp2p` → `lan` при загрузке настроек.
- Новые волны: A (зачистка), B (UI), C (LAN+шифрование+сеть), D (Git), E (polish).

## Ссылки

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [LIBP2P.md](../LIBP2P.md) (archived)
