#Requires -Version 5.1
<#
.SYNOPSIS
  Legacy wrapper — use collect-logs.ps1 instead.

.EXAMPLE
  .\scripts\collect-lan-logs.ps1 -Seconds 30
#>
param(
    [string] $Device,
    [int] $Seconds = 20,
    [string] $OutFile = ""
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$args = @('-Source', 'android', '-Seconds', $Seconds, '-Tail', '500')
if ($Device) { $args += @('-Device', $Device) }
if ($OutFile) { $args += @('-OutFile', $OutFile) }
& (Join-Path $scriptDir 'collect-logs.ps1') @args
