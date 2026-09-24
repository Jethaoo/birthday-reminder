<#
.SYNOPSIS
    Runs the Flutter app on a physical Android device against the local Worker.

.DESCRIPTION
    A physical device cannot use 10.0.2.2 (that alias only exists on the Android
    emulator), so this script works out the host's LAN address, checks the Worker
    is reachable on it, and launches the app with the matching API_BASE_URL.

.EXAMPLE
    pwsh -File scripts/dev-phone.ps1
    pwsh -File scripts/dev-phone.ps1 -Port 8788 -Device fuorhatwpfceda9p
#>
param(
    [string]$Device,
    [int]$Port = 8787,
    [string]$ApiBaseUrl
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

function Get-LanAddress {
    Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -match '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)' } |
        Select-Object -First 1 -ExpandProperty IPAddress
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

$lanAddress = if ($ApiBaseUrl) { ([Uri]$ApiBaseUrl).Host } else { Get-LanAddress }
if (-not $lanAddress) {
    Write-Error 'Could not determine a LAN address. Pass -ApiBaseUrl http://<host>:<port>.'
}

$baseUrl = if ($ApiBaseUrl) { $ApiBaseUrl.TrimEnd('/') } else { "http://${lanAddress}:${Port}" }

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
