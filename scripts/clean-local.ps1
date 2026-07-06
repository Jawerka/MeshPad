# Remove local dev artifacts (safe — nothing here is required in git).
param(
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$patterns = @(
    'meshpad.apk',
    'meshpad-*.apk',
    'meshpad-*-windows-x64.zip',
    'meshpad-*-windows-x64-setup.exe',
    'meshpad-hub'
)

foreach ($pattern in $patterns) {
    Get-ChildItem -Path $root -Filter $pattern -File -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

foreach ($dir in @('logs', 'dist', 'data', 'var', 'coverage')) {
    $path = Join-Path $root $dir
    if (Test-Path $path) {
        Remove-Item -Recurse -Force $path
        Write-Host "Removed $dir/"
    }
}

if ($Build) {
    dart run melos clean
    Write-Host 'melos clean done'
}

Write-Host 'Local cleanup complete.'
