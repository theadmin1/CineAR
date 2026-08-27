param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$assetIDs = @(
    "metal_office_desk",
    "SchoolChair_01",
    "SchoolDesk_01",
    "metal_trash_can",
    "cardboard_box_01",
    "plastic_crate_02",
    "wooden_crate_02",
    "Barrel_02",
    "hand_truck",
    "drawer_cabinet",
    "vintage_wooden_drawer_01",
    "steel_frame_shelves_01",
    "metal_tool_chest",
    "plastic_monobloc_chair_01",
    "wooden_stool_01",
    "WetFloorSign_01",
    "korean_fire_extinguisher_01",
    "security_camera_01",
    "power_box_01",
    "korean_public_payphone_01",
    "wall_clock",
    "caged_hanging_light",
    "hanging_industrial_lamp",
    "ceiling_fan",
    "industrial_wall_lamp",
    "industrial_wall_sconce",
    "desk_lamp_arm_01",
    "classic_laptop",
    "television_02",
    "boombox"
)

function Save-VerifiedFile {
    param(
        [Parameter(Mandatory = $true)] [string]$URL,
        [Parameter(Mandatory = $true)] [string]$Destination,
        [Parameter(Mandatory = $true)] [string]$ExpectedMD5
    )

    $parent = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    if (Test-Path -LiteralPath $Destination) {
        $current = (Get-FileHash -LiteralPath $Destination -Algorithm MD5).Hash.ToLowerInvariant()
        if ($current -eq $ExpectedMD5.ToLowerInvariant()) { return }
    }

    Invoke-WebRequest -Uri $URL -OutFile $Destination -UseBasicParsing
    $actual = (Get-FileHash -LiteralPath $Destination -Algorithm MD5).Hash.ToLowerInvariant()
    if ($actual -ne $ExpectedMD5.ToLowerInvariant()) {
        throw "MD5 mismatch for $Destination (expected $ExpectedMD5, got $actual)"
    }
}

$root = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $root | Out-Null

foreach ($assetID in $assetIDs) {
    Write-Host "CINEAR_FETCH $assetID"
    $files = Invoke-RestMethod -Uri "https://api.polyhaven.com/files/$assetID"
    $entry = $files.gltf."1k".gltf
    if ($null -eq $entry) {
        throw "Poly Haven has no 1K glTF entry for $assetID"
    }

    $assetDirectory = Join-Path $root $assetID
    $mainName = [IO.Path]::GetFileName(([Uri]$entry.url).AbsolutePath)
    Save-VerifiedFile -URL $entry.url -Destination (Join-Path $assetDirectory $mainName) -ExpectedMD5 $entry.md5

    foreach ($property in $entry.include.PSObject.Properties) {
        $relative = $property.Name.Replace('/', [IO.Path]::DirectorySeparatorChar)
        Save-VerifiedFile `
            -URL $property.Value.url `
            -Destination (Join-Path $assetDirectory $relative) `
            -ExpectedMD5 $property.Value.md5
    }
}

Write-Host "CINEAR_FETCH_COMPLETE $($assetIDs.Count) $root"
