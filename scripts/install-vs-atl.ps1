#Requires -Version 5.1
<#
.SYNOPSIS
  Ensures Visual Studio Installer is available and installs C++ ATL (needed for Windows release build).

.EXAMPLE
  .\scripts\install-vs-atl.ps1
  Opens Visual Studio Installer (GUI).

.EXAMPLE
  .\scripts\install-vs-atl.ps1 -InstallAtl
  Tries silent ATL install (requires elevated PowerShell).
#>
param(
    [switch] $InstallAtl,
    [switch] $DownloadOnly
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$InstallerExe = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\setup.exe"
$ToolsDir = Join-Path (Get-MeshPadRoot) "tools"
$Bootstrapper = Join-Path $ToolsDir "vs_BuildTools.exe"
$BootstrapperUrl = "https://aka.ms/vs/17/release/vs_BuildTools.exe"
$AtlComponent = "Microsoft.VisualStudio.Component.VC.ATL"

function Get-VisualStudioInstallPath {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\18\BuildTools",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community"
    )
    foreach ($path in $candidates) {
        if (Test-Path (Join-Path $path "VC\Tools\MSVC")) {
            return $path
        }
    }
    return $null
}

function Ensure-BootstrapperDownloaded {
    if (Test-Path $Bootstrapper) {
        Write-Host "Bootstrapper already present: $Bootstrapper"
        return
    }

    New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
    Write-Host "Downloading Visual Studio Build Tools bootstrapper..."
    Write-Host "  $BootstrapperUrl"
    Invoke-WebRequest -Uri $BootstrapperUrl -OutFile $Bootstrapper -UseBasicParsing
    Write-Host "Saved: $Bootstrapper" -ForegroundColor Green
}

if (Test-WindowsCppAtlHeaders) {
    Write-Host "C++ ATL headers are already installed." -ForegroundColor Green
    exit 0
}

Ensure-BootstrapperDownloaded

if ($DownloadOnly) {
    if (Test-Path $InstallerExe) {
        Write-Host "Visual Studio Installer: $InstallerExe"
    } else {
        Write-Host "Installer not found. Run bootstrapper to install it:"
        Write-Host "  Start-Process `"$Bootstrapper`""
    }
    exit 0
}

if (-not (Test-Path $InstallerExe)) {
    Write-Host "Visual Studio Installer not found. Launching bootstrapper..."
    Start-Process -FilePath $Bootstrapper -ArgumentList "--wait"
    if (-not (Test-Path $InstallerExe)) {
        throw "Installer still missing after bootstrapper. Complete setup in the GUI, then re-run this script."
    }
}

if ($InstallAtl) {
    $installPath = Get-VisualStudioInstallPath
    if (-not $installPath) {
        throw "No Visual Studio C++ installation found. Run: Start-Process `"$Bootstrapper`" and install Desktop development with C++."
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdmin) {
        Write-Host "Elevating to install ATL component..." -ForegroundColor Yellow
        $argList = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", $PSCommandPath,
            "-InstallAtl"
        )
        Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $argList -Wait
        exit $LASTEXITCODE
    }

    Write-Host "Installing ATL into: $installPath"
    & $InstallerExe modify `
        --installPath $installPath `
        --add $AtlComponent `
        --passive --norestart --force

    if ($LASTEXITCODE -ne 0) {
        throw "setup.exe exited with code $LASTEXITCODE"
    }

    if (Test-WindowsCppAtlHeaders) {
        Write-Host "ATL installed successfully." -ForegroundColor Green
        exit 0
    }

    throw "ATL install finished but atlstr.h was not found. Open Visual Studio Installer and add ATL manually."
}

Write-Host ""
Write-Host "Visual Studio Installer will open."
Write-Host "Steps: Modify -> Individual components -> C++ ATL (x86 & x64) -> Apply"
Write-Host ""
Write-Host "Or run elevated install:"
Write-Host "  .\scripts\install-vs-atl.ps1 -InstallAtl"
Write-Host ""

Start-Process -FilePath $InstallerExe
