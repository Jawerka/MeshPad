#Requires -Version 5.1
<#
.SYNOPSIS
  Тестовый прогон MeshPad: codegen, bootstrap, analyze, unit- и widget-тесты.

.DESCRIPTION
  Локальный аналог CI. Возвращает ненулевой код при любой ошибке.
  Текущая папка терминала после завершения не меняется.

.PARAMETER SkipBootstrap
  Не выполнять melos bootstrap.

.PARAMETER SkipCodegen
  Не запускать drift build_runner в meshpad_core.

.PARAMETER WithFormat
  Дополнительно проверить форматирование (melos run format).

.PARAMETER WithBuild
  После тестов собрать debug-сборку Windows (apps/meshpad).

.EXAMPLE
  .\scripts\test-run.ps1

.EXAMPLE
  .\scripts\test-run.ps1 -WithFormat -WithBuild
#>
param(
    [switch] $SkipBootstrap,
    [switch] $SkipCodegen,
    [switch] $WithFormat,
    [switch] $WithBuild
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$InitialLocation = Save-Location

$Root = Split-Path -Parent $PSScriptRoot
$FlutterBin = Join-Path $env:LOCALAPPDATA "flutter\bin"
$PubBin = Join-Path $env:LOCALAPPDATA "Pub\Cache\bin"
$JavaHome = "C:\Program Files\Android\Android Studio\jbr"
$AndroidSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"

function Write-Step([string] $Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Invoke-Step([string] $Name, [scriptblock] $Action) {
    Write-Step $Name
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "Шаг «$Name» завершился с кодом $LASTEXITCODE"
    }
}

if (-not (Test-Path (Join-Path $FlutterBin "flutter.bat"))) {
    throw "Flutter не найден в $FlutterBin. Запустите .\scripts\setup.ps1"
}

if (Test-Path $JavaHome) {
    $env:JAVA_HOME = $JavaHome
}
if (Test-Path $AndroidSdk) {
    $env:ANDROID_HOME = $AndroidSdk
    $env:ANDROID_SDK_ROOT = $AndroidSdk
}

$env:Path = "$FlutterBin;$PubBin;" + $env:Path

$sw = [System.Diagnostics.Stopwatch]::StartNew()

try {
    Invoke-InDirectory $Root {
        if (-not $SkipCodegen) {
            Invoke-Step "Drift codegen (meshpad_core)" {
                Invoke-InDirectory (Join-Path $Root "packages\meshpad_core") {
                    dart run build_runner build
                }
            }
        }

        if (-not $SkipBootstrap) {
            Invoke-Step "melos bootstrap" {
                dart run melos bootstrap
            }
        }

        if ($WithFormat) {
            Invoke-Step "melos run format" {
                dart run melos run format
            }
        }

        Invoke-Step "melos run analyze" {
            dart run melos run analyze
        }

        Invoke-Step "melos run test (core, p2p)" {
            dart run melos run test
        }

        Invoke-Step "flutter test (app)" {
            Invoke-InDirectory (Join-Path $Root "apps\meshpad") {
                flutter test
            }
        }

        if ($WithBuild) {
            Invoke-Step "flutter build windows --debug" {
                Invoke-InDirectory (Join-Path $Root "apps\meshpad") {
                    flutter build windows --debug
                }
            }
        }
    }

    $sw.Stop()
    Write-Host ""
    Write-Host "Тестовый прогон успешен ($([math]::Round($sw.Elapsed.TotalSeconds, 1)) с)." -ForegroundColor Green
    exit 0
} catch {
    $sw.Stop()
    Write-Host ""
    Write-Host "Тестовый прогон провален: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Restore-Location $InitialLocation
}
