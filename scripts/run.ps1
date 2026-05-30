#Requires -Version 5.1
<#
.SYNOPSIS
  Run MeshPad (Flutter app).

.PARAMETER Device
  Target: windows, chrome, android, or device id from `flutter devices`.

.EXAMPLE
  .\scripts\run.ps1
  .\scripts\run.ps1 -Device chrome
#>
param(
    [string] $Device = "windows"
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

    function Test-DeveloperModeEnabled {
        try {
            $key = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -ErrorAction SilentlyContinue
            return $key.AllowDevelopmentWithoutDevLicense -eq 1
        } catch {
            return $false
        }
    }

    if (-not (Test-Path (Join-Path $FlutterBin "flutter.bat"))) {
        throw "Flutter not found. Run .\scripts\setup.ps1 first."
    }

    if ($Device -eq "windows" -and -not (Test-DeveloperModeEnabled)) {
        Write-Host ""
        Write-Host "WARNING: Windows Developer Mode is OFF." -ForegroundColor Yellow
        Write-Host "Flutter plugins need symlink support. Enable Developer Mode, then retry."
        Write-Host ""
        Write-Host "  1. Win+I -> Privacy & security -> For developers -> Developer Mode ON"
        Write-Host "  2. Or run:  start ms-settings:developers"
        Write-Host ""
        $open = Read-Host "Open settings now? [Y/n]"
        if ($open -ne "n" -and $open -ne "N") {
            Start-Process "ms-settings:developers"
        }
        Write-Host ""
    }

    if (Test-Path $JavaHome) { $env:JAVA_HOME = $JavaHome }
    if (Test-Path $AndroidSdk) {
        $env:ANDROID_HOME = $AndroidSdk
        $env:ANDROID_SDK_ROOT = $AndroidSdk
    }

    $env:Path = "$FlutterBin;$env:Path"

    Write-Host "Running MeshPad from $AppDir (device: $Device)"
    $script:RunExitCode = 0
    Invoke-InDirectory $AppDir {
        flutter run -d $Device
        $script:RunExitCode = $LASTEXITCODE
    }
    if ($RunExitCode -ne 0) {
        if ($Device -eq "windows") {
            Write-Host ""
            Write-Host "If you saw 'symlink support' error: enable Developer Mode and run again." -ForegroundColor Yellow
        }
        exit $RunExitCode
    }
} finally {
    Restore-Location $InitialLocation
}
