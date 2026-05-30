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
