#Requires -Version 5.1
<#
.SYNOPSIS
  Read MeshPad logs from a local Windows data dir and/or a connected Android device.

.DESCRIPTION
  Windows: tails {dataDir}/meshpad.log (path from %LOCALAPPDATA%\MeshPad\app_settings.json).
  Android: adb logcat filtered to meshpad:* lines (same prefix as I/flutter print).

.PARAMETER Source
  auto   - both when adb device is connected, otherwise windows only
  windows - local log file only
  android - adb logcat only
  both    - windows file + android logcat

.EXAMPLE
  .\scripts\collect-logs.ps1
  .\scripts\collect-logs.ps1 -Source both -Tail 300
  .\scripts\collect-logs.ps1 -Source android -Seconds 30 -OutFile dual.log
  .\scripts\collect-logs.ps1 -Follow
#>
param(
    [ValidateSet('auto', 'windows', 'android', 'both')]
    [string] $Source = 'auto',
    [string] $Device,
    [int] $Tail = 200,
    [int] $Seconds = 0,
    [switch] $Follow,
    [string] $OutFile = ''
)

$ErrorActionPreference = 'Stop'

function Get-MeshPadWindowsLogPath {
    $settingsPath = Join-Path $env:LOCALAPPDATA 'MeshPad\app_settings.json'
    $dataDir = $null
    if (Test-Path $settingsPath) {
        try {
            $json = Get-Content -Raw -Encoding UTF8 $settingsPath | ConvertFrom-Json
            if ($json.data_dir) { $dataDir = [string]$json.data_dir }
        } catch {
            Write-Warning "Failed to parse $settingsPath : $_"
        }
    }
    if (-not $dataDir) {
        $support = Join-Path $env:LOCALAPPDATA 'MeshPad'
        if (-not (Test-Path $support)) {
            $support = Join-Path $env:APPDATA 'com.meshpad.meshpad'
        }
        $dataDir = Join-Path $support 'meshpad'
    }
    return (Join-Path $dataDir 'meshpad.log')
}

function Get-AdbPath {
    $adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    if (-not (Test-Path $adb)) { throw "adb not found at $adb" }
    return $adb
}

function Resolve-AdbDevice {
    param([string] $RequestedId)
    $adb = Get-AdbPath
    if ($RequestedId) {
        $state = & $adb -s $RequestedId get-state 2>&1
        if ($LASTEXITCODE -ne 0 -or $state -ne 'device') {
            throw "Android device '$RequestedId' is not ready (state: $state)"
        }
        return $RequestedId
    }
    $lines = & $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\tdevice$' }
    if (-not $lines) { return $null }
    foreach ($line in $lines) {
        $id = ($line -split '\s+', 2)[0]
        if ($id -and $id -notmatch '^emulator-') { return $id }
    }
    return ($lines[0] -split '\s+', 2)[0]
}

function Read-WindowsLogs {
    param([int] $LineCount, [switch] $Wait)
    $path = Get-MeshPadWindowsLogPath
    Write-Host "Windows log: $path" -ForegroundColor Cyan
    if (-not (Test-Path $path)) {
        Write-Warning 'Local log file not found yet. Start MeshPad on Windows to create it.'
        return @()
    }
    if ($Wait) {
        Get-Content -Path $path -Wait -Tail $LineCount -Encoding UTF8
        return @()
    }
    return Get-Content -Path $path -Tail $LineCount -Encoding UTF8
}

function Read-AndroidLogs {
    param(
        [string] $DeviceId,
        [int] $LineCount,
        [int] $CaptureSeconds,
        [switch] $Wait
    )
    $adb = Get-AdbPath
    $pattern = 'meshpad:|45837|45838|_meshpad|Dart Socket ERROR'
    Write-Host "Android device: $DeviceId" -ForegroundColor Cyan

    if ($CaptureSeconds -gt 0) {
        Write-Host "Capturing ${CaptureSeconds}s..."
        & $adb -s $DeviceId logcat -c | Out-Null
        Start-Sleep -Seconds $CaptureSeconds
    }

    if ($Wait) {
        & $adb -s $DeviceId logcat -v time | Select-String -Pattern $pattern -CaseSensitive:$false
        return @()
    }

    $raw = & $adb -s $DeviceId logcat -d -v time 2>&1
    $filtered = $raw | Select-String -Pattern $pattern -CaseSensitive:$false
    if ($LineCount -gt 0) {
        return $filtered | Select-Object -Last $LineCount | ForEach-Object { $_.Line }
    }
    return $filtered | ForEach-Object { $_.Line }
}

$adbDevice = Resolve-AdbDevice -RequestedId $Device
$useAndroid = $Source -in @('android', 'both') -or ($Source -eq 'auto' -and $adbDevice)
$useWindows = $Source -in @('windows', 'both') -or ($Source -eq 'auto')

if ($Source -eq 'android' -and -not $adbDevice) {
    throw 'No adb device connected. Use -Source windows or connect the phone.'
}

$combined = New-Object System.Collections.Generic.List[string]

if ($Follow) {
    if ($useWindows -and $useAndroid) {
        Write-Host 'Follow mode supports one source at a time. Using Windows log file.' -ForegroundColor Yellow
        $useAndroid = $false
    }
    if ($useWindows) {
        Read-WindowsLogs -LineCount $Tail -Wait
        exit 0
    }
    if ($useAndroid) {
        Read-AndroidLogs -DeviceId $adbDevice -LineCount $Tail -Wait
        exit 0
    }
    throw 'Nothing to follow.'
}

if ($useWindows) {
    $combined.Add('=== Windows ===')
    $combined.AddRange([string[]](Read-WindowsLogs -LineCount $Tail))
}

if ($useAndroid) {
    $combined.Add('')
    $combined.Add('=== Android ===')
    $combined.AddRange([string[]](Read-AndroidLogs -DeviceId $adbDevice -LineCount $Tail -CaptureSeconds $Seconds))
}

if ($OutFile) {
    $combined | Set-Content -Encoding utf8 $OutFile
    Write-Host "Saved $($combined.Count) lines to $OutFile"
} else {
    $combined | ForEach-Object { $_ }
}
