#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$FlutterDir = Join-Path $env:LOCALAPPDATA "flutter"
$FlutterBin = Join-Path $FlutterDir "bin"

function Ensure-Flutter {
    if (Test-Path (Join-Path $FlutterBin "flutter.bat")) {
        Write-Host "Flutter SDK: $FlutterDir"
        return
    }
    Write-Host "Cloning Flutter stable to $FlutterDir ..."
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git is required. Install from https://git-scm.com/"
    }
    git clone --depth 1 -b stable https://github.com/flutter/flutter.git $FlutterDir
}

function Add-FlutterToPath {
    $env:Path = "$FlutterBin;" + $env:Path
}

Ensure-Flutter
Add-FlutterToPath

Write-Host "Running flutter doctor (may download Dart SDK on first run) ..."
$doctor = & "$FlutterBin\flutter.bat" doctor 2>&1
$doctor | Write-Host
if ($LASTEXITCODE -ne 0) {
    Write-Warning "flutter doctor failed. If Dart SDK download failed, check network access to storage.googleapis.com"
}

Set-Location $Root

if (Get-Command melos -ErrorAction SilentlyContinue) {
    Write-Host "melos found globally"
} else {
    Write-Host "Activating melos ..."
    & "$FlutterBin\dart.bat" pub global activate melos
    $PubCache = & "$FlutterBin\dart.bat" pub global list 2>$null
    $GlobalBin = Join-Path $env:LOCALAPPDATA "Pub\Cache\bin"
    if (Test-Path $GlobalBin) {
        $env:Path = "$GlobalBin;" + $env:Path
    }
}

if (Test-Path (Join-Path $Root "melos.yaml")) {
    if (Test-Path (Join-Path $Root "apps\meshpad\pubspec.yaml")) {
        Write-Host "Bootstrapping workspace ..."
        melos bootstrap
    } else {
        Write-Host "Workspace not bootstrapped yet. Run scripts\bootstrap.ps1 after apps exist."
    }
}

Write-Host ""
Write-Host "Setup complete. For a new shell, add to PATH:"
Write-Host "  $FlutterBin"
