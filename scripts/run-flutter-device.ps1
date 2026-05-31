#Requires -Version 5.1
<#
.SYNOPSIS
  Helper: run MeshPad via flutter on one device (used by run.ps1 -Device dual).
#>
param(
    [Parameter(Mandatory)]
    [string] $WorkingDir,
    [Parameter(Mandatory)]
    [string] $DeviceId,
    [string] $WindowTitle = "MeshPad"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

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
    $platformTools = Join-Path $AndroidSdk "platform-tools"
    if (Test-Path $platformTools) {
        $env:Path = "$platformTools;$env:Path"
    }
}
$env:Path = "$FlutterBin;$env:Path"

$host.UI.RawUI.WindowTitle = $WindowTitle
Write-Host "MeshPad flutter run -d $DeviceId"
Write-Host "Directory: $WorkingDir"
Write-Host ""

Invoke-InDirectory $WorkingDir {
    flutter run -d $DeviceId
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
