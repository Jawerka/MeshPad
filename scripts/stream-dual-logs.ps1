#Requires -Version 5.1
<#
.SYNOPSIS
  Background dual log streamer (Windows meshpad.log + Android logcat).

  Started by run.ps1 -CollectLogs / run-dual-with-logs.ps1 — not for direct use.
#>
param(
    [Parameter(Mandatory)]
    [string] $OutFile,
    [Parameter(Mandatory)]
    [string] $AndroidDeviceId,
    [Parameter(Mandatory)]
    [string] $StopFile
)

$ErrorActionPreference = 'SilentlyContinue'
. "$PSScriptRoot\_logging.ps1"

function Write-StreamLine {
    param(
        [string] $Source,
        [string] $Line
    )
    if (-not $Line) { return }
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    [IO.File]::AppendAllText(
        $OutFile,
        "[$ts] [$Source] $Line`r`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Read-NewWindowsLines {
    param(
        [string] $Path,
        [ref] $Offset
    )
    if (-not (Test-Path -LiteralPath $Path)) { return }

    $stream = $null
    $reader = $null
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        if ($stream.Length -le $Offset.Value) { return }
        $stream.Position = $Offset.Value
        $reader = New-Object IO.StreamReader($stream)
        while ($null -ne ($line = $reader.ReadLine())) {
            Write-StreamLine 'Windows' $line
        }
        $Offset.Value = $stream.Position
    } catch {
        # Windows app may rotate/truncate the log while we read.
    } finally {
        if ($reader) { $reader.Dispose() }
        if ($stream) { $stream.Dispose() }
    }
}

function Read-NewAndroidLines {
    param(
        [string] $Path,
        [ref] $Offset
    )
    if (-not (Test-Path -LiteralPath $Path)) { return }

    $stream = $null
    $reader = $null
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        if ($stream.Length -le $Offset.Value) { return }
        $stream.Position = $Offset.Value
        $reader = New-Object IO.StreamReader($stream)
        while ($null -ne ($line = $reader.ReadLine())) {
            if (Test-MeshPadAndroidLogLine $line) {
                Write-StreamLine 'Android' $line
            }
        }
        $Offset.Value = $stream.Position
    } finally {
        if ($reader) { $reader.Dispose() }
        if ($stream) { $stream.Dispose() }
    }
}

$winPath = Get-MeshPadWindowsLogPath
$winOffset = 0L
if (Test-Path -LiteralPath $winPath) {
    $winOffset = (Get-Item -LiteralPath $winPath).Length
}

$adb = Get-AdbPath
$adbLogFile = Join-Path ([IO.Path]::GetTempPath()) "meshpad-adb-$PID.log"
if (Test-Path -LiteralPath $adbLogFile) {
    Remove-Item -LiteralPath $adbLogFile -Force
}

& $adb -s $AndroidDeviceId logcat -c | Out-Null

Write-StreamLine 'session' '=== MeshPad dual log stream started ==='
Write-StreamLine 'session' "Windows log: $winPath"
Write-StreamLine 'session' "Android device: $AndroidDeviceId"

$adbProcess = Start-Process -FilePath $adb `
    -ArgumentList @('-s', $AndroidDeviceId, 'logcat', '-v', 'time') `
    -RedirectStandardOutput $adbLogFile `
    -NoNewWindow `
    -PassThru

$adbOffset = 0L
$winOffsetRef = [ref]$winOffset
$adbOffsetRef = [ref]$adbOffset

while (-not (Test-Path -LiteralPath $StopFile)) {
    Read-NewWindowsLines -Path $winPath -Offset $winOffsetRef
    Read-NewAndroidLines -Path $adbLogFile -Offset $adbOffsetRef
    Start-Sleep -Milliseconds 300
}

Read-NewWindowsLines -Path $winPath -Offset $winOffsetRef
Read-NewAndroidLines -Path $adbLogFile -Offset $adbOffsetRef

if ($adbProcess -and -not $adbProcess.HasExited) {
    Stop-Process -Id $adbProcess.Id -Force -ErrorAction SilentlyContinue
}
Remove-Item -LiteralPath $adbLogFile -Force -ErrorAction SilentlyContinue

Write-StreamLine 'session' '=== MeshPad dual log stream ended ==='
