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

$activeNetwork = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
    Where-Object {
        $_.NetAdapter.Status -eq "Up" -and
        $_.IPv4DefaultGateway -and
        $_.IPv4Address
    } |
    Sort-Object { $_.NetIPInterface.InterfaceMetric } |
    Select-Object -First 1

$address = $activeNetwork.IPv4Address.IPAddress | Select-Object -First 1
if (-not $address) {
    $address = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike "127.*" -and
            $_.IPAddress -notlike "169.254.*" -and
            $_.InterfaceAlias -notmatch "Loopback|vEthernet|VMware|VirtualBox"
        } |
        Sort-Object InterfaceMetric |
        Select-Object -First 1 -ExpandProperty IPAddress
}

if ($address) {
    Write-Host "iPhone sunucu adresi: http://${address}:8765"
    Write-Host "CineAR > AI Derinlik alanina bu adresi yazin. iPhone ve PC ayni Wi-Fi'da olmali."
} else {
    Write-Warning "Etkin Wi-Fi/Ethernet IPv4 adresi bulunamadi. Ag baglantisini kontrol edin."
}
Write-Host "Ilk acilis model dosyalarini indirecegi icin birkac dakika surebilir."
Write-Host "Hizli profil: SAM nokta=${env:CINEAR_SAM_POINTS}, azami kenar=${env:CINEAR_SAM_MAX_SIDE}px"

Push-Location $repoRoot
try {
    & $python -m uvicorn AIService.server:app --host 0.0.0.0 --port 8765
} finally {
    Pop-Location
}
