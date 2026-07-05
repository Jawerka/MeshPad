#Requires -Version 5.1
<#
.SYNOPSIS
  Build MeshPad Windows release, zip, and Inno Setup installer.

.PARAMETER OutputDir
  Folder for meshpad-<version>-windows-x64.zip and meshpad-<version>-windows-x64-setup.exe.
  Defaults to the repository root.

.PARAMETER Run
  Launch meshpad.exe after a successful build.

.EXAMPLE
  .\scripts\build-windows.ps1
  .\scripts\build-windows.ps1 -Run
#>
param(
    [string] $OutputDir = "",
    [switch] $Run
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\_common.ps1"

$InitialLocation = Save-Location
try {
    $paths = Initialize-MeshPadDevEnvironment
    $root = $paths.Root
    if ([string]::IsNullOrWhiteSpace($OutputDir)) {
        $OutputDir = $root
    }
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    $outputDirResolved = (Resolve-Path -LiteralPath $OutputDir).Path

    Ensure-WindowsCppAtlHeaders

    $releaseDir = Join-Path $paths.AppDir "build\windows\x64\runner\Release"
    $releaseExe = Join-Path $releaseDir "meshpad.exe"

    Write-Host "Building MeshPad Windows release..."
    $script:BuildExitCode = 0
    Invoke-InDirectory $paths.AppDir {
        flutter build windows --release
        $script:BuildExitCode = $LASTEXITCODE
    }
    if ($BuildExitCode -ne 0) {
        exit $BuildExitCode
    }

    if (-not (Test-Path $releaseExe)) {
        throw "Release binary not found: $releaseExe"
    }

    $version = & (Join-Path $PSScriptRoot "read-app-version.ps1")
    $zipName = "meshpad-$version-windows-x64.zip"
    $zipPath = Join-Path $outputDirResolved $zipName

    Write-Host "Packaging $zipName..."
    if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
    Compress-Archive -Path $releaseDir -DestinationPath $zipPath -Force

    Write-Host "Building Windows installer..."
    & (Join-Path $PSScriptRoot "package-windows-installer.ps1") `
        -Version $version `
        -ReleaseDir $releaseDir `
        -OutputDir $outputDirResolved

    $setupPath = Join-Path $outputDirResolved "meshpad-$version-windows-x64-setup.exe"
    Write-Host ""
    Write-Host "Windows release artifacts:" -ForegroundColor Green
    Write-Host "  $releaseExe"
    Write-Host "  $zipPath"
    Write-Host "  $setupPath"

    if ($Run) {
        Write-Host ""
        Write-Host "Starting $releaseExe" -ForegroundColor Green
        & $releaseExe
        exit $LASTEXITCODE
    }
} finally {
    Restore-Location $InitialLocation
}
