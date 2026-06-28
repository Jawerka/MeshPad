#Requires -Version 5.1
<#
.SYNOPSIS
  Единая точка входа для локальной разработки MeshPad.

.DESCRIPTION
  По умолчанию запускает приложение на Windows (flutter run).
  Режим -Test выполняет полный тестовый прогон (как локальный CI).

.PARAMETER Test
  Анализ + unit/widget-тесты вместо запуска приложения.

.PARAMETER Device
  Устройство для flutter run: windows (по умолчанию), android, dual.

.PARAMETER SkipBootstrap
  Не вызывать melos bootstrap / codegen автоматически.

.PARAMETER WithFormat
  Только с -Test: проверить форматирование.

.PARAMETER WithBuild
  Только с -Test: собрать Windows debug после тестов.

.PARAMETER Release
  Release-сборка Windows и запуск meshpad.exe (без hot reload).

.EXAMPLE
  .\dev.ps1 -Release
  Production-like запуск на Windows.
#>
param(
    [switch] $Test,
    [switch] $Release,
    [string] $Device = "windows",
    [switch] $SkipBootstrap,
    [switch] $SkipCodegen,
    [switch] $WithFormat,
    [switch] $WithBuild
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$InitialLocation = Save-Location
$sw = [System.Diagnostics.Stopwatch]::StartNew()

function Write-Step([string] $Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Invoke-Step([string] $Name, [scriptblock] $Action) {
    Write-Step $Name
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "Step failed ($Name): exit code $LASTEXITCODE"
    }
}

try {
    $paths = Initialize-MeshPadDevEnvironment

    if (-not $SkipBootstrap) {
        Ensure-MeshPadBootstrapped -Paths $paths -SkipCodegen:$SkipCodegen
    }

    if ($Test) {
        Invoke-InDirectory $paths.Root {
            if ($WithFormat) {
                Invoke-Step "melos run format" {
                    dart run melos run format
                }
            }

            Invoke-Step "melos run analyze" {
                dart run melos run analyze
            }

            Invoke-Step "melos run test" {
                dart run melos run test
            }

            Invoke-Step "flutter test (app)" {
                Invoke-InDirectory $paths.AppDir {
                    flutter test
                }
            }

            if ($WithBuild) {
                Invoke-Step "flutter build windows --debug" {
                    Invoke-InDirectory $paths.AppDir {
                        flutter build windows --debug
                    }
                }
            }
        }

        $sw.Stop()
        Write-Host ""
        Write-Host "Test run OK ($([math]::Round($sw.Elapsed.TotalSeconds, 1)) s)." -ForegroundColor Green
        exit 0
    }

    if ($Release) {
        if ($Device -ne "windows") {
            throw "-Release supports Windows only. For Android use .\scripts\build-android.ps1"
        }

        Ensure-WindowsCppAtlHeaders

        $releaseExe = Join-Path $paths.AppDir "build\windows\x64\runner\Release\meshpad.exe"

        Invoke-Step "flutter build windows --release" {
            Invoke-InDirectory $paths.AppDir {
                flutter build windows --release
            }
        }

        if (-not (Test-Path $releaseExe)) {
            throw "Release binary not found: $releaseExe"
        }

        Write-Host ""
        Write-Host "Starting release build: $releaseExe" -ForegroundColor Green
        & $releaseExe
        exit $LASTEXITCODE
    }

    # --- Run app (debug) ---
    if ($Device -eq "windows" -and -not (Test-WindowsDeveloperMode)) {
        Show-DeveloperModeHint
    }

    if ($Device -in @("dual", "both", "lan", "android")) {
        & "$PSScriptRoot\run.ps1" -Device $Device
        exit $LASTEXITCODE
    }

    Write-Host "Starting MeshPad ($Device) from $($paths.AppDir)"
    Write-Host "  LAN logs: collect with .\scripts\collect-logs.ps1"
    Write-Host ""

    $script:RunExitCode = 0
    Invoke-InDirectory $paths.AppDir {
        flutter run -d $Device
        $script:RunExitCode = $LASTEXITCODE
    }

    if ($RunExitCode -ne 0) {
        exit $RunExitCode
    }
} catch {
    $sw.Stop()
    Write-Host ""
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Restore-Location $InitialLocation
}
