$ErrorActionPreference = "Stop"

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$python = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
if (-not (Test-Path -LiteralPath $python)) {
    throw "AI ortami kurulu degil. Once AIService\setup_windows.ps1 calistirin."
}

$modelCache = Join-Path $PSScriptRoot ".cache"
[void](New-Item -ItemType Directory -Path $modelCache -Force)
$env:HF_HOME = Join-Path $modelCache "huggingface"
$env:TORCH_HOME = Join-Path $modelCache "torch"
if (-not $env:CINEAR_SAM_POINTS) { $env:CINEAR_SAM_POINTS = "6" }
if (-not $env:CINEAR_SAM_MAX_SIDE) { $env:CINEAR_SAM_MAX_SIDE = "448" }
if (-not $env:CINEAR_SAM_ENABLED) { $env:CINEAR_SAM_ENABLED = "0" }
if (-not $env:CINEAR_DEPTH_INPUT_SIZE) { $env:CINEAR_DEPTH_INPUT_SIZE = "322" }

# Older CineAR virtual environments do not contain the lightweight Bonjour
# dependency. Install only that missing package so an existing CUDA/PyTorch
# installation is not rebuilt just to gain automatic local-network discovery.
& $python -c "import zeroconf" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Otomatik PC bulma bileseni kuruluyor (yalnizca ilk acilista)..."
    & $python -m pip install "zeroconf>=0.136,<1"
    if ($LASTEXITCODE -ne 0) {
        throw "Bonjour bileseni kurulamadi. Internet baglantisini kontrol edip yeniden deneyin."
    }
}

$networkCandidates = @(Get-NetIPConfiguration -ErrorAction SilentlyContinue |
    Where-Object {
        $_.NetAdapter.Status -eq "Up" -and
        $_.IPv4DefaultGateway -and
        $_.IPv4Address -and
        $_.InterfaceAlias -notmatch "Loopback|vEthernet|VMware|VirtualBox|Hyper-V"
    } |
    Sort-Object { $_.NetIPInterface.InterfaceMetric })

# Telefonun erisecegi fiziksel Wi-Fi adresini Ethernet ve sanal adaptorlere tercih et.
# Windows dili Turkce veya Ingilizce olabilecegi icin hem media type hem ad/aciklama
# denetlenir.
$wifiNetwork = $networkCandidates |
    Where-Object {
        $_.NetAdapter.MediaType -eq "Native 802.11" -or
        $_.InterfaceAlias -match "Wi-?Fi|Wireless|WLAN|Kablosuz" -or
        $_.NetAdapter.InterfaceDescription -match "Wi-?Fi|Wireless|WLAN|802\.11|Kablosuz"
    } |
    Select-Object -First 1

$activeNetwork = if ($wifiNetwork) {
    $wifiNetwork
} else {
    $networkCandidates | Select-Object -First 1
}

$address = $activeNetwork.IPv4Address.IPAddress | Select-Object -First 1
$addressLabel = if ($wifiNetwork) { "Mevcut Wi-Fi IPv4 adresi" } else { "Etkin ag IPv4 adresi" }
$adapterName = $activeNetwork.InterfaceAlias
if (-not $address) {
    $address = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.InterfaceAlias -notmatch "Loopback|vEthernet|VMware|VirtualBox"
        } |
        Sort-Object InterfaceMetric |
        Select-Object -First 1 -ExpandProperty IPAddress
    $addressLabel = "Bulunan yerel IPv4 adresi"
    $adapterName = $null
}

if ($address) {
    $env:CINEAR_ADVERTISE_ADDRESS = $address
    if ($adapterName) {
        Write-Host "Aktif ag adaptoru: $adapterName"
    }
    Write-Host "${addressLabel}: $address" -ForegroundColor Cyan
    Write-Host "iPhone sunucu adresi: http://${address}:8765"
    Write-Host "CineAR bu adresi otomatik bulacak. iPhone ve PC ayni Wi-Fi'da olmali."
} else {
    Remove-Item Env:CINEAR_ADVERTISE_ADDRESS -ErrorAction SilentlyContinue
    Write-Warning "Etkin Wi-Fi/Ethernet IPv4 adresi bulunamadi. Ag baglantisini kontrol edin."
}
Write-Host "Ilk acilis model dosyalarini indirecegi icin birkac dakika surebilir."
$samMode = if ($env:CINEAR_SAM_ENABLED -eq "1") { "acik" } else { "kapali (hizli)" }
Write-Host "Hizli profil: Depth=${env:CINEAR_DEPTH_INPUT_SIZE}px, SAM=$samMode"

Push-Location $repoRoot
try {
    & $python -m uvicorn AIService.server:app --host 0.0.0.0 --port 8765
} finally {
    Pop-Location
}
