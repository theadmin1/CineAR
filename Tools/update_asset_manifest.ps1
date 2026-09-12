param(
    [string]$Assets = "CineAR/RoomAssets",
    [string]$Manifest = "CineAR/RoomAssets/MANIFEST.sha256"
)

$ErrorActionPreference = "Stop"
$assetRoot = (Resolve-Path -LiteralPath $Assets).Path
$manifestPath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Manifest))
$lines = Get-ChildItem -LiteralPath $assetRoot -Filter "*.usdz" -File |
    Sort-Object -Property Name |
    ForEach-Object {
        $digest = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$digest  $($_.Name)"
    }

if ($lines.Count -eq 0) {
    throw "No USDZ assets found under $assetRoot"
}
[System.IO.File]::WriteAllLines($manifestPath, $lines, [System.Text.UTF8Encoding]::new($false))
Write-Host "SYNAPMANTIS_MANIFEST_OK assets=$($lines.Count) path=$manifestPath"
