# Shared helpers for MeshPad scripts (dot-source from scripts/*.ps1).

function Save-Location {
    return Get-Location
}

function Restore-Location {
    param([System.Management.Automation.PathInfo] $Location)
    if ($Location) {
        Set-Location -Path $Location
    }
}

function Invoke-InDirectory {
    param(
        [Parameter(Mandatory)]
        [string] $Path,
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock
    )
    Push-Location $Path
    try {
        & $ScriptBlock
    } finally {
        Pop-Location
    }
}

function Get-MeshPadRoot {
    return Split-Path -Parent $PSScriptRoot
}

function Get-MeshPadPaths {
    $Root = Get-MeshPadRoot
    return @{
        Root       = $Root
        AppDir     = Join-Path $Root "apps\meshpad"
        CoreDir    = Join-Path $Root "packages\meshpad_core"
        FlutterBin = Join-Path $env:LOCALAPPDATA "flutter\bin"
        PubBin     = Join-Path $env:LOCALAPPDATA "Pub\Cache\bin"
        JavaHome   = "C:\Program Files\Android\Android Studio\jbr"
        AndroidSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
    }
}

function Initialize-MeshPadDevEnvironment {
    $paths = Get-MeshPadPaths

    if (-not (Test-Path (Join-Path $paths.FlutterBin "flutter.bat"))) {
        throw "Flutter not found. Run scripts\setup.ps1 then scripts\bootstrap.ps1"
    }

    if (Test-Path $paths.JavaHome) {
        $env:JAVA_HOME = $paths.JavaHome
    }
    if (Test-Path $paths.AndroidSdk) {
        $env:ANDROID_HOME = $paths.AndroidSdk
        $env:ANDROID_SDK_ROOT = $paths.AndroidSdk
        $platformTools = Join-Path $paths.AndroidSdk "platform-tools"
        if (Test-Path $platformTools) {
            $env:Path = "$platformTools;$env:Path"
        }
    }

    $env:Path = "$($paths.FlutterBin);$($paths.PubBin);$env:Path"
    return $paths
}

function Test-MeshPadBootstrapped {
    param([hashtable] $Paths)
    $appConfig = Join-Path $Paths.AppDir ".dart_tool\package_config.json"
    $coreConfig = Join-Path $Paths.CoreDir ".dart_tool\package_config.json"
    return (Test-Path $appConfig) -and (Test-Path $coreConfig)
}

function Ensure-MeshPadBootstrapped {
    param(
        [hashtable] $Paths,
        [switch] $SkipCodegen
    )

    if (-not (Test-MeshPadBootstrapped -Paths $Paths)) {
        Write-Host "First run: melos bootstrap..." -ForegroundColor Yellow
        Invoke-InDirectory $Paths.Root {
            dart run melos bootstrap
            if ($LASTEXITCODE -ne 0) { throw "melos bootstrap failed" }
        }
    }

    if (-not $SkipCodegen) {
        $generated = Join-Path $Paths.CoreDir "lib\src\database\database.g.dart"
        if (-not (Test-Path $generated)) {
            Write-Host "Drift codegen (build_runner)..." -ForegroundColor Yellow
            Invoke-InDirectory $Paths.CoreDir {
                dart run build_runner build --delete-conflicting-outputs
                if ($LASTEXITCODE -ne 0) { throw "build_runner failed" }
            }
        }
    }
}

function Test-WindowsDeveloperMode {
    try {
        $key = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -ErrorAction SilentlyContinue
        return $key.AllowDevelopmentWithoutDevLicense -eq 1
    } catch {
        return $false
    }
}

function Show-DeveloperModeHint {
    Write-Host ""
    Write-Host "WARNING: Windows Developer Mode is OFF." -ForegroundColor Yellow
    Write-Host "Enable Developer Mode in Windows Settings, then retry."
    Write-Host "  start ms-settings:developers"
    Write-Host ""
}

function Test-WindowsCppAtlHeaders {
    $roots = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio",
        "${env:ProgramFiles}\Microsoft Visual Studio"
    )

    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        $headers = Get-ChildItem -Path $root -Recurse -Filter "atlstr.h" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '\\atlmfc\\include\\atlstr\.h$' }
        if ($headers) {
            return $true
        }
    }

    return $false
}

function Show-WindowsCppAtlHint {
    $installRoot = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\18\BuildTools"
    if (-not (Test-Path $installRoot)) {
        $installRoot = "<your Visual Studio install path>"
    }

    Write-Host ""
    Write-Host "ERROR: C++ ATL headers are missing (atlstr.h)." -ForegroundColor Red
    Write-Host "flutter_secure_storage_windows needs ATL from Visual Studio Build Tools."
    Write-Host ""
    Write-Host "Fix (Visual Studio Installer):"
    Write-Host "  1. Open Visual Studio Installer"
    Write-Host "  2. Modify your C++ Build Tools installation"
    Write-Host "  3. Individual components -> search ATL"
    Write-Host "  4. Check: C++ ATL for latest build tools (x86 and x64)"
    Write-Host "  5. Apply, then re-run: .\dev.ps1 -Release"
    Write-Host ""
    Write-Host "Or from elevated PowerShell (adjust install path if needed):"
    Write-Host "  & `"${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe`" modify --installPath `"$installRoot`" --add Microsoft.VisualStudio.Component.VC.ATL --passive --norestart"
    Write-Host ""
}

function Ensure-WindowsCppAtlHeaders {
    if (Test-WindowsCppAtlHeaders) { return }
    Show-WindowsCppAtlHint
    throw "Install Visual Studio C++ ATL component, then retry."
}
