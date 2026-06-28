# Prints semver from apps/meshpad/pubspec.yaml (PLAN §11.0.2).
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$line = Select-String -Path (Join-Path $root 'apps\meshpad\pubspec.yaml') -Pattern '^version:' | Select-Object -First 1
$raw = ($line.Line -replace 'version:\s*', '').Trim()
$semver = ($raw -replace '\+.*', '').Trim()
Write-Output $semver
