# Builds meshpad-<version>-windows-x64-setup.exe via Inno Setup 6 (PLAN §11.9.2).
param(
    [Parameter(Mandatory)]
    [string]$Version,
    [Parameter(Mandatory)]
    [string]$ReleaseDir,
    [string]$OutputDir = ".",
    [string]$IssFile
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
if (-not $IssFile) {
    $IssFile = Join-Path $PSScriptRoot 'windows\meshpad.iss'
}

$releasePath = Resolve-Path $ReleaseDir
$exe = Join-Path $releasePath 'meshpad.exe'
if (-not (Test-Path $exe)) {
    throw "Release build not found: $exe (run flutter build windows --release first)"
}

$outputPath = Resolve-Path -LiteralPath $OutputDir -ErrorAction SilentlyContinue
if (-not $outputPath) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    $outputPath = Resolve-Path $OutputDir
}

$isccCandidates = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
)
$iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    throw @"
Inno Setup 6 not found. Install from https://jrsoftware.org/isinfo.php
  choco install innosetup -y
"@
}

Write-Host "Packaging MeshPad $Version from $releasePath"
& $iscc $IssFile `
    "/DMyAppVersion=$Version" `
    "/DReleaseDir=$releasePath" `
    "/DOutputDir=$outputPath"

$setup = Join-Path $outputPath "meshpad-$Version-windows-x64-setup.exe"
if (-not (Test-Path $setup)) {
    throw "Installer was not created: $setup"
}
Write-Host "Created $setup"
