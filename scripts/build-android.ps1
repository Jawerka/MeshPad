#Requires -Version 5.1
<#
.SYNOPSIS
  Build MeshPad release APK and copy it to a fixed destination (overwrite).

.PARAMETER OutputDir
  Folder that receives meshpad.apk after a successful build.

.EXAMPLE
  .\scripts\build-android.ps1
  .\scripts\build-android.ps1 -OutputDir "D:\releases\meshpad"
#>
param(
    [string] $OutputDir = "V:\files\Documents\A56\Documents\meshpad"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$InitialLocation = Save-Location
try {
    $Root = Split-Path -Parent $PSScriptRoot
    $AppDir = Join-Path $Root "apps\meshpad"
    $FlutterBin = Join-Path $env:LOCALAPPDATA "flutter\bin"
    $JavaHome = "C:\Program Files\Android\Android Studio\jbr"
    $AndroidSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"

    if (-not (Test-Path (Join-Path $FlutterBin "flutter.bat"))) {
        throw "Flutter not found. Run .\scripts\setup.ps1 first."
    }

    if (Test-Path $JavaHome) { $env:JAVA_HOME = $JavaHome }
    if (Test-Path $AndroidSdk) {
        $env:ANDROID_HOME = $AndroidSdk
        $env:ANDROID_SDK_ROOT = $AndroidSdk
    }

    $env:Path = "$FlutterBin;$env:Path"

    $ApkSource = Join-Path $AppDir "build\app\outputs\flutter-apk\app-release.apk"
    $ApkName = "meshpad.apk"
    $ApkDest = Join-Path $OutputDir $ApkName

    Write-Host "Building MeshPad release APK..."
    $script:BuildExitCode = 0
    Invoke-InDirectory $AppDir {
        flutter build apk --release
        $script:BuildExitCode = $LASTEXITCODE
    }
    if ($BuildExitCode -ne 0) {
        exit $BuildExitCode
    }

    if (-not (Test-Path $ApkSource)) {
        throw "Build finished but APK not found: $ApkSource"
    }

    if (-not (Test-Path $OutputDir)) {
        Write-Host "Creating output folder: $OutputDir"
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    Copy-Item -Path $ApkSource -Destination $ApkDest -Force
    Write-Host ""
    Write-Host "APK copied to: $ApkDest" -ForegroundColor Green
} finally {
    Restore-Location $InitialLocation
}
