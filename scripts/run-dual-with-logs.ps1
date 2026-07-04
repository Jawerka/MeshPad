#Requires -Version 5.1
<#
.SYNOPSIS
  Run MeshPad on Windows + Android and save merged LAN logs for later analysis.

.DESCRIPTION
  Starts dual flutter run (same as run.ps1 -Device dual) and streams Windows meshpad.log
  plus filtered Android logcat into logs/sessions/<timestamp>.log.
  On exit, copies the session to logs/latest-dual.log for the agent to read.

.PARAMETER AndroidDevice
  ADB device id (wireless or USB). Auto-detected if omitted.

.PARAMETER KeepWindowsOpen
  Leave the Windows flutter window open after the Android session ends.

.PARAMETER LogOutFile
  Custom session log path (default: logs/sessions/<timestamp>.log).

.EXAMPLE
  .\scripts\run-dual-with-logs.ps1
  .\dev.ps1 -Device dual -CollectLogs
#>
param(
    [string] $AndroidDevice = '',
    [switch] $KeepWindowsOpen,
    [string] $LogOutFile = ''
)

$ErrorActionPreference = 'Stop'
$runScript = Join-Path $PSScriptRoot 'run.ps1'
& $runScript -Device dual -CollectLogs -AndroidDevice $AndroidDevice -KeepWindowsOpen:$KeepWindowsOpen -LogOutFile $LogOutFile
exit $LASTEXITCODE
