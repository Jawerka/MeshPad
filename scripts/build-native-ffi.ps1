# Builds meshpad_p2p_native cdylib and copies into Flutter runner/native (PLAN 8.4).
param(
    [ValidateSet('debug', 'release')]
    [string]$Profile = 'release'
)

$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifest = Join-Path $root 'native\meshpad_p2p_native\Cargo.toml'
$cargoArgs = @('build', '--manifest-path', $manifest, '--lib')
if ($Profile -eq 'release') { $cargoArgs += '--release' }

Write-Host "Building native FFI ($Profile)..."
& cargo @cargoArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$src = Join-Path $root "native\meshpad_p2p_native\target\$Profile\meshpad_p2p_native.dll"
if (-not (Test-Path $src)) {
    throw "Expected DLL not found: $src"
}

$dstDir = Join-Path $root 'apps\meshpad\windows\runner\native'
New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
Copy-Item -Path $src -Destination (Join-Path $dstDir 'meshpad_p2p_native.dll') -Force
Write-Host "Copied to $dstDir\meshpad_p2p_native.dll"
