# libp2p (archived)

> **Статус:** archived ([ADR 0003](ADR/0003-simplicity-lan-git.md)). Production sync = **LAN only**.

Код libp2p остаётся в репозитории для экспериментов и тестов, но **не входит** в production:

- `createSyncTransport()` всегда возвращает `LanSyncTransport`
- Переключатель в настройках скрыт (`MeshPadFeatureFlags.libp2pTransportSettingVisible = false`)
- CI/release не собирает Rust FFI (`native/meshpad_p2p_native`, `scripts/build-native-ffi*`)

## Где лежит код

| Путь | Назначение |
|------|------------|
| `packages/meshpad_p2p/lib/src/libp2p/` | `Libp2pSyncTransport`, wire gateway |
| `native/meshpad_p2p_sidecar/` | Dart HTTP sidecar (dev harness) |
| `native/meshpad_p2p_native/` | Rust scaffold + integration tests |

## Локальный dev (опционально)

```powershell
dart run meshpad_p2p_sidecar
# или
cargo run -p meshpad_p2p_native
```

Sidecar по умолчанию: `http://127.0.0.1:45839`. Wire format совместим с LAN codec — см. [SYNC_WIRE.md](SYNC_WIRE.md).

Подробности API sidecar: [native/meshpad_p2p_sidecar/README.md](../native/meshpad_p2p_sidecar/README.md), [native/meshpad_p2p_native/README.md](../native/meshpad_p2p_native/README.md).
