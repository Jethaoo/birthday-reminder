<#
.SYNOPSIS
    Runs the Flutter app on a physical Android device against the local Worker.

.DESCRIPTION
    A physical device cannot use 10.0.2.2 (that alias only exists on the Android
    emulator), so this script works out the host's LAN address, checks the Worker
    is reachable on it, and launches the app with the matching API_BASE_URL.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts/dev-phone.ps1
    powershell -ExecutionPolicy Bypass -File scripts/dev-phone.ps1 -Port 8788
#>
param(
    [string]$Device,
    [int]$Port = 8787,
    [string]$ApiBaseUrl
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

function Get-LanAddress {
    # The phone can only reach the host on its real network adapter, so prefer the
    # interface that carries the default route and skip virtual ones (WSL,
    # Hyper-V, Docker, VPN, Bluetooth). Otherwise a 172.x vEthernet address wins.
    $virtualPattern = 'vEthernet|WSL|Loopback|Hyper-V|VirtualBox|VMware|Docker|Bluetooth|Tailscale|ZeroTier|Npcap|TAP-|VPN|Remote NDIS'

    Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Sort-Object RouteMetric, InterfaceMetric |
        ForEach-Object {
            $adapter = Get-NetAdapter -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue
            if (-not $adapter -or $adapter.Status -ne 'Up') { return }
            if ($adapter.Name -match $virtualPattern -or $adapter.InterfaceDescription -match $virtualPattern) { return }

            $address = Get-NetIPAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -notlike '127.*' } |
                Select-Object -First 1 -ExpandProperty IPAddress

            if ($address) {
                [pscustomobject]@{ IPAddress = $address; Adapter = $adapter.Name }
            }
        } | Select-Object -First 1
}

function Test-PortOpen {
    param([string]$HostName, [int]$PortNumber)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $connect = $client.BeginConnect($HostName, $PortNumber, $null, $null)
        if (-not $connect.AsyncWaitHandle.WaitOne(1500)) { return $false }
        $client.EndConnect($connect)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

if ($ApiBaseUrl) {
    $lanAddress = ([Uri]$ApiBaseUrl).Host
    $adapterName = 'from -ApiBaseUrl'
} else {
    $lan = Get-LanAddress
    if (-not $lan) {
        Write-Error 'Could not determine a LAN address. Pass -ApiBaseUrl http://<host>:<port>.'
    }
    $lanAddress = $lan.IPAddress
    $adapterName = $lan.Adapter
}

$baseUrl = if ($ApiBaseUrl) { $ApiBaseUrl.TrimEnd('/') } else { "http://${lanAddress}:${Port}" }
Write-Host "Host address: $lanAddress ($adapterName)" -ForegroundColor Cyan

if (-not (Test-PortOpen -HostName $lanAddress -PortNumber $Port)) {
    Write-Host "The Worker is not reachable on ${lanAddress}:${Port} yet." -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Start it in another terminal (it must bind to all interfaces, not just localhost):'
    Write-Host "    cd $repoRoot\backend"
    Write-Host "    pnpm exec wrangler dev --ip 0.0.0.0 --port $Port"
    Write-Host ''
    Write-Host 'If Windows Firewall prompts, allow access on private networks.'
    exit 1
}

if (-not $Device) {
    $devices = flutter devices --machine | ConvertFrom-Json
    $android = $devices | Where-Object { $_.targetPlatform -like 'android*' } | Select-Object -First 1
    if (-not $android) {
        Write-Error 'No Android device detected. Connect a device or pass -Device <id>.'
    }
    $Device = $android.id
    Write-Host "Using device $($android.name) ($Device)"
}

Write-Host "Backend reachable at $baseUrl" -ForegroundColor Green
Write-Host "Starting the app against $baseUrl" -ForegroundColor Green

Push-Location (Join-Path $repoRoot 'app')
try {
    flutter run --device-id $Device --dart-define=API_BASE_URL=$baseUrl
} finally {
    Pop-Location
}
