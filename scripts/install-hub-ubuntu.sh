#!/usr/bin/env bash
set -euo pipefail

# Install MeshPad Hub on Ubuntu (22.04+).
# Usage: sudo ./scripts/install-hub-ubuntu.sh [/path/to/meshpad-hub-binary]

BINARY="${1:-./meshpad-hub}"
INSTALL_BIN="/usr/local/bin/meshpad-hub"
DATA_DIR="/var/lib/meshpad-hub"
CONFIG_DIR="/etc/meshpad"
CONFIG_FILE="${CONFIG_DIR}/hub.env"
SERVICE="scripts/meshpad-hub.service"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo $0 [binary-path]" >&2
  exit 1
fi

if [[ ! -f "${BINARY}" ]]; then
  echo "Binary not found: ${BINARY}" >&2
  exit 1
fi

id -u meshpad &>/dev/null || useradd --system --home "${DATA_DIR}" --shell /usr/sbin/nologin meshpad

install -m 0755 "${BINARY}" "${INSTALL_BIN}"
mkdir -p "${DATA_DIR}" "${CONFIG_DIR}"
chown -R meshpad:meshpad "${DATA_DIR}"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  cat >"${CONFIG_FILE}" <<'EOF'
# MESHPAD_HUB_NAME="MeshPad Hub"
# MESHPAD_API_KEY=
EOF
  chmod 0644 "${CONFIG_FILE}"
fi

install -m 0644 "${SERVICE}" /etc/systemd/system/meshpad-hub.service
systemctl daemon-reload
systemctl enable meshpad-hub
systemctl restart meshpad-hub

if command -v ufw >/dev/null 2>&1 && ufw status | grep -q 'Status: active'; then
  ufw allow 8787/tcp comment 'MeshPad Hub web' || true
  ufw allow 45837/udp comment 'MeshPad discovery' || true
  ufw allow 45838/tcp comment 'MeshPad LAN sync' || true
  ufw allow 45840/tcp comment 'MeshPad LAN sync TLS' || true
fi

echo "MeshPad Hub installed."
echo "Open http://$(hostname -I | awk '{print $1}'):8787/ on the LAN."
systemctl status meshpad-hub --no-pager || true
