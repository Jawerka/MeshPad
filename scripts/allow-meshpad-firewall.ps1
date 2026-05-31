# Allow MeshPad LAN discovery and sync through Windows Firewall.
# Run once as Administrator:  .\scripts\allow-meshpad-firewall.ps1

$ErrorActionPreference = 'Stop'

function Add-MeshPadRule {
    param(
        [string]$DisplayName,
        [string]$Protocol,
        [int[]]$LocalPort
    )

    $existing = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Rule already exists: $DisplayName"
        return
    }

    New-NetFirewallRule `
        -DisplayName $DisplayName `
        -Direction Inbound `
        -Action Allow `
        -Protocol $Protocol `
        -LocalPort $LocalPort `
        -Profile Any | Out-Null

    Write-Host "Added rule: $DisplayName ($Protocol $($LocalPort -join ','))"
}

Add-MeshPadRule -DisplayName 'MeshPad LAN Discovery (UDP)' -Protocol UDP -LocalPort 45837
Add-MeshPadRule -DisplayName 'MeshPad LAN Sync (TCP)' -Protocol TCP -LocalPort 45838
Add-MeshPadRule -DisplayName 'MeshPad LAN Sync dynamic (TCP)' -Protocol TCP -LocalPort 44800-46000
Add-MeshPadRule -DisplayName 'MeshPad mDNS (UDP)' -Protocol UDP -LocalPort 5353

Write-Host 'Done. Restart MeshPad on Windows if it was already running.'
