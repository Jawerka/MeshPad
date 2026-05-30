param(
  [string]$DataDir = ".\var\meshpad",
  [string]$BindHost = "127.0.0.1",
  [int]$Port = 8787
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Push-Location (Join-Path $root "apps\meshpad_server")
try {
  dart run bin/meshpad_server.dart --data-dir $DataDir --host $BindHost --port $Port
} finally {
  Pop-Location
}
