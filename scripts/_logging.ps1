# Shared log path helpers for collect-logs.ps1 and stream-dual-logs.ps1.

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

function Get-MeshPadAndroidLogPattern {
    return 'meshpad:|45837|45838|_meshpad|Dart Socket ERROR'
}

function Test-MeshPadAndroidLogLine {
    param([string] $Line)
    if (-not $Line) { return $false }
    return $Line -match (Get-MeshPadAndroidLogPattern)
}

function New-MeshPadLogSession {
    param(
        [string] $Root,
        [string] $LogOutFile = ''
    )

    $logsDir = Join-Path $Root 'logs'
    $sessionsDir = Join-Path $logsDir 'sessions'
    New-Item -ItemType Directory -Force -Path $sessionsDir | Out-Null

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $sessionLog = if ($LogOutFile) {
        $LogOutFile
    } else {
        Join-Path $sessionsDir "$stamp.log"
    }

    $sessionDir = Split-Path -Parent $sessionLog
    if ($sessionDir -and -not (Test-Path $sessionDir)) {
        New-Item -ItemType Directory -Force -Path $sessionDir | Out-Null
    }

    return @{
        Stamp       = $stamp
        LogsDir     = $logsDir
        SessionLog  = $sessionLog
        LatestLog   = Join-Path $logsDir 'latest-dual.log'
        MetaFile    = Join-Path $logsDir 'latest-dual.meta.json'
        StopFile    = Join-Path $logsDir ".stop-$stamp"
        CollectorPidFile = Join-Path $logsDir ".collector-$stamp.pid"
    }
}

function Start-MeshPadDualLogCollector {
    param(
        [hashtable] $Session,
        [string] $AndroidDeviceId
    )

    $streamScript = Join-Path $PSScriptRoot 'stream-dual-logs.ps1'
    if (-not (Test-Path $streamScript)) {
        throw "Missing log stream script: $streamScript"
    }

    $argumentLine = @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        "`"$streamScript`""
        '-OutFile'
        "`"$($Session.SessionLog)`""
        '-AndroidDeviceId'
        "`"$AndroidDeviceId`""
        '-StopFile'
        "`"$($Session.StopFile)`""
    ) -join ' '

    $collector = Start-Process -FilePath 'powershell.exe' -PassThru -WindowStyle Hidden -ArgumentList $argumentLine
    Set-Content -LiteralPath $Session.CollectorPidFile -Encoding ascii -Value $collector.Id

    return $collector
}

function Stop-MeshPadDualLogCollector {
    param(
        [hashtable] $Session,
        [System.Diagnostics.Process] $Collector,
        [string] $AndroidDeviceId,
        [int] $WaitMs = 8000
    )

    if (Test-Path $Session.StopFile) {
        Remove-Item -LiteralPath $Session.StopFile -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType File -Force -Path $Session.StopFile | Out-Null

    if ($Collector -and -not $Collector.HasExited) {
        $null = $Collector.WaitForExit($WaitMs)
        if (-not $Collector.HasExited) {
            Stop-Process -Id $Collector.Id -Force -ErrorAction SilentlyContinue
        }
    }

    $tail = 500
    try {
        $snapshot = & (Join-Path $PSScriptRoot 'collect-logs.ps1') -Source both -Tail $tail -Device $AndroidDeviceId 2>&1
    } catch {
        $snapshot = @("collect-logs failed: $($_.Exception.Message)")
    }
    if ($snapshot) {
        $block = @(
            ''
            "=== Final snapshot $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') (last $tail lines) ==="
        ) + $snapshot
        Add-Content -LiteralPath $Session.SessionLog -Encoding UTF8 -Value $block
    }

    Copy-Item -LiteralPath $Session.SessionLog -Destination $Session.LatestLog -Force

    $meta = @{
        session_log  = $Session.SessionLog
        latest_log   = $Session.LatestLog
        ended_at     = (Get-Date).ToString('o')
        android_device = $AndroidDeviceId
        windows_log  = Get-MeshPadWindowsLogPath
    } | ConvertTo-Json -Depth 3
    Set-Content -LiteralPath $Session.MetaFile -Encoding UTF8 -Value $meta

    Remove-Item -LiteralPath $Session.StopFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $Session.CollectorPidFile -Force -ErrorAction SilentlyContinue
}
