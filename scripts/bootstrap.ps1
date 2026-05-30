#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$FlutterBin = Join-Path $env:LOCALAPPDATA "flutter\bin"

if (Test-Path (Join-Path $FlutterBin "flutter.bat")) {
    $env:Path = "$FlutterBin;" + $env:Path
}

Set-Location $Root

& "$PSScriptRoot\setup.ps1"

$AppDir = Join-Path $Root "apps\meshpad"
if (-not (Test-Path (Join-Path $AppDir "pubspec.yaml"))) {
    Write-Host "Creating Flutter app in apps/meshpad ..."
    New-Item -ItemType Directory -Force -Path (Join-Path $Root "apps") | Out-Null
    & flutter create --org com.meshpad --project-name meshpad `
        --platforms=android,windows,linux,web `
        $AppDir
} elseif (-not (Test-Path (Join-Path $AppDir "windows"))) {
    Write-Host "Adding platform folders to existing app ..."
    Set-Location $AppDir
    & flutter create --org com.meshpad --project-name meshpad `
        --platforms=android,windows,linux,web .
    Set-Location $Root
}

# Ensure packages exist (bootstrap.ps1 may be re-run)
$CoreDir = Join-Path $Root "packages\meshpad_core"
if (-not (Test-Path (Join-Path $CoreDir "pubspec.yaml"))) {
    Write-Host "Run full bootstrap after packages/meshpad_core is committed."
}

melos bootstrap

Write-Host "Bootstrap finished."
