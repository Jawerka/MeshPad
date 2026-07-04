#Requires -Version 5.1
# Build MeshPad Hub on a remote Ubuntu host and restart meshpad-hub.service.
# Usage: .\scripts\deploy-hub.ps1 [-RemoteHost 192.168.88.48] [-RemoteUser root]

param(
  [string]$RemoteHost = "192.168.88.48",
  [string]$RemoteUser = "root",
  [string]$RemoteWorkDir = "/tmp/meshpad-hub-build"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$root = Get-MeshPadRoot
$archive = Join-Path $env:TEMP "meshpad-hub-src.tgz"
$remoteScript = Join-Path $env:TEMP "meshpad-hub-deploy.sh"

Write-Host "Packing hub workspace..."
if (Test-Path $archive) { Remove-Item -Force $archive }

$packRoot = Join-Path $env:TEMP "meshpad-hub-pack"
if (Test-Path $packRoot) { Remove-Item -Recurse -Force $packRoot }
New-Item -ItemType Directory -Path $packRoot | Out-Null

$paths = @(
  "apps/meshpad_server",
  "packages/meshpad_core",
  "packages/meshpad_p2p",
  "packages/meshpad_api_client",
  "native/meshpad_p2p_sidecar",
  "scripts/install-hub-ubuntu.sh",
  "scripts/meshpad-hub.service"
)
foreach ($rel in $paths) {
  $src = Join-Path $root $rel
  $dst = Join-Path $packRoot $rel
  $parent = Split-Path -Parent $dst
  if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  Copy-Item -Recurse -Force $src $dst
}

Copy-Item -Force (Join-Path $root "scripts/hub-workspace-pubspec.yaml") (Join-Path $packRoot "pubspec.yaml")

Push-Location $packRoot
try {
  & tar -czf $archive .
} finally {
  Pop-Location
}
Remove-Item -Recurse -Force $packRoot

$scriptBody = @'
#!/usr/bin/env bash
set -euo pipefail
REMOTE_WORK="__REMOTE_WORK__"
ARCHIVE="${REMOTE_WORK}.tgz"
rm -rf "$REMOTE_WORK"
mkdir -p "$REMOTE_WORK"
tar -xzf "$ARCHIVE" -C "$REMOTE_WORK"
cd "$REMOTE_WORK"
echo "[hub] dart pub get (workspace)..."
dart pub get
cd apps/meshpad_server
echo "[hub] dart pub get (server)..."
dart pub get
echo "[hub] dart compile exe (may take several minutes)..."
dart compile exe bin/meshpad_server.dart -o meshpad-hub
echo "[hub] install + restart..."
install -m 0755 meshpad-hub /usr/local/bin/meshpad-hub
systemctl restart meshpad-hub
sleep 2
systemctl is-active meshpad-hub
curl -sf http://127.0.0.1:8787/hub/status | head -c 200
echo
'@ -replace '__REMOTE_WORK__', $RemoteWorkDir
[System.IO.File]::WriteAllText($remoteScript, ($scriptBody -replace "`r`n", "`n"))

$remote = "${RemoteUser}@${RemoteHost}"
Write-Host "Uploading to $remote..."
scp $archive "${remote}:${RemoteWorkDir}.tgz"
scp $remoteScript "${remote}:/tmp/meshpad-hub-deploy.sh"

Write-Host "Building and installing on server..."
ssh $remote "chmod +x /tmp/meshpad-hub-deploy.sh && /tmp/meshpad-hub-deploy.sh"

Write-Host "Hub deployed. Open http://${RemoteHost}:8787/"
