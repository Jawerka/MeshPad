#Requires -Version 5.1
<#
.SYNOPSIS
  Connect to an Android device over the network via ADB (wireless debugging).

.PARAMETER DeviceIp
  Phone IP on the LAN (e.g. 192.168.88.3).

.PARAMETER PairingPort
  Port from "Pair device with pairing code" (wireless debugging dialog).

.PARAMETER ConnectPort
  Port from the main Wireless debugging screen (IP address & port). Used for adb connect.

.PARAMETER PairingCode
  Six-digit code from the pairing dialog. Required with -Pair. Expires quickly — use a fresh code.

.PARAMETER Pair
  Run adb pair before adb connect.

.PARAMETER Address
  Legacy: host:port for connect-only (no pairing). Prefer -DeviceIp and -ConnectPort.

.EXAMPLE
  # After pairing once, reconnect until ports change:
  .\scripts\connect-adb.ps1 -DeviceIp 192.168.88.3 -ConnectPort 40699

.EXAMPLE
  # First time (ports from phone — pairing port != connect port):
  .\scripts\connect-adb.ps1 -DeviceIp 192.168.88.3 -PairingPort 38817 -ConnectPort 40699 -Pair -PairingCode 183476
#>
param(
    [string] $DeviceIp,

    [int] $PairingPort = 0,

    [int] $ConnectPort = 0,

    [string] $PairingCode,

    [switch] $Pair,

    [string] $Address
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$AndroidSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$Adb = Join-Path $AndroidSdk "platform-tools\adb.exe"

if (-not (Test-Path $Adb)) {
    throw "adb not found at $Adb. Install Android SDK platform-tools (Android Studio SDK Manager)."
}

function Invoke-Adb {
    param([Parameter(ValueFromRemainingArguments)][string[]] $Args)
    & $Adb @Args
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

if ($Address -and -not $DeviceIp) {
    $parts = $Address -split ':', 2
    $DeviceIp = $parts[0]
    if ($parts.Length -gt 1 -and -not $ConnectPort) {
        $ConnectPort = [int]$parts[1]
    }
}

if (-not $DeviceIp) {
    throw "Specify -DeviceIp (and -ConnectPort) or -Address host:port."
}

if (-not $ConnectPort) {
    throw "Specify -ConnectPort (main wireless debugging port on the phone)."
}

$pairTarget = $null
if ($PairingPort -gt 0) {
    $pairTarget = "${DeviceIp}:$PairingPort"
} elseif ($Pair -and $Address) {
    $pairTarget = $Address
}

if ($Pair) {
    if (-not $PairingCode) {
        throw "Wireless debugging pairing requires -PairingCode (6 digits from the phone)."
    }
    if (-not $pairTarget) {
        throw "Pairing needs -PairingPort (from 'Pair device with pairing code'), not -ConnectPort."
    }
    Write-Host "Pairing with $pairTarget ..."
    Write-Host "(Use the pairing port from the pairing dialog, not the main debug port.)" -ForegroundColor DarkGray
    Invoke-Adb pair $pairTarget $PairingCode
}

$connectTarget = "${DeviceIp}:$ConnectPort"
Write-Host "Connecting to $connectTarget ..."
Invoke-Adb connect $connectTarget
Write-Host ""
Invoke-Adb devices -l
