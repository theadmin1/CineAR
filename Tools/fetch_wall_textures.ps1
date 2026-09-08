param(
    [string]$OutputDirectory = ".asset-cache/wall-textures"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
# Powered by Poly Haven: https://polyhaven.com
$root = [IO.Path]::GetFullPath($OutputDirectory)
foreach ($assetID in @("brick_wall_001", "wood_plank_wall")) {
    $metadata = Invoke-RestMethod -Uri "https://api.polyhaven.com/files/$assetID"
    $directory = Join-Path $root $assetID
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    foreach ($map in @("Diffuse", "nor_gl", "Rough")) {
        $entry = $metadata.$map."1k".jpg
        if (!$entry -or ([Uri]$entry.url).Host -ne "dl.polyhaven.org") {
            throw "Missing or unexpected official 1K texture: $assetID/$map"
        }
        $destination = Join-Path $directory "$map.jpg"
        if ((Test-Path -LiteralPath $destination) -and
            (Get-FileHash -LiteralPath $destination -Algorithm MD5).Hash -eq $entry.md5) {
            continue
        }
        Invoke-WebRequest -Uri $entry.url -OutFile $destination -UseBasicParsing
        if ((Get-FileHash -LiteralPath $destination -Algorithm MD5).Hash -ne $entry.md5) {
            throw "Texture checksum mismatch: $assetID/$map"
        }
    }
    Write-Host "CINEAR_WALL_TEXTURES_OK $assetID"
}
