#Requires -Version 5.1
<#
.SYNOPSIS
  Run MeshPad (Flutter app).

.PARAMETER Device
  Target device:
  - windows, chrome, or a device id from flutter devices
  - android - first connected phone/emulator (via adb)
  - dual / both / lan - Windows in a new window + Android in this terminal (LAN testing)

.PARAMETER AndroidDevice
  ADB device id for dual/android mode (e.g. 192.168.88.3:40699). Auto-detected if omitted.

.PARAMETER KeepWindowsOpen
  When using dual mode, leave the Windows flutter run window open after Android session ends.

.PARAMETER CollectLogs
  Dual mode only: stream Windows + Android logs to logs/latest-dual.log while running.

.PARAMETER LogOutFile
  Custom session log path (with -CollectLogs). Default: logs/sessions/<timestamp>.log

.EXAMPLE
  .\scripts\run.ps1
  .\scripts\run.ps1 -Device chrome
  .\scripts\run.ps1 -Device dual
  .\scripts\run.ps1 -Device dual -CollectLogs
  .\scripts\run.ps1 -Device dual -AndroidDevice 192.168.88.3:40699
#>
param(
    [string] $Device = "windows",
    [string] $AndroidDevice = "",
    [switch] $KeepWindowsOpen,
    [switch] $CollectLogs,
    [string] $LogOutFile = ""
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
    $AdbExe = Join-Path $AndroidSdk "platform-tools\adb.exe"
    $DeviceRunnerScript = Join-Path $PSScriptRoot "run-flutter-device.ps1"

    function Test-DeveloperModeEnabled {
        try {
            $key = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -ErrorAction SilentlyContinue
            return $key.AllowDevelopmentWithoutDevLicense -eq 1
        } catch {
            return $false
        }
    }

    function Initialize-MeshPadRunEnvironment {
        if (-not (Test-Path (Join-Path $FlutterBin "flutter.bat"))) {
            throw "Flutter not found. Run .\scripts\setup.ps1 first."
        }

        if (Test-Path $JavaHome) { $env:JAVA_HOME = $JavaHome }
        if (Test-Path $AndroidSdk) {
            $env:ANDROID_HOME = $AndroidSdk
            $env:ANDROID_SDK_ROOT = $AndroidSdk
            $PlatformTools = Join-Path $AndroidSdk "platform-tools"
            if (Test-Path $PlatformTools) {
                $env:Path = "$PlatformTools;$env:Path"
            }
        }

        $env:Path = "$FlutterBin;$env:Path"
    }

    function Get-DefaultAndroidDeviceId {
        if (-not (Test-Path $AdbExe)) {
            return $null
        }

        $lines = & $AdbExe devices | Select-Object -Skip 1 | Where-Object { $_ -match '\tdevice$' }
        if (-not $lines) {
            return $null
        }

        foreach ($line in $lines) {
            $id = ($line -split '\s+', 2)[0]
            if ($id -and $id -notmatch '^emulator-') {
                return $id
            }
        }

        return ($lines[0] -split '\s+', 2)[0]
    }

    function Resolve-AndroidDeviceId {
        param([string] $RequestedId)

        if ($RequestedId) {
            if (-not (Test-Path $AdbExe)) {
                throw "adb not found at $AdbExe"
            }
            $state = & $AdbExe -s $RequestedId get-state 2>&1
            if ($LASTEXITCODE -ne 0 -or $state -ne 'device') {
                throw "Android device '$RequestedId' is not ready (state: $state)"
            }
            return $RequestedId
        }

        $detected = Get-DefaultAndroidDeviceId
        if (-not $detected) {
            throw "No adb device in 'device' state. Connect the phone or pass -AndroidDevice."
        }
        return $detected
    }

    function Start-MeshPadFlutterRunWindow {
        param(
            [Parameter(Mandatory)]
            [string] $WorkingDir,
            [Parameter(Mandatory)]
            [string] $DeviceId,
            [string] $WindowTitle = "MeshPad"
        )

        if (-not (Test-Path $DeviceRunnerScript)) {
            throw "Missing helper script: $DeviceRunnerScript"
        }

        function Format-ProcessArgument {
            param([string] $Value)
            return '"' + ($Value -replace '"', '""') + '"'
        }

        # Start-Process splits unquoted values on spaces; pass one quoted command line.
        $argumentLine = @(
            '-NoExit'
            '-ExecutionPolicy Bypass'
            '-File ' + (Format-ProcessArgument $DeviceRunnerScript)
            '-WorkingDir ' + (Format-ProcessArgument $WorkingDir)
            '-DeviceId ' + (Format-ProcessArgument $DeviceId)
            '-WindowTitle ' + (Format-ProcessArgument $WindowTitle)
        ) -join ' '

        return Start-Process -FilePath 'powershell.exe' -PassThru -ArgumentList $argumentLine
    }

    function Stop-MeshPadWindowsApp {
        Get-Process -Name meshpad -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    Initialize-MeshPadRunEnvironment

    $isDual = $Device -in @('dual', 'both', 'lan')
    if ($Device -eq 'android') {
        $Device = Resolve-AndroidDeviceId -RequestedId $AndroidDevice
    }

    if ($isDual) {
        if (-not (Test-DeveloperModeEnabled)) {
            Write-Host ""
            Write-Host "WARNING: Windows Developer Mode is OFF." -ForegroundColor Yellow
            Write-Host "Flutter plugins need symlink support. Enable Developer Mode, then retry."
            Write-Host ""
            Write-Host "  1. Win+I -> Privacy and security -> For developers -> Developer Mode ON"
            Write-Host "  2. Or run:  start ms-settings:developers"
            Write-Host ""
            $open = Read-Host "Open settings now? [Y/n]"
            if ($open -ne "n" -and $open -ne "N") {
                Start-Process "ms-settings:developers"
            }
            Write-Host ""
        }

        $androidId = Resolve-AndroidDeviceId -RequestedId $AndroidDevice
        Write-Host "Dual run: Windows (new window) + Android ($androidId)"
        Write-Host "  Windows logs: separate PowerShell window"
        Write-Host "  Android logs: this terminal (meshpad:* lines)"
        if ($CollectLogs) {
            Write-Host "  Session logs: logs/latest-dual.log (merged, updated on exit)"
        } else {
            Write-Host "  Collect logs:   .\scripts\collect-logs.ps1 -Source both"
            Write-Host "  Or dual+logs:   .\scripts\run-dual-with-logs.ps1"
        }
        Write-Host "  Quit Android with q; Windows stops unless -KeepWindowsOpen"
        Write-Host ""

        $logSession = $null
        $logCollector = $null
        if ($CollectLogs) {
            . "$PSScriptRoot\_logging.ps1"
            $logSession = New-MeshPadLogSession -Root $Root -LogOutFile $LogOutFile
            $logCollector = Start-MeshPadDualLogCollector -Session $logSession -AndroidDeviceId $androidId
            Write-Host "Logging session: $($logSession.SessionLog)" -ForegroundColor Green
            Write-Host "Agent reads:       $($logSession.LatestLog)" -ForegroundColor Green
            Write-Host ""
        }

        $windowsShell = Start-MeshPadFlutterRunWindow `
            -WorkingDir $AppDir `
            -DeviceId windows `
            -WindowTitle "MeshPad Windows"

        if (-not $windowsShell) {
            throw "Failed to start Windows PowerShell window."
        }

        Write-Host "Windows session started (PID $($windowsShell.Id)). Waiting 5s for flutter..."
        Start-Sleep -Seconds 5

        $script:RunExitCode = 0
        try {
            Invoke-InDirectory $AppDir {
                flutter run -d $androidId
                $script:RunExitCode = $LASTEXITCODE
            }
        } finally {
            if ($CollectLogs -and $logSession) {
                Write-Host ""
                Write-Host "Finalizing log session..."
                Stop-MeshPadDualLogCollector -Session $logSession -Collector $logCollector -AndroidDeviceId $androidId
                Write-Host "Logs saved: $($logSession.LatestLog)" -ForegroundColor Green
            }
            if (-not $KeepWindowsOpen) {
                Write-Host ""
                Write-Host "Stopping Windows MeshPad..."
                Stop-MeshPadWindowsApp
                if ($windowsShell -and -not $windowsShell.HasExited) {
                    Stop-Process -Id $windowsShell.Id -Force -ErrorAction SilentlyContinue
                }
            } else {
                Write-Host ""
                Write-Host "Android session ended. Windows flutter run is still open in the other window."
            }
        }

        if ($RunExitCode -ne 0) {
            exit $RunExitCode
        }
        return
    }

    if ($Device -eq "windows" -and -not (Test-DeveloperModeEnabled)) {
        Write-Host ""
        Write-Host "WARNING: Windows Developer Mode is OFF." -ForegroundColor Yellow
        Write-Host "Flutter plugins need symlink support. Enable Developer Mode, then retry."
        Write-Host ""
        Write-Host "  1. Win+I -> Privacy and security -> For developers -> Developer Mode ON"
        Write-Host "  2. Or run:  start ms-settings:developers"
        Write-Host ""
        $open = Read-Host "Open settings now? [Y/n]"
        if ($open -ne "n" -and $open -ne "N") {
            Start-Process "ms-settings:developers"
        }
        Write-Host ""
    }

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
