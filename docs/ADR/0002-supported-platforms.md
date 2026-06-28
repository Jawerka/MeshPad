# ADR 0002: Поддерживаемые платформы

| Поле | Значение |
|------|----------|
| Статус | **Accepted** |
| Дата | 2026-06-01 |
| Заменяет | ADR 0001 (iOS target, удалён) |

## Решение

Клиент MeshPad (`apps/meshpad`) поддерживает **только**:

- **Windows**
- **Android**
- **Linux (Ubuntu)**

**iOS** и **macOS** не разрабатываются: каталоги `ios/` и `macos/` удалены, CI-сборки Apple отключены.

**Web** не является поддерживаемой продуктовой платформой (см. [PLATFORMS.md](../PLATFORMS.md)).

## Ссылки

- [PLATFORMS.md](../PLATFORMS.md)
- [DEVELOPMENT.md](../DEVELOPMENT.md)
- [ARCHITECTURE.md](../ARCHITECTURE.md)
