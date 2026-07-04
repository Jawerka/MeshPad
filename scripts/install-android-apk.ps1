#Requires -Version 5.1
<#
.SYNOPSIS
  Install MeshPad release APK on a connected Android device via adb.

.PARAMETER ApkPath
  Path to APK. Defaults to the Flutter release output.

.PARAMETER DeviceId
  adb device serial (from adb devices). Auto-detected if omitted.

.PARAMETER Build
  Run build-android.ps1 before install.

.EXAMPLE
  .\scripts\install-android-apk.ps1 -Build
  .\scripts\install-android-apk.ps1 -ApkPath "apps\meshpad\build\app\outputs\flutter-apk\app-release.apk"
#>
param(
    [string] $ApkPath = "",
    [string] $DeviceId = "",
    [switch] $Build
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$InitialLocation = Save-Location
try {
    $Root = Split-Path -Parent $PSScriptRoot
    $DefaultApk = Join-Path $Root "apps\meshpad\build\app\outputs\flutter-apk\app-release.apk"
    $AndroidSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
    $Adb = Join-Path $AndroidSdk "platform-tools\adb.exe"

    if (-not (Test-Path $Adb)) {
        throw "adb not found at $Adb. Install Android SDK platform-tools."
    }

    if ($Build) {
        & "$PSScriptRoot\build-android.ps1"
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    if ([string]::IsNullOrWhiteSpace($ApkPath)) {
        $ApkPath = $DefaultApk
    }

    if (-not (Test-Path $ApkPath)) {
        throw "APK not found: $ApkPath. Run .\scripts\build-android.ps1 first."
    }

    function Resolve-DeviceId {
        param([string] $Requested)
        if ($Requested) {
            $state = & $Adb -s $Requested get-state 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Device not ready: $Requested ($state)"
            }
            return $Requested
        }

        $lines = & $Adb devices | Select-Object -Skip 1 | Where-Object {
            $_.Trim() -match '\sdevice(\s|$)'
        }
        if (-not $lines) {
            throw @"
No adb device connected.
  - Connect USB and enable USB debugging, or
  - Run .\scripts\connect-adb.ps1 -DeviceIp <IP> -ConnectPort <port>
"@
        }

        $firstLine = @($lines)[0].ToString().Trim()
        $first = ($firstLine -split '\s+', 2)[0]
        if ($lines.Count -gt 1) {
            Write-Host "Multiple devices; using $first (pass -DeviceId to override)" -ForegroundColor Yellow
        }
        return $first
    }

    $device = Resolve-DeviceId -Requested $DeviceId
    Write-Host "Installing $ApkPath on $device ..."
    & $Adb @('-s', $device, 'install', '-r', '-d', $ApkPath)
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    Write-Host ""
    Write-Host "MeshPad installed successfully." -ForegroundColor Green
    Write-Host "Launch the app on the phone and pair with Windows on the same Wi-Fi."
} finally {
    Restore-Location $InitialLocation
}
