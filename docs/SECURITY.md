# MeshPad — threat model (кратко)

Документ для LAN sync и headless API. Не заменяет полный security audit.

## Модель доверия

| Компонент | Доверие |
|-----------|---------|
| **LAN sync** | Только устройства после **PIN-pairing**; shared auth token (secure storage на клиенте) |
| **Web client** | Доверяет **headless server** + опциональный **API key**; браузер не участвует в LAN sync |
| **FS** | Источник истины на устройстве; индекс Drift восстанавливается из FS |

## LAN (production)

- Трафик sync: HTTPS `:45840` с **pinning** сертификата после pairing; fallback HTTP `:45838` в доверенной сети.
- Заголовки `X-MeshPad-Peer-Id` + `X-MeshPad-Auth-Token` на `/meshpad/p2p/*` (кроме pairing/health).
- Вложения: те же лимиты размера/типа, что и Web API (см. `attachment_upload_policy.dart`).
- Токен **не** хранится в `trusted/*.json` (см. [ARCHITECTURE.md](ARCHITECTURE.md)).
- Риски: утечка token → отзыв trust; изоляция клиентов на роутере; подмена DNS/mDNS в гостевой сети → используйте manual peer + PIN.

## Web API (`meshpad_server`)

- Аутентификация: опциональный **`X-MeshPad-Api-Key`** на `/api/*` (кроме `/api/health`).
- **CSRF:** для API key в заголовке CSRF **не критичен** (не cookie-based session); не встраивайте ключ в URL.
- **SSE** `/api/events`: тот же API key; буфер replay по `Last-Event-ID` (см. [SYNC_WIRE.md](SYNC_WIRE.md)).
- **Rate limit:** ~120 запросов/мин на IP (`api_rate_limit.dart`); `/api/health` и `OPTIONS` без лимита.
- **Upload:** `PUT /api/notes/.../attachments/...` — allowlist расширений, max **100 MB** (`attachment_upload_policy.dart`).
- Сервер слушает интерфейс по умолчанию — не выставляйте в интернет без reverse proxy + TLS + firewall.

## Device signing keys (волна 2.7)

- При первом запуске создаётся **Ed25519** пара: `signing_public_key` + `signing_key_algorithm` в `local_identity.json`.
- **Приватный ключ** не в JSON: `flutter_secure_storage` (Android/Windows) или `devices/.device_signing_key` (headless/tests).
- При pairing обмениваются `signing_public_key` (offer + confirm).
- LAN sync: если у trusted peer есть `signing_public_key`, каждый запрос подписывается (`X-MeshPad-Timestamp` + `X-MeshPad-Signature`); см. [SYNC_WIRE.md](SYNC_WIRE.md).

## Вне scope 0.3.x

- E2EE поверх note body (волна 2.9+)
- Formal penetration test

## Рекомендации

1. Production Web: всегда **API key** + HTTPS reverse proxy.
2. LAN: отключите «изоляцию клиентов» на роутере для pairing; иначе **ручной IP:port**.
3. Регулярный **export** zip в настройках как offline backup.
