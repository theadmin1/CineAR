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

$address = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
        $_.IPAddress -notlike "127.*" -and
        $_.IPAddress -notlike "169.254.*" -and
        $_.InterfaceAlias -notmatch "Loopback|vEthernet"
    } |
    Sort-Object InterfaceMetric |
    Select-Object -First 1 -ExpandProperty IPAddress

if ($address) {
    Write-Host "iPhone sunucu adresi: http://${address}:8765"
}
Write-Host "Ilk acilis model dosyalarini indirecegi icin birkac dakika surebilir."

Push-Location $repoRoot
try {
    & $python -m uvicorn AIService.server:app --host 0.0.0.0 --port 8765
} finally {
    Pop-Location
}
