param(
  [string]$BindHost = "127.0.0.1",
  [int]$Port = 8787
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Write-Host "Starting MeshPad server on http://${BindHost}:${Port} ..."
$serverJob = Start-Job -ScriptBlock {
  param($Root, $BindHost, $Port)
  Set-Location (Join-Path $Root "apps\meshpad_server")
  dart run bin/meshpad_server.dart --host $BindHost --port $Port
} -ArgumentList $root, $BindHost, $Port

Start-Sleep -Seconds 2

try {
  Write-Host "Launching Flutter Web client (chrome)..."
  Set-Location (Join-Path $root "apps\meshpad")
  flutter run -d chrome
} finally {
  Stop-Job $serverJob -ErrorAction SilentlyContinue
  Remove-Job $serverJob -Force -ErrorAction SilentlyContinue
}
