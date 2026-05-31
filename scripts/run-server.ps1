param(
  [string]$DataDir = ".\var\meshpad",
  [string]$BindHost = "127.0.0.1",
  [int]$Port = 8787,
  [switch]$P2p,
  [int]$SyncIntervalMinutes = 15
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Push-Location (Join-Path $root "apps\meshpad_server")
try {
  $args = @("--data-dir", $DataDir, "--host", $BindHost, "--port", $Port)
  if ($P2p) {
    $args += @("--p2p", "--sync-interval", $SyncIntervalMinutes)
  }
  dart run bin/meshpad_server.dart @args
} finally {
  Pop-Location
}
