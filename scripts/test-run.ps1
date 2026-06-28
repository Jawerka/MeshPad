#Requires -Version 5.1
<#
.SYNOPSIS
  Тестовый прогон MeshPad (обёртка над dev.ps1 -Test).

.EXAMPLE
  .\scripts\test-run.ps1
  .\scripts\test-run.ps1 -WithFormat -WithBuild
#>
param(
    [switch] $SkipBootstrap,
    [switch] $SkipCodegen,
    [switch] $WithFormat,
    [switch] $WithBuild
)

$args = @("-Test")
if ($SkipBootstrap) { $args += "-SkipBootstrap" }
if ($SkipCodegen) { $args += "-SkipCodegen" }
if ($WithFormat) { $args += "-WithFormat" }
if ($WithBuild) { $args += "-WithBuild" }

& "$PSScriptRoot\dev.ps1" @args
exit $LASTEXITCODE
