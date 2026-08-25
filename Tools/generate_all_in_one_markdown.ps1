param(
    [string]$OutputPath = "PROJECT_ALL_IN_ONE.md"
)

$ErrorActionPreference = "Stop"

function Get-RepositoryRelativePath(
    [string]$BasePath,
    [string]$FullPath
) {
    $baseWithSeparator = $BasePath.TrimEnd("\", "/") + "\"
    $baseUri = [System.Uri]::new($baseWithSeparator)
    $fullUri = [System.Uri]::new($FullPath)
    return [System.Uri]::UnescapeDataString(
        $baseUri.MakeRelativeUri($fullUri).ToString()
    ).Replace("\", "/")
}

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$outputFullPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    [System.IO.Path]::GetFullPath($OutputPath)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputPath))
}

$repoPrefix = $repoRoot.TrimEnd("\", "/") + "\"
if (-not $outputFullPath.StartsWith(
    $repoPrefix,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Output must remain inside the repository: $outputFullPath"
}

$outputRelativePath = Get-RepositoryRelativePath $repoRoot $outputFullPath
$sourceRelativePath = Get-RepositoryRelativePath $repoRoot $PSCommandPath

$textExtensions = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
@(
    ".swift", ".md", ".json", ".yaml", ".yml", ".plist",
    ".pbxproj", ".xcscheme", ".py", ".ps1", ".txt", ".sha256"
) | ForEach-Object { [void]$textExtensions.Add($_) }

$sensitiveExtensions = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)
@(
    ".p8", ".p12", ".pem", ".key", ".cer", ".mobileprovision"
) | ForEach-Object { [void]$sensitiveExtensions.Add($_) }

$candidatePaths = @(
    & git -C $repoRoot ls-files --cached
) + @($sourceRelativePath)

if ($LASTEXITCODE -ne 0) {
    throw "git ls-files failed with exit code $LASTEXITCODE"
}

$projectPaths = $candidatePaths |
    ForEach-Object { $_.Replace("\", "/") } |
    Where-Object {
        $candidateFileName = [System.IO.Path]::GetFileName($_)
        $_ -and
        $_ -ne $outputRelativePath -and
        $candidateFileName -notlike "PROJECT_ALL_IN_ONE*.md" -and
        -not $_.StartsWith(".git/")
    } |
    Sort-Object -Unique

$textPaths = [System.Collections.Generic.List[string]]::new()
$binaryPaths = [System.Collections.Generic.List[string]]::new()
$sensitivePaths = [System.Collections.Generic.List[string]]::new()

foreach ($relativePath in $projectPaths) {
    $fullPath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { continue }

    $fileName = [System.IO.Path]::GetFileName($relativePath)
    $extension = [System.IO.Path]::GetExtension($relativePath)
    if (
        $sensitiveExtensions.Contains($extension) -or
        $fileName -match '^(\.env($|\.)|credentials|secrets?)'
    ) {
        $sensitivePaths.Add($relativePath)
    } elseif ($fileName -eq ".gitignore" -or $textExtensions.Contains($extension)) {
        $textPaths.Add($relativePath)
    } else {
        $binaryPaths.Add($relativePath)
    }
}

$secretPatterns = [System.Collections.Generic.List[string]]::new()
$secretPatterns.Add('-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')
$secretPatterns.Add(('AK' + 'IA[0-9A-Z]{16}'))
$secretPatterns.Add(('gh' + '[pousr]_[A-Za-z0-9]{20,}'))
$secretPatterns.Add(('sk' + '-[A-Za-z0-9]{20,}'))
$secretPatterns.Add(('xox' + '[baprs]-[A-Za-z0-9-]{10,}'))
$secretPatterns.Add(('AI' + 'za[0-9A-Za-z_-]{35}'))

foreach ($relativePath in $textPaths) {
    $fullPath = Join-Path $repoRoot $relativePath
    $content = [System.IO.File]::ReadAllText($fullPath)
    foreach ($pattern in $secretPatterns) {
        if ([regex]::IsMatch($content, $pattern)) {
            throw "Potential secret detected; snapshot was not written: $relativePath"
        }
    }
}

function Get-LanguageTag([string]$Path) {
    $fileName = [System.IO.Path]::GetFileName($Path)
    if ($fileName -eq ".gitignore") { return "gitignore" }

    switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        ".swift" { return "swift" }
        ".md" { return "markdown" }
        ".json" { return "json" }
        ".yaml" { return "yaml" }
        ".yml" { return "yaml" }
        ".plist" { return "xml" }
        ".pbxproj" { return "text" }
        ".xcscheme" { return "xml" }
        ".py" { return "python" }
        ".ps1" { return "powershell" }
        ".sha256" { return "text" }
        ".txt" { return "text" }
        default { return "text" }
    }
}

function Get-CodeFence([string]$Content) {
    $maximumRun = 0
    foreach ($match in [regex]::Matches($Content, '`+')) {
        $maximumRun = [Math]::Max($maximumRun, $match.Value.Length)
    }
    $length = [Math]::Max(4, $maximumRun + 1)
    return ([char]96).ToString() * $length
}

$headCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { $headCommit = "unavailable" }
$branchName = (& git -C $repoRoot rev-parse --abbrev-ref HEAD).Trim()
if ($LASTEXITCODE -ne 0) { $branchName = "unavailable" }
$generatedAt = [DateTimeOffset]::Now.ToString("yyyy-MM-dd HH:mm:ss zzz")

$projectFile = Join-Path $repoRoot "CineAR.xcodeproj/project.pbxproj"
$projectSettings = [System.IO.File]::ReadAllText($projectFile)
$marketingVersionMatch = [regex]::Match(
    $projectSettings,
    'MARKETING_VERSION\s*=\s*([^;]+);'
)
$buildVersionMatch = [regex]::Match(
    $projectSettings,
    'CURRENT_PROJECT_VERSION\s*=\s*([^;]+);'
)
$marketingVersion = if ($marketingVersionMatch.Success) {
    $marketingVersionMatch.Groups[1].Value.Trim()
} else {
    "unknown"
}
$buildVersion = if ($buildVersionMatch.Success) {
    $buildVersionMatch.Groups[1].Value.Trim()
} else {
    "unknown"
}

$builder = [System.Text.StringBuilder]::new()
[void]$builder.AppendLine("# CineAR — Tüm Proje Tek Dosya")
[void]$builder.AppendLine()
[void]$builder.AppendLine("> Bu belge, CineAR deposunun paylaşılabilir ve aranabilir tek Markdown görünümüdür.")
[void]$builder.AppendLine("> Metin tabanlı proje dosyaları eksiksiz gömülür; binary varlıklar boyut ve SHA-256 ile listelenir.")
[void]$builder.AppendLine()
[void]$builder.AppendLine("- Uygulama sürümü: ``$marketingVersion``")
[void]$builder.AppendLine("- Proje build numarası: ``$buildVersion``")
[void]$builder.AppendLine("- Git dalı: ``$branchName``")
[void]$builder.AppendLine("- Kaynak commit: ``$headCommit``")
[void]$builder.AppendLine("- Oluşturulma zamanı: ``$generatedAt``")
[void]$builder.AppendLine("- Bundle ID: ``com.cinear.virtualproduction``")
[void]$builder.AppendLine("- Deployment target: iOS 17.0")
[void]$builder.AppendLine()
[void]$builder.AppendLine("## Projenin amacı")
[void]$builder.AppendLine()
[void]$builder.AppendLine("CineAR; LiDAR destekli iPhone ile bir odayı RoomPlan üzerinden tarayan, gerçek kamera görüntüsünü opak tarama kaplamalarıyla örtmeden 14 hazır CC0 dekoru veya kullanıcının USDZ modellerini zemine yerleştiren yerel iOS uygulamasıdır. Dekorlar taşınabilir, döndürülebilir, ölçeklendirilebilir ve ARWorldMap tabanlı proje olarak saklanabilir.")
[void]$builder.AppendLine()
[void]$builder.AppendLine("## Teknoloji ve ana yetenekler")
[void]$builder.AppendLine()
[void]$builder.AppendLine("- Swift + SwiftUI kullanıcı arayüzü")
[void]$builder.AppendLine("- ARKit dünya takibi, düzlem algılama, raycast, scene reconstruction ve occlusion")
[void]$builder.AppendLine("- RoomPlan ile semantik oda taraması ve ``room.json`` üretimi")
[void]$builder.AppendLine("- Gerçek kamera görünümü, insan/mesh occlusion ve tarama sırasında hafif RoomPlan kılavuzları")
[void]$builder.AppendLine("- Gerçekçi boyutlandırılmış 14 gömülü CC0 USDZ varlığı ve paneli kapatan yerleştirme modu")
[void]$builder.AppendLine("- AR düzlemi bulunamadığında ekran ışını üzerinde serbest yerleştirme fallback'i")
[void]$builder.AppendLine("- Manuel dekor sürükleme, döndürme ve ölçekleme")
[void]$builder.AppendLine("- ARWorldMap + ``scene.json`` ile kalıcı anchor/transform saklama ve relocalization")
[void]$builder.AppendLine("- ReplayKit/AVFoundation tabanlı HEVC video ve AAC ses kaydı")
[void]$builder.AppendLine("- Codemagic ile imzalı IPA üretimi ve TestFlight yüklemesi")
[void]$builder.AppendLine()
[void]$builder.AppendLine("## Çalışma ve dağıtım gereksinimleri")
[void]$builder.AppendLine()
[void]$builder.AppendLine("| Alan | Değer |")
[void]$builder.AppendLine("| --- | --- |")
[void]$builder.AppendLine("| Hedef | iPhone, iOS 17.0+ |")
[void]$builder.AppendLine("| Oda taraması | RoomPlan destekli LiDAR iPhone Pro |")
[void]$builder.AppendLine("| Yerel derleme | macOS + Xcode; gerçek cihaz gerekir |")
[void]$builder.AppendLine("| Bulut derleme | Codemagic, Xcode 26.4, App Store signing |")
[void]$builder.AppendLine("| Dağıtım | App Store Connect / TestFlight |")
[void]$builder.AppendLine("| Swift dil modu | Swift 5.0 proje ayarı |")
[void]$builder.AppendLine()
[void]$builder.AppendLine("## Mimari harita")
[void]$builder.AppendLine()
[void]$builder.AppendLine("| Bileşen | Sorumluluk |")
[void]$builder.AppendLine("| --- | --- |")
[void]$builder.AppendLine("| ``CineARApp`` / ``ContentView`` | Uygulama girişi, yerleştirme modu, 3B kütüphane ve tarayıcı sunumu |")
[void]$builder.AppendLine("| ``ARSessionController`` | ARSession yaşam döngüsü, raycast, manuel dekorlar, gesture'lar, kayıt ve proje koordinasyonu |")
[void]$builder.AppendLine("| ``RoomScannerController`` | RoomPlan taraması, arka planda güvenli JSON staging ve explicit teardown |")
[void]$builder.AppendLine("| ``RoomRealityRenderer`` | Ana arayüzde kapalı tutulan deneysel semantik oda renderer'ı |")
[void]$builder.AppendLine("| ``BundledRoomRealityAssetProvider`` | Gömülü USDZ prototiplerini rollere bağlama ve gerçekçi metre boyutlarına getirme |")
[void]$builder.AppendLine("| ``SceneProjectStore`` | ``scene.json``, ``room.json``, ARWorldMap, içe aktarılan USDZ ve kayıt dosyaları |")
[void]$builder.AppendLine("| ``ProfessionalRecorder`` | HEVC video, mikrofon sesi ve kayıt yaşam döngüsü |")
[void]$builder.AppendLine("| ``RealityTheme`` / ``PropKind`` | Materyal tarifleri, oda rolleri ve 19 manuel dekor türü |")
[void]$builder.AppendLine("| ``codemagic.yaml`` | Xcode 26.4 build, signing, artan build numarası ve App Store Connect yayını |")
[void]$builder.AppendLine()
[void]$builder.AppendLine("## Temel kullanıcı akışı")
[void]$builder.AppendLine()
[void]$builder.AppendLine("1. ARKit alanı izler ve yatay/dikey yüzeyleri algılar.")
[void]$builder.AppendLine("2. Kullanıcı **Oda Tara** ile aynı ARSession üzerinde RoomPlan taramasını açar.")
[void]$builder.AppendLine("3. Sonuç compact ``room.json`` olarak arka planda hazırlanır ve kullanıcı onayıyla atomik biçimde kaydedilir.")
[void]$builder.AppendLine("4. Tarayıcı kapandığında opak oda geometrisi çizilmeden gerçek kamera görünümüne dönülür.")
[void]$builder.AppendLine("5. Kullanıcı hızlı dekor, 14 modellik kütüphane veya kendi USDZ varlığını seçer; büyük panel otomatik kapanır.")
[void]$builder.AppendLine("6. Kullanıcı zemine dokunur; AR düzlemi yoksa dokunma ışını üzerindeki güvenli mesafe kullanılır.")
[void]$builder.AppendLine("7. RealityKit gesture'larıyla dekor taşınır, döndürülür ve ölçeklenir.")
[void]$builder.AppendLine("8. **Kaydet** ile world map ve dekor transformları, **HEVC Çekim** ile video/ses çıktısı üretilir.")
[void]$builder.AppendLine()
[void]$builder.AppendLine("## Uygulamanın yerel veri yapısı")
[void]$builder.AppendLine()
[void]$builder.AppendLine('````text')
[void]$builder.AppendLine("CineARProjects/MainSet/")
[void]$builder.AppendLine("  scene.json")
[void]$builder.AppendLine("  worldmap.arexperience")
[void]$builder.AppendLine("  room.json")
[void]$builder.AppendLine("  Assets/*.usdz")
[void]$builder.AppendLine("  Recordings/*.mov")
[void]$builder.AppendLine('````')
[void]$builder.AppendLine()
[void]$builder.AppendLine("``room.json`` semantik tarama verisi olarak saklanır ancak normal kamera görünümünde opak oda geometrisine dönüştürülmez. Kullanıcının gerçek mekân verileri, kayıtları ve içe aktardığı özel USDZ dosyaları uygulama sandbox'ında tutulur; bunlar kaynak deposunun veya bu snapshot'ın parçası değildir.")
[void]$builder.AppendLine()
[void]$builder.AppendLine("## Mevcut kapsamın sınırları")
[void]$builder.AppendLine()
[void]$builder.AppendLine("Bu sürüm cihazda çalışan bir sanal prodüksiyon prototipidir. Gömülü modeller mobil uyumlu low-poly varlıklardır. ProRes, 10-bit Log/HDR, genlock, harici timecode, lens distortion kalibrasyonu, clean plate/alpha pass ve gerçek nesne silmeye yönelik temporal video inpainting henüz bulunmaz. Fiziksel cihaz performansı ve sinema teslim kalitesi ``Docs/DEVICE_TEST.md`` ölçütleriyle ayrıca doğrulanmalıdır.")
[void]$builder.AppendLine()
[void]$builder.AppendLine("## Kapsam ve yeniden üretim")
[void]$builder.AppendLine()
[void]$builder.AppendLine("Bu belge ``$sourceRelativePath`` çalıştırılarak yeniden üretilebilir:")
[void]$builder.AppendLine()
[void]$builder.AppendLine('````powershell')
[void]$builder.AppendLine("powershell -ExecutionPolicy Bypass -File Tools/generate_all_in_one_markdown.ps1")
[void]$builder.AppendLine('````')
[void]$builder.AppendLine()
[void]$builder.AppendLine("Belgenin kendisi sonsuz iç içe geçmeyi önlemek için kaynak listesine alınmaz. Git metadata'sı ve yerel/ignore edilmiş dosyalar dahil edilmez. Sertifika, private key veya provisioning profile uzantıları bulunursa içerikleri gömülmez.")
[void]$builder.AppendLine()
[void]$builder.AppendLine("## Proje dosya envanteri")
[void]$builder.AppendLine()
[void]$builder.AppendLine('````text')
foreach ($relativePath in $projectPaths) {
    [void]$builder.AppendLine($relativePath)
}
[void]$builder.AppendLine('````')
[void]$builder.AppendLine()
[void]$builder.AppendLine("## Binary varlık envanteri")
[void]$builder.AppendLine()
if ($binaryPaths.Count -eq 0) {
    [void]$builder.AppendLine("Binary varlık bulunamadı.")
} else {
    [void]$builder.AppendLine("| Dosya | Boyut (byte) | SHA-256 |")
    [void]$builder.AppendLine("| --- | ---: | --- |")
    foreach ($relativePath in $binaryPaths) {
        $fullPath = Join-Path $repoRoot $relativePath
        $size = (Get-Item -LiteralPath $fullPath).Length
        $hash = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash.ToLowerInvariant()
        [void]$builder.AppendLine("| ``$relativePath`` | $size | ``$hash`` |")
    }
}
[void]$builder.AppendLine()
[void]$builder.AppendLine("## Güvenlik nedeniyle içeriği gömülmeyen dosyalar")
[void]$builder.AppendLine()
if ($sensitivePaths.Count -eq 0) {
    [void]$builder.AppendLine("Yok.")
} else {
    foreach ($relativePath in $sensitivePaths) {
        [void]$builder.AppendLine("- ``$relativePath``")
    }
}
[void]$builder.AppendLine()
[void]$builder.AppendLine("## Metin kaynakları indeksi")
[void]$builder.AppendLine()
[void]$builder.AppendLine("| Dosya | Satır | Boyut (byte) |")
[void]$builder.AppendLine("| --- | ---: | ---: |")
foreach ($relativePath in $textPaths) {
    $fullPath = Join-Path $repoRoot $relativePath
    $content = [System.IO.File]::ReadAllText($fullPath)
    $lineCount = if ($content.Length -eq 0) {
        0
    } else {
        ([regex]::Matches($content, "\r\n|\n|\r")).Count + 1
    }
    $size = (Get-Item -LiteralPath $fullPath).Length
    [void]$builder.AppendLine("| ``$relativePath`` | $lineCount | $size |")
}
[void]$builder.AppendLine()
[void]$builder.AppendLine("# Metin tabanlı proje dosyalarının tam içeriği")
[void]$builder.AppendLine()

foreach ($relativePath in $textPaths) {
    $fullPath = Join-Path $repoRoot $relativePath
    $content = [System.IO.File]::ReadAllText($fullPath)
    $language = Get-LanguageTag $relativePath
    $fence = Get-CodeFence $content

    [void]$builder.AppendLine("## ``$relativePath``")
    [void]$builder.AppendLine()
    [void]$builder.AppendLine("$fence$language")
    [void]$builder.Append($content)
    if (-not $content.EndsWith("`n") -and -not $content.EndsWith("`r")) {
        [void]$builder.AppendLine()
    }
    [void]$builder.AppendLine($fence)
    [void]$builder.AppendLine()
}

$outputDirectory = [System.IO.Path]::GetDirectoryName($outputFullPath)
[System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
$utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
$finalText = $builder.ToString().TrimEnd([char[]]@("`r", "`n")) + "`n"
[System.IO.File]::WriteAllText($outputFullPath, $finalText, $utf8WithoutBom)

Write-Host "Generated $outputRelativePath"
Write-Host "Text sources: $($textPaths.Count)"
Write-Host "Binary assets: $($binaryPaths.Count)"
Write-Host "Sensitive files omitted: $($sensitivePaths.Count)"
