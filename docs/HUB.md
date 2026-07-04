# MeshPad LAN Hub (Ubuntu)

Headless **равноправный peer** с веб-страницей PIN/QR для pairing. Store-and-forward: устройства синхронизируются с хабом в разное время; хаб хранит копии на диске.

## Требования

- Ubuntu 22.04 / 24.04 LTS
- Одна LAN/Wi‑Fi сеть с клиентами (без AP client isolation)
- `avahi-daemon` для mDNS (обычно уже установлен)

## Быстрая установка

```bash
# На машине сборки (Linux):
cd apps/meshpad_server
dart pub get
dart compile exe bin/meshpad_server.dart -o meshpad-hub

# На сервере Ubuntu (root):
sudo ./scripts/install-hub-ubuntu.sh ./meshpad-hub
```

Откройте в браузере: `http://<lan-ip>:8787/`

Страница показывает PIN и PNG QR (`GET /hub/qr.png`). SVG fallback: `/hub/qr.svg`.

## Ручной запуск (dev)

```bash
cd apps/meshpad_server
dart run meshpad_server --hub --data-dir ./var/meshpad-hub
```

## Порты

| Порт | Назначение |
|------|------------|
| 8787/tcp | Веб UI (PIN + QR) |
| 45837/udp | Discovery |
| 45838/tcp | LAN sync + pairing |
| 45840/tcp | LAN sync TLS |

## Pairing

1. На хабе откройте `http://192.168.x.x:8787/`
2. На Android: Устройства → сканировать QR или ввести IP:45838 + PIN
3. После pairing — автоматическая синхронизация

## Статус синхронизации

На главной странице хаба:

- **Индикатор** (зелёный / жёлтый / серый) — результат последней синхронизации
- **Заметок / в очереди / устройств** — локальное состояние хаба
- **Список устройств** — ✓ sync / ✗ offline после последнего прогона
- **Журнал** — последние события (pairing, sync)
- **Синхронизировать** — ручной запуск

API: `GET /hub/status` (JSON), `POST /hub/sync` (принудительный sync).

## systemd

```bash
sudo systemctl status meshpad-hub
sudo journalctl -u meshpad-hub -f
```

Конфиг: `/etc/meshpad/hub.env` (`MESHPAD_HUB_NAME`, опционально `MESHPAD_API_KEY` для `/api/*`).

## Troubleshooting

- **QR не открывается** — проверьте firewall (`ufw allow 45838/tcp`)
- **Устройства не видят друг друга** — отключите client isolation на роутере
- **mDNS** — `systemctl status avahi-daemon`

См. также [ARCHITECTURE.md](ARCHITECTURE.md), [SYNC_WIRE.md](SYNC_WIRE.md).
