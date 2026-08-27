$ErrorActionPreference = "Stop"

$serviceRoot = $PSScriptRoot
$environmentRoot = Join-Path $serviceRoot ".venv"
$python = Join-Path $environmentRoot "Scripts\python.exe"

if (-not (Test-Path -LiteralPath $python)) {
    # Reuse a compatible system CUDA PyTorch when present. This avoids another
    # multi-gigabyte download on development PCs that already have it installed.
    py -3.10 -m venv --system-site-packages $environmentRoot
    if ($LASTEXITCODE -ne 0) { throw "Python sanal ortami olusturulamadi." }
}

& $python -m pip install --upgrade pip setuptools wheel
if ($LASTEXITCODE -ne 0) { throw "pip/setuptools guncellenemedi." }
$torchReady = $false
try {
    & $python -c "import torch, torchvision; assert torch.cuda.is_available(); assert tuple(map(int, torch.__version__.split('+')[0].split('.')[:2])) >= (2, 5)"
    $torchReady = $LASTEXITCODE -eq 0
} catch {
    $torchReady = $false
}
if (-not $torchReady) {
    & $python -m pip install `
        torch==2.5.1 torchvision==0.20.1 `
        --index-url https://download.pytorch.org/whl/cu121
    if ($LASTEXITCODE -ne 0) { throw "CUDA PyTorch kurulamadi." }
}
& $python -m pip install --upgrade --ignore-installed `
    -r (Join-Path $serviceRoot "requirements.txt")
if ($LASTEXITCODE -ne 0) { throw "AI servis bagimliliklari kurulamadi." }

# The optional SAM 2 CUDA post-processing extension is fragile on native Windows.
# Meta documents that disabling it only skips small-hole cleanup and leaves inference usable.
$env:SAM2_BUILD_CUDA = "0"
& $python -m pip install "git+https://github.com/facebookresearch/sam2.git"
if ($LASTEXITCODE -ne 0) { throw "SAM 2 kurulamadi." }

& $python -c "import torch; print('CUDA:', torch.cuda.is_available()); print('GPU:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU')"
if ($LASTEXITCODE -ne 0) { throw "AI ortami dogrulanamadi." }
Write-Host "Kurulum tamamlandi. AIService\run_server.ps1 ile servisi baslatin."
