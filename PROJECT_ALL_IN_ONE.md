# CineAR — Tüm Proje Tek Dosya

> Bu belge, CineAR deposunun paylaşılabilir ve aranabilir tek Markdown görünümüdür.
> Metin tabanlı proje dosyaları eksiksiz gömülür; binary varlıklar boyut ve SHA-256 ile listelenir.

- Uygulama sürümü: `0.12.1`
- Proje build numarası: `20`
- Git dalı: `main`
- Kaynak commit: `9cf315a62052e32ffab60a00b76684f2c9da10d5`
- Oluşturulma zamanı: `2026-08-31 21:55:23 +03:00`
- Bundle ID: `com.cinear.virtualproduction`
- Deployment target: iOS 17.0

## Projenin amacı

CineAR; LiDAR destekli iPhone ile bir odayı RoomPlan üzerinden tarayan, gerçek kamera görüntüsünü opak tarama kaplamalarıyla örtmeden isteğe bağlı beyaz hatlarla gösteren ve 30 fotogerçekçi CC0 dekoru zemine, yatay yüzeye, duvara veya tavana yerleştiren yerel iOS uygulamasıdır. Dekorlar döndürülebilir, ölçeklendirilebilir ve ARWorldMap tabanlı proje olarak saklanabilir; sanal ışıkların gücü, sıcaklığı ve açısı ayarlanabilir.

## Teknoloji ve ana yetenekler

- Swift + SwiftUI kullanıcı arayüzü
- ARKit dünya takibi, düzlem algılama, raycast, scene reconstruction ve occlusion
- Aynı Wi-Fi'daki PC'de SAM 2.1 Tiny + Depth Anything V2 Small; LiDAR metre kalibrasyonlu görünmez RealityKit occlusion mesh'i
- RoomPlan ile semantik oda taraması ve `room.json` üretimi
- RoomPlan dönüşünde mevcut frame'i yoklayan deterministik AR hazır olma kurtarması
- Yeni taramadan sonra normal takip gelir gelmez otomatik ve eşlenmiş ARWorldMap kaydı
- Gerçek kamera görünümü, insan/mesh occlusion, tarama sırasında RoomPlan kılavuzları ve sonrasında isteğe bağlı hafif Beyaz Hatlar modu
- Poly Haven kaynaklı 1K PBR dokulu 30 fotogerçekçi CC0 USDZ varlığı ve yüzey türüne göre yerleştirme
- Tavan/duvar/masa ışıklarında güç, renk sıcaklığı, yatay yön, dikey eğim, hüzme genişliği ve kalıcı sahne kaydı
- USDZ yükleme/normalize hatasında kategoriye uygun prosedürel model fallback'i; görünmez veya yarım kalan yerleştirme yok
- Kamerayı açık tutan kompakt alt dock ve yalnız istenince açılan ayrıntılı kontrol paneli
- AR düzlemi bulunamadığında ekran ışınını bilinen veya tahmini zeminle kesiştiren yerleştirme fallback'i
- Manuel dekor sürükleme, döndürme ve ölçekleme
- ARWorldMap + `scene.json` ile kalıcı anchor/transform saklama ve relocalization
- ReplayKit/AVFoundation tabanlı HEVC video ve AAC ses kaydı
- Codemagic ile imzalı IPA üretimi ve TestFlight yüklemesi

## Çalışma ve dağıtım gereksinimleri

| Alan | Değer |
| --- | --- |
| Hedef | iPhone, iOS 17.0+ |
| Oda taraması | RoomPlan destekli LiDAR iPhone Pro |
| Yerel derleme | macOS + Xcode; gerçek cihaz gerekir |
| Bulut derleme | Codemagic, Xcode 26.4, App Store signing |
| Dağıtım | App Store Connect / TestFlight |
| Swift dil modu | Swift 5.0 proje ayarı |

## Mimari harita

| Bileşen | Sorumluluk |
| --- | --- |
| `CineARApp` / `ContentView` | Uygulama girişi, yerleştirme modu, 3B kütüphane ve tarayıcı sunumu |
| `ARSessionController` | ARSession yaşam döngüsü, raycast, manuel dekorlar, gesture'lar, kayıt ve proje koordinasyonu |
| `RoomScannerController` | RoomPlan taraması, arka planda güvenli JSON staging ve explicit teardown |
| `RoomRealityRenderer` | Düşük maliyetli beyaz oda hatları, görünmez yüzey collider'ları ve deneysel tema renderer'ı |
| `BundledRoomRealityAssetProvider` | Gömülü USDZ prototiplerini rollere bağlama ve gerçekçi metre boyutlarına getirme |
| `SceneProjectStore` | `scene.json`, `room.json`, ARWorldMap, içe aktarılan USDZ ve kayıt dosyaları |
| `ProfessionalRecorder` | HEVC video, mikrofon sesi ve kayıt yaşam döngüsü |
| `RealityTheme` / `PropKind` | Materyal tarifleri, oda rolleri ve 19 manuel dekor türü |
| `codemagic.yaml` | Xcode 26.4 build, signing, artan build numarası ve App Store Connect yayını |

## Temel kullanıcı akışı

1. ARKit alanı izler ve yatay/dikey yüzeyleri algılar.
2. Kullanıcı **Oda Tara** ile aynı ARSession üzerinde RoomPlan taramasını açar.
3. Sonuç compact `room.json` olarak arka planda hazırlanır ve kullanıcı onayıyla atomik biçimde kaydedilir.
4. Tarayıcı kapandığında opak oda geometrisi çizilmeden gerçek kamera görünümüne dönülür; kullanıcı isterse **Beyaz Hatlar** ile tarama sınırlarını açar.
5. Kullanıcı kompakt dock'tan hızlı dekor, 30 parçalık fotogerçekçi kütüphane veya kendi USDZ varlığını seçer; büyük panel otomatik kapanır ve yerleştirmeden sonra kompakt dock geri gelir.
6. Kullanıcı zemine dokunur; AR düzlemi yoksa dokunma ışını bilinen veya kamera yüksekliğinden tahmin edilen zeminle kesiştirilir.
7. RealityKit gesture'larıyla dekor taşınır, döndürülür ve ölçeklenir.
8. İlk world map tarama sonrasında otomatik kaydedilir; sonraki **Kaydet** istekleri takip hazır değilse sıraya alınır. **HEVC Çekim** video/ses çıktısı üretir.

## Uygulamanın yerel veri yapısı

````text
CineARProjects/MainSet/
  scene.json
  worldmap.arexperience
  room.json
  Assets/*.usdz
  Recordings/*.mov
````

`room.json` semantik tarama verisi olarak saklanır ancak normal kamera görünümünde opak oda geometrisine dönüştürülmez. Kullanıcının gerçek mekân verileri, kayıtları ve içe aktardığı özel USDZ dosyaları uygulama sandbox'ında tutulur; bunlar kaynak deposunun veya bu snapshot'ın parçası değildir.

## Mevcut kapsamın sınırları

Bu sürüm cihazda çalışan bir sanal prodüksiyon prototipidir. Gömülü modeller mobil uyumlu low-poly varlıklardır. ProRes, 10-bit Log/HDR, genlock, harici timecode, lens distortion kalibrasyonu, clean plate/alpha pass ve gerçek nesne silmeye yönelik temporal video inpainting henüz bulunmaz. Fiziksel cihaz performansı ve sinema teslim kalitesi `Docs/DEVICE_TEST.md` ölçütleriyle ayrıca doğrulanmalıdır.

## Kapsam ve yeniden üretim

Bu belge `Tools/generate_all_in_one_markdown.ps1` çalıştırılarak yeniden üretilebilir:

````powershell
powershell -ExecutionPolicy Bypass -File Tools/generate_all_in_one_markdown.ps1
````

Belgenin kendisi sonsuz iç içe geçmeyi önlemek için kaynak listesine alınmaz. Git metadata'sı ve yerel/ignore edilmiş dosyalar dahil edilmez. Sertifika, private key veya provisioning profile uzantıları bulunursa içerikleri gömülmez.

## Proje dosya envanteri

````text
.gitignore
AIService/fusion.py
AIService/README.md
AIService/requirements.txt
AIService/run_server.ps1
AIService/server.py
AIService/setup_windows.ps1
AIService/test_fusion.py
AIService/THIRD_PARTY_NOTICES.md
CineAR.xcodeproj/project.pbxproj
CineAR.xcodeproj/xcshareddata/xcschemes/CineAR.xcscheme
CineAR/AIEnhancementClient.swift
CineAR/ARSessionController.swift
CineAR/ARViewContainer.swift
CineAR/Assets.xcassets/AccentColor.colorset/Contents.json
CineAR/Assets.xcassets/AppIcon.appiconset/CineAR-AppIcon-1024.png
CineAR/Assets.xcassets/AppIcon.appiconset/Contents.json
CineAR/Assets.xcassets/Contents.json
CineAR/BundledRoomRealityAssetProvider.swift
CineAR/CineARApp.swift
CineAR/ContentView.swift
CineAR/Info.plist
CineAR/ProfessionalRecorder.swift
CineAR/PropKind.swift
CineAR/RealityTheme.swift
CineAR/RoomAssets/Barrel_02.usdz
CineAR/RoomAssets/bathroomSink.usdz
CineAR/RoomAssets/bathtub.usdz
CineAR/RoomAssets/bedDouble.usdz
CineAR/RoomAssets/bookcaseClosedWide.usdz
CineAR/RoomAssets/boombox.usdz
CineAR/RoomAssets/caged_hanging_light.usdz
CineAR/RoomAssets/cardboard_box_01.usdz
CineAR/RoomAssets/ceiling_fan.usdz
CineAR/RoomAssets/chairModernCushion.usdz
CineAR/RoomAssets/classic_laptop.usdz
CineAR/RoomAssets/desk_lamp_arm_01.usdz
CineAR/RoomAssets/drawer_cabinet.usdz
CineAR/RoomAssets/hand_truck.usdz
CineAR/RoomAssets/hanging_industrial_lamp.usdz
CineAR/RoomAssets/industrial_wall_lamp.usdz
CineAR/RoomAssets/industrial_wall_sconce.usdz
CineAR/RoomAssets/kitchenFridge.usdz
CineAR/RoomAssets/kitchenStove.usdz
CineAR/RoomAssets/kitchenStoveElectric.usdz
CineAR/RoomAssets/korean_fire_extinguisher_01.usdz
CineAR/RoomAssets/korean_public_payphone_01.usdz
CineAR/RoomAssets/LICENSE-KENNEY.txt
CineAR/RoomAssets/LICENSE-POLYHAVEN.txt
CineAR/RoomAssets/loungeDesignSofa.usdz
CineAR/RoomAssets/MANIFEST.sha256
CineAR/RoomAssets/metal_office_desk.usdz
CineAR/RoomAssets/metal_tool_chest.usdz
CineAR/RoomAssets/metal_trash_can.usdz
CineAR/RoomAssets/plastic_crate_02.usdz
CineAR/RoomAssets/plastic_monobloc_chair_01.usdz
CineAR/RoomAssets/power_box_01.usdz
CineAR/RoomAssets/SchoolChair_01.usdz
CineAR/RoomAssets/SchoolDesk_01.usdz
CineAR/RoomAssets/security_camera_01.usdz
CineAR/RoomAssets/stairs.usdz
CineAR/RoomAssets/steel_frame_shelves_01.usdz
CineAR/RoomAssets/table.usdz
CineAR/RoomAssets/television_02.usdz
CineAR/RoomAssets/televisionModern.usdz
CineAR/RoomAssets/toilet.usdz
CineAR/RoomAssets/vintage_wooden_drawer_01.usdz
CineAR/RoomAssets/wall_clock.usdz
CineAR/RoomAssets/washerDryerStacked.usdz
CineAR/RoomAssets/WetFloorSign_01.usdz
CineAR/RoomAssets/wooden_crate_02.usdz
CineAR/RoomAssets/wooden_stool_01.usdz
CineAR/RoomRealityRenderer.swift
CineAR/RoomScanner.swift
CineAR/SceneProjectStore.swift
codemagic.yaml
Docs/CODEMAGIC.md
Docs/DEVICE_TEST.md
Docs/ICON_PROMPT.md
README.md
Tools/convert_kenney_to_usdz.py
Tools/convert_polyhaven_to_usdz.py
Tools/fetch_polyhaven_props.ps1
Tools/generate_all_in_one_markdown.ps1
Tools/render_usdz_thumbnails.py
Tools/validate_usdz_assets.py
````

## Binary varlık envanteri

| Dosya | Boyut (byte) | SHA-256 |
| --- | ---: | --- |
| `CineAR/Assets.xcassets/AppIcon.appiconset/CineAR-AppIcon-1024.png` | 1280549 | `61704d12fadea91d1e96ae279d31a21ecf0c0e4f66f213b09cca658d5d3643ff` |
| `CineAR/RoomAssets/Barrel_02.usdz` | 537940 | `db44c3823a4313fcb39cc3363de427390b1126dbfccbaede42dfc4c62cc832fe` |
| `CineAR/RoomAssets/bathroomSink.usdz` | 28447 | `2de87dbd39ec292d8575aaf526160310ac090659d6cba1fb0b9d7b231f0cc643` |
| `CineAR/RoomAssets/bathtub.usdz` | 50915 | `3a24cebb0eac7b5dbf190958aeda8e3599b38a9d51c826cf349f703a2c44ce53` |
| `CineAR/RoomAssets/bedDouble.usdz` | 21700 | `c658a28c0afb73daa53330d9747f0651056f172f990df8acecf29003511d0297` |
| `CineAR/RoomAssets/bookcaseClosedWide.usdz` | 31610 | `39d09d860911c9e51a807d33607cec97eb314929c717e848956175ab0f0e2e7f` |
| `CineAR/RoomAssets/boombox.usdz` | 3479128 | `23d131aee04991d1b89989b6d74e2e769b70aca2d1cdd17a990e768019310e0b` |
| `CineAR/RoomAssets/caged_hanging_light.usdz` | 3952770 | `b4834b13750c18ee2ba3da62fe4392257f66d06330b47966b42c316d0e227025` |
| `CineAR/RoomAssets/cardboard_box_01.usdz` | 2992902 | `f0968ac22285b3d7a9af0bfbe4576dc2f9074378dcfbbd2ec093064f9a5e48b0` |
| `CineAR/RoomAssets/ceiling_fan.usdz` | 2535342 | `f8343f8c3647a46c87bfb2188ed5e943ffc32ada06e8dd155b94914bc6e5697d` |
| `CineAR/RoomAssets/chairModernCushion.usdz` | 10190 | `11ae4610ca26984e5f1318c4aba81e5a9090e0c820e4969d4105bd75f147ea9e` |
| `CineAR/RoomAssets/classic_laptop.usdz` | 2745811 | `f927c1c0cd84346380eb2aa8a720be3b40acb27e02881505619013f15a3f7145` |
| `CineAR/RoomAssets/desk_lamp_arm_01.usdz` | 3902780 | `6dc22925edb49c4ea4580c5c92eae78901119f734f7e659537ea0db54d44b96a` |
| `CineAR/RoomAssets/drawer_cabinet.usdz` | 2219127 | `351c5a13e7b4321717eb10ec9696825b1399a872aad41c3739dc8c4223f44f68` |
| `CineAR/RoomAssets/hand_truck.usdz` | 3639690 | `fb69f9da5eee8a94b8751c34576f86385ed89e997873d549268774fe307b4486` |
| `CineAR/RoomAssets/hanging_industrial_lamp.usdz` | 3604302 | `abb5fb8f34f63408885db1bace875ce69fa7c2fcc3eb59c1741f5d1b5e42f937` |
| `CineAR/RoomAssets/industrial_wall_lamp.usdz` | 3955877 | `41dd0ce90dbc114ac6bed1ff58a4ca9b9cf45526d44fcca75f958647bad34ea9` |
| `CineAR/RoomAssets/industrial_wall_sconce.usdz` | 2264430 | `c665e13f562047084407f0fb42e12dbf10db3ccaec6ce1e1ea1bfac9cc10bbee` |
| `CineAR/RoomAssets/kitchenFridge.usdz` | 24080 | `a69f54abdfe4d08aa9408acd80b5d43f8d8126762456988c113a9ae5f94729b7` |
| `CineAR/RoomAssets/kitchenStove.usdz` | 69862 | `b8162bd10dd56e6936cd0f4035a7cfe158f9ea46bd11c14c0b8e1f5e5121da68` |
| `CineAR/RoomAssets/kitchenStoveElectric.usdz` | 29702 | `b6607fcdfb518b204779961d1fb87a138436236a64438a81c6fcdcdc5606b4ba` |
| `CineAR/RoomAssets/korean_fire_extinguisher_01.usdz` | 2038320 | `0f329ca78bfbb62c158761c8b28bbc78a03481f0987ddeff60820f427810af4a` |
| `CineAR/RoomAssets/korean_public_payphone_01.usdz` | 5265471 | `e25b910f745ebfa2e27bc4ac3a88fd87c9b8707be76290121916377e3b076a72` |
| `CineAR/RoomAssets/loungeDesignSofa.usdz` | 12081 | `e1ff365a2245f802cd0c31f6972927d8b3a82a4356a46a1f525e79d58558d3ad` |
| `CineAR/RoomAssets/metal_office_desk.usdz` | 1847151 | `8e54007f0ddd27d5173e7f4931cdd5792322f6fe39143cfa3bfa5e98ab944511` |
| `CineAR/RoomAssets/metal_tool_chest.usdz` | 2896433 | `ddf665fc24dbda1019d726c54288afc71500758c5bddd3289dc4cb87fc194bba` |
| `CineAR/RoomAssets/metal_trash_can.usdz` | 5583572 | `d253968b18ad9982405358c23428602936c0c8342e1d225fdd4041e854619871` |
| `CineAR/RoomAssets/plastic_crate_02.usdz` | 2088182 | `c11bdb1dbad63f969123893423f44a7865558d5883759efac6d3e3697907a7a9` |
| `CineAR/RoomAssets/plastic_monobloc_chair_01.usdz` | 2086673 | `6866f6d1b1d3323d522d261a89b6a9c79907c3ae5a8b6c7d9d1daf3d9204ce3a` |
| `CineAR/RoomAssets/power_box_01.usdz` | 3489291 | `247cb86f3662b3cdc532229875c3e2ac56d986d5044b967cc51e9499d6fb60a0` |
| `CineAR/RoomAssets/SchoolChair_01.usdz` | 711033 | `738a489ba9b5aebb46539e4c1a5e22488709b3804b21f3deaf1c72677fcff4f6` |
| `CineAR/RoomAssets/SchoolDesk_01.usdz` | 589809 | `b21c081a220d72d0f837170f3dbe6c319db62910efa54b5d7f7bd7bced252596` |
| `CineAR/RoomAssets/security_camera_01.usdz` | 2355175 | `ee59094614b7e7a096dab1f7fd934b6dc9d5cc1b277382418481ebe896ade92a` |
| `CineAR/RoomAssets/stairs.usdz` | 27638 | `683484e342a13f68b78dda26ab97e0861d0ff36cbe2bbe39e4b4162b3cdb953b` |
| `CineAR/RoomAssets/steel_frame_shelves_01.usdz` | 1767903 | `a809a38664d4e8a65bb067d89a9f74985c1bc24c297b855fa14af4eed807700b` |
| `CineAR/RoomAssets/table.usdz` | 11768 | `2e84220a7d8db7ca03254c303be3f017ed5c07a080e86f9d94b15a18688af6d0` |
| `CineAR/RoomAssets/television_02.usdz` | 1332571 | `dc44f800926690dc281aed2f7fccb9340d70e253395c26ee59a80af3e097eaea` |
| `CineAR/RoomAssets/televisionModern.usdz` | 8484 | `a1f811cf0f1e9b4d8f3ca52e6ac0783d33e04809d97a8badda1a432e3b269819` |
| `CineAR/RoomAssets/toilet.usdz` | 22209 | `b6b52edf4f9d1403a261bf2ab56dd86f7a92840d0346ea23663f17510d972ff9` |
| `CineAR/RoomAssets/vintage_wooden_drawer_01.usdz` | 952403 | `e9f71c22852b4d505872ee41211c7e52297f09a683309a3f50fb36e3328468fe` |
| `CineAR/RoomAssets/wall_clock.usdz` | 1702023 | `9b83332d0db22eab9b514ee5a727acad1d846545785f763c558786e5bc165767` |
| `CineAR/RoomAssets/washerDryerStacked.usdz` | 83204 | `76d9e6d877d7003c51a503a1c6f890a7b85e9430363daa01f65a2cbb8fd72a16` |
| `CineAR/RoomAssets/WetFloorSign_01.usdz` | 275541 | `080f512792bcbfdaf913200c3b1e3f1a162c46b16d1ab655ae1b965617c74601` |
| `CineAR/RoomAssets/wooden_crate_02.usdz` | 2456256 | `842aedb3aa03d4fa34d5e78eb6e7cdf67a2e0da8a26d389b05181bfc494bee8b` |
| `CineAR/RoomAssets/wooden_stool_01.usdz` | 1433252 | `56fe820ab98f0bad3ba2fdaef340dd9a015b8020802b4859172d343445dba69f` |

## Güvenlik nedeniyle içeriği gömülmeyen dosyalar

Yok.

## Metin kaynakları indeksi

| Dosya | Satır | Boyut (byte) |
| --- | ---: | ---: |
| `.gitignore` | 30 | 559 |
| `AIService/fusion.py` | 100 | 3952 |
| `AIService/README.md` | 56 | 2480 |
| `AIService/requirements.txt` | 10 | 186 |
| `AIService/run_server.ps1` | 49 | 1778 |
| `AIService/server.py` | 197 | 7404 |
| `AIService/setup_windows.ps1` | 42 | 1945 |
| `AIService/test_fusion.py` | 27 | 835 |
| `AIService/THIRD_PARTY_NOTICES.md` | 21 | 745 |
| `CineAR.xcodeproj/project.pbxproj` | 276 | 13316 |
| `CineAR.xcodeproj/xcshareddata/xcschemes/CineAR.xcscheme` | 25 | 2161 |
| `CineAR/AIEnhancementClient.swift` | 435 | 17725 |
| `CineAR/ARSessionController.swift` | 4397 | 182864 |
| `CineAR/ARViewContainer.swift` | 14 | 274 |
| `CineAR/Assets.xcassets/AccentColor.colorset/Contents.json` | 22 | 330 |
| `CineAR/Assets.xcassets/AppIcon.appiconset/Contents.json` | 15 | 223 |
| `CineAR/Assets.xcassets/Contents.json` | 8 | 64 |
| `CineAR/BundledRoomRealityAssetProvider.swift` | 360 | 15400 |
| `CineAR/CineARApp.swift` | 13 | 185 |
| `CineAR/ContentView.swift` | 977 | 41036 |
| `CineAR/Info.plist` | 58 | 2069 |
| `CineAR/ProfessionalRecorder.swift` | 415 | 14546 |
| `CineAR/PropKind.swift` | 358 | 14201 |
| `CineAR/RealityTheme.swift` | 233 | 8307 |
| `CineAR/RoomAssets/LICENSE-KENNEY.txt` | 16 | 619 |
| `CineAR/RoomAssets/LICENSE-POLYHAVEN.txt` | 49 | 1217 |
| `CineAR/RoomAssets/MANIFEST.sha256` | 45 | 3837 |
| `CineAR/RoomRealityRenderer.swift` | 2073 | 79050 |
| `CineAR/RoomScanner.swift` | 601 | 20139 |
| `CineAR/SceneProjectStore.swift` | 887 | 36386 |
| `codemagic.yaml` | 131 | 4245 |
| `Docs/CODEMAGIC.md` | 86 | 4640 |
| `Docs/DEVICE_TEST.md` | 142 | 9565 |
| `Docs/ICON_PROMPT.md` | 25 | 1445 |
| `README.md` | 221 | 13670 |
| `Tools/convert_kenney_to_usdz.py` | 122 | 3767 |
| `Tools/convert_polyhaven_to_usdz.py` | 145 | 4557 |
| `Tools/fetch_polyhaven_props.ps1` | 88 | 2781 |
| `Tools/generate_all_in_one_markdown.ps1` | 347 | 18202 |
| `Tools/render_usdz_thumbnails.py` | 98 | 3779 |
| `Tools/validate_usdz_assets.py` | 67 | 2269 |

# Metin tabanlı proje dosyalarının tam içeriği

## `.gitignore`

````gitignore
# Xcode local state and build output
DerivedData/
build/
*.xcuserstate
xcuserdata/
*.xccheckout
*.xcscmblueprint
.DS_Store

# Apple signing secrets — never commit these
*.p8
*.p12
*.mobileprovision
ios_distribution_private_key*

# Local environment files
.env
.env.*

# Downloaded source archives; converted CC0 USDZ files are committed instead
Kenney-Furniture-Kit.zip
.asset-cache/
.tools-cache/
AIService/.venv/
AIService/__pycache__/
AIService/.cache/

# Generated handoff archives are release artifacts, not source files
CineAR-Codemagic-Handoff-*.zip
````

## `AIService/fusion.py`

````python
"""LiDAR-calibrated monocular depth fusion with SAM 2 boundary priors."""

from __future__ import annotations

import numpy as np


MIN_DEPTH_METERS = 0.15
MAX_DEPTH_METERS = 12.0


def _fit_affine(candidate: np.ndarray, lidar: np.ndarray, valid: np.ndarray) -> tuple[np.ndarray, float]:
    x = candidate[valid].astype(np.float64, copy=False)
    y = lidar[valid].astype(np.float64, copy=False)
    if x.size > 20_000:
        indices = np.linspace(0, x.size - 1, 20_000, dtype=np.int64)
        x = x[indices]
        y = y[indices]

    design = np.column_stack((x, np.ones_like(x)))
    scale, offset = np.linalg.lstsq(design, y, rcond=None)[0]
    prediction = candidate * np.float32(scale) + np.float32(offset)
    residual = np.abs(prediction[valid] - lidar[valid])
    cutoff = np.quantile(residual, 0.85)
    refined = np.zeros_like(valid)
    refined[valid] = residual <= cutoff
    if np.count_nonzero(refined) >= 128:
        x = candidate[refined].astype(np.float64, copy=False)
        y = lidar[refined].astype(np.float64, copy=False)
        design = np.column_stack((x, np.ones_like(x)))
        scale, offset = np.linalg.lstsq(design, y, rcond=None)[0]
        prediction = candidate * np.float32(scale) + np.float32(offset)

    score = float(np.median(np.abs(prediction[valid] - lidar[valid])))
    return prediction.astype(np.float32, copy=False), score


def align_relative_depth(relative: np.ndarray, lidar: np.ndarray) -> np.ndarray:
    """Resolve relative-depth direction and affine scale from real LiDAR metres."""
    valid = (
        np.isfinite(lidar)
        & (lidar >= MIN_DEPTH_METERS)
        & (lidar <= MAX_DEPTH_METERS)
        & np.isfinite(relative)
    )
    if np.count_nonzero(valid) < 128:
        fallback = lidar.astype(np.float32, copy=True)
        fallback[~np.isfinite(fallback)] = 0
        return fallback

    normalized = relative.astype(np.float32, copy=False)
    inverse = 1.0 / np.maximum(normalized, np.float32(1e-4))
    direct_result, direct_score = _fit_affine(normalized, lidar, valid)
    inverse_result, inverse_score = _fit_affine(inverse, lidar, valid)
    return direct_result if direct_score <= inverse_score else inverse_result


def _mask_edge(mask: np.ndarray) -> np.ndarray:
    padded = np.pad(mask, 1, mode="edge")
    eroded = np.ones_like(mask, dtype=bool)
    for y_offset in range(3):
        for x_offset in range(3):
            eroded &= padded[
                y_offset : y_offset + mask.shape[0],
                x_offset : x_offset + mask.shape[1],
            ]
    return mask & ~eroded


def fuse_depth(relative: np.ndarray, lidar: np.ndarray, masks: list[np.ndarray]) -> np.ndarray:
    """Keep reliable LiDAR, fill holes with AI, and sharpen SAM 2 boundaries."""
    aligned = align_relative_depth(relative, lidar)
    lidar_valid = (
        np.isfinite(lidar)
        & (lidar >= MIN_DEPTH_METERS)
        & (lidar <= MAX_DEPTH_METERS)
    )

    # Calibrate each sufficiently observed SAM object independently. This prevents
    # a table and the wall behind it from sharing one monocular-depth offset.
    boundary = np.zeros(lidar.shape, dtype=bool)
    for mask in masks:
        if mask.shape != lidar.shape:
            continue
        region = mask & lidar_valid & np.isfinite(aligned)
        if np.count_nonzero(region) >= 32:
            offset = np.median(lidar[region] - aligned[region])
            aligned[mask] += np.float32(offset)
        boundary |= _mask_edge(mask)

    fused = aligned.astype(np.float32, copy=True)
    regular = lidar_valid & ~boundary
    fused[regular] = lidar[regular] * 0.90 + aligned[regular] * 0.10
    edge_valid = lidar_valid & boundary
    fused[edge_valid] = lidar[edge_valid] * 0.35 + aligned[edge_valid] * 0.65
    fused[~np.isfinite(fused)] = 0
    invalid_range = (fused < MIN_DEPTH_METERS) | (fused > MAX_DEPTH_METERS)
    fused[invalid_range] = 0
    return np.ascontiguousarray(fused, dtype=np.float32)
````

## `AIService/README.md`

````markdown
# CineAR PC AI Derinlik Servisi

Bu servis iPhone'un kamera karesini ve ARKit LiDAR derinligini ayni Wi-Fi uzerinden
alir. Depth Anything V2 Small ile yogun derinlik uretir, SAM 2.1 Tiny maskelerini
nesne siniri olarak kullanir ve sonucu LiDAR metreleriyle kalibre ederek telefona
geri yollar. RealityKit dunya takibi ve anchor'lar telefonda kalir.

## Windows kurulumu

PowerShell'de depo kokunden:

```powershell
powershell -ExecutionPolicy Bypass -File .\AIService\setup_windows.ps1
powershell -ExecutionPolicy Bypass -File .\AIService\run_server.ps1
```

Ilk kurulum ve ilk servis acilisi PyTorch ile model agirliklarini indirir. Windows
Guvenlik Duvari sorarsa Python icin yalnizca `Ozel aglar` erisimini acin. Konsolda
yazilan `http://192.168...:8765` adresini CineAR icindeki `AI Derinlik` ayarina girin.
iPhone ve PC ayni yerel agda olmalidir.

Hotspot veya Wi-Fi degistiginde IP adresi de degisir. `run_server.ps1`, varsayilan ag
gecidi bulunan etkin Wi-Fi/Ethernet baglantisini secer; VMware/VirtualBox gibi sanal
adaptorlere ait adresleri iPhone adresi olarak gostermez. Betigi yeniden baslatin ve
ekranda yazan yeni adresi uygulamadaki `AI Derinlik` alanina girin.

PC'de saglik adresi calisip iPhone baglanamiyorsa iPhone Safari'de konsolda yazan
adresin sonuna `/health` ekleyerek acin. Safari de acamiyorsa Wi-Fi istemci yalitimi
ve Windows Guvenlik Duvari kontrol edilmelidir. Safari aciyor fakat CineAR acamiyorsa
iPhone Ayarlarinda CineAR icin `Yerel Ag` izni etkinlestirilmelidir.

Bu bilgisayardaki RTX 3050 Laptop GPU 4 GB icin varsayilan modeller bilerek
`Depth-Anything-V2-Small` ve `sam2.1-hiera-tiny` secilmistir. Daha buyuk modeller
gecikmeyi ve bellek tasmasi riskini ciddi bicimde artirir.

27 Agustos 2026 yerel dogrulamasinda RTX 3050 ilk isitma istegini 1847 ms,
ikinci istegi 682 ms'de tamamladi; SAM 2 dokuz maske uretti ve yapay LiDAR
boslugunun %100'u metreye kalibre edilmis Depth Anything sonucu ile doldu.
iPhone istemcisi 1500 ms'yi asan sonucu eski hareketli insan geometrisi
uretmemek icin reddeder ve ARKit occlusion'a geri doner.

Saglik kontrolu:

```powershell
Invoke-RestMethod http://127.0.0.1:8765/health
```

## Lisans

- Meta SAM 2 kodu ve agirliklari: Apache-2.0
- Depth Anything V2 Small: Apache-2.0
- Depth Anything V2 Base/Large/Giant: CC-BY-NC-4.0; ticari CineAR paketinde kullanilmaz

Model agirliklari Git deposuna veya iOS uygulamasina eklenmez; kurulum sirasinda
resmi Hugging Face depolarindan PC onbellegine indirilir.
````

## `AIService/requirements.txt`

````text
fastapi>=0.115,<1
huggingface-hub>=0.26,<2
numpy>=1.26,<2
pillow>=10,<13
pydantic>=2.9,<3
python-multipart>=0.0.9,<1
safetensors>=0.4,<1
transformers>=4.45,<6
uvicorn[standard]>=0.30,<1
````

## `AIService/run_server.ps1`

````powershell
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

Push-Location $repoRoot
try {
    & $python -m uvicorn AIService.server:app --host 0.0.0.0 --port 8765
} finally {
    Pop-Location
}
````

## `AIService/server.py`

````python
"""CineAR LAN inference service: Depth Anything V2 + SAM 2.1 + LiDAR fusion."""

from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager, nullcontext
from io import BytesIO
import os
from threading import Lock
import time

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import Response
import numpy as np
from PIL import Image
import torch
import torch.nn.functional as torch_functional
from transformers import AutoImageProcessor, AutoModelForDepthEstimation

from AIService.fusion import fuse_depth


DEPTH_MODEL_ID = os.environ.get(
    "CINEAR_DEPTH_MODEL",
    "depth-anything/Depth-Anything-V2-Small-hf",
)
SAM_MODEL_ID = os.environ.get("CINEAR_SAM_MODEL", "facebook/sam2.1-hiera-tiny")
SAM_POINTS_PER_SIDE = int(os.environ.get("CINEAR_SAM_POINTS", "8"))
SAM_MAX_SIDE = int(os.environ.get("CINEAR_SAM_MAX_SIDE", "512"))
MAX_PIXELS = 640 * 480


class InferenceModels:
    def __init__(self) -> None:
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.depth_processor = None
        self.depth_model = None
        self.mask_generator = None
        self.ready = False
        self.load_error: str | None = None
        self.lock = Lock()

    def load(self) -> None:
        try:
            self.depth_processor = AutoImageProcessor.from_pretrained(DEPTH_MODEL_ID)
            self.depth_model = AutoModelForDepthEstimation.from_pretrained(DEPTH_MODEL_ID)
            self.depth_model = self.depth_model.to(self.device).eval()

            from sam2.automatic_mask_generator import SAM2AutomaticMaskGenerator
            from sam2.build_sam import build_sam2_hf

            sam_model = build_sam2_hf(
                SAM_MODEL_ID,
                device=str(self.device),
                apply_postprocessing=False,
            )
            self.mask_generator = SAM2AutomaticMaskGenerator(
                model=sam_model,
                points_per_side=SAM_POINTS_PER_SIDE,
                points_per_batch=16,
                pred_iou_thresh=0.88,
                stability_score_thresh=0.92,
                crop_n_layers=0,
                min_mask_region_area=0,
                output_mode="binary_mask",
            )
            self.ready = True
        except Exception as error:  # surfaced by /health and startup log
            self.load_error = f"{type(error).__name__}: {error}"
            raise

    def _autocast(self):
        if self.device.type == "cuda":
            return torch.autocast(device_type="cuda", dtype=torch.float16)
        return nullcontext()

    def _relative_depth(self, image: Image.Image, height: int, width: int) -> np.ndarray:
        inputs = self.depth_processor(images=image, return_tensors="pt")
        pixel_values = inputs["pixel_values"].to(self.device)
        with torch.inference_mode(), self._autocast():
            prediction = self.depth_model(pixel_values=pixel_values).predicted_depth
            prediction = torch_functional.interpolate(
                prediction.unsqueeze(1),
                size=(height, width),
                mode="bicubic",
                align_corners=False,
            ).squeeze(0).squeeze(0)
        return prediction.float().cpu().numpy().astype(np.float32, copy=False)

    def _sam_masks(self, image: Image.Image, height: int, width: int) -> list[np.ndarray]:
        scale = min(1.0, SAM_MAX_SIDE / max(image.size))
        sam_size = (
            max(32, round(image.width * scale)),
            max(32, round(image.height * scale)),
        )
        sam_image = np.asarray(
            image.resize(sam_size, Image.Resampling.BILINEAR),
            dtype=np.uint8,
        ).copy()
        with torch.inference_mode(), self._autocast():
            records = self.mask_generator.generate(sam_image)
        records.sort(key=lambda item: item["area"], reverse=True)
        masks: list[np.ndarray] = []
        for record in records[:48]:
            binary = Image.fromarray(record["segmentation"].astype(np.uint8) * 255)
            resized = binary.resize((width, height), Image.Resampling.NEAREST)
            mask = np.asarray(resized) > 0
            coverage = float(np.count_nonzero(mask)) / mask.size
            if 0.002 <= coverage <= 0.92:
                masks.append(mask)
        return masks

    def infer(self, image: Image.Image, lidar: np.ndarray) -> tuple[np.ndarray, int, float]:
        if not self.ready:
            raise RuntimeError(self.load_error or "Models are not ready")
        started = time.perf_counter()
        with self.lock:
            relative = self._relative_depth(image, lidar.shape[0], lidar.shape[1])
            masks = self._sam_masks(image, lidar.shape[0], lidar.shape[1])
            fused = fuse_depth(relative, lidar, masks)
        elapsed_ms = (time.perf_counter() - started) * 1_000
        return fused, len(masks), elapsed_ms


models = InferenceModels()


@asynccontextmanager
async def lifespan(_: FastAPI):
    await asyncio.to_thread(models.load)
    yield


app = FastAPI(title="CineAR AI Depth", version="1.0", lifespan=lifespan)


@app.get("/health")
def health() -> dict[str, object]:
    return {
        "ready": models.ready,
        "device": str(models.device),
        "depth_model": DEPTH_MODEL_ID,
        "sam_model": SAM_MODEL_ID,
        "error": models.load_error,
    }


@app.post("/v1/depth")
async def depth(
    image: UploadFile = File(...),
    lidar: UploadFile = File(...),
    frame_id: str = Form(...),
    depth_width: int = Form(...),
    depth_height: int = Form(...),
) -> Response:
    if not models.ready:
        raise HTTPException(status_code=503, detail=models.load_error or "Models are loading")
    if depth_width <= 0 or depth_height <= 0 or depth_width * depth_height > MAX_PIXELS:
        raise HTTPException(status_code=400, detail="Invalid depth dimensions")

    image_bytes, lidar_bytes = await asyncio.gather(image.read(), lidar.read())
    expected_bytes = depth_width * depth_height * np.dtype("<f4").itemsize
    if len(lidar_bytes) != expected_bytes:
        raise HTTPException(
            status_code=400,
            detail=f"LiDAR payload is {len(lidar_bytes)} bytes; expected {expected_bytes}",
        )
    try:
        camera_image = Image.open(BytesIO(image_bytes)).convert("RGB")
        camera_image.load()
    except Exception as error:
        raise HTTPException(status_code=400, detail=f"Invalid camera image: {error}") from error

    lidar_depth = np.frombuffer(lidar_bytes, dtype="<f4").reshape(depth_height, depth_width)
    try:
        fused, mask_count, elapsed_ms = await asyncio.to_thread(
            models.infer,
            camera_image,
            lidar_depth,
        )
    except RuntimeError as error:
        if "out of memory" in str(error).lower() and torch.cuda.is_available():
            torch.cuda.empty_cache()
        raise HTTPException(status_code=500, detail=str(error)) from error

    return Response(
        content=fused.astype("<f4", copy=False).tobytes(),
        media_type="application/octet-stream",
        headers={
            "X-CineAR-Frame-ID": frame_id,
            "X-CineAR-Depth-Width": str(depth_width),
            "X-CineAR-Depth-Height": str(depth_height),
            "X-CineAR-SAM-Masks": str(mask_count),
            "X-CineAR-Inference-MS": f"{elapsed_ms:.1f}",
        },
    )
````

## `AIService/setup_windows.ps1`

````powershell
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
````

## `AIService/test_fusion.py`

````python
import unittest

import numpy as np

from AIService.fusion import fuse_depth


class FusionTests(unittest.TestCase):
    def test_relative_depth_is_calibrated_to_lidar_metres(self):
        y, x = np.mgrid[0:24, 0:32]
        lidar = (0.8 + x * 0.03 + y * 0.01).astype(np.float32)
        relative_inverse = 1.0 / ((lidar - 0.2) / 1.7)
        result = fuse_depth(relative_inverse, lidar, [])
        self.assertLess(float(np.median(np.abs(result - lidar))), 0.01)

    def test_ai_fills_invalid_lidar_hole(self):
        lidar = np.full((24, 32), 2.0, dtype=np.float32)
        relative = np.full_like(lidar, 5.0)
        relative[:, 16:] = 3.0
        lidar[8:16, 10:22] = 0
        result = fuse_depth(relative, lidar, [])
        self.assertTrue(np.all(result[8:16, 10:22] > 0.15))


if __name__ == "__main__":
    unittest.main()
````

## `AIService/THIRD_PARTY_NOTICES.md`

````markdown
# AI third-party notices

CineAR's optional PC inference service downloads and executes these models at
installation/runtime. Model weights are not committed to this repository.

## Segment Anything Model 2 (SAM 2.1 Tiny)

- Source: https://github.com/facebookresearch/sam2
- Model: `facebook/sam2.1-hiera-tiny`
- Copyright: Meta Platforms, Inc. and affiliates
- License: Apache License 2.0

## Depth Anything V2 Small

- Source: https://github.com/DepthAnything/Depth-Anything-V2
- Model: `depth-anything/Depth-Anything-V2-Small-hf`
- License for the Small model: Apache License 2.0

Depth Anything V2 Base, Large, and Giant are intentionally not used because
their published license is CC-BY-NC-4.0 and CineAR may be commercially distributed.
````

## `CineAR.xcodeproj/project.pbxproj`

````text
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {};
	objectVersion = 56;
	objects = {

/* Begin PBXBuildFile section */
		A10000000000000000000001 /* CineARApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = B10000000000000000000001 /* CineARApp.swift */; };
		A10000000000000000000002 /* ContentView.swift in Sources */ = {isa = PBXBuildFile; fileRef = B10000000000000000000002 /* ContentView.swift */; };
		A10000000000000000000003 /* ARViewContainer.swift in Sources */ = {isa = PBXBuildFile; fileRef = B10000000000000000000003 /* ARViewContainer.swift */; };
		A10000000000000000000004 /* PropKind.swift in Sources */ = {isa = PBXBuildFile; fileRef = B10000000000000000000004 /* PropKind.swift */; };
		A10000000000000000000005 /* ARSessionController.swift in Sources */ = {isa = PBXBuildFile; fileRef = B10000000000000000000005 /* ARSessionController.swift */; };
		A10000000000000000000006 /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = B10000000000000000000006 /* Assets.xcassets */; };
		A10000000000000000000007 /* SceneProjectStore.swift in Sources */ = {isa = PBXBuildFile; fileRef = B10000000000000000000009 /* SceneProjectStore.swift */; };
		A10000000000000000000008 /* ProfessionalRecorder.swift in Sources */ = {isa = PBXBuildFile; fileRef = B1000000000000000000000A /* ProfessionalRecorder.swift */; };
		A10000000000000000000009 /* RoomScanner.swift in Sources */ = {isa = PBXBuildFile; fileRef = B1000000000000000000000B /* RoomScanner.swift */; };
		A1000000000000000000000A /* RealityTheme.swift in Sources */ = {isa = PBXBuildFile; fileRef = B1000000000000000000000C /* RealityTheme.swift */; };
		A1000000000000000000000B /* RoomRealityRenderer.swift in Sources */ = {isa = PBXBuildFile; fileRef = B1000000000000000000000D /* RoomRealityRenderer.swift */; };
		A1000000000000000000000C /* BundledRoomRealityAssetProvider.swift in Sources */ = {isa = PBXBuildFile; fileRef = B1000000000000000000000E /* BundledRoomRealityAssetProvider.swift */; };
		A1000000000000000000000D /* RoomAssets in Resources */ = {isa = PBXBuildFile; fileRef = B1000000000000000000000F /* RoomAssets */; };
		A1000000000000000000000E /* AIEnhancementClient.swift in Sources */ = {isa = PBXBuildFile; fileRef = B10000000000000000000010 /* AIEnhancementClient.swift */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		B10000000000000000000001 /* CineARApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = CineARApp.swift; sourceTree = "<group>"; };
		B10000000000000000000002 /* ContentView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ContentView.swift; sourceTree = "<group>"; };
		B10000000000000000000003 /* ARViewContainer.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ARViewContainer.swift; sourceTree = "<group>"; };
		B10000000000000000000004 /* PropKind.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PropKind.swift; sourceTree = "<group>"; };
		B10000000000000000000005 /* ARSessionController.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ARSessionController.swift; sourceTree = "<group>"; };
		B10000000000000000000006 /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; };
		B10000000000000000000007 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; };
		B10000000000000000000008 /* CineAR.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = CineAR.app; sourceTree = BUILT_PRODUCTS_DIR; };
		B10000000000000000000009 /* SceneProjectStore.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SceneProjectStore.swift; sourceTree = "<group>"; };
		B1000000000000000000000A /* ProfessionalRecorder.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ProfessionalRecorder.swift; sourceTree = "<group>"; };
		B1000000000000000000000B /* RoomScanner.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RoomScanner.swift; sourceTree = "<group>"; };
		B1000000000000000000000C /* RealityTheme.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RealityTheme.swift; sourceTree = "<group>"; };
		B1000000000000000000000D /* RoomRealityRenderer.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RoomRealityRenderer.swift; sourceTree = "<group>"; };
		B1000000000000000000000E /* BundledRoomRealityAssetProvider.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = BundledRoomRealityAssetProvider.swift; sourceTree = "<group>"; };
		B1000000000000000000000F /* RoomAssets */ = {isa = PBXFileReference; lastKnownFileType = folder; path = RoomAssets; sourceTree = "<group>"; };
		B10000000000000000000010 /* AIEnhancementClient.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = AIEnhancementClient.swift; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		C10000000000000000000001 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = ();
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		D10000000000000000000001 = {
			isa = PBXGroup;
			children = (
				D10000000000000000000002 /* CineAR */,
				D10000000000000000000003 /* Products */,
			);
			sourceTree = "<group>";
		};
		D10000000000000000000002 /* CineAR */ = {
			isa = PBXGroup;
			children = (
				B10000000000000000000001 /* CineARApp.swift */,
				B10000000000000000000002 /* ContentView.swift */,
				B10000000000000000000003 /* ARViewContainer.swift */,
				B10000000000000000000004 /* PropKind.swift */,
				B10000000000000000000005 /* ARSessionController.swift */,
				B10000000000000000000009 /* SceneProjectStore.swift */,
				B1000000000000000000000A /* ProfessionalRecorder.swift */,
				B1000000000000000000000B /* RoomScanner.swift */,
				B1000000000000000000000C /* RealityTheme.swift */,
				B1000000000000000000000D /* RoomRealityRenderer.swift */,
				B1000000000000000000000E /* BundledRoomRealityAssetProvider.swift */,
				B10000000000000000000010 /* AIEnhancementClient.swift */,
				B1000000000000000000000F /* RoomAssets */,
				B10000000000000000000006 /* Assets.xcassets */,
				B10000000000000000000007 /* Info.plist */,
			);
			path = CineAR;
			sourceTree = "<group>";
		};
		D10000000000000000000003 /* Products */ = {
			isa = PBXGroup;
			children = (
				B10000000000000000000008 /* CineAR.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		E10000000000000000000001 /* CineAR */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = F10000000000000000000002 /* Build configuration list for PBXNativeTarget "CineAR" */;
			buildPhases = (
				C10000000000000000000002 /* Sources */,
				C10000000000000000000001 /* Frameworks */,
				C10000000000000000000003 /* Resources */,
			);
			buildRules = ();
			dependencies = ();
			name = CineAR;
			productName = CineAR;
			productReference = B10000000000000000000008 /* CineAR.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		E10000000000000000000002 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				TargetAttributes = {
					E10000000000000000000001 = { CreatedOnToolsVersion = 15.0; };
				};
			};
			buildConfigurationList = F10000000000000000000001 /* Build configuration list for PBXProject "CineAR" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (en, Base);
			mainGroup = D10000000000000000000001;
			productRefGroup = D10000000000000000000003 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (E10000000000000000000001 /* CineAR */);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		C10000000000000000000003 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				A10000000000000000000006 /* Assets.xcassets in Resources */,
				A1000000000000000000000D /* RoomAssets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		C10000000000000000000002 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				A10000000000000000000001 /* CineARApp.swift in Sources */,
				A10000000000000000000002 /* ContentView.swift in Sources */,
				A10000000000000000000003 /* ARViewContainer.swift in Sources */,
				A10000000000000000000004 /* PropKind.swift in Sources */,
				A10000000000000000000005 /* ARSessionController.swift in Sources */,
				A10000000000000000000007 /* SceneProjectStore.swift in Sources */,
				A10000000000000000000008 /* ProfessionalRecorder.swift in Sources */,
				A10000000000000000000009 /* RoomScanner.swift in Sources */,
				A1000000000000000000000A /* RealityTheme.swift in Sources */,
				A1000000000000000000000B /* RoomRealityRenderer.swift in Sources */,
				A1000000000000000000000C /* BundledRoomRealityAssetProvider.swift in Sources */,
				A1000000000000000000000E /* AIEnhancementClient.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		F10000000000000000000003 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = ("DEBUG=1", "$(inherited)");
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		F10000000000000000000004 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				GCC_C_LANGUAGE_STANDARD = gnu17;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
		};
			name = Release;
		};
		F10000000000000000000005 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_ACCENT_COLOR_NAME = AccentColor;
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 20;
				DEVELOPMENT_ASSET_PATHS = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = CineAR/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MARKETING_VERSION = 0.12.1;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				PRODUCT_BUNDLE_IDENTIFIER = com.cinear.virtualproduction;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
				VERSIONING_SYSTEM = "apple-generic";
			};
			name = Debug;
		};
		F10000000000000000000006 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_ACCENT_COLOR_NAME = AccentColor;
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 20;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = CineAR/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MARKETING_VERSION = 0.12.1;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				PRODUCT_BUNDLE_IDENTIFIER = com.cinear.virtualproduction;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = 1;
				VERSIONING_SYSTEM = "apple-generic";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		F10000000000000000000001 /* Build configuration list for PBXProject "CineAR" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				F10000000000000000000003 /* Debug */,
				F10000000000000000000004 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		F10000000000000000000002 /* Build configuration list for PBXNativeTarget "CineAR" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				F10000000000000000000005 /* Debug */,
				F10000000000000000000006 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = E10000000000000000000002 /* Project object */;
}
````

## `CineAR.xcodeproj/xcshareddata/xcschemes/CineAR.xcscheme`

````xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1500" version="1.7">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="E10000000000000000000001" BuildableName="CineAR.app" BlueprintName="CineAR" ReferencedContainer="container:CineAR.xcodeproj"/>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"/>
   <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="E10000000000000000000001" BuildableName="CineAR.app" BlueprintName="CineAR" ReferencedContainer="container:CineAR.xcodeproj"/>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="E10000000000000000000001" BuildableName="CineAR.app" BlueprintName="CineAR" ReferencedContainer="container:CineAR.xcodeproj"/>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration="Debug"/>
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>

````

## `CineAR/AIEnhancementClient.swift`

````swift
import ARKit
import CoreImage
import Foundation
import RealityKit
import UIKit
import simd

enum AIEnhancementStatus: Equatable {
    case disabled
    case waiting
    case waitingForDepth
    case active(latencyMilliseconds: Int, samMaskCount: Int)
    case failed(String)

    var title: String {
        switch self {
        case .disabled: "Kapalı"
        case .waiting: "PC bağlantısı bekleniyor"
        case .waitingForDepth: "PC bağlı · LiDAR karesi bekleniyor"
        case .active(let latency, let masks): "Aktif · \(latency) ms · \(masks) maske"
        case .failed(let message): "Hata · \(message)"
        }
    }
}

struct AIDepthResult {
    let frameID: UUID
    let cameraTransform: simd_float4x4
    let intrinsics: simd_float3x3
    let imageWidth: Int
    let imageHeight: Int
    let depthWidth: Int
    let depthHeight: Int
    let depthMeters: [Float]
    let totalLatencyMilliseconds: Int
    let inferenceMilliseconds: Int
    let samMaskCount: Int
}

enum AIEnhancementError: LocalizedError {
    case invalidServerAddress
    case missingSceneDepth
    case imageEncodingFailed
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidServerAddress: "Geçerli bir PC adresi gir (ör. http://192.168.1.20:8765)"
        case .missingSceneDepth: "Bu karede LiDAR derinliği yok"
        case .imageEncodingFailed: "Kamera karesi AI servisi için hazırlanamadı"
        case .invalidResponse: "AI servisinden geçersiz derinlik verisi geldi"
        case .server(let message): message
        }
    }
}

@MainActor
final class AIEnhancementClient {
    private struct CapturedMetadata {
        let frameID: UUID
        let cameraTransform: simd_float4x4
        let intrinsics: simd_float3x3
        let imageWidth: Int
        let imageHeight: Int
        let depthWidth: Int
        let depthHeight: Int
        let startedAt: ContinuousClock.Instant
    }

    private let context = CIContext(options: [.cacheIntermediates: false])
    private let clock = ContinuousClock()
    private var activeTask: URLSessionDataTask?
    private var lastSubmission: ContinuousClock.Instant?
    private let minimumFrameInterval: Duration = .milliseconds(700)

    var isBusy: Bool { activeTask != nil }

    static func serverURL(from text: String) -> URL? {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if !value.contains("://") { value = "http://" + value }
        guard var components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host != nil,
              components.user == nil,
              components.password == nil else { return nil }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url
    }

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
    }

    func submit(
        frame: ARFrame,
        serverURL: URL,
        completion: @escaping (Result<AIDepthResult, Error>) -> Void
    ) {
        guard activeTask == nil else { return }
        let now = clock.now
        if let lastSubmission, now - lastSubmission < minimumFrameInterval { return }
        lastSubmission = now

        guard let sceneDepth = frame.smoothedSceneDepth ?? frame.sceneDepth else {
            completion(.failure(AIEnhancementError.missingSceneDepth))
            return
        }
        let depthMap = sceneDepth.depthMap
        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)
        guard let lidarData = Self.copyFloat32Depth(from: depthMap) else {
            completion(.failure(AIEnhancementError.missingSceneDepth))
            return
        }

        let capturedImage = frame.capturedImage
        let imageWidth = CVPixelBufferGetWidth(capturedImage)
        let imageHeight = CVPixelBufferGetHeight(capturedImage)
        guard let jpegData = jpegData(from: capturedImage) else {
            completion(.failure(AIEnhancementError.imageEncodingFailed))
            return
        }

        let metadata = CapturedMetadata(
            frameID: UUID(),
            cameraTransform: frame.camera.transform,
            intrinsics: frame.camera.intrinsics,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            depthWidth: depthWidth,
            depthHeight: depthHeight,
            startedAt: now
        )
        var endpoint = serverURL
        endpoint.append(path: "v1/depth")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        let boundary = "CineAR-\(metadata.frameID.uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.multipartBody(
            boundary: boundary,
            frameID: metadata.frameID,
            depthWidth: depthWidth,
            depthHeight: depthHeight,
            jpegData: jpegData,
            lidarData: lidarData
        )

        activeTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.activeTask = nil
                if let error {
                    if (error as? URLError)?.code != .cancelled {
                        completion(.failure(Self.connectionError(error, serverURL: serverURL)))
                    }
                    return
                }
                guard let http = response as? HTTPURLResponse, let data else {
                    completion(.failure(AIEnhancementError.invalidResponse))
                    return
                }
                guard (200..<300).contains(http.statusCode) else {
                    let detail = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                    completion(.failure(AIEnhancementError.server(detail)))
                    return
                }
                let expectedCount = metadata.depthWidth * metadata.depthHeight
                guard data.count == expectedCount * MemoryLayout<Float>.size else {
                    completion(.failure(AIEnhancementError.invalidResponse))
                    return
                }
                var depths = [Float](repeating: 0, count: expectedCount)
                _ = depths.withUnsafeMutableBytes { destination in
                    data.copyBytes(to: destination)
                }
                let elapsed = metadata.startedAt.duration(to: self.clock.now)
                let components = elapsed.components
                let totalMilliseconds = Int(components.seconds * 1_000)
                    + Int(components.attoseconds / 1_000_000_000_000_000)
                let inference = Int(
                    Double(http.value(forHTTPHeaderField: "X-CineAR-Inference-MS") ?? "0") ?? 0
                )
                let masks = Int(http.value(forHTTPHeaderField: "X-CineAR-SAM-Masks") ?? "0") ?? 0
                completion(.success(AIDepthResult(
                    frameID: metadata.frameID,
                    cameraTransform: metadata.cameraTransform,
                    intrinsics: metadata.intrinsics,
                    imageWidth: metadata.imageWidth,
                    imageHeight: metadata.imageHeight,
                    depthWidth: metadata.depthWidth,
                    depthHeight: metadata.depthHeight,
                    depthMeters: depths,
                    totalLatencyMilliseconds: totalMilliseconds,
                    inferenceMilliseconds: inference,
                    samMaskCount: masks
                )))
            }
        }
        activeTask?.resume()
    }

    func testHealth(
        serverURL: URL,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        var endpoint = serverURL
        endpoint.append(path: "health")
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                if let error {
                    completion(.failure(Self.connectionError(error, serverURL: serverURL)))
                    return
                }
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      let data,
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      object["ready"] as? Bool == true else {
                    completion(.failure(AIEnhancementError.invalidResponse))
                    return
                }
                let device = object["device"] as? String ?? "bilinmeyen cihaz"
                completion(.success(device))
            }
        }.resume()
    }

    private static func connectionError(_ error: Error, serverURL: URL) -> Error {
        guard let urlError = error as? URLError else { return error }
        let address = serverURL.absoluteString
        switch urlError.code {
        case .timedOut:
            return AIEnhancementError.server(
                "PC yanıt vermedi: \(address). Aynı Wi-Fi ve güvenlik duvarını kontrol et"
            )
        case .cannotConnectToHost:
            return AIEnhancementError.server(
                "\(address) adresinde servis yok; PC'de run_server.ps1 açık kalmalı"
            )
        case .cannotFindHost:
            return AIEnhancementError.server("PC adresi bulunamadı: \(address)")
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return AIEnhancementError.server(
                "iPhone ağ bağlantısı veya CineAR Yerel Ağ izni kapalı"
            )
        case .appTransportSecurityRequiresSecureConnection:
            return AIEnhancementError.server("iOS yerel HTTP bağlantısını engelledi")
        default:
            return AIEnhancementError.server(urlError.localizedDescription)
        }
    }

    private func jpegData(from pixelBuffer: CVPixelBuffer) -> Data? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let maximumSide: CGFloat = 640
        let scale = min(1, maximumSide / max(image.extent.width, image.extent.height))
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.72)
    }

    private static func copyFloat32Depth(from pixelBuffer: CVPixelBuffer) -> Data? {
        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_DepthFloat32 else {
            return nil
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        var result = Data(capacity: width * height * MemoryLayout<Float>.size)
        for row in 0..<height {
            let bytes = base
                .advanced(by: row * bytesPerRow)
                .assumingMemoryBound(to: UInt8.self)
            result.append(bytes, count: width * MemoryLayout<Float>.size)
        }
        return result
    }

    private static func multipartBody(
        boundary: String,
        frameID: UUID,
        depthWidth: Int,
        depthHeight: Int,
        jpegData: Data,
        lidarData: Data
    ) -> Data {
        var body = Data()
        func append(_ value: String) {
            body.append(value.data(using: .utf8)!)
        }
        func field(_ name: String, _ value: String) {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append("\(value)\r\n")
        }
        field("frame_id", frameID.uuidString)
        field("depth_width", String(depthWidth))
        field("depth_height", String(depthHeight))
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"image\"; filename=\"frame.jpg\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(jpegData)
        append("\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"lidar\"; filename=\"depth.f32\"\r\n")
        append("Content-Type: application/octet-stream\r\n\r\n")
        body.append(lidarData)
        append("\r\n--\(boundary)--\r\n")
        return body
    }
}

@MainActor
final class AIDepthOcclusionRenderer {
    private weak var arView: ARView?
    private var anchor: AnchorEntity?
    private var model: ModelEntity?

    func install(in arView: ARView) {
        self.arView = arView
        if let anchor, anchor.parent != nil { return }
        let newAnchor = AnchorEntity(world: SIMD3<Float>(repeating: 0))
        newAnchor.name = "cinear.ai-depth.anchor"
        arView.scene.addAnchor(newAnchor)
        anchor = newAnchor
    }

    func clear() {
        model?.removeFromParent()
        model = nil
    }

    func remove() {
        clear()
        anchor?.removeFromParent()
        anchor = nil
        arView = nil
    }

    func render(_ result: AIDepthResult) throws {
        guard let arView else { return }
        install(in: arView)
        let mesh = try Self.makeMesh(from: result)
        let replacement = ModelEntity(mesh: mesh, materials: [OcclusionMaterial()])
        replacement.name = "cinear.ai-depth.occlusion.\(result.frameID.uuidString)"
        model?.removeFromParent()
        anchor?.addChild(replacement)
        model = replacement
    }

    private static func makeMesh(from result: AIDepthResult) throws -> MeshResource {
        let width = result.depthWidth
        let height = result.depthHeight
        let step = max(1, max(width / 80, height / 60))
        var xValues = Array(stride(from: 0, to: width, by: step))
        var yValues = Array(stride(from: 0, to: height, by: step))
        if xValues.last != width - 1 { xValues.append(width - 1) }
        if yValues.last != height - 1 { yValues.append(height - 1) }

        let fx = result.intrinsics.columns.0.x * Float(width) / Float(result.imageWidth)
        let fy = result.intrinsics.columns.1.y * Float(height) / Float(result.imageHeight)
        let cx = result.intrinsics.columns.2.x * Float(width) / Float(result.imageWidth)
        let cy = result.intrinsics.columns.2.y * Float(height) / Float(result.imageHeight)
        guard fx.isFinite, fy.isFinite, fx > 0, fy > 0 else {
            throw AIEnhancementError.invalidResponse
        }

        let columns = xValues.count
        var positions = [SIMD3<Float>]()
        var sampledDepths = [Float]()
        var valid = [Bool]()
        positions.reserveCapacity(columns * yValues.count)
        sampledDepths.reserveCapacity(columns * yValues.count)
        valid.reserveCapacity(columns * yValues.count)
        for y in yValues {
            for x in xValues {
                let depth = result.depthMeters[y * width + x]
                let isValid = depth.isFinite && (0.15...12).contains(depth)
                sampledDepths.append(depth)
                valid.append(isValid)
                guard isValid else {
                    positions.append(.zero)
                    continue
                }
                let cameraX = (Float(x) - cx) / fx * depth
                let cameraY = -(Float(y) - cy) / fy * depth
                let cameraPoint = SIMD4<Float>(cameraX, cameraY, -depth, 1)
                let worldPoint = result.cameraTransform * cameraPoint
                positions.append([worldPoint.x, worldPoint.y, worldPoint.z])
            }
        }

        var indices = [UInt32]()
        for row in 0..<(yValues.count - 1) {
            for column in 0..<(columns - 1) {
                let topLeft = row * columns + column
                let topRight = topLeft + 1
                let bottomLeft = topLeft + columns
                let bottomRight = bottomLeft + 1
                let corners = [topLeft, topRight, bottomLeft, bottomRight]
                guard corners.allSatisfy({ valid[$0] }) else { continue }
                let depths = corners.map { sampledDepths[$0] }
                let minimum = depths.min() ?? 0
                let maximum = depths.max() ?? .greatestFiniteMagnitude
                let allowedJump = max(0.12, minimum * 0.08)
                guard maximum - minimum <= allowedJump else { continue }
                indices.append(contentsOf: [
                    UInt32(topLeft), UInt32(bottomLeft), UInt32(topRight),
                    UInt32(topRight), UInt32(bottomLeft), UInt32(bottomRight),
                ])
            }
        }
        guard indices.count >= 3 else { throw AIEnhancementError.invalidResponse }
        var descriptor = MeshDescriptor(name: "cinear.ai-depth.mesh")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }
}
````

## `CineAR/ARSessionController.swift`

````swift
import ARKit
import AVFoundation
import Combine
import Foundation
import ImageIO
import RealityKit
import RoomPlan
import Speech
import simd
import SwiftUI
import UIKit
import Vision

struct SceneObjectSummary: Identifiable, Equatable {
    let id: UUID
    let title: String
    let symbol: String
    let detail: String
    let isLiveEffect: Bool
}

@MainActor
final class ARSessionController: NSObject, ObservableObject {
    @Published var selectedProp: PropKind = .crate
    @Published var selectedEntityID: UUID?
    @Published var statusText = "Kamerayı hareket ettirerek alanı tara"
    @Published var trackingColor: Color = .yellow
    @Published private(set) var isRecording = false
    @Published private(set) var isRecordingTransitioning = false
    @Published var lastRecordingURL: URL?
    @Published private(set) var importedAssetURLs: [URL] = []
    @Published var selectedAssetURL: URL?
    @Published private(set) var activeRealityThemeID: RealityThemeID?
    @Published private(set) var hasScannedRoom = false
    @Published private(set) var isARReady = false
    @Published private(set) var isPlacingProp = false
    @Published private(set) var isRoomOutlineVisible = false
    @Published private(set) var selectedLightSettings: VirtualLightSettings?
    @Published private(set) var isAimingLight = false
    @Published private(set) var placementSurfaceMessage = "Yüzey ölçülüyor"
    @Published private(set) var placementSurfaceColor: Color = .yellow
    @Published private(set) var placementReticlePoint: CGPoint?
    @Published private(set) var aiEnhancementEnabled = false
    @Published private(set) var aiServerAddress = ""
    @Published private(set) var aiEnhancementStatus: AIEnhancementStatus = .disabled
    @Published private(set) var sceneObjects: [SceneObjectSummary] = []
    @Published private(set) var savedPlaces: [SavedPlaceSummary] = []
    @Published private(set) var isLiveAppleEnabled = false
    @Published private(set) var isListeningForCGICommands = false
    @Published private(set) var liveCGIStatus = "Hazır efekt seç veya Türkçe komut ver"

    private(set) var arView: ARView?
    private let projectStore = SceneProjectStore()
    private let recorder = ProfessionalRecorder()
    private let roomRealityRenderer = RoomRealityRenderer(
        assetProvider: BundledRoomRealityAssetProvider()
    )
    private let manualAssetProvider = BundledRoomRealityAssetProvider()
    private let aiEnhancementClient = AIEnhancementClient()
    private let aiDepthRenderer = AIDepthOcclusionRenderer()
    private var renderedAnchorIDs = Set<UUID>()
    private var renderedAnchorIDByPlacementID: [UUID: UUID] = [:]
    private var knownPropAnchorIDs = Set<UUID>()
    private var supersededPropAnchorIDs = Set<UUID>()
    private var managedPropAnchorsByPlacementID: [UUID: ARAnchor] = [:]
    private var renderedEntities: [UUID: ModelEntity] = [:]
    private var renderedLights: [UUID: SpotLight] = [:]
    private var renderedLightEmitters: [UUID: ModelEntity] = [:]
    private var renderedLightFootprints: [UUID: AnchorEntity] = [:]
    private var loadingEntityIDs = Set<UUID>()
    private var assetLoadSubscriptions: [UUID: AnyCancellable] = [:]
    private var renderGeneration: UInt64 = 0
    private weak var coachingOverlay: ARCoachingOverlayView?
    private var isSavingWorldMap = false
    private var recordingPhase: RecordingPhase = .idle
    private var roomCoordinateSpaceIsActive = false
    private var preferredRealityThemeID: RealityThemeID?
    private var isSessionInterrupted = false
    private var shouldRestoreRoomRealityAfterInterruption = false
    private var configurationBeforeInterruption: ARConfiguration?
    private var isRoomScanActive = false
    private var didAttemptSessionFailureRecovery = false
    private var realityThemeToRestoreAfterScan: RealityThemeID?
    private var pendingRealityThemeAfterScan: RealityThemeID?
    private var isPostScanThemeScheduled = false
    private var postScanThemeGeneration: UInt64 = 0
    private var isRoomRealityRendering = false
    private var lastKnownFloorY: Float?
    private var lastKnownCeilingY: Float?
    private let floorSurfaceTracker = FloorSurfaceTracker()
    private var lastPlacementGuidanceTimestamp: TimeInterval = 0
    private var lastProjectorRefreshTimestamp: TimeInterval = 0
    private var shouldSaveWorldMapWhenReady = false
    private var shouldShowRoomOutlineWhenReady = false
    private var readinessRecoveryGeneration: UInt64 = 0
    private var pendingAutoSaveAnchorIDs = Set<UUID>()
    private var shouldArchiveAfterNextSave = false
    private var pendingArchiveName: String?
    private var bloodWaterfallParticles: [UUID: [BloodWaterfallParticle]] = [:]
    private var liveAppleAnchor: AnchorEntity?
    private var filteredLiveApplePosition: SIMD3<Float>?
    private var lastLiveAppleObservationTimestamp: TimeInterval = 0
    private var lastHandDetectionTimestamp: TimeInterval = 0
    private var handDetectionInFlight = false
    private let handDetectionQueue = DispatchQueue(
        label: "com.cinear.hand-pose",
        qos: .userInitiated
    )
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "tr_TR"))
    private let speechAudioEngine = AVAudioEngine()
    private var speechRequest: SFSpeechAudioBufferRecognitionRequest?
    private var speechTask: SFSpeechRecognitionTask?
    private var lastProcessedCGITranscript = ""
    private var hasSpeechInputTap = false

    private static let realityThemeDefaultsKey = "cinear.activeRealityTheme"
    private static let aiEnabledDefaultsKey = "cinear.aiDepth.enabled"
    private static let aiServerDefaultsKey = "cinear.aiDepth.server"
    // The user's verified RTX server on the current LAN. This is a real initial
    // value, not a TextField placeholder; it remains editable if DHCP changes it.
    private static let defaultAIServerAddress = "http://192.168.1.12:8765"
    private static let obsoleteAIServerAddresses: Set<String> = [
        "http://192.168.1.9:8765",
        "http://192.168.1.20:8765"
    ]
    private static let liveAppleSceneID = UUID(
        uuidString: "C1EA0000-0000-4000-8000-000000000001"
    )!

    private enum RecordingPhase {
        case idle
        case starting
        case recording
        case stopping
    }

    var roomModelURL: URL { projectStore.roomModelURL }
    var roomDataURL: URL { projectStore.roomDataURL }
    var sharedARSession: ARSession? { arView?.session }

    override init() {
        super.init()
        aiEnhancementEnabled = UserDefaults.standard.bool(forKey: Self.aiEnabledDefaultsKey)
        let storedAIAddress = UserDefaults.standard.string(forKey: Self.aiServerDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let storedAIAddress,
           !Self.obsoleteAIServerAddresses.contains(storedAIAddress),
           AIEnhancementClient.serverURL(from: storedAIAddress) != nil {
            aiServerAddress = storedAIAddress
        } else {
            aiServerAddress = Self.defaultAIServerAddress
        }
        UserDefaults.standard.set(aiServerAddress, forKey: Self.aiServerDefaultsKey)
        aiEnhancementStatus = aiEnhancementEnabled ? .waiting : .disabled
        importedAssetURLs = projectStore.importedModelURLs
        hasScannedRoom = FileManager.default.fileExists(atPath: roomDataURL.path)
        if projectStore.savedPlaces.isEmpty,
           projectStore.project.worldMapChecksum != nil {
            _ = try? projectStore.archiveCurrentProject(preferredName: "Önceki Mekân")
        }
        refreshSceneCatalogs()
        // Opaque room replacements can cover people and make the camera feel unstable.
        // Always launch in the real-camera view; the legacy renderer stays internal.
        UserDefaults.standard.removeObject(forKey: Self.realityThemeDefaultsKey)
        if let error = projectStore.initializationError {
            publishStatus(
                "Kayıtlı scene.json okunamadı: \(error.localizedDescription)",
                color: .red
            )
        } else if let notice = projectStore.initializationNotice {
            publishStatus(notice, color: .yellow)
        }
    }

    func makeARView() -> ARView {
        if let arView { return arView }

        let view = ARView(frame: .zero)
        view.automaticallyConfigureSession = false
        view.session.delegateQueue = .main
        view.session.delegate = self
        view.environment.sceneUnderstanding.options.insert(.occlusion)
        view.environment.sceneUnderstanding.options.insert(.collision)
        view.renderOptions.remove(.disablePersonOcclusion)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
        let surfaceProbe = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleSurfaceProbe(_:))
        )
        surfaceProbe.minimumPressDuration = 0
        surfaceProbe.cancelsTouchesInView = false
        surfaceProbe.delegate = self
        view.addGestureRecognizer(surfaceProbe)
        addCoachingOverlay(to: view)

        arView = view
        if aiEnhancementEnabled {
            aiDepthRenderer.install(in: view)
        }
        runSession()
        return view
    }

    private func configuration(
        initialWorldMap: ARWorldMap? = nil,
        enableAdvancedOcclusion: Bool = true
    ) -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        configuration.isLightEstimationEnabled = true
        configuration.isAutoFocusEnabled = true
        configuration.initialWorldMap = initialWorldMap

        if enableAdvancedOcclusion,
           ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        }
        if enableAdvancedOcclusion,
           ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }
        // Keep scene depth alongside person depth when the device supports both.
        // Person segmentation handles people; scene depth/mesh handles furniture
        // crossing in front of a virtual prop.
        if enableAdvancedOcclusion,
           ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        if enableAdvancedOcclusion,
           ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
        }
        return configuration
    }

    private func runSession(initialWorldMap: ARWorldMap? = nil) {
        guard ARWorldTrackingConfiguration.isSupported else {
            publishStatus("Bu cihaz ARKit dünya takibini desteklemiyor", color: .red)
            return
        }

        renderGeneration &+= 1
        readinessRecoveryGeneration &+= 1
        cancelPendingPostScanTheme()
        isARReady = false
        isSessionInterrupted = false
        shouldRestoreRoomRealityAfterInterruption = false
        configurationBeforeInterruption = nil
        didAttemptSessionFailureRecovery = false
        assetLoadSubscriptions.values.forEach { $0.cancel() }
        renderedAnchorIDs.removeAll()
        renderedAnchorIDByPlacementID.removeAll()
        knownPropAnchorIDs.removeAll()
        supersededPropAnchorIDs.removeAll()
        pendingAutoSaveAnchorIDs.removeAll()
        managedPropAnchorsByPlacementID.removeAll()
        if let initialWorldMap {
            for anchor in initialWorldMap.anchors {
                guard let descriptor = PropKind.descriptor(from: anchor.name) else { continue }
                managedPropAnchorsByPlacementID[descriptor.id] = anchor
            }
        }
        renderedEntities.removeAll()
        renderedLights.removeAll()
        renderedLightEmitters.removeAll()
        renderedLightFootprints.removeAll()
        bloodWaterfallParticles.removeAll()
        loadingEntityIDs.removeAll()
        assetLoadSubscriptions.removeAll()
        selectedEntityID = nil
        selectedLightSettings = nil
        isAimingLight = false
        placementReticlePoint = nil
        liveAppleAnchor = nil
        filteredLiveApplePosition = nil
        isRoomOutlineVisible = false
        guard let arView else { return }
        aiEnhancementClient.cancel()
        aiDepthRenderer.remove()
        arView.scene.anchors.removeAll()
        roomCoordinateSpaceIsActive = initialWorldMap != nil
        lastKnownFloorY = nil
        lastKnownCeilingY = nil
        floorSurfaceTracker.reset()
        if roomCoordinateSpaceIsActive {
            updateKnownFloorFromRoomData()
        }
        arView.session.delegateQueue = .main
        arView.session.delegate = self
        arView.session.run(
            configuration(initialWorldMap: initialWorldMap),
            options: [.resetTracking, .removeExistingAnchors]
        )
        roomRealityRenderer.install(in: arView)
        if aiEnhancementEnabled {
            aiDepthRenderer.install(in: arView)
            aiEnhancementStatus = .waiting
        }
        refreshPhysicalRoomOcclusionIfPossible()
        restoreRoomRealityIfPossible()
        scheduleReadinessRecovery()
    }

    func pauseForRoomScan() {
        cancelPlacement()
        if isListeningForCGICommands { stopCGIVoiceCommands() }
        aiEnhancementClient.cancel()
        aiDepthRenderer.clear()
        let themeAwaitingSafeRestore = pendingRealityThemeAfterScan
        cancelPendingPostScanTheme()
        readinessRecoveryGeneration &+= 1
        shouldShowRoomOutlineWhenReady = false
        isRoomScanActive = true
        isARReady = false
        realityThemeToRestoreAfterScan = themeAwaitingSafeRestore
            ?? (roomRealityRenderer.isVisible ? activeRealityThemeID : nil)
        roomRealityRenderer.isVisible = false
        roomRealityRenderer.isPhysicalOcclusionVisible = false
        isRoomOutlineVisible = false
        setPhysicalSceneOcclusion(enabled: false)
        arView?.isHidden = true
        // RoomPlan already performs its own LiDAR processing. Temporarily omit the
        // additional mesh/person passes so scanning does not run three heavy pipelines.
        arView?.session.run(
            configuration(enableAdvancedOcclusion: false),
            options: [.resetSceneReconstruction]
        )
        do {
            try persistAllEntityTransforms()
        } catch {
            publishStatus("Dekor konumları kaydedilemedi: \(error.localizedDescription)", color: .red)
        }
        publishStatus("Oda taraması açılıyor; aynı dünya koordinatları korunuyor", color: .yellow)
    }

    func setAIEnhancementEnabled(_ enabled: Bool) {
        aiEnhancementEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.aiEnabledDefaultsKey)
        guard enabled else {
            aiEnhancementClient.cancel()
            aiDepthRenderer.clear()
            aiEnhancementStatus = .disabled
            refreshPhysicalRoomOcclusionIfPossible()
            return
        }
        // The live LiDAR/AI mesh is more precise than RoomPlan's coarse furniture
        // boxes. Never run both depth writers together; overlapping occluders are the
        // main reason a newly placed prop can appear half cut or fully hidden.
        roomRealityRenderer.isPhysicalOcclusionVisible = false
        aiEnhancementStatus = AIEnhancementClient.serverURL(from: aiServerAddress) == nil
            ? .failed(AIEnhancementError.invalidServerAddress.localizedDescription)
            : .waiting
        if let arView { aiDepthRenderer.install(in: arView) }
    }

    func setAIServerAddress(_ address: String) {
        aiServerAddress = address
        UserDefaults.standard.set(address, forKey: Self.aiServerDefaultsKey)
        if aiEnhancementEnabled {
            aiEnhancementClient.cancel()
            aiDepthRenderer.clear()
            aiEnhancementStatus = AIEnhancementClient.serverURL(from: address) == nil
                ? .failed(AIEnhancementError.invalidServerAddress.localizedDescription)
                : .waiting
        }
    }

    func testAIServerConnection() {
        guard let url = AIEnhancementClient.serverURL(from: aiServerAddress) else {
            aiEnhancementStatus = .failed(AIEnhancementError.invalidServerAddress.localizedDescription)
            return
        }
        aiEnhancementStatus = .waiting
        aiEnhancementClient.testHealth(serverURL: url) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let device):
                // A successful test means the user intends to use the service. The old
                // flow painted the test green but left frame submission disabled when
                // the toggle was off, which looked exactly like a broken connection.
                self.setAIEnhancementEnabled(true)
                self.aiEnhancementStatus = .active(latencyMilliseconds: 0, samMaskCount: 0)
                self.publishStatus(
                    "AI servisi hazır: \(device) — canlı derinlik otomatik açıldı",
                    color: .green
                )
            case .failure(let error):
                self.aiEnhancementStatus = .failed(error.localizedDescription)
            }
        }
    }

    private func submitFrameToAIIfNeeded(_ frame: ARFrame) {
        guard aiEnhancementEnabled,
              !isRoomScanActive,
              !isSessionInterrupted,
              case .normal = frame.camera.trackingState,
              let serverURL = AIEnhancementClient.serverURL(from: aiServerAddress) else { return }
        aiEnhancementClient.submit(frame: frame, serverURL: serverURL) { [weak self] result in
            guard let self, self.aiEnhancementEnabled else { return }
            switch result {
            case .success(let depth):
                // RTX 3050-class PCs commonly need 2-3 seconds for Depth Anything
                // plus SAM 2. The mesh is already expressed in the captured frame's
                // world transform, so a valid static-scene result remains usable. The
                // previous 1.5 s cutoff incorrectly reported successful HTTP 200
                // responses as a broken connection.
                guard depth.totalLatencyMilliseconds <= 6_000 else {
                    self.aiDepthRenderer.clear()
                    self.refreshPhysicalRoomOcclusionIfPossible(
                        allowWhileAIEnabled: true
                    )
                    self.aiEnhancementStatus = .failed(
                        "Gecikme \(depth.totalLatencyMilliseconds) ms; PC veya Wi-Fi yavaş"
                    )
                    return
                }
                do {
                    self.roomRealityRenderer.isPhysicalOcclusionVisible = false
                    try self.aiDepthRenderer.render(depth)
                    self.aiEnhancementStatus = .active(
                        latencyMilliseconds: depth.totalLatencyMilliseconds,
                        samMaskCount: depth.samMaskCount
                    )
                } catch {
                    self.refreshPhysicalRoomOcclusionIfPossible(
                        allowWhileAIEnabled: true
                    )
                    self.aiEnhancementStatus = .failed(error.localizedDescription)
                }
            case .failure(let error):
                if let aiError = error as? AIEnhancementError,
                   case .missingSceneDepth = aiError {
                    if self.aiEnhancementStatus != .waitingForDepth {
                        self.aiDepthRenderer.clear()
                        self.refreshPhysicalRoomOcclusionIfPossible(
                            allowWhileAIEnabled: true
                        )
                    }
                    self.aiEnhancementStatus = .waitingForDepth
                } else {
                    self.aiDepthRenderer.clear()
                    self.refreshPhysicalRoomOcclusionIfPossible(
                        allowWhileAIEnabled: true
                    )
                    self.aiEnhancementStatus = .failed(error.localizedDescription)
                }
            }
        }
    }

    func resumeAfterRoomScan(result: RoomScanResult?) {
        isRoomScanActive = false
        isARReady = false
        didAttemptSessionFailureRecovery = false
        isSessionInterrupted = false
        shouldRestoreRoomRealityAfterInterruption = false
        configurationBeforeInterruption = nil
        arView?.isHidden = false
        setPhysicalSceneOcclusion(enabled: true)

        var themeToSchedule = realityThemeToRestoreAfterScan
        var completionStatus: (message: String, color: Color)?
        switch result {
        case .success:
            hasScannedRoom = FileManager.default.fileExists(atPath: roomDataURL.path)
            roomCoordinateSpaceIsActive = hasScannedRoom
            roomRealityRenderer.clear()
            roomRealityRenderer.isVisible = false
            activeRealityThemeID = nil
            preferredRealityThemeID = nil
            isRoomOutlineVisible = false
            shouldShowRoomOutlineWhenReady = false
            themeToSchedule = nil
            UserDefaults.standard.removeObject(forKey: Self.realityThemeDefaultsKey)
            var invalidationMessage: String?
            do {
                try projectStore.invalidateWorldMapForRoomScan()
            } catch {
                invalidationMessage = error.localizedDescription
            }
            if let invalidationMessage {
                shouldSaveWorldMapWhenReady = false
                completionStatus = (
                    "Tarama kaydedildi, ancak proje haritası güncellenemedi: \(invalidationMessage)",
                    .red
                )
            } else {
                updateKnownFloorFromRoomData()
                shouldSaveWorldMapWhenReady = hasScannedRoom
                shouldArchiveAfterNextSave = hasScannedRoom
                pendingArchiveName = nil
                completionStatus = (
                    "Tarama kaydedildi — sahne haritası takip hazır olunca otomatik kaydedilecek",
                    .green
                )
            }
        case .cancelled:
            completionStatus = ("Oda taraması iptal edildi; AR sahnesi devam ediyor", .yellow)
        case .failure(let message):
            completionStatus = ("Oda taraması tamamlanamadı: \(message)", .red)
        case nil:
            completionStatus = ("Oda taraması kapatıldı; AR sahnesi devam ediyor", .yellow)
        }

        realityThemeToRestoreAfterScan = nil
        pendingRealityThemeAfterScan = themeToSchedule
        arView?.session.delegateQueue = .main
        arView?.session.delegate = self
        arView?.session.run(configuration(), options: [])
        refreshPhysicalRoomOcclusionIfPossible()
        scheduleReadinessRecovery()

        if let completionStatus {
            publishStatus(completionStatus.message, color: completionStatus.color)
        }
        if let trackingState = arView?.session.currentFrame?.camera.trackingState {
            _ = schedulePendingPostScanThemeIfReady(trackingState: trackingState)
        }
    }

    func selectRealityTheme(_ id: RealityThemeID) {
        cancelPendingPostScanTheme()
        guard !isSessionInterrupted else {
            publishStatus("AR oturumu kesintisi bitene kadar oda teması değiştirilemez", color: .yellow)
            return
        }
        guard !isRoomRealityRendering else {
            publishStatus("Oda gerçekliği hazırlanıyor; lütfen kısa bir süre bekle", color: .yellow)
            return
        }
        guard let arView else {
            publishStatus("AR görünümü henüz hazır değil", color: .red)
            return
        }
        guard FileManager.default.fileExists(atPath: roomDataURL.path) else {
            hasScannedRoom = false
            publishStatus("Önce Oda Tara ile alanın duvar ve nesnelerini tara", color: .yellow)
            return
        }
        guard roomCoordinateSpaceIsActive else {
            publishStatus("Kayıtlı odayı hizalamak için önce sahne haritasını Yükle", color: .yellow)
            return
        }
        guard let trackingState = arView.session.currentFrame?.camera.trackingState,
              case .normal = trackingState else {
            pendingRealityThemeAfterScan = id
            publishStatus("Tema, kamera takibi hazır olduğunda uygulanacak", color: .yellow)
            return
        }

        isRoomRealityRendering = true
        roomRealityRenderer.isPhysicalOcclusionVisible = false
        setPhysicalSceneOcclusion(enabled: true)
        defer { isRoomRealityRendering = false }

        do {
            roomRealityRenderer.install(in: arView)
            let theme = RealityThemeCatalog.theme(withID: id)
            let report = try roomRealityRenderer.render(
                roomJSONURL: roomDataURL,
                theme: theme
            )
            roomRealityRenderer.isVisible = true
            activeRealityThemeID = id
            preferredRealityThemeID = id
            isRoomOutlineVisible = false
            hasScannedRoom = true
            UserDefaults.standard.set(id.rawValue, forKey: Self.realityThemeDefaultsKey)
            setPhysicalSceneOcclusion(enabled: true)
            var notices: [String] = []
            if report.polygonApproximationCount > 0 {
                notices.append("\(report.polygonApproximationCount) yüzey yaklaşıklandı")
            }
            let omittedCount = report.skippedElementCount + report.unmatchedPortalCount
            if omittedCount > 0 {
                notices.append("\(omittedCount) öğe eşleşmedi")
            }
            let detail = notices.isEmpty ? "" : " • " + notices.joined(separator: ", ")
            publishStatus(
                "\(theme.title) etkin — \(report.renderedElementCount) oda öğesi değiştirildi\(detail)",
                color: notices.isEmpty ? .green : .yellow
            )
        } catch {
            roomRealityRenderer.isVisible = false
            activeRealityThemeID = nil
            isRoomOutlineVisible = false
            setPhysicalSceneOcclusion(enabled: true)
            refreshPhysicalRoomOcclusionIfPossible()
            publishStatus("Oda teması uygulanamadı: \(error.localizedDescription)", color: .red)
        }
    }

    func showOriginalReality() {
        cancelPendingPostScanTheme()
        shouldRestoreRoomRealityAfterInterruption = false
        roomRealityRenderer.isVisible = false
        activeRealityThemeID = nil
        preferredRealityThemeID = nil
        isRoomOutlineVisible = false
        shouldShowRoomOutlineWhenReady = false
        UserDefaults.standard.removeObject(forKey: Self.realityThemeDefaultsKey)
        setPhysicalSceneOcclusion(enabled: true)
        refreshPhysicalRoomOcclusionIfPossible()
        publishStatus("Gerçek oda görünümü etkin; eklediğin objeler korunuyor", color: .green)
    }

    func showRoomOutline() {
        cancelPendingPostScanTheme()
        shouldRestoreRoomRealityAfterInterruption = false
        guard !isRoomScanActive, !isSessionInterrupted else {
            publishStatus("Tarama veya AR kesintisi bittiğinde tekrar dene", color: .yellow)
            return
        }
        guard let arView else {
            publishStatus("AR görünümü henüz hazır değil", color: .red)
            return
        }
        guard FileManager.default.fileExists(atPath: roomDataURL.path) else {
            hasScannedRoom = false
            shouldShowRoomOutlineWhenReady = false
            publishStatus("Beyaz oda hatları için önce Oda Tara'yı tamamla", color: .yellow)
            return
        }
        guard roomCoordinateSpaceIsActive else {
            shouldShowRoomOutlineWhenReady = true
            loadWorldMap()
            return
        }
        guard let trackingState = arView.session.currentFrame?.camera.trackingState,
              case .normal = trackingState else {
            shouldShowRoomOutlineWhenReady = true
            scheduleReadinessRecovery()
            publishStatus("Beyaz Hatlar takip hazır olduğunda otomatik açılacak", color: .yellow)
            return
        }

        do {
            shouldShowRoomOutlineWhenReady = false
            roomRealityRenderer.install(in: arView)
            let report: RoomRealityRenderReport
            if roomRealityRenderer.hasPreparedOutline,
               let preparedReport = roomRealityRenderer.lastReport {
                report = preparedReport
            } else {
                report = try roomRealityRenderer.renderOutline(roomJSONURL: roomDataURL)
            }
            roomRealityRenderer.isVisible = true
            isRoomOutlineVisible = true
            activeRealityThemeID = nil
            preferredRealityThemeID = nil
            UserDefaults.standard.removeObject(forKey: Self.realityThemeDefaultsKey)
            setPhysicalSceneOcclusion(enabled: true)
            updateKnownFloorFromRoomData()
            refreshPhysicalRoomOcclusionIfPossible()
            publishStatus(
                "Beyaz Hatlar etkin — \(report.renderedElementCount) tarama öğesi gösteriliyor",
                color: .green
            )
        } catch {
            roomRealityRenderer.isVisible = false
            isRoomOutlineVisible = false
            shouldShowRoomOutlineWhenReady = false
            setPhysicalSceneOcclusion(enabled: true)
            publishStatus("Oda hatları gösterilemedi: \(error.localizedDescription)", color: .red)
        }
    }

    func selectProp(_ prop: PropKind) {
        persistSelectedLightSettings()
        isAimingLight = false
        placementReticlePoint = nil
        selectedProp = prop
        selectedEntityID = nil
        selectedLightSettings = nil
        if prop == .custom, selectedAssetURL == nil {
            isPlacingProp = false
            publishStatus("USDZ seçildi — önce kütüphaneden bir model ekle", color: .yellow)
        } else {
            isPlacingProp = true
            placementSurfaceMessage = "LiDAR yüzeyi doğrulanıyor"
            placementSurfaceColor = .yellow
            publishStatus(
                "\(prop.title) seçildi — \(placementInstruction(for: prop))",
                color: .blue
            )
        }
    }

    func cancelPlacement() {
        guard isPlacingProp else { return }
        isPlacingProp = false
        placementSurfaceMessage = "Yerleştirme kapalı"
        placementSurfaceColor = .yellow
        placementReticlePoint = nil
        publishStatus("Yerleştirme iptal edildi", color: .yellow)
    }

    private func placementInstruction(for prop: PropKind) -> String {
        switch prop.placementSurface {
        case .floor: "taranmış zemine dokun"
        case .horizontal: "zemine veya masa gibi yatay yüzeye dokun"
        case .wall: "taranmış duvara dokun"
        case .ceiling: "telefonu tavana çevirip taranmış tavana dokun"
        }
    }

    private func placementFailureMessage(for prop: PropKind) -> String {
        switch prop.placementSurface {
        case .floor:
            "Kararlı zemin bulunamadı — zemini yavaşça tara, sonra tekrar dokun"
        case .horizontal:
            "Kararlı yatay yüzey bulunamadı — yüzeyi yavaşça tara, sonra tekrar dokun"
        case .wall:
            "Kararlı duvar bulunamadı — duvarı yavaşça tara, sonra tekrar dokun"
        case .ceiling:
            "Kararlı tavan bulunamadı — telefonu yukarı çevirip tavanı yavaşça tara"
        }
    }

    private func selectRenderedEntity(id: UUID) {
        persistSelectedLightSettings()
        isAimingLight = false
        selectedEntityID = id
        if let placement = projectStore.placement(id: id), placement.kind.emitsVirtualLight {
            selectedLightSettings = placement.lightSettings ?? .defaultFixture
            publishStatus("Işık seçildi — güç, renk, yön, eğim ve hüzmeyi ayarlayabilirsin", color: .blue)
        } else {
            selectedLightSettings = nil
            publishStatus("Dekor seçildi — konumu kilitli; döndür veya ölçekle", color: .blue)
        }
    }

    func selectSceneObject(id: UUID) {
        if id == Self.liveAppleSceneID {
            publishStatus("Canlı elma efekti seçildi — kapatmak için Sahne listesindeki çöp kutusunu kullan", color: .blue)
            return
        }
        guard projectStore.placement(id: id) != nil else {
            refreshSceneCatalogs()
            publishStatus("Sahne öğesi artık bulunmuyor", color: .yellow)
            return
        }
        isPlacingProp = false
        placementReticlePoint = nil
        selectRenderedEntity(id: id)
    }

    func setLiveAppleEnabled(_ enabled: Bool) {
        isLiveAppleEnabled = enabled
        filteredLiveApplePosition = nil
        lastLiveAppleObservationTimestamp = 0
        if enabled {
            liveCGIStatus = "Elini kameraya göster; elma avuç merkezine bağlanacak"
            publishStatus("Canlı elma etkin — avucunu açık biçimde kameraya göster", color: .green)
        } else {
            if let anchor = liveAppleAnchor {
                anchor.scene?.removeAnchor(anchor)
            }
            liveAppleAnchor = nil
            liveCGIStatus = "Canlı elma kapalı"
        }
        refreshSceneCatalogs()
    }

    func toggleCGIVoiceCommands() {
        if isListeningForCGICommands {
            stopCGIVoiceCommands()
        } else {
            startCGIVoiceCommands()
        }
    }

    func stopCGIVoiceCommands() {
        speechTask?.cancel()
        speechTask = nil
        speechRequest?.endAudio()
        speechRequest = nil
        if speechAudioEngine.isRunning { speechAudioEngine.stop() }
        if hasSpeechInputTap {
            speechAudioEngine.inputNode.removeTap(onBus: 0)
            hasSpeechInputTap = false
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isListeningForCGICommands = false
        if liveCGIStatus == "Dinliyorum…" {
            liveCGIStatus = "Sesli komut kapalı"
        }
    }

    private func startCGIVoiceCommands() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            requestMicrophoneAndBeginCGISpeechRecognition()
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if status == .authorized {
                        self.requestMicrophoneAndBeginCGISpeechRecognition()
                    } else {
                        self.liveCGIStatus = "Konuşma tanıma izni verilmedi"
                        self.publishStatus("Ayarlar'dan Konuşma Tanıma iznini aç", color: .yellow)
                    }
                }
            }
        case .denied, .restricted:
            liveCGIStatus = "Konuşma tanıma izni kapalı"
            publishStatus("Ayarlar'dan Konuşma Tanıma iznini aç", color: .yellow)
        @unknown default:
            liveCGIStatus = "Konuşma tanıma kullanılamıyor"
        }
    }

    private func requestMicrophoneAndBeginCGISpeechRecognition() {
        let audioSession = AVAudioSession.sharedInstance()
        switch audioSession.recordPermission {
        case .granted:
            beginCGISpeechRecognition()
        case .undetermined:
            audioSession.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.beginCGISpeechRecognition()
                    } else {
                        self.liveCGIStatus = "Mikrofon izni verilmedi"
                        self.publishStatus("Ayarlar'dan Mikrofon iznini aç", color: .yellow)
                    }
                }
            }
        case .denied:
            liveCGIStatus = "Mikrofon izni kapalı"
            publishStatus("Ayarlar'dan Mikrofon iznini aç", color: .yellow)
        @unknown default:
            liveCGIStatus = "Mikrofon kullanılamıyor"
        }
    }

    private func beginCGISpeechRecognition() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            liveCGIStatus = "Türkçe konuşma tanıma şu anda kullanılamıyor"
            return
        }
        stopCGIVoiceCommands()
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.duckOthers, .defaultToSpeaker]
            )
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.taskHint = .confirmation
            if speechRecognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }
            speechRequest = request
            lastProcessedCGITranscript = ""

            let inputNode = speechAudioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) {
                [weak request] buffer, _ in
                request?.append(buffer)
            }
            hasSpeechInputTap = true
            speechAudioEngine.prepare()
            try speechAudioEngine.start()
            isListeningForCGICommands = true
            liveCGIStatus = "Dinliyorum…"

            speechTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let result {
                        self.handleCGITranscript(
                            result.bestTranscription.formattedString,
                            isFinal: result.isFinal
                        )
                    }
                    if error != nil {
                        self.stopCGIVoiceCommands()
                    }
                }
            }
        } catch {
            stopCGIVoiceCommands()
            liveCGIStatus = "Mikrofon başlatılamadı: \(error.localizedDescription)"
            publishStatus(liveCGIStatus, color: .red)
        }
    }

    private func handleCGITranscript(_ transcript: String, isFinal: Bool) {
        let command = transcript.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "tr_TR")
        ).lowercased()
        guard command != lastProcessedCGITranscript else { return }

        if command.contains("kan selalesi") || command.contains("kan ak") {
            lastProcessedCGITranscript = command
            selectProp(.bloodWaterfall)
            liveCGIStatus = "Kan şelalesi seçildi; başlangıç için duvara dokun"
            if isFinal { stopCGIVoiceCommands() }
            return
        }
        if command.contains("elma") {
            lastProcessedCGITranscript = command
            let shouldRemove = command.contains("kaldir")
                || command.contains("sil")
                || command.contains("kapat")
            setLiveAppleEnabled(!shouldRemove)
            liveCGIStatus = shouldRemove
                ? "Elma efekti kaldırıldı"
                : "Elma etkin; elini kameraya göster"
            if isFinal { stopCGIVoiceCommands() }
            return
        }
        liveCGIStatus = transcript.isEmpty ? "Dinliyorum…" : "Duyulan: \(transcript)"
        if isFinal { stopCGIVoiceCommands() }
    }

    private func updateLiveAppleTracking(using frame: ARFrame) {
        guard isLiveAppleEnabled, isARReady, !isRoomScanActive, !isSessionInterrupted,
              let arView else { return }
        if frame.timestamp - lastHandDetectionTimestamp < 0.12 || handDetectionInFlight {
            if frame.timestamp - lastLiveAppleObservationTimestamp > 0.42 {
                liveAppleAnchor?.isEnabled = false
            }
            return
        }
        lastHandDetectionTimestamp = frame.timestamp
        handDetectionInFlight = true
        let pixelBuffer = frame.capturedImage
        let viewportSize = arView.bounds.size
        let imageOrientation: CGImagePropertyOrientation
        switch arView.window?.windowScene?.interfaceOrientation {
        case .some(.landscapeLeft): imageOrientation = .up
        case .some(.landscapeRight): imageOrientation = .down
        case .some(.portraitUpsideDown): imageOrientation = .left
        default: imageOrientation = .right
        }
        handDetectionQueue.async { [weak self, weak arView] in
            let request = VNDetectHumanHandPoseRequest()
            request.maximumHandCount = 1
            var normalizedPalm: CGPoint?
            do {
                let handler = VNImageRequestHandler(
                    cvPixelBuffer: pixelBuffer,
                    orientation: imageOrientation,
                    options: [:]
                )
                try handler.perform([request])
                if let observation = request.results?.first {
                    let points = try observation.recognizedPoints(.all)
                    let jointNames: [VNHumanHandPoseObservation.JointName] = [
                        .wrist, .indexMCP, .middleMCP, .littleMCP
                    ]
                    let valid = jointNames.compactMap { name -> VNRecognizedPoint? in
                        guard let point = points[name], point.confidence >= 0.30 else { return nil }
                        return point
                    }
                    if valid.count >= 3 {
                        let count = CGFloat(valid.count)
                        normalizedPalm = CGPoint(
                            x: valid.reduce(CGFloat.zero) { $0 + $1.location.x } / count,
                            y: valid.reduce(CGFloat.zero) { $0 + $1.location.y } / count
                        )
                    }
                }
            } catch {
                normalizedPalm = nil
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.handDetectionInFlight = false
                guard self.isLiveAppleEnabled,
                      let arView,
                      let normalizedPalm,
                      viewportSize.width > 0,
                      viewportSize.height > 0 else { return }
                let point = CGPoint(
                    x: normalizedPalm.x * viewportSize.width,
                    y: (1 - normalizedPalm.y) * viewportSize.height
                )
                self.placeLiveApple(using: frame, in: arView, at: point)
            }
        }
    }

    private func placeLiveApple(using frame: ARFrame, in arView: ARView, at point: CGPoint) {
        guard let depth = sceneDepthSample(frame: frame, in: arView, at: point) else {
            liveCGIStatus = "El görüldü; avuç derinliği ölçülüyor"
            return
        }
        let cameraPosition = SIMD3<Float>(
            frame.camera.transform.columns.3.x,
            frame.camera.transform.columns.3.y,
            frame.camera.transform.columns.3.z
        )
        var towardCamera = cameraPosition - depth.worldPoint
        if simd_length_squared(towardCamera) > 0.000_001 {
            towardCamera = simd_normalize(towardCamera)
        } else {
            towardCamera = [0, 0, 1]
        }
        let measured = depth.worldPoint + towardCamera * 0.045 + SIMD3<Float>(0, 0.055, 0)
        let filtered: SIMD3<Float>
        if let previous = filteredLiveApplePosition,
           simd_distance(previous, measured) < 0.45 {
            filtered = previous + (measured - previous) * 0.24
        } else {
            filtered = measured
        }
        filteredLiveApplePosition = filtered
        lastLiveAppleObservationTimestamp = frame.timestamp

        let anchor: AnchorEntity
        if let existing = liveAppleAnchor, existing.scene != nil {
            anchor = existing
        } else {
            anchor = AnchorEntity(world: filtered)
            anchor.name = "cinear.cgi.live-apple"
            let apple = makeAppleEntity()
            apple.position.y = -0.065
            anchor.addChild(apple)
            arView.scene.addAnchor(anchor)
            liveAppleAnchor = anchor
        }
        anchor.position = filtered
        anchor.isEnabled = true
        liveCGIStatus = String(format: "Elma avuçta • %.2f m", depth.depthMeters)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView else { return }
        let point = recognizer.location(in: arView)

        if isAimingLight {
            retargetSelectedLight(in: arView, at: point)
            return
        }

        if !isPlacingProp,
           let hitEntity = arView.entity(at: point),
           let id = entityID(from: hitEntity) {
            selectRenderedEntity(id: id)
            return
        }

        guard isPlacingProp else { return }

        guard !isRoomScanActive,
              !isSessionInterrupted,
              isARReady,
              let trackingState = arView.session.currentFrame?.camera.trackingState,
              case .normal = trackingState else {
            publishStatus("Kararlı yerleştirme için telefonu yavaşlat ve yeşil takibi bekle", color: .yellow)
            return
        }

        guard let placementSolution = placementSolution(
            in: arView,
            at: point,
            for: selectedProp
        ) else {
            publishStatus(
                placementFailureMessage(for: selectedProp),
                color: .yellow
            )
            return
        }
        let placementTransform = placementSolution.transform

        let id = UUID()
        guard selectedProp != .custom || selectedAssetURL != nil else {
            publishStatus("Önce kütüphaneden bir USDZ dekor seç", color: .yellow)
            return
        }
        let placement = PlacementRecord(
            id: id,
            kind: selectedProp,
            assetFileName: selectedProp == .custom ? selectedAssetURL?.lastPathComponent : nil,
            transform: StoredTransform(defaultTransform(for: selectedProp)),
            lightSettings: selectedProp.emitsVirtualLight ? .defaultFixture : nil
        )
        do {
            try projectStore.upsert(placement)
            let anchor = ARAnchor(
                name: selectedProp.anchorName(id: id),
                transform: placementTransform
            )
            knownPropAnchorIDs.insert(anchor.identifier)
            managedPropAnchorsByPlacementID[id] = anchor
            pendingAutoSaveAnchorIDs.insert(anchor.identifier)
            arView.session.add(anchor: anchor)
            selectedEntityID = id
            selectedLightSettings = placement.lightSettings
            isPlacingProp = false
            placementReticlePoint = nil
            render(prop: selectedProp, id: id, for: anchor)
            refreshSceneCatalogs()
            if selectedProp == .custom {
                publishStatus("USDZ sahneye yükleniyor...", color: .yellow)
            } else if renderedEntities[id] != nil {
                publishStatus(
                    "\(selectedProp.title) yüzeye sabitlendi — \(placementSolution.source.title)",
                    color: .green
                )
            } else {
                publishStatus("\(selectedProp.title) hazırlanıyor...", color: .yellow)
            }
        } catch {
            publishStatus("Proje kaydedilemedi: \(error.localizedDescription)", color: .red)
        }
    }

    @objc private func handleSurfaceProbe(_ recognizer: UILongPressGestureRecognizer) {
        guard isPlacingProp, let arView,
              recognizer.state == .began || recognizer.state == .changed else { return }
        let point = recognizer.location(in: arView)
        placementReticlePoint = point
        guard let frame = arView.session.currentFrame else { return }
        updatePlacementGuidance(using: frame, at: point, force: true)
    }

    private func placementSolution(
        in arView: ARView,
        at point: CGPoint,
        for prop: PropKind
    ) -> PlacementSurfaceSolution? {
        if prop.placementSurface == .floor {
            return strictFloorPlacementSolution(in: arView, at: point, for: prop)
        }

        // When a room theme is visible, use the geometry the user actually sees. The
        // RoomPlan replacement scene is virtual RealityKit content, so ARKit's plane
        // raycast below cannot intersect it on its own.
        if let hit = roomRealityRenderer.placementHit(in: arView, at: point) {
            if surfaceAccepts(
                prop: prop,
                normal: hit.normal,
                position: hit.position,
                cameraY: arView.cameraTransform.translation.y
            ) {
                return PlacementSurfaceSolution(
                    transform: placementTransform(
                        position: hit.position,
                        normal: hit.normal,
                        prop: prop,
                        cameraPosition: arView.cameraTransform.translation
                    ),
                    position: hit.position,
                    normal: hit.normal,
                    source: .roomPlanGeometry,
                    depthMeters: nil
                )
            }
        }

        // Scene-understanding collision is backed by the LiDAR reconstruction mesh.
        // It catches stable horizontal surfaces such as tables even when ARKit has
        // not promoted that patch to a plane anchor yet.
        if let hit = arView.hitTest(point, query: .all, mask: .all).first(where: {
            entityID(from: $0.entity) == nil
                && !belongsToRoomReality($0.entity)
                && surfaceAccepts(
                    prop: prop,
                    normal: $0.normal,
                    position: $0.position,
                    cameraY: arView.cameraTransform.translation.y
                )
        }) {
            return PlacementSurfaceSolution(
                transform: placementTransform(
                    position: hit.position,
                    normal: hit.normal,
                    prop: prop,
                    cameraPosition: arView.cameraTransform.translation
                ),
                position: hit.position,
                normal: hit.normal,
                source: .lidarMesh,
                depthMeters: nil
            )
        }

        let preferredAlignment: ARRaycastQuery.TargetAlignment =
            prop.placementSurface == .wall ? .vertical : .horizontal
        let queries: [(ARRaycastQuery.Target, ARRaycastQuery.TargetAlignment)] = [
            (.existingPlaneGeometry, preferredAlignment),
            (.existingPlaneInfinite, preferredAlignment)
        ]

        for (target, alignment) in queries {
            let results = arView.raycast(
                from: point,
                allowing: target,
                alignment: alignment
            )
            if let result = results.first(where: {
                raycastResult($0, matches: prop, cameraY: arView.cameraTransform.translation.y)
            }) {
                let position = result.worldTransform.columns.3
                let worldPosition = SIMD3<Float>(position.x, position.y, position.z)
                let normal = SIMD3<Float>(
                        result.worldTransform.columns.1.x,
                        result.worldTransform.columns.1.y,
                        result.worldTransform.columns.1.z
                    )
                return PlacementSurfaceSolution(
                    transform: placementTransform(
                        position: worldPosition,
                        normal: normal,
                        prop: prop,
                        cameraPosition: arView.cameraTransform.translation
                    ),
                    position: worldPosition,
                    normal: normal,
                    source: .arkitPlane,
                    depthMeters: nil
                )
            }
        }

        // RoomPlan also gives us a persistent ceiling height. Intersecting the screen
        // ray with it keeps ceiling fixtures stable even when ARKit's live ceiling
        // plane is temporarily outside the current camera frame.
        if prop.placementSurface == .ceiling,
           roomCoordinateSpaceIsActive,
           let ceilingY = lastKnownCeilingY,
           let ray = arView.ray(through: point) {
            let direction = simd_normalize(ray.direction)
            guard direction.y > 0.025 else { return nil }
            let distance = (ceilingY - ray.origin.y) / direction.y
            if distance.isFinite, distance >= 0.20, distance <= 8.0 {
                let position = ray.origin + direction * distance
                return PlacementSurfaceSolution(
                    transform: placementTransform(
                        position: position,
                        normal: [0, -1, 0],
                        prop: prop,
                        cameraPosition: arView.cameraTransform.translation
                    ),
                    position: position,
                    normal: [0, -1, 0],
                    source: .roomPlanLevel,
                    depthMeters: nil
                )
            }
        }

        // A completed RoomPlan scan provides a persistent world-space floor level.
        // Intersect the exact screen ray with that recorded floor instead of guessing
        // from camera height. This remains stable while making the full floor tappable.
        if prop.placementSurface == .horizontal,
           roomCoordinateSpaceIsActive,
           let floorY = lastKnownFloorY,
           let ray = arView.ray(through: point) {
            let direction = simd_normalize(ray.direction)
            guard direction.y < -0.025 else { return nil }
            let distance = (floorY - ray.origin.y) / direction.y
            if distance.isFinite, distance >= 0.20, distance <= 8.0 {
                let position = ray.origin + direction * distance
                return PlacementSurfaceSolution(
                    transform: placementTransform(
                        position: position,
                        normal: [0, 1, 0],
                        prop: prop,
                        cameraPosition: arView.cameraTransform.translation
                    ),
                    position: position,
                    normal: [0, 1, 0],
                    source: .roomPlanLevel,
                    depthMeters: nil
                )
            }
        }

        // Do not fabricate a camera-relative point. Such an object looks acceptable
        // for a single frame but visibly swims once the camera moves. The user keeps
        // placement mode active until ARKit has a persistent plane/RoomPlan surface.
        return nil
    }

    /// Floor props use a deliberately stricter resolver than generic horizontal
    /// props. A table is horizontal and often sits more than 25 cm below the camera;
    /// height alone can therefore never prove that a hit is the floor.
    private func strictFloorPlacementSolution(
        in arView: ARView,
        at point: CGPoint,
        for prop: PropKind
    ) -> PlacementSurfaceSolution? {
        guard let frame = arView.session.currentFrame else { return nil }
        let cameraY = frame.camera.transform.columns.3.y
        let depth = sceneDepthSample(frame: frame, in: arView, at: point)

        // A finite classified plane is the strongest tap-local ARKit result. When
        // LiDAR depth exists it must agree, preventing a floor plane behind a table
        // from accepting the table pixel as a floor placement.
        let classifiedResults = arView.raycast(
            from: point,
            allowing: .existingPlaneGeometry,
            alignment: .horizontal
        )
        for result in classifiedResults {
            guard let plane = result.anchor as? ARPlaneAnchor,
                  plane.classification == .floor else { continue }
            let position = SIMD3<Float>(
                result.worldTransform.columns.3.x,
                result.worldTransform.columns.3.y,
                result.worldTransform.columns.3.z
            )
            guard depth.map({ floorDepthAgrees($0, position: position, floorY: position.y) })
                    ?? true else { continue }
            return floorSolution(
                position: position,
                normal: [0, 1, 0],
                prop: prop,
                cameraPosition: arView.cameraTransform.translation,
                source: .classifiedFloorPlane,
                depth: depth
            )
        }

        guard let floor = floorSurfaceTracker.estimate(cameraY: cameraY),
              floor.isStable else { return nil }
        lastKnownFloorY = floor.y

        // Scene-understanding collision is exact to the reconstructed LiDAR mesh,
        // but RealityKit doesn't expose the mesh face classification in this hit.
        // Require agreement with both the classified floor level and tap-local depth.
        if let hit = arView.hitTest(point, query: .all, mask: .all).first(where: {
            entityID(from: $0.entity) == nil
                && !belongsToRoomReality($0.entity)
                && !belongsToProjectorVisualization($0.entity)
                && abs(simd_normalize($0.normal).y) >= 0.78
                && abs($0.position.y - floor.y) <= 0.055
        }), let depth,
           floorDepthAgrees(depth, position: hit.position, floorY: floor.y) {
            return floorSolution(
                position: hit.position,
                normal: hit.normal,
                prop: prop,
                cameraPosition: arView.cameraTransform.translation,
                source: .lidarMesh,
                depth: depth
            )
        }

        if let hit = roomRealityRenderer.placementHit(in: arView, at: point),
           abs(simd_normalize(hit.normal).y) >= 0.78,
           abs(hit.position.y - floor.y) <= 0.055,
           let depth,
           floorDepthAgrees(depth, position: hit.position, floorY: floor.y) {
            return floorSolution(
                position: hit.position,
                normal: hit.normal,
                prop: prop,
                cameraPosition: arView.cameraTransform.translation,
                source: .roomPlanGeometry,
                depth: depth
            )
        }

        // Extend the trusted floor only when the current depth pixel independently
        // lands on that same metric level. This makes an already-scanned floor fully
        // tappable without ever projecting through furniture in the foreground.
        guard let ray = arView.ray(through: point) else { return nil }
        let direction = simd_normalize(ray.direction)
        guard direction.y < -0.025 else { return nil }
        let distance = (floor.y - ray.origin.y) / direction.y
        guard distance.isFinite, (0.20...8.0).contains(distance) else { return nil }
        let position = ray.origin + direction * distance
        guard let depth,
              floorDepthAgrees(depth, position: position, floorY: floor.y) else { return nil }
        return floorSolution(
            position: position,
            normal: [0, 1, 0],
            prop: prop,
            cameraPosition: arView.cameraTransform.translation,
            source: floor.source,
            depth: depth
        )
    }

    private func floorSolution(
        position: SIMD3<Float>,
        normal: SIMD3<Float>,
        prop: PropKind,
        cameraPosition: SIMD3<Float>,
        source: PlacementSurfaceSource,
        depth: SceneDepthSurfaceSample?
    ) -> PlacementSurfaceSolution {
        PlacementSurfaceSolution(
            transform: placementTransform(
                position: position,
                normal: normal,
                prop: prop,
                cameraPosition: cameraPosition
            ),
            position: position,
            normal: normal,
            source: source,
            depthMeters: depth?.depthMeters
        )
    }

    private func floorDepthAgrees(
        _ depth: SceneDepthSurfaceSample,
        position: SIMD3<Float>,
        floorY: Float
    ) -> Bool {
        guard abs(depth.worldPoint.y - floorY) <= 0.10,
              simd_distance(depth.worldPoint, position) <= 0.22 else { return false }
        if let normal = depth.worldNormal {
            return abs(normal.y) >= 0.68
        }
        return true
    }

    private func updatePlacementGuidance(
        using frame: ARFrame,
        at requestedPoint: CGPoint? = nil,
        force: Bool = false
    ) {
        guard isPlacingProp, let arView,
              force || frame.timestamp - lastPlacementGuidanceTimestamp >= 0.14 else { return }
        lastPlacementGuidanceTimestamp = frame.timestamp
        guard isARReady, case .normal = frame.camera.trackingState else {
            placementSurfaceMessage = "Sarı: dünya takibinin yeşile dönmesini bekle"
            placementSurfaceColor = .yellow
            return
        }
        let point = requestedPoint
            ?? placementReticlePoint
            ?? CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        if let solution = placementSolution(in: arView, at: point, for: selectedProp) {
            let depthText = solution.depthMeters.map { String(format: " • %.2f m", $0) } ?? ""
            placementSurfaceMessage = "Doğrulandı: \(solution.source.title)\(depthText)"
            placementSurfaceColor = .green
            return
        }

        if selectedProp.placementSurface == .floor {
            let cameraY = frame.camera.transform.columns.3.y
            if let estimate = floorSurfaceTracker.estimate(cameraY: cameraY), estimate.isStable,
               sceneDepthSample(frame: frame, in: arView, at: point) != nil {
                placementSurfaceMessage = "Kırmızı: görünen yüzey zemin değil"
                placementSurfaceColor = .red
            } else {
                placementSurfaceMessage = "Sarı: LiDAR zemini ölçüyor"
                placementSurfaceColor = .yellow
            }
        } else {
            placementSurfaceMessage = "Sarı: uygun yüzeyi yavaşça tara"
            placementSurfaceColor = .yellow
        }
    }

    private func surfaceAccepts(
        prop: PropKind,
        normal: SIMD3<Float>,
        position: SIMD3<Float>,
        cameraY: Float
    ) -> Bool {
        guard simd_length_squared(normal) > 0.000_001 else { return false }
        let verticalComponent = abs(simd_normalize(normal).y)
        switch prop.placementSurface {
        case .wall:
            return verticalComponent < 0.45
        case .ceiling:
            return verticalComponent > 0.72 && position.y > cameraY + 0.25
        case .floor:
            return verticalComponent > 0.72 && position.y < cameraY - 0.25
        case .horizontal:
            return verticalComponent > 0.72 && position.y < cameraY + 0.20
        }
    }

    private func raycastResult(
        _ result: ARRaycastResult,
        matches prop: PropKind,
        cameraY: Float
    ) -> Bool {
        let y = result.worldTransform.columns.3.y
        let classification = (result.anchor as? ARPlaneAnchor)?.classification
        switch prop.placementSurface {
        case .wall:
            return true
        case .ceiling:
            return classification == .ceiling || y > cameraY + 0.25
        case .floor:
            return classification == .floor
        case .horizontal:
            return classification != .ceiling && y < cameraY + 0.20
        }
    }

    private func updateKnownFloorFromRoomData() {
        floorSurfaceTracker.clearRoomFloor()
        lastKnownFloorY = nil
        guard let room = try? RoomRealityRenderer.loadRoomJSON(from: roomDataURL) else { return }
        let levels = room.floors.compactMap { floor -> Float? in
            let y = floor.transform.columns.3.y
            return y.isFinite ? y : nil
        }.sorted()
        if !levels.isEmpty {
            let roomFloorY = levels[levels.count / 2]
            floorSurfaceTracker.setRoomFloor(roomFloorY)
            lastKnownFloorY = roomFloorY
        }
        do {
            if let ceilingY = try roomRealityRenderer.inferredCeilingLevel(
                roomJSONURL: roomDataURL
            ), ceilingY.isFinite {
                lastKnownCeilingY = ceilingY
            }
        } catch {
            lastKnownCeilingY = nil
        }
    }

    private func updateKnownFloor(from anchors: [ARAnchor]) {
        guard let cameraY = arView?.session.currentFrame?.camera.transform.columns.3.y else { return }
        floorSurfaceTracker.update(with: anchors, cameraY: cameraY)
        if let estimate = floorSurfaceTracker.estimate(cameraY: cameraY), estimate.isStable {
            lastKnownFloorY = estimate.y
        }
    }

    private func sceneDepthSample(
        frame: ARFrame,
        in arView: ARView,
        at viewPoint: CGPoint
    ) -> SceneDepthSurfaceSample? {
        guard arView.bounds.width > 1, arView.bounds.height > 1,
              let sceneDepth = frame.smoothedSceneDepth ?? frame.sceneDepth else { return nil }
        let depthMap = sceneDepth.depthMap
        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)
        guard depthWidth > 4, depthHeight > 4 else { return nil }

        let orientation = arView.window?.windowScene?.interfaceOrientation ?? .portrait
        let normalizedViewPoint = CGPoint(
            x: viewPoint.x / arView.bounds.width,
            y: viewPoint.y / arView.bounds.height
        )
        let imagePoint = normalizedViewPoint.applying(
            frame.displayTransform(
                for: orientation,
                viewportSize: arView.bounds.size
            ).inverted()
        )
        guard imagePoint.x.isFinite, imagePoint.y.isFinite,
              (0...1).contains(imagePoint.x), (0...1).contains(imagePoint.y) else { return nil }

        let centerX = min(max(Int(imagePoint.x * CGFloat(depthWidth - 1)), 2), depthWidth - 3)
        let centerY = min(max(Int(imagePoint.y * CGFloat(depthHeight - 1)), 2), depthHeight - 3)
        let confidenceMap = sceneDepth.confidenceMap

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        if let confidenceMap { CVPixelBufferLockBaseAddress(confidenceMap, .readOnly) }
        defer {
            if let confidenceMap { CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly) }
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
        }
        guard let depthBase = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let confidenceBase = confidenceMap.flatMap { CVPixelBufferGetBaseAddress($0) }
        let confidenceBytesPerRow = confidenceMap.map { CVPixelBufferGetBytesPerRow($0) } ?? 0

        func confidenceIsUsable(x: Int, y: Int) -> Bool {
            guard let confidenceBase else { return true }
            let value = confidenceBase
                .advanced(by: y * confidenceBytesPerRow + x)
                .assumingMemoryBound(to: UInt8.self).pointee
            return value >= UInt8(ARConfidenceLevel.medium.rawValue)
        }

        func depthValue(x: Int, y: Int) -> Float? {
            guard x >= 0, x < depthWidth, y >= 0, y < depthHeight,
                  confidenceIsUsable(x: x, y: y) else { return nil }
            let row = depthBase.advanced(by: y * depthBytesPerRow)
            let value = row.assumingMemoryBound(to: Float32.self)[x]
            return value.isFinite && (0.15...8.0).contains(value) ? value : nil
        }

        var neighborhood: [Float] = []
        neighborhood.reserveCapacity(25)
        for y in (centerY - 2)...(centerY + 2) {
            for x in (centerX - 2)...(centerX + 2) {
                if let value = depthValue(x: x, y: y) { neighborhood.append(value) }
            }
        }
        guard neighborhood.count >= 9 else { return nil }
        neighborhood.sort()
        let medianDepth = neighborhood[neighborhood.count / 2]

        func unproject(x: Int, y: Int, depth: Float) -> SIMD3<Float> {
            let imageResolution = frame.camera.imageResolution
            let scaleX = Float(depthWidth) / Float(imageResolution.width)
            let scaleY = Float(depthHeight) / Float(imageResolution.height)
            let intrinsics = frame.camera.intrinsics
            let fx = intrinsics.columns.0.x * scaleX
            let fy = intrinsics.columns.1.y * scaleY
            let cx = intrinsics.columns.2.x * scaleX
            let cy = intrinsics.columns.2.y * scaleY
            let cameraPoint = SIMD4<Float>(
                (Float(x) - cx) / fx * depth,
                -(Float(y) - cy) / fy * depth,
                -depth,
                1
            )
            let worldPoint = frame.camera.transform * cameraPoint
            return SIMD3(worldPoint.x, worldPoint.y, worldPoint.z)
        }

        let worldPoint = unproject(x: centerX, y: centerY, depth: medianDepth)
        var worldNormal: SIMD3<Float>?
        if let leftDepth = depthValue(x: centerX - 2, y: centerY),
           let rightDepth = depthValue(x: centerX + 2, y: centerY),
           let upperDepth = depthValue(x: centerX, y: centerY - 2),
           let lowerDepth = depthValue(x: centerX, y: centerY + 2) {
            let horizontal = unproject(x: centerX + 2, y: centerY, depth: rightDepth)
                - unproject(x: centerX - 2, y: centerY, depth: leftDepth)
            let vertical = unproject(x: centerX, y: centerY + 2, depth: lowerDepth)
                - unproject(x: centerX, y: centerY - 2, depth: upperDepth)
            let crossed = simd_cross(horizontal, vertical)
            if simd_length_squared(crossed) > 0.000_001 {
                worldNormal = simd_normalize(crossed)
            }
        }
        return SceneDepthSurfaceSample(
            worldPoint: worldPoint,
            worldNormal: worldNormal,
            depthMeters: medianDepth
        )
    }

    private func placementTransform(
        position: SIMD3<Float>,
        normal: SIMD3<Float>,
        prop: PropKind,
        cameraPosition: SIMD3<Float>
    ) -> simd_float4x4 {
        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4(position.x, position.y, position.z, 1)

        guard prop.placementSurface == .wall else { return transform }

        // Wall props remain upright and face the camera side of the scanned wall.
        var forward = SIMD3<Float>(normal.x, 0, normal.z)
        guard simd_length_squared(forward) > 0.000_001 else { return transform }
        forward = simd_normalize(forward)
        let towardCamera = cameraPosition - position
        if simd_dot(forward, towardCamera) < 0 {
            forward = -forward
        }
        let up = SIMD3<Float>(0, 1, 0)
        let right = simd_normalize(simd_cross(up, forward))
        transform.columns.0 = SIMD4(right.x, right.y, right.z, 0)
        transform.columns.1 = SIMD4(up.x, up.y, up.z, 0)
        transform.columns.2 = SIMD4(forward.x, forward.y, forward.z, 0)
        return transform
    }

    func removeSelectedProp() {
        guard let id = selectedEntityID else {
            publishStatus("Önce silinecek dekoru seç", color: .yellow)
            return
        }
        removeSceneObject(id: id)
    }

    func removeSceneObject(id: UUID) {
        if id == Self.liveAppleSceneID {
            setLiveAppleEnabled(false)
            publishStatus("Canlı elma efekti sahneden kaldırıldı", color: .green)
            return
        }
        guard let arView, let placement = projectStore.placement(id: id) else {
            refreshSceneCatalogs()
            publishStatus("Silinecek sahne öğesi bulunamadı", color: .yellow)
            return
        }
        do {
            try projectStore.remove(id: id)
        } catch {
            publishStatus("Dekor silinemedi: \(error.localizedDescription)", color: .red)
            return
        }

        let anchor = arView.session.currentFrame?.anchors.first(where: {
            PropKind.descriptor(from: $0.name)?.id == id
        })
        if let anchor {
            arView.session.remove(anchor: anchor)
            renderedAnchorIDs.remove(anchor.identifier)
            knownPropAnchorIDs.remove(anchor.identifier)
        }
        managedPropAnchorsByPlacementID[id] = nil
        detachRenderedPlacement(id: id, clearSelection: true)
        refreshSceneCatalogs()
        publishStatus("\(placement.kind.title) sahneden silindi", color: .green)
    }

    func removeAllProps() {
        guard let arView else { return }
        do {
            try projectStore.removeAll()
        } catch {
            publishStatus("Dekorlar temizlenemedi: \(error.localizedDescription)", color: .red)
            return
        }

        renderGeneration &+= 1
        assetLoadSubscriptions.values.forEach { $0.cancel() }
        assetLoadSubscriptions.removeAll()
        loadingEntityIDs.removeAll()
        let propAnchors = arView.session.currentFrame?.anchors.filter {
            PropKind.from(anchorName: $0.name) != nil
        } ?? []
        for anchor in propAnchors {
            arView.session.remove(anchor: anchor)
        }
        renderedEntities.values.forEach { $0.parent?.removeFromParent() }
        renderedLightFootprints.values.forEach { $0.scene?.removeAnchor($0) }
        renderedAnchorIDs.removeAll()
        renderedAnchorIDByPlacementID.removeAll()
        knownPropAnchorIDs.removeAll()
        supersededPropAnchorIDs.removeAll()
        pendingAutoSaveAnchorIDs.removeAll()
        managedPropAnchorsByPlacementID.removeAll()
        renderedEntities.removeAll()
        renderedLights.removeAll()
        renderedLightEmitters.removeAll()
        renderedLightFootprints.removeAll()
        selectedEntityID = nil
        selectedLightSettings = nil
        isAimingLight = false
        setLiveAppleEnabled(false)
        refreshSceneCatalogs()
        publishStatus("Sanal dekorlar temizlendi", color: .green)
    }

    func importUSDZ(from sourceURL: URL) {
        persistSelectedLightSettings()
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }
        do {
            let importedURL = try projectStore.importModel(from: sourceURL)
            importedAssetURLs = projectStore.importedModelURLs
            selectedAssetURL = importedURL
            selectedProp = .custom
            selectedLightSettings = nil
            isPlacingProp = true
            publishStatus("\(importedURL.lastPathComponent) seçildi — kararlı yüzey görünce dokun", color: .green)
        } catch {
            publishStatus("USDZ içe aktarılamadı: \(error.localizedDescription)", color: .red)
        }
    }

    func reportAssetImportFailure(_ error: Error) {
        publishStatus("Dosya seçilemedi: \(error.localizedDescription)", color: .red)
    }

    func selectImportedAsset(_ url: URL) {
        persistSelectedLightSettings()
        selectedAssetURL = url
        selectedProp = .custom
        selectedEntityID = nil
        selectedLightSettings = nil
        isPlacingProp = true
        publishStatus("\(url.deletingPathExtension().lastPathComponent) seçildi — kararlı yüzey görünce dokun", color: .blue)
    }

    func showSceneLightControls() {
        persistSelectedLightSettings()
        isAimingLight = false
        if let placement = projectStore.project.placements.last(where: {
            $0.kind.emitsVirtualLight
        }) {
            selectedEntityID = placement.id
            selectedLightSettings = placement.lightSettings ?? .defaultFixture
            isPlacingProp = false
            if isARReady {
                let recovery = restorePlacementAnchorsIfNeeded(
                    allowCreatingMissingAnchors: true
                )
                if recovery.insertedAnchor {
                    shouldSaveWorldMapWhenReady = true
                    scheduleReadinessRecovery()
                }
            }
            publishStatus(
                "Sahne ışığı seçildi — güç, sıcaklık, yön, eğim ve hüzmeyi ayarla",
                color: .blue
            )
            return
        }

        selectedProp = .cagedCeilingLight
        selectedEntityID = nil
        selectedLightSettings = nil
        isPlacingProp = true
        placementSurfaceMessage = "Sarı: LiDAR tavanı ölçüyor"
        placementSurfaceColor = .yellow
        publishStatus(
            "Sahne ışığı eklemek için taranmış tavana dokun",
            color: .blue
        )
    }

    func saveWorldMap(archiveName: String? = nil) {
        shouldArchiveAfterNextSave = true
        let normalizedName = archiveName?.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingArchiveName = normalizedName.flatMap { $0.isEmpty ? nil : $0 }
        guard let arView else {
            shouldArchiveAfterNextSave = false
            pendingArchiveName = nil
            publishStatus("AR görünümü henüz hazır değil", color: .red)
            return
        }
        guard !isSavingWorldMap else {
            shouldSaveWorldMapWhenReady = true
            publishStatus("Mevcut kayıt tamamlanınca mekân arşivlenecek", color: .yellow)
            return
        }
        guard let trackingState = arView.session.currentFrame?.camera.trackingState,
              case .normal = trackingState else {
            shouldSaveWorldMapWhenReady = true
            scheduleReadinessRecovery()
            publishStatus(
                "Kaydetme sıraya alındı — kamera takibi hazır olunca tamamlanacak",
                color: .yellow
            )
            return
        }
        shouldSaveWorldMapWhenReady = false
        performWorldMapSave(in: arView)
    }

    private func performWorldMapSave(in arView: ARView) {
        guard !isSavingWorldMap else {
            publishStatus("Sahne haritası zaten kaydediliyor", color: .yellow)
            return
        }
        persistSelectedLightSettings()
        do {
            try persistAllEntityTransforms()
        } catch {
            publishStatus("Dekor konumları kaydedilemedi: \(error.localizedDescription)", color: .red)
            return
        }

        isSavingWorldMap = true
        publishStatus("Sahne haritası hazırlanıyor...", color: .yellow)

        captureAndSaveWorldMap(in: arView, attempt: 0)
    }

    private func captureAndSaveWorldMap(in arView: ARView, attempt: Int) {
        arView.session.getCurrentWorldMap { [weak self] worldMap, error in
            guard let self else { return }
            DispatchQueue.main.async {
                do {
                    if let error { throw error }
                    guard let worldMap else { throw CineARError.worldMapUnavailable }
                    // scene.json is written before ARKit acknowledges the newly added
                    // anchor. A world-map snapshot taken during that short window can
                    // otherwise contain the old anchor set. Replace only CineAR's
                    // managed anchors with the freshest ARFrame snapshot; Apple
                    // explicitly permits editing ARWorldMap.anchors before archiving.
                    self.reconcileManagedAnchors(
                        in: worldMap,
                        currentFrame: arView.session.currentFrame
                    )
                    do {
                        try self.validate(worldMap: worldMap)
                    } catch let cinearError as CineARError {
                        guard case .sceneSnapshotMismatch = cinearError,
                              attempt >= 12 else { throw cinearError }

                        // An anchor absent from every source after the retry window has
                        // no recoverable world transform. Keep the valid intersection
                        // instead of leaving the whole project permanently unsavable.
                        let survivingIDs = Set(worldMap.anchors.compactMap {
                            PropKind.descriptor(from: $0.name)?.id
                        })
                        let repairedData = try NSKeyedArchiver.archivedData(
                            withRootObject: worldMap,
                            requiringSecureCoding: true
                        )
                        let discardedCount = try self.projectStore.saveWorldMapData(
                            repairedData,
                            retainingPlacementIDs: survivingIDs
                        )
                        self.discardOrphanedRenderedContent(survivingIDs: survivingIDs)
                        self.isSavingWorldMap = false
                        let archiveResult = self.archiveSavedPlaceIfRequested()
                        self.refreshSceneCatalogs()
                        let archiveDetail = archiveResult.message.map { " — " + $0 } ?? ""
                        self.publishStatus(
                            "Sahne kaydı onarıldı — \(discardedCount) anchorsız kayıt temizlendi\(archiveDetail)",
                            color: archiveResult.failed ? .yellow : .green
                        )
                        return
                    }
                    let data = try NSKeyedArchiver.archivedData(
                        withRootObject: worldMap,
                        requiringSecureCoding: true
                    )
                    try self.projectStore.saveWorldMapData(data)
                    self.isSavingWorldMap = false
                    let archiveResult = self.shouldSaveWorldMapWhenReady
                        ? (message: nil, failed: false)
                        : self.archiveSavedPlaceIfRequested()
                    self.refreshSceneCatalogs()
                    let archiveDetail = archiveResult.message.map { " — " + $0 } ?? ""
                    self.publishStatus(
                        "Set projesi ve dünya haritası kaydedildi\(archiveDetail)",
                        color: archiveResult.failed ? .yellow : .green
                    )
                } catch {
                    if let cinearError = error as? CineARError,
                       case .sceneSnapshotMismatch = cinearError,
                       attempt < 12,
                       self.arView === arView,
                       !self.isRoomScanActive,
                       !self.isSessionInterrupted {
                        self.publishStatus(
                            "Yeni dekor dünya haritasına işleniyor...",
                            color: .yellow
                        )
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                            guard let self, self.isSavingWorldMap else { return }
                            self.captureAndSaveWorldMap(in: arView, attempt: attempt + 1)
                        }
                        return
                    }
                    self.isSavingWorldMap = false
                    self.shouldArchiveAfterNextSave = false
                    self.pendingArchiveName = nil
                    self.publishStatus(
                        "Kaydetme başarısız: \(error.localizedDescription)",
                        color: .red
                    )
                }
                if self.shouldSaveWorldMapWhenReady || self.shouldShowRoomOutlineWhenReady {
                    self.scheduleReadinessRecovery()
                }
            }
        }
    }

    private func reconcileManagedAnchors(
        in worldMap: ARWorldMap,
        currentFrame: ARFrame?
    ) {
        let expectedKinds = Dictionary(uniqueKeysWithValues: projectStore.project.placements.map {
            ($0.id, $0.kind)
        })
        var freshestAnchors: [UUID: ARAnchor] = [:]

        func collect(_ anchors: [ARAnchor]) {
            for anchor in anchors {
                guard let descriptor = PropKind.descriptor(from: anchor.name),
                      expectedKinds[descriptor.id] == descriptor.kind else { continue }
                freshestAnchors[descriptor.id] = anchor
            }
        }

        // A RoomPlan transition can briefly omit app anchors from both its result and
        // the first live frame. Because scanning shares the ARSession coordinate space,
        // the last committed anchor transforms are still safe candidates.
        collect(projectStore.storedManagedAnchors())
        // The new map overrides stored copies; the current ARFrame wins last.
        collect(worldMap.anchors)
        collect(Array(managedPropAnchorsByPlacementID.values))
        if let currentFrame { collect(currentFrame.anchors) }

        let unmanagedAnchors = worldMap.anchors.filter {
            $0.name?.hasPrefix("cinear.prop.") != true
        }
        let managedAnchors = projectStore.project.placements.compactMap {
            freshestAnchors[$0.id]
        }
        worldMap.anchors = unmanagedAnchors + managedAnchors
    }

    private func discardOrphanedRenderedContent(survivingIDs: Set<UUID>) {
        let discardedIDs = Set(renderedEntities.keys).subtracting(survivingIDs)
        for id in discardedIDs {
            detachRenderedPlacement(id: id)
            managedPropAnchorsByPlacementID[id] = nil
        }
        if let selectedEntityID, !survivingIDs.contains(selectedEntityID) {
            self.selectedEntityID = nil
            selectedLightSettings = nil
        }
    }

    private func detachRenderedPlacement(id: UUID, clearSelection: Bool = false) {
        if let anchorID = renderedAnchorIDByPlacementID.removeValue(forKey: id) {
            renderedAnchorIDs.remove(anchorID)
        }
        renderedEntities[id]?.parent?.removeFromParent()
        renderedEntities[id] = nil
        renderedLights[id]?.removeFromParent()
        renderedLights[id] = nil
        renderedLightEmitters[id] = nil
        bloodWaterfallParticles[id] = nil
        if let footprint = renderedLightFootprints.removeValue(forKey: id) {
            footprint.scene?.removeAnchor(footprint)
        }
        assetLoadSubscriptions[id]?.cancel()
        assetLoadSubscriptions[id] = nil
        loadingEntityIDs.remove(id)
        if clearSelection, selectedEntityID == id {
            selectedEntityID = nil
            selectedLightSettings = nil
            isAimingLight = false
        }
    }

    /// RoomPlan reconfiguration and AR relocalization may briefly remove app-owned
    /// anchors even though their scene records and last world transforms are valid.
    /// Rebind visuals to a live matching anchor, or recreate the missing anchor after
    /// a short grace period so an object never disappears permanently.
    private func restorePlacementAnchorsIfNeeded(
        allowCreatingMissingAnchors: Bool
    ) -> (insertedAnchor: Bool, waitingForAnchor: Bool) {
        guard let arView, !isRoomScanActive, !isSessionInterrupted else {
            return (false, false)
        }

        let placements = projectStore.project.placements
        let expectedKinds = Dictionary(uniqueKeysWithValues: placements.map {
            ($0.id, $0.kind)
        })
        var liveAnchors: [UUID: ARAnchor] = [:]
        for anchor in arView.session.currentFrame?.anchors ?? [] {
            guard let descriptor = PropKind.descriptor(from: anchor.name),
                  expectedKinds[descriptor.id] == descriptor.kind,
                  liveAnchors[descriptor.id] == nil else { continue }
            liveAnchors[descriptor.id] = anchor
        }
        var storedAnchors: [UUID: ARAnchor] = [:]
        let needsStoredFallback = placements.contains {
            liveAnchors[$0.id] == nil && managedPropAnchorsByPlacementID[$0.id] == nil
        }
        if needsStoredFallback {
            for anchor in projectStore.storedManagedAnchors() {
                guard let descriptor = PropKind.descriptor(from: anchor.name),
                      expectedKinds[descriptor.id] == descriptor.kind,
                      storedAnchors[descriptor.id] == nil else { continue }
                storedAnchors[descriptor.id] = anchor
            }
        }

        var insertedAnchor = false
        var waitingForAnchor = false
        for placement in placements {
            if let liveAnchor = liveAnchors[placement.id] {
                knownPropAnchorIDs.insert(liveAnchor.identifier)
                managedPropAnchorsByPlacementID[placement.id] = liveAnchor
                if renderedAnchorIDByPlacementID[placement.id] != liveAnchor.identifier {
                    detachRenderedPlacement(id: placement.id)
                    render(prop: placement.kind, id: placement.id, for: liveAnchor)
                }
                continue
            }

            guard let cachedAnchor = managedPropAnchorsByPlacementID[placement.id]
                ?? storedAnchors[placement.id] else { continue }

            if pendingAutoSaveAnchorIDs.contains(cachedAnchor.identifier) {
                waitingForAnchor = true
                continue
            }
            guard allowCreatingMissingAnchors else {
                waitingForAnchor = true
                continue
            }

            let replacement = ARAnchor(
                name: placement.kind.anchorName(id: placement.id),
                transform: cachedAnchor.transform
            )
            supersededPropAnchorIDs.insert(cachedAnchor.identifier)
            managedPropAnchorsByPlacementID[placement.id] = replacement
            knownPropAnchorIDs.insert(replacement.identifier)
            pendingAutoSaveAnchorIDs.insert(replacement.identifier)
            detachRenderedPlacement(id: placement.id)
            arView.session.add(anchor: replacement)
            render(prop: placement.kind, id: placement.id, for: replacement)
            insertedAnchor = true
            waitingForAnchor = true
        }
        return (insertedAnchor, waitingForAnchor)
    }

    @discardableResult
    private func savePendingWorldMapIfPossible(
        trackingState: ARCamera.TrackingState?
    ) -> Bool {
        guard shouldSaveWorldMapWhenReady, !isSavingWorldMap,
              let trackingState, case .normal = trackingState,
              let arView else { return false }
        shouldSaveWorldMapWhenReady = false
        performWorldMapSave(in: arView)
        return true
    }

    private func scheduleReadinessRecovery() {
        readinessRecoveryGeneration &+= 1
        let generation = readinessRecoveryGeneration
        pollReadiness(generation: generation, attempt: 0)
    }

    private func pollReadiness(generation: UInt64, attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + (attempt == 0 ? 0.12 : 0.25)) {
            [weak self] in
            guard let self,
                  self.readinessRecoveryGeneration == generation,
                  !self.isRoomScanActive,
                  !self.isSessionInterrupted else { return }

            let trackingState = self.arView?.session.currentFrame?.camera.trackingState
            var anchorRecoveryWaiting = false
            switch trackingState {
            case .normal?:
                self.isARReady = true
                self.didAttemptSessionFailureRecovery = false
                let anchorRecovery = self.restorePlacementAnchorsIfNeeded(
                    allowCreatingMissingAnchors: attempt >= 4
                )
                anchorRecoveryWaiting = anchorRecovery.waitingForAnchor
                if anchorRecovery.insertedAnchor {
                    self.shouldSaveWorldMapWhenReady = true
                } else if self.savePendingWorldMapIfPossible(trackingState: trackingState) {
                    return
                }
                if self.shouldShowRoomOutlineWhenReady {
                    self.shouldShowRoomOutlineWhenReady = false
                    self.showRoomOutline()
                    return
                }
            case .limited(let reason)?:
                _ = reason
                self.isARReady = false
            case .notAvailable?, nil:
                self.isARReady = false
            }

            let needsAnotherCheck = !self.isARReady
                || self.shouldSaveWorldMapWhenReady
                || self.shouldShowRoomOutlineWhenReady
                || anchorRecoveryWaiting
            if needsAnotherCheck, attempt < 40 {
                self.pollReadiness(generation: generation, attempt: attempt + 1)
            }
        }
    }

    func loadWorldMap() {
        guard !isSavingWorldMap else {
            publishStatus("Kaydetme tamamlanmadan sahne yüklenemez", color: .yellow)
            return
        }
        do {
            let snapshot: StoredWorldMapSnapshot
            let recoveryNotice: String?
            do {
                snapshot = try projectStore.worldMapSnapshotForLoading()
                recoveryNotice = nil
            } catch let storeError as SceneProjectStoreError {
                switch storeError {
                case .worldMapOutOfDate, .worldMapChecksumMismatch:
                    let recovery = try projectStore.recoverWorldMapSnapshot()
                    snapshot = recovery.snapshot
                    if recovery.discardedPlacementCount == 0,
                       recovery.discardedAnchorCount == 0 {
                        recoveryNotice = "Kayıt doğrulaması onarıldı"
                    } else {
                        recoveryNotice = "Sahne kurtarıldı — "
                            + "\(recovery.discardedPlacementCount) haritasız nesne, "
                            + "\(recovery.discardedAnchorCount) sahipsiz anchor temizlendi"
                    }
                default:
                    throw storeError
                }
            }
            guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: ARWorldMap.self,
                from: snapshot.data
            ) else {
                throw CineARError.worldMapUnavailable
            }
            try validate(worldMap: worldMap, placements: snapshot.project.placements)
            projectStore.activate(snapshot)
            importedAssetURLs = projectStore.importedModelURLs
            hasScannedRoom = FileManager.default.fileExists(atPath: roomDataURL.path)
            refreshSceneCatalogs()
            runSession(initialWorldMap: worldMap)
            let prefix = recoveryNotice.map { $0 + " — " } ?? ""
            publishStatus(prefix + "aynı alanı göster; kamera yeniden konumlanıyor", color: .yellow)
        } catch {
            shouldShowRoomOutlineWhenReady = false
            publishStatus("Kayıtlı sahne yüklenemedi: \(error.localizedDescription)", color: .red)
        }
    }

    func loadSavedPlace(id: UUID) {
        guard !isSavingWorldMap else {
            publishStatus("Kaydetme tamamlanmadan başka mekân yüklenemez", color: .yellow)
            return
        }
        do {
            let snapshot = try projectStore.installSavedPlace(id: id)
            guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: ARWorldMap.self,
                from: snapshot.data
            ) else {
                throw CineARError.worldMapUnavailable
            }
            try validate(worldMap: worldMap, placements: snapshot.project.placements)
            projectStore.activate(snapshot)
            importedAssetURLs = projectStore.importedModelURLs
            hasScannedRoom = FileManager.default.fileExists(atPath: roomDataURL.path)
            roomCoordinateSpaceIsActive = hasScannedRoom
            roomRealityRenderer.clear()
            roomRealityRenderer.isVisible = false
            isRoomOutlineVisible = false
            setLiveAppleEnabled(false)
            refreshSceneCatalogs()
            runSession(initialWorldMap: worldMap)
            publishStatus("Kayıtlı mekân açıldı — aynı alanı göstererek yeniden konumlan", color: .yellow)
        } catch {
            refreshSceneCatalogs()
            publishStatus("Mekân yüklenemedi: \(error.localizedDescription)", color: .red)
        }
    }

    func deleteSavedPlace(id: UUID) {
        do {
            try projectStore.deleteSavedPlace(id: id)
            refreshSceneCatalogs()
            publishStatus("Kayıtlı mekân silindi", color: .green)
        } catch {
            publishStatus("Mekân silinemedi: \(error.localizedDescription)", color: .red)
        }
    }

    func startRecording() {
        guard case .idle = recordingPhase else {
            publishStatus("Kayıt işlemi zaten devam ediyor", color: .yellow)
            return
        }
        if isListeningForCGICommands { stopCGIVoiceCommands() }
        recordingPhase = .starting
        isRecordingTransitioning = true
        coachingOverlay?.isHidden = true
        publishStatus("HEVC kayıt hazırlanıyor...", color: .yellow)

        persistSelectedLightSettings()
        do {
            try persistAllEntityTransforms()
            let url = try projectStore.nextRecordingURL()
            recorder.start(
                outputURL: url,
                runtimeFailure: { [weak self] error in
                    guard let self, case .recording = self.recordingPhase else { return }
                    self.publishStatus(
                        "Kayıt sırasında hata oluştu: \(error.localizedDescription)",
                        color: .red
                    )
                    self.stopRecording()
                },
                completion: { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success:
                        guard case .starting = self.recordingPhase else { return }
                        self.recordingPhase = .recording
                        self.isRecordingTransitioning = false
                        self.isRecording = true
                        self.coachingOverlay?.isHidden = true
                        self.statusText = "HEVC çekim devam ediyor — yönü değiştirmeyin"
                        self.trackingColor = .red
                    case .failure(let error):
                        self.recordingPhase = .idle
                        self.isRecordingTransitioning = false
                        self.isRecording = false
                        self.coachingOverlay?.isHidden = false
                        self.publishStatus(
                            "Kayıt başlatılamadı: \(error.localizedDescription)",
                            color: .red
                        )
                    }
                }
            )
        } catch {
            recordingPhase = .idle
            isRecordingTransitioning = false
            coachingOverlay?.isHidden = false
            publishStatus("Kayıt dosyası açılamadı: \(error.localizedDescription)", color: .red)
        }
    }

    func stopRecording() {
        guard case .recording = recordingPhase else {
            publishStatus("Durdurulabilecek etkin bir kayıt yok", color: .yellow)
            return
        }
        recordingPhase = .stopping
        isRecordingTransitioning = true
        publishStatus("MOV dosyası tamamlanıyor...", color: .yellow)

        recorder.stop { [weak self] result in
            guard let self else { return }
            self.recordingPhase = .idle
            self.isRecordingTransitioning = false
            self.isRecording = false
            self.coachingOverlay?.isHidden = false
            switch result {
            case .success(let url):
                self.lastRecordingURL = url
                self.publishStatus("Çekim MOV dosyasına kaydedildi", color: .green)
            case .failure(let error):
                self.publishStatus("Kayıt bitirilemedi: \(error.localizedDescription)", color: .red)
            }
        }
    }

    private func render(prop: PropKind, id: UUID, for anchor: ARAnchor) {
        guard arView != nil,
              knownPropAnchorIDs.contains(anchor.identifier),
              !renderedAnchorIDs.contains(anchor.identifier),
              renderedEntities[id] == nil,
              !loadingEntityIDs.contains(id) else { return }
        guard let placement = projectStore.placement(id: id), placement.kind == prop else {
            publishStatus(
                "Sahne tutarsız: \(id.uuidString) kimlikli anchor için dekor kaydı yok",
                color: .red
            )
            return
        }

        if let descriptor = prop.photorealDescriptor {
            let generation = renderGeneration
            let loadingProxy = makeLoadingProxy(
                for: prop,
                dimensions: descriptor.dimensions
            )
            attach(
                entity: loadingProxy,
                prop: prop,
                id: id,
                anchor: anchor,
                generation: generation
            )
            guard let modelURL = bundledAssetURL(named: descriptor.assetName) else {
                publishStatus(
                    "\(prop.title) USDZ pakette bulunamadı; görünür yedek model kullanılıyor",
                    color: .yellow
                )
                return
            }
            loadingEntityIDs.insert(id)
            let request = Entity.loadAsync(contentsOf: modelURL)
            assetLoadSubscriptions[id] = request
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    guard let self, self.renderGeneration == generation else { return }
                    self.loadingEntityIDs.remove(id)
                    self.assetLoadSubscriptions[id] = nil
                    if case .failure(let error) = completion {
                        self.publishStatus(
                            "\(prop.title) USDZ açılamadı; yedek model gösteriliyor: "
                                + error.localizedDescription,
                            color: .yellow
                        )
                    }
                } receiveValue: { [weak self] content in
                    guard let self,
                          let entity = self.makePhotorealLibraryEntity(
                            content: content,
                            prop: prop,
                            descriptor: descriptor
                          ) else {
                        self?.publishStatus(
                            "\(prop.title) ölçüsü okunamadı; yedek model gösteriliyor",
                            color: .yellow
                        )
                        return
                    }
                    if self.replaceRenderedEntity(
                        entity: entity,
                        prop: prop,
                        id: id,
                        anchor: anchor,
                        generation: generation
                    ) {
                        self.publishStatus(
                            "\(prop.title) gerçek USDZ modeli hazır",
                            color: .green
                        )
                    }
                }
            return
        }

        if prop.bundledAssetName != nil {
            let entity: ModelEntity
            if let bundledEntity = makeBundledLibraryEntity(for: prop) {
                entity = bundledEntity
            } else {
                let dimensions = libraryDescriptor(for: prop)?.dimensions
                    ?? SIMD3<Float>(repeating: 0.5)
                entity = makeLoadingProxy(for: prop, dimensions: dimensions)
                publishStatus(
                    "\(prop.title) USDZ açılamadı; görünür yedek model kullanılıyor",
                    color: .yellow
                )
            }
            attach(
                entity: entity,
                prop: prop,
                id: id,
                anchor: anchor,
                generation: renderGeneration
            )
            return
        }

        if prop == .custom {
            let modelURL: URL
            guard let fileName = placement.assetFileName else {
                publishStatus("3B dekor yüklenemedi: USDZ kaydı eksik", color: .red)
                return
            }
            do {
                modelURL = try projectStore.modelURL(fileName: fileName)
            } catch {
                publishStatus("3B dekor yüklenemedi: \(error.localizedDescription)", color: .red)
                return
            }
            let generation = renderGeneration
            attach(
                entity: makeLoadingProxy(
                    for: prop,
                    dimensions: SIMD3<Float>(repeating: 0.35)
                ),
                prop: prop,
                id: id,
                anchor: anchor,
                generation: generation
            )
            loadingEntityIDs.insert(id)
            let request = ModelEntity.loadModelAsync(contentsOf: modelURL)
            assetLoadSubscriptions[id] = request
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    guard let self, self.renderGeneration == generation else { return }
                    self.loadingEntityIDs.remove(id)
                    self.assetLoadSubscriptions[id] = nil
                    if case .failure(let error) = completion {
                        self.publishStatus(
                            "3B dekor açılamadı; yedek model gösteriliyor: "
                                + error.localizedDescription,
                            color: .yellow
                        )
                    }
                } receiveValue: { [weak self] entity in
                    guard let self else { return }
                    if self.replaceRenderedEntity(
                        entity: entity,
                        prop: prop,
                        id: id,
                        anchor: anchor,
                        generation: generation
                    ) {
                        self.publishStatus("3B dekor hazır", color: .green)
                    }
                }
            return
        }

        attach(
            entity: makeBuiltInEntity(for: prop),
            prop: prop,
            id: id,
            anchor: anchor,
            generation: renderGeneration
        )
    }

    private func attach(
        entity: ModelEntity,
        prop: PropKind,
        id: UUID,
        anchor: ARAnchor,
        generation: UInt64
    ) {
        guard let arView,
              generation == renderGeneration,
              knownPropAnchorIDs.contains(anchor.identifier),
              !renderedAnchorIDs.contains(anchor.identifier),
              renderedEntities[id] == nil,
              let placement = projectStore.placement(id: id),
              placement.kind == prop else { return }
        let entity = makeContactPivotEntity(content: entity, for: prop)
        let anchorEntity = AnchorEntity(anchor: anchor)
        entity.name = id.uuidString
        entity.transform = placement.transform.realityKitTransform
        if entity.collision == nil {
            entity.generateCollisionShapes(recursive: true)
        }
        addContactShadow(to: entity, for: prop)
        if prop.emitsVirtualLight {
            let settings = placement.lightSettings ?? .defaultFixture
            installVirtualLight(on: entity, prop: prop, id: id, settings: settings)
            if selectedEntityID == id {
                selectedLightSettings = settings
            }
        }
        anchorEntity.addChild(entity)
        arView.scene.addAnchor(anchorEntity)
        if prop.emitsVirtualLight,
           let light = renderedLights[id],
           let settings = placement.lightSettings ?? selectedLightSettings {
            apply(settings: settings, to: light, prop: prop)
        }

        // Translation is deliberately excluded: a placed prop stays bound to its
        // world anchor. Rotation and scale remain available for art direction.
        arView.installGestures([.rotation, .scale], for: entity)

        renderedAnchorIDs.insert(anchor.identifier)
        renderedAnchorIDByPlacementID[id] = anchor.identifier
        renderedEntities[id] = entity
        if prop == .bloodWaterfall {
            installBloodWaterfallRuntime(on: entity, id: id)
        }
    }

    private func installBloodWaterfallRuntime(on entity: ModelEntity, id: UUID) {
        var particles: [BloodWaterfallParticle] = []
        for index in 0..<18 {
            guard let drop = entity.findEntity(named: "cinear.blood.drop.\(index)") as? ModelEntity
            else { continue }
            particles.append(
                BloodWaterfallParticle(
                    entity: drop,
                    phase: Float(index) / 18,
                    lateral: drop.position.x,
                    depth: drop.position.z
                )
            )
        }
        bloodWaterfallParticles[id] = particles
    }

    private func updateBloodWaterfalls(timestamp: TimeInterval) {
        let time = Float(timestamp)
        for particles in bloodWaterfallParticles.values {
            for (index, particle) in particles.enumerated() {
                let progress = (time * (0.62 + Float(index % 4) * 0.035) + particle.phase)
                    .truncatingRemainder(dividingBy: 1)
                particle.entity.position = [
                    particle.lateral + sin(time * 2.3 + Float(index)) * 0.012,
                    -0.04 - progress * 1.43,
                    particle.depth
                ]
                let stretch = 1.35 + min(progress * 1.8, 1.5)
                particle.entity.scale = [1, stretch, 1]
            }
        }
    }

    @discardableResult
    private func replaceRenderedEntity(
        entity: ModelEntity,
        prop: PropKind,
        id: UUID,
        anchor: ARAnchor,
        generation: UInt64
    ) -> Bool {
        guard let arView,
              generation == renderGeneration,
              knownPropAnchorIDs.contains(anchor.identifier),
              renderedAnchorIDs.contains(anchor.identifier),
              let current = renderedEntities[id],
              let parent = current.parent,
              let placement = projectStore.placement(id: id),
              placement.kind == prop else { return false }

        let preservedTransform = current.transform
        let entity = makeContactPivotEntity(content: entity, for: prop)
        renderedLights[id]?.removeFromParent()
        renderedLights[id] = nil
        renderedLightEmitters[id] = nil
        current.removeFromParent()

        entity.name = id.uuidString
        entity.transform = preservedTransform
        if entity.collision == nil {
            entity.generateCollisionShapes(recursive: true)
        }
        addContactShadow(to: entity, for: prop)
        if prop.emitsVirtualLight {
            let settings = (selectedEntityID == id ? selectedLightSettings : nil)
                ?? placement.lightSettings
                ?? .defaultFixture
            installVirtualLight(on: entity, prop: prop, id: id, settings: settings)
            if selectedEntityID == id {
                selectedLightSettings = settings
            }
        }
        parent.addChild(entity)
        if prop.emitsVirtualLight,
           let light = renderedLights[id] {
            let settings = (selectedEntityID == id ? selectedLightSettings : nil)
                ?? placement.lightSettings
                ?? .defaultFixture
            apply(settings: settings, to: light, prop: prop)
        }
        arView.installGestures([.rotation, .scale], for: entity)
        renderedEntities[id] = entity
        return true
    }

    func setSelectedLightEnabled(_ isEnabled: Bool) {
        guard var settings = selectedLightSettings else { return }
        settings.isEnabled = isEnabled
        previewSelectedLight(settings)
        persistSelectedLightSettings()
    }

    func setSelectedLightIntensity(_ lumens: Float) {
        guard var settings = selectedLightSettings else { return }
        settings.intensityLumens = min(max(lumens, 0), 12_000)
        previewSelectedLight(settings)
    }

    func setSelectedLightTemperature(_ kelvin: Float) {
        guard var settings = selectedLightSettings else { return }
        settings.temperatureKelvin = min(max(kelvin, 2_000), 6_500)
        previewSelectedLight(settings)
    }

    func setSelectedLightConeAngle(_ degrees: Float) {
        guard var settings = selectedLightSettings else { return }
        settings.coneAngleDegrees = min(max(degrees, 8), 120)
        previewSelectedLight(settings)
    }

    func setSelectedLightSoftness(_ softness: Float) {
        guard var settings = selectedLightSettings else { return }
        settings.beamSoftness = min(max(softness, 0), 1)
        previewSelectedLight(settings)
    }

    func setSelectedLightYaw(_ degrees: Float) {
        guard var settings = selectedLightSettings else { return }
        settings.yawDegrees = min(max(degrees, -180), 180)
        settings.targetPosition = nil
        settings.targetNormal = nil
        previewSelectedLight(settings)
    }

    func setSelectedLightTilt(_ degrees: Float) {
        guard var settings = selectedLightSettings else { return }
        settings.tiltDegrees = min(max(degrees, -75), 75)
        settings.targetPosition = nil
        settings.targetNormal = nil
        previewSelectedLight(settings)
    }

    func beginSelectedLightTargeting() {
        guard selectedEntityID != nil, selectedLightSettings != nil else {
            publishStatus("Önce sahnedeki bir ışığı seç", color: .yellow)
            return
        }
        isPlacingProp = false
        isAimingLight = true
        publishStatus(
            "Projektör hedefi — ışığın vuracağı zemin, masa veya duvara dokun",
            color: .blue
        )
    }

    func cancelSelectedLightTargeting() {
        guard isAimingLight else { return }
        isAimingLight = false
        publishStatus("Projektör hedef seçimi iptal edildi", color: .yellow)
    }

    func persistSelectedLightSettings() {
        guard let id = selectedEntityID,
              let settings = selectedLightSettings,
              settings.isValid,
              let placement = projectStore.placement(id: id),
              placement.kind.emitsVirtualLight,
              placement.lightSettings != settings else { return }
        do {
            try projectStore.updateLightSettings(id: id, settings: settings)
        } catch {
            publishStatus("Işık ayarları kaydedilemedi: \(error.localizedDescription)", color: .red)
        }
    }

    private func previewSelectedLight(_ settings: VirtualLightSettings) {
        selectedLightSettings = settings
        guard let id = selectedEntityID,
              let light = renderedLights[id],
              let prop = projectStore.placement(id: id)?.kind else { return }
        apply(settings: settings, to: light, prop: prop)
    }

    private func retargetSelectedLight(in arView: ARView, at point: CGPoint) {
        guard let id = selectedEntityID,
              var settings = selectedLightSettings,
              renderedLights[id] != nil else {
            isAimingLight = false
            publishStatus("Işık hedeflenemedi; sahnedeki ışığı yeniden seç", color: .yellow)
            return
        }
        guard let hit = projectorSurfaceHit(in: arView, at: point) else {
            publishStatus("Projektör hedefi bulunamadı; yüzeyi biraz daha tara", color: .yellow)
            return
        }
        let normal = simd_normalize(hit.normal)
        settings.targetPosition = [hit.position.x, hit.position.y, hit.position.z]
        settings.targetNormal = [normal.x, normal.y, normal.z]
        selectedLightSettings = settings
        isAimingLight = false
        previewSelectedLight(settings)
        persistSelectedLightSettings()
        publishStatus(
            String(format: "Projektör hedefi sabitlendi — %.2f m", hit.distanceMeters),
            color: .green
        )
    }

    private func projectorSurfaceHit(in arView: ARView, at point: CGPoint) -> ProjectorSurfaceHit? {
        if let hit = arView.hitTest(point, query: .all, mask: .all).first(where: {
            entityID(from: $0.entity) == nil
                && !belongsToProjectorVisualization($0.entity)
        }), simd_length_squared(hit.normal) > 0.000_001 {
            let distance = simd_distance(hit.position, arView.cameraTransform.translation)
            return ProjectorSurfaceHit(
                position: hit.position,
                normal: hit.normal,
                distanceMeters: distance
            )
        }
        if let hit = roomRealityRenderer.placementHit(in: arView, at: point),
           simd_length_squared(hit.normal) > 0.000_001 {
            return ProjectorSurfaceHit(
                position: hit.position,
                normal: hit.normal,
                distanceMeters: simd_distance(hit.position, arView.cameraTransform.translation)
            )
        }
        for alignment in [ARRaycastQuery.TargetAlignment.horizontal, .vertical] {
            if let result = arView.raycast(
                from: point,
                allowing: .existingPlaneGeometry,
                alignment: alignment
            ).first {
                let position = SIMD3<Float>(
                    result.worldTransform.columns.3.x,
                    result.worldTransform.columns.3.y,
                    result.worldTransform.columns.3.z
                )
                let normal = SIMD3<Float>(
                    result.worldTransform.columns.1.x,
                    result.worldTransform.columns.1.y,
                    result.worldTransform.columns.1.z
                )
                return ProjectorSurfaceHit(
                    position: position,
                    normal: normal,
                    distanceMeters: simd_distance(position, arView.cameraTransform.translation)
                )
            }
        }
        return nil
    }

    private func installVirtualLight(
        on entity: ModelEntity,
        prop: PropKind,
        id: UUID,
        settings: VirtualLightSettings
    ) {
        renderedLights[id]?.removeFromParent()
        let light = SpotLight()
        light.name = "cinear.virtual-light.\(id.uuidString)"
        light.shadow = SpotLightComponent.Shadow()

        let dimensions = prop.photorealDescriptor?.dimensions ?? SIMD3<Float>(0.5, 0.5, 0.5)
        switch prop.placementSurface {
        case .ceiling:
            light.position = [0, -dimensions.y * 0.48, 0]
        case .wall:
            light.position = [0, 0, dimensions.z * 0.52]
        case .floor, .horizontal:
            light.position = [0, dimensions.y * 0.34, dimensions.z * 0.16]
        }
        entity.addChild(light)
        renderedLights[id] = light
        var emitterMaterial = UnlitMaterial()
        emitterMaterial.color = .init(tint: .white)
        let emitter: ModelEntity
        if prop == .cagedCeilingLight || prop == .lightPanel {
            emitter = ModelEntity(
                mesh: .generateBox(size: [0.58, 0.018, 0.07], cornerRadius: 0.009),
                materials: [emitterMaterial]
            )
        } else {
            emitter = ModelEntity(
                mesh: .generateSphere(radius: 0.035),
                materials: [emitterMaterial]
            )
        }
        emitter.name = "cinear.virtual-light.emitter"
        light.addChild(emitter)
        renderedLightEmitters[id] = emitter
        apply(settings: settings, to: light, prop: prop)
    }

    private func apply(settings: VirtualLightSettings, to light: SpotLight, prop: PropKind) {
        light.isEnabled = settings.isEnabled
        light.light.intensity = settings.intensityLumens
        light.light.color = Self.colorTemperature(kelvin: settings.temperatureKelvin)
        light.light.innerAngleInDegrees = settings.coneAngleDegrees
            * (1 - settings.effectiveBeamSoftness * 0.72)
        light.light.outerAngleInDegrees = settings.coneAngleDegrees
        light.light.attenuationRadius = min(
            max(sqrt(max(settings.intensityLumens, 1) / 1_000) * 4, 2),
            12
        )
        if let target = settings.projectorTarget,
           let parent = light.parent {
            let parentWorld = parent.transformMatrix(relativeTo: nil)
            let localTarget4 = simd_inverse(parentWorld) * SIMD4(target.x, target.y, target.z, 1)
            let localTarget = SIMD3(localTarget4.x, localTarget4.y, localTarget4.z)
            let direction = localTarget - light.position
            if simd_length_squared(direction) > 0.000_001 {
                light.orientation = simd_quatf(
                    from: SIMD3<Float>(0, 0, -1),
                    to: simd_normalize(direction)
                )
                light.light.attenuationRadius = min(max(simd_length(direction) * 1.35, 2), 20)
            }
        } else {
            let baseDirection: SIMD3<Float>
            switch prop.placementSurface {
            case .ceiling:
                baseDirection = [0, -1, 0]
            case .wall:
                baseDirection = simd_normalize(SIMD3<Float>(0, -0.35, 1))
            case .floor, .horizontal:
                baseDirection = simd_normalize(SIMD3<Float>(0, -0.88, 0.32))
            }
            let yaw = simd_quatf(
                angle: settings.effectiveYawDegrees * .pi / 180,
                axis: SIMD3<Float>(0, 1, 0)
            )
            let tilt = simd_quatf(
                angle: settings.effectiveTiltDegrees * .pi / 180,
                axis: SIMD3<Float>(1, 0, 0)
            )
            let direction = simd_normalize(yaw.act(tilt.act(baseDirection)))
            light.orientation = simd_quatf(
                from: SIMD3<Float>(0, 0, -1),
                to: direction
            )
        }
        if let idText = light.name.split(separator: ".").last,
           let id = UUID(uuidString: String(idText)),
           let emitter = renderedLightEmitters[id] {
            var material = UnlitMaterial()
            material.color = .init(tint: Self.colorTemperature(kelvin: settings.temperatureKelvin))
            if var model = emitter.components[ModelComponent.self] {
                model.materials = [material]
                emitter.components.set(model)
            }
        }
        refreshProjectorFootprint(id: entityID(for: light), settings: settings)
    }

    private func refreshProjectorLights() {
        for (id, light) in renderedLights {
            guard let placement = projectStore.placement(id: id) else { continue }
            let settings = (selectedEntityID == id ? selectedLightSettings : nil)
                ?? placement.lightSettings
                ?? .defaultFixture
            apply(settings: settings, to: light, prop: placement.kind)
        }
    }

    private func refreshProjectorFootprint(
        id: UUID?,
        settings: VirtualLightSettings
    ) {
        guard let id, let arView, let light = renderedLights[id], light.scene != nil,
              settings.isEnabled, settings.intensityLumens > 1 else {
            if let id, let footprint = renderedLightFootprints.removeValue(forKey: id) {
                footprint.scene?.removeAnchor(footprint)
            }
            return
        }

        let lightWorld = light.transformMatrix(relativeTo: nil)
        let origin = SIMD3<Float>(
            lightWorld.columns.3.x,
            lightWorld.columns.3.y,
            lightWorld.columns.3.z
        )
        let forward = simd_normalize(SIMD3<Float>(
            -lightWorld.columns.2.x,
            -lightWorld.columns.2.y,
            -lightWorld.columns.2.z
        ))

        let target: SIMD3<Float>
        let storedNormal: SIMD3<Float>?
        if let storedTarget = settings.projectorTarget {
            target = storedTarget
            storedNormal = settings.projectorTargetNormal
        } else if forward.y < -0.025,
                  let floorY = lastKnownFloorY {
            let distance = (floorY - origin.y) / forward.y
            guard distance.isFinite, (0.15...20).contains(distance) else { return }
            target = origin + forward * distance
            storedNormal = [0, 1, 0]
        } else {
            if let footprint = renderedLightFootprints.removeValue(forKey: id) {
                footprint.scene?.removeAnchor(footprint)
            }
            return
        }

        let beam = target - origin
        let distance = simd_length(beam)
        guard distance.isFinite, distance >= 0.08, distance <= 20 else { return }
        let direction = beam / distance
        var normal = storedNormal ?? -direction
        guard simd_length_squared(normal) > 0.000_001 else { return }
        normal = simd_normalize(normal)
        if simd_dot(normal, -direction) < 0 { normal = -normal }

        let halfAngle = settings.coneAngleDegrees * .pi / 360
        let radius = min(max(tan(halfAngle) * distance, 0.045), 3.5)
        let incidence = max(abs(simd_dot(direction, normal)), 0.28)
        let elongatedRadius = min(radius / incidence, radius * 3.2)

        let anchor: AnchorEntity
        let visualRoot: Entity
        if let existing = renderedLightFootprints[id],
           let existingRoot = existing.children.first {
            anchor = existing
            visualRoot = existingRoot
        } else {
            anchor = AnchorEntity(world: .zero)
            anchor.name = "cinear.projector.anchor.\(id.uuidString)"
            visualRoot = Entity()
            visualRoot.name = "cinear.projector.surface.\(id.uuidString)"
            anchor.addChild(visualRoot)
            let factors: [Float] = [1.0, 0.82, 0.64, 0.46, 0.28]
            for (index, factor) in factors.enumerated() {
                guard let disc = makeProjectorDisc(index: index) else { continue }
                disc.name = "cinear.projector.disc.\(index)"
                disc.position.y = Float(index) * 0.00035
                disc.scale = [factor, 1, factor]
                visualRoot.addChild(disc)
            }
            arView.scene.addAnchor(anchor)
            renderedLightFootprints[id] = anchor
        }

        var projectedForward = direction - normal * simd_dot(direction, normal)
        if simd_length_squared(projectedForward) < 0.000_001 {
            projectedForward = SIMD3<Float>(0, 0, 1)
                - normal * simd_dot(SIMD3<Float>(0, 0, 1), normal)
        }
        if simd_length_squared(projectedForward) < 0.000_001 {
            projectedForward = SIMD3<Float>(1, 0, 0)
                - normal * simd_dot(SIMD3<Float>(1, 0, 0), normal)
        }
        let surfaceForward = simd_normalize(projectedForward)
        let surfaceRight = simd_normalize(simd_cross(normal, surfaceForward))
        let orientationMatrix = simd_float3x3(columns: (
            surfaceRight,
            normal,
            surfaceForward
        ))
        visualRoot.position = target + normal * 0.006
        visualRoot.orientation = simd_quatf(orientationMatrix)

        let factors: [Float] = [1.0, 0.82, 0.64, 0.46, 0.28]
        let intensity = min(max(settings.intensityLumens / 12_000, 0), 1)
        let color = Self.colorTemperature(kelvin: settings.temperatureKelvin)
        for (index, child) in visualRoot.children.enumerated() {
            guard index < factors.count, let disc = child as? ModelEntity else { continue }
            let factor = factors[index]
            disc.scale = [radius * factor, 1, elongatedRadius * factor]
            let edgeWeight = Float(index + 1) / Float(factors.count)
            let alpha = CGFloat(
                min(0.34, (0.018 + intensity * 0.105)
                    * (0.55 + edgeWeight * (1.2 - settings.effectiveBeamSoftness * 0.45)))
            )
            var material = UnlitMaterial()
            material.color = .init(tint: color.withAlphaComponent(alpha))
            if var model = disc.components[ModelComponent.self] {
                model.materials = [material]
                disc.components.set(model)
            }
        }
    }

    private func makeProjectorDisc(index: Int) -> ModelEntity? {
        let segments = 48
        var positions: [SIMD3<Float>] = [.zero]
        positions.reserveCapacity(segments + 1)
        for segment in 0..<segments {
            let angle = Float(segment) / Float(segments) * 2 * .pi
            positions.append([cos(angle), 0, sin(angle)])
        }
        var indices: [UInt32] = []
        indices.reserveCapacity(segments * 3)
        for segment in 0..<segments {
            indices.append(0)
            indices.append(UInt32((segment + 1) % segments + 1))
            indices.append(UInt32(segment + 1))
        }
        var descriptor = MeshDescriptor(name: "cinear.projector.disc.\(index)")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.primitives = .triangles(indices)
        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return nil }
        return ModelEntity(mesh: mesh, materials: [UnlitMaterial()])
    }

    private func entityID(for light: SpotLight) -> UUID? {
        guard let idText = light.name.split(separator: ".").last else { return nil }
        return UUID(uuidString: String(idText))
    }

    private static func colorTemperature(kelvin: Float) -> UIColor {
        let temperature = Double(min(max(kelvin, 2_000), 6_500)) / 100
        let red: Double
        let green: Double
        let blue: Double
        if temperature <= 66 {
            red = 255
            green = 99.4708025861 * log(temperature) - 161.1195681661
            blue = temperature <= 19
                ? 0
                : 138.5177312231 * log(temperature - 10) - 305.0447927307
        } else {
            red = 329.698727446 * pow(temperature - 60, -0.1332047592)
            green = 288.1221695283 * pow(temperature - 60, -0.0755148492)
            blue = 255
        }
        func channel(_ value: Double) -> CGFloat {
            CGFloat(min(max(value, 0), 255) / 255)
        }
        return UIColor(red: channel(red), green: channel(green), blue: channel(blue), alpha: 1)
    }

    private func persistAllEntityTransforms() throws {
        let transforms = Dictionary(uniqueKeysWithValues: renderedEntities.map {
            ($0.key, $0.value.transform)
        })
        try projectStore.updateTransforms(transforms)
    }

    private func validate(
        worldMap: ARWorldMap,
        placements: [PlacementRecord]? = nil
    ) throws {
        var anchorKinds: [UUID: PropKind] = [:]
        for anchor in worldMap.anchors {
            guard let descriptor = PropKind.descriptor(from: anchor.name) else { continue }
            guard anchorKinds.updateValue(descriptor.kind, forKey: descriptor.id) == nil else {
                throw CineARError.duplicatePropAnchor(descriptor.id)
            }
        }

        let records = placements ?? projectStore.project.placements
        let placementKinds = Dictionary(uniqueKeysWithValues: records.map {
            ($0.id, $0.kind)
        })
        let anchorIDs = Set(anchorKinds.keys)
        let placementIDs = Set(placementKinds.keys)
        let missingFromMap = placementIDs.subtracting(anchorIDs).count
        let missingFromProject = anchorIDs.subtracting(placementIDs).count
        let kindMismatch = anchorIDs.intersection(placementIDs).filter {
            anchorKinds[$0] != placementKinds[$0]
        }.count

        guard missingFromMap == 0, missingFromProject == 0, kindMismatch == 0 else {
            throw CineARError.sceneSnapshotMismatch(
                missingFromMap: missingFromMap,
                missingFromProject: missingFromProject,
                kindMismatch: kindMismatch
            )
        }
    }

    private func entityID(from entity: Entity) -> UUID? {
        var candidate: Entity? = entity
        while let current = candidate {
            if let id = UUID(uuidString: current.name) { return id }
            candidate = current.parent
        }
        return nil
    }

    private func belongsToRoomReality(_ entity: Entity) -> Bool {
        var candidate: Entity? = entity
        while let current = candidate {
            if current.name.hasPrefix("cinear.reality.") { return true }
            candidate = current.parent
        }
        return false
    }

    private func belongsToProjectorVisualization(_ entity: Entity) -> Bool {
        var candidate: Entity? = entity
        while let current = candidate {
            if current.name.hasPrefix("cinear.projector.") { return true }
            candidate = current.parent
        }
        return false
    }

    /// Wraps every visual in a surface-contact pivot. Rotation and scale then happen
    /// around the physical contact point instead of the USDZ's often arbitrary center.
    private func makeContactPivotEntity(
        content: ModelEntity,
        for prop: PropKind
    ) -> ModelEntity {
        if content.name.hasPrefix("cinear.contact-pivot") { return content }
        let root = ModelEntity()
        root.name = "cinear.contact-pivot.\(prop.rawValue)"
        root.addChild(content)
        let bounds = root.visualBounds(
            recursive: true,
            relativeTo: root,
            excludeInactive: false
        )
        let extents = bounds.extents
        if [extents.x, extents.y, extents.z].allSatisfy({ $0.isFinite && $0 > 0.0001 }) {
            switch prop.placementSurface {
            case .floor, .horizontal:
                let minimumY = bounds.center.y - extents.y * 0.5
                content.position.y -= minimumY
            case .ceiling:
                let maximumY = bounds.center.y + extents.y * 0.5
                content.position.y -= maximumY
            case .wall:
                let minimumZ = bounds.center.z - extents.z * 0.5
                content.position.z += 0.008 - minimumZ
            }
            root.collision = CollisionComponent(
                shapes: [ShapeResource.generateBox(size: SIMD3(
                    max(extents.x, 0.04),
                    max(extents.y, 0.04),
                    max(extents.z, 0.04)
                ))]
            )
        } else if content.collision == nil {
            content.generateCollisionShapes(recursive: true)
        }
        return root
    }

    private func defaultTransform(for prop: PropKind) -> Transform {
        return Transform(
            scale: [1, 1, 1],
            rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
            translation: .zero
        )
    }

    /// Gives immediate visual confirmation while RealityKit opens a bundled or
    /// imported USDZ. It deliberately uses the catalog envelope, so it occupies the
    /// same contact plane as the final asset and remains a usable fallback if that
    /// individual file cannot be decoded on the device.
    private func makeLoadingProxy(
        for prop: PropKind,
        dimensions: SIMD3<Float>
    ) -> ModelEntity {
        let safeDimensions = SIMD3<Float>(
            max(dimensions.x, 0.04),
            max(dimensions.y, 0.04),
            max(dimensions.z, 0.04)
        )
        let mesh = MeshResource.generateBox(
            size: safeDimensions,
            cornerRadius: min(safeDimensions.x, safeDimensions.y, safeDimensions.z) * 0.06
        )
        let entity: ModelEntity
        if prop.emitsVirtualLight {
            var material = UnlitMaterial()
            material.color = .init(
                tint: UIColor(red: 1.0, green: 0.82, blue: 0.48, alpha: 1)
            )
            entity = ModelEntity(mesh: mesh, materials: [material])
        } else {
            let material = SimpleMaterial(
                color: UIColor(red: 0.28, green: 0.52, blue: 0.66, alpha: 1),
                roughness: 0.82,
                isMetallic: false
            )
            entity = ModelEntity(mesh: mesh, materials: [material])
        }
        entity.name = "cinear.loading-proxy.\(prop.rawValue)"
        entity.collision = CollisionComponent(
            shapes: [ShapeResource.generateBox(size: safeDimensions)]
        )
        return entity
    }

    private func bundledAssetURL(named assetName: String) -> URL? {
        if let url = Bundle.main.url(
            forResource: assetName,
            withExtension: "usdz",
            subdirectory: "RoomAssets"
        ) ?? Bundle.main.url(forResource: assetName, withExtension: "usdz") {
            return url
        }
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let explicitURL = resourceURL
            .appendingPathComponent("RoomAssets", isDirectory: true)
            .appendingPathComponent(assetName)
            .appendingPathExtension("usdz")
        return FileManager.default.fileExists(atPath: explicitURL.path) ? explicitURL : nil
    }

    private func makePhotorealLibraryEntity(
        content: Entity,
        prop: PropKind,
        descriptor: PhotorealPropDescriptor
    ) -> ModelEntity? {
        let measurementRoot = Entity()
        measurementRoot.addChild(content)
        let bounds = measurementRoot.visualBounds(
            recursive: true,
            relativeTo: measurementRoot,
            // The USDZ is intentionally measured before it is anchored. RealityKit
            // reports unanchored entities as inactive, so excluding inactive children
            // produces a zero-size box and forces every valid model to its proxy.
            excludeInactive: false
        )
        content.removeFromParent()
        let extents = bounds.extents
        guard [extents.x, extents.y, extents.z].allSatisfy({ $0.isFinite && $0 > 0.0001 }) else {
            return nil
        }
        let ratios = descriptor.dimensions / extents
        let scale = min(ratios.x, ratios.y, ratios.z)
        guard scale.isFinite, (0.001...1_000).contains(scale) else { return nil }

        let centered = Entity()
        centered.addChild(content)
        centered.position = -bounds.center

        let fitted = Entity()
        fitted.addChild(centered)
        fitted.scale = SIMD3(repeating: scale)

        let root = ModelEntity()
        root.name = "cinear.photoreal.\(prop.rawValue)"
        root.addChild(fitted)
        let fittedBounds = root.visualBounds(
            recursive: true,
            relativeTo: root,
            excludeInactive: false
        )
        guard [fittedBounds.extents.x, fittedBounds.extents.y, fittedBounds.extents.z]
            .allSatisfy({ $0.isFinite && $0 > 0.0001 && $0 < 12 }) else { return nil }

        // The descriptor defines the placement envelope. Align the rendered mesh
        // with the envelope's contact face so uniformly fitted assets never float.
        switch descriptor.surface {
        case .floor, .horizontal:
            fitted.position.y = (-descriptor.dimensions.y + fittedBounds.extents.y) * 0.5
        case .ceiling:
            fitted.position.y = (descriptor.dimensions.y - fittedBounds.extents.y) * 0.5
        case .wall:
            fitted.position.z = (-descriptor.dimensions.z + fittedBounds.extents.z) * 0.5
        }
        root.collision = CollisionComponent(
            shapes: [ShapeResource.generateBox(size: descriptor.dimensions)]
        )
        return root
    }

    private func makeBundledLibraryEntity(for prop: PropKind) -> ModelEntity? {
        guard let descriptor = libraryDescriptor(for: prop),
              let content = manualAssetProvider.makeEntity(
                for: descriptor.role,
                theme: RealityThemeCatalog.modern,
                targetDimensions: descriptor.dimensions
              ) else { return nil }

        let root = ModelEntity()
        root.name = "cinear.library.\(prop.rawValue)"
        root.addChild(content)
        root.collision = CollisionComponent(
            shapes: [ShapeResource.generateBox(size: descriptor.dimensions)]
        )
        return root
    }

    private func addContactShadow(to entity: ModelEntity, for prop: PropKind) {
        guard let contact = groundContactDescriptor(for: prop) else { return }
        let material = RealityMaterialRecipe(
            0.015, 0.018, 0.022,
            alpha: 0.20,
            roughness: 1
        ).makeMaterial()
        let shadow = ModelEntity(
            mesh: .generateSphere(radius: 0.5),
            materials: [material]
        )
        shadow.name = "cinear.contact-shadow"
        shadow.scale = [contact.width, 0.006, contact.depth]
        shadow.position = [0, contact.localY, 0]
        entity.addChild(shadow)
    }

    private func groundContactDescriptor(
        for prop: PropKind
    ) -> (width: Float, depth: Float, localY: Float)? {
        if let descriptor = prop.photorealDescriptor,
           descriptor.surface == .floor || descriptor.surface == .horizontal {
            return (
                descriptor.dimensions.x * 0.82,
                descriptor.dimensions.z * 0.82,
                0.004
            )
        }
        if let descriptor = libraryDescriptor(for: prop) {
            return (
                descriptor.dimensions.x * 0.82,
                descriptor.dimensions.z * 0.82,
                0.004
            )
        }
        switch prop {
        case .stage: return (1.82, 1.22, 0.004)
        case .crate: return (0.48, 0.48, 0.004)
        case .plant: return (0.31, 0.31, 0.004)
        case .floorLamp: return (0.30, 0.30, 0.004)
        case .apple: return (0.13, 0.13, 0.004)
        case .wall, .lightPanel, .rug, .custom, .chair, .table, .sofa,
             .bed, .bookcase, .television, .refrigerator, .oven, .stove,
             .sink, .bathtub, .toilet, .washerDryer, .stairs, .bloodWaterfall:
            return nil
        default:
            return nil
        }
    }

    private func libraryDescriptor(
        for prop: PropKind
    ) -> (role: RealityObjectRole, dimensions: SIMD3<Float>)? {
        switch prop {
        case .chair: (.chair, [0.58, 0.92, 0.58])
        case .table: (.table, [1.40, 0.76, 0.82])
        case .sofa: (.sofa, [2.00, 0.90, 0.88])
        case .bed: (.bed, [1.60, 0.68, 2.05])
        case .bookcase: (.storage, [1.05, 1.90, 0.38])
        case .television: (.television, [1.20, 0.76, 0.16])
        case .refrigerator: (.refrigerator, [0.76, 1.82, 0.72])
        case .oven: (.oven, [0.66, 0.92, 0.66])
        case .stove: (.stove, [0.66, 0.92, 0.66])
        case .sink: (.sink, [0.68, 0.90, 0.58])
        case .bathtub: (.bathtub, [1.72, 0.62, 0.78])
        case .toilet: (.toilet, [0.70, 0.82, 0.76])
        case .washerDryer: (.washerDryer, [0.72, 1.62, 0.72])
        case .stairs: (.stairs, [1.20, 1.20, 2.00])
        case .wall, .stage, .crate, .lightPanel, .plant, .floorLamp,
             .rug, .backdrop, .custom: nil
        default: nil
        }
    }

    private func makeBuiltInEntity(for prop: PropKind) -> ModelEntity {
        switch prop {
        case .wall:
            let mesh = MeshResource.generateBox(width: 2.4, height: 2.5, depth: 0.05)
            let material = SimpleMaterial(
                color: UIColor(red: 0.16, green: 0.24, blue: 0.31, alpha: 1),
                roughness: 0.78,
                isMetallic: false
            )
            return ModelEntity(mesh: mesh, materials: [material])

        case .stage:
            let mesh = MeshResource.generateBox(width: 2.0, height: 0.18, depth: 1.4)
            let material = SimpleMaterial(color: .darkGray, roughness: 0.62, isMetallic: false)
            return ModelEntity(mesh: mesh, materials: [material])

        case .crate:
            let mesh = MeshResource.generateBox(size: 0.55, cornerRadius: 0.025)
            let material = SimpleMaterial(
                color: UIColor(red: 0.42, green: 0.24, blue: 0.10, alpha: 1),
                roughness: 0.9,
                isMetallic: false
            )
            return ModelEntity(mesh: mesh, materials: [material])

        case .lightPanel:
            let mesh = MeshResource.generateBox(width: 0.9, height: 0.55, depth: 0.035)
            var material = UnlitMaterial()
            material.color = .init(tint: .white)
            return ModelEntity(mesh: mesh, materials: [material])

        case .plant:
            let potMaterial = SimpleMaterial(
                color: UIColor(red: 0.45, green: 0.20, blue: 0.10, alpha: 1),
                roughness: 0.88,
                isMetallic: false
            )
            let leafMaterial = SimpleMaterial(
                color: UIColor(red: 0.10, green: 0.42, blue: 0.16, alpha: 1),
                roughness: 0.82,
                isMetallic: false
            )
            let root = ModelEntity(
                mesh: .generateBox(size: [0.34, 0.36, 0.34], cornerRadius: 0.06),
                materials: [potMaterial]
            )
            let foliage = ModelEntity(mesh: .generateSphere(radius: 0.36), materials: [leafMaterial])
            foliage.position = [0, 0.48, 0]
            root.addChild(foliage)
            return root

        case .floorLamp:
            let frameMaterial = SimpleMaterial(color: .darkGray, roughness: 0.34, isMetallic: true)
            let shadeMaterial = SimpleMaterial(
                color: UIColor(red: 0.84, green: 0.77, blue: 0.63, alpha: 1),
                roughness: 0.72,
                isMetallic: false
            )
            var bulbMaterial = UnlitMaterial()
            bulbMaterial.color = .init(
                tint: UIColor(red: 1, green: 0.84, blue: 0.54, alpha: 1)
            )
            let root = ModelEntity(
                mesh: .generateBox(size: [0.32, 0.045, 0.32], cornerRadius: 0.06),
                materials: [frameMaterial]
            )
            let pole = ModelEntity(
                mesh: .generateBox(width: 0.025, height: 1.34, depth: 0.025),
                materials: [frameMaterial]
            )
            pole.position = [0, 0.69, 0]
            let lowerShade = ModelEntity(
                mesh: .generateBox(size: [0.36, 0.17, 0.36], cornerRadius: 0.085),
                materials: [shadeMaterial]
            )
            lowerShade.position = [0, 1.34, 0]
            let upperShade = ModelEntity(
                mesh: .generateBox(size: [0.28, 0.15, 0.28], cornerRadius: 0.075),
                materials: [shadeMaterial]
            )
            upperShade.position = [0, 1.48, 0]
            let bulb = ModelEntity(
                mesh: .generateSphere(radius: 0.065),
                materials: [bulbMaterial]
            )
            bulb.position = [0, 1.31, 0]
            root.addChild(pole)
            root.addChild(lowerShade)
            root.addChild(upperShade)
            root.addChild(bulb)
            return root

        case .rug:
            let material = SimpleMaterial(
                color: UIColor(red: 0.26, green: 0.43, blue: 0.52, alpha: 1),
                roughness: 0.96,
                isMetallic: false
            )
            return ModelEntity(
                mesh: .generateBox(size: [1.80, 0.012, 1.20], cornerRadius: 0.08),
                materials: [material]
            )

        case .backdrop:
            let material = SimpleMaterial(
                color: UIColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 1),
                roughness: 0.76,
                isMetallic: false
            )
            return ModelEntity(
                mesh: .generateBox(size: [2.40, 1.80, 0.045], cornerRadius: 0.025),
                materials: [material]
            )

        case .bloodWaterfall:
            return makeBloodWaterfallEntity()

        case .apple:
            return makeAppleEntity()

        case .chair, .table, .sofa, .bed, .bookcase, .television,
             .refrigerator, .oven, .stove, .sink, .bathtub, .toilet,
             .washerDryer, .stairs, .custom:
            preconditionFailure("USDZ assets are loaded through the library path")
        default:
            preconditionFailure("Photoreal USDZ assets are loaded asynchronously")
        }
    }

    private func makeAppleEntity() -> ModelEntity {
        let skin = RealityMaterialRecipe(
            0.64, 0.025, 0.018,
            roughness: 0.31,
            metallic: 0.02
        ).makeMaterial()
        let stemMaterial = RealityMaterialRecipe(
            0.18, 0.07, 0.025,
            roughness: 0.88
        ).makeMaterial()
        let leafMaterial = RealityMaterialRecipe(
            0.04, 0.28, 0.055,
            roughness: 0.68
        ).makeMaterial()

        let root = ModelEntity()
        root.name = "cinear.cgi.apple"
        let body = ModelEntity(mesh: .generateSphere(radius: 0.065), materials: [skin])
        body.scale = [1.0, 0.92, 1.0]
        body.position.y = 0.062
        let crown = ModelEntity(mesh: .generateSphere(radius: 0.046), materials: [skin])
        crown.scale = [1.08, 0.46, 1.08]
        crown.position.y = 0.105
        let stem = ModelEntity(
            mesh: .generateBox(size: [0.009, 0.046, 0.009], cornerRadius: 0.003),
            materials: [stemMaterial]
        )
        stem.position = [0.004, 0.145, 0]
        stem.orientation = simd_quatf(angle: -0.18, axis: [0, 0, 1])
        let leaf = ModelEntity(
            mesh: .generateBox(size: [0.047, 0.004, 0.021], cornerRadius: 0.008),
            materials: [leafMaterial]
        )
        leaf.position = [0.026, 0.143, 0]
        leaf.orientation = simd_quatf(angle: 0.30, axis: [0, 0, 1])
        root.addChild(body)
        root.addChild(crown)
        root.addChild(stem)
        root.addChild(leaf)
        root.collision = CollisionComponent(
            shapes: [ShapeResource.generateSphere(radius: 0.069)]
        )
        return root
    }

    private func makeBloodWaterfallEntity() -> ModelEntity {
        let root = ModelEntity()
        root.name = "cinear.cgi.blood-waterfall"
        let liquid = RealityMaterialRecipe(
            0.40, 0.006, 0.012,
            alpha: 0.82,
            roughness: 0.24,
            metallic: 0.03
        ).makeMaterial()
        let darkLiquid = RealityMaterialRecipe(
            0.16, 0.002, 0.008,
            alpha: 0.72,
            roughness: 0.32
        ).makeMaterial()

        let sheet = ModelEntity(
            mesh: .generateBox(size: [0.72, 1.48, 0.018], cornerRadius: 0.009),
            materials: [liquid]
        )
        sheet.name = "cinear.blood.sheet"
        sheet.position = [0, -0.73, 0.035]
        root.addChild(sheet)

        for index in 0..<18 {
            let radius = Float(0.017 + Double(index % 4) * 0.003)
            let drop = ModelEntity(mesh: .generateSphere(radius: radius), materials: [
                index.isMultiple(of: 3) ? darkLiquid : liquid
            ])
            drop.name = "cinear.blood.drop.\(index)"
            let lateral = (Float(index % 6) - 2.5) * 0.11
            drop.position = [lateral, -Float(index) / 18 * 1.42, 0.065 + Float(index % 3) * 0.009]
            drop.scale.y = 1.8 + Float(index % 3) * 0.35
            root.addChild(drop)
        }

        let puddle = ModelEntity(mesh: .generateSphere(radius: 0.5), materials: [darkLiquid])
        puddle.name = "cinear.blood.puddle"
        puddle.position = [0, -1.49, 0.22]
        puddle.scale = [0.86, 0.022, 0.34]
        root.addChild(puddle)
        root.collision = CollisionComponent(
            shapes: [ShapeResource.generateBox(size: [0.76, 1.54, 0.08])]
        )
        return root
    }

    private func addCoachingOverlay(to view: ARView) {
        let coaching = ARCoachingOverlayView()
        coaching.session = view.session
        coaching.goal = .anyPlane
        coaching.activatesAutomatically = true
        coaching.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(coaching)
        coachingOverlay = coaching
        NSLayoutConstraint.activate([
            coaching.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            coaching.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            coaching.topAnchor.constraint(equalTo: view.topAnchor),
            coaching.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func refreshSceneCatalogs() {
        var titleCounts: [String: Int] = [:]
        let placements = projectStore.project.placements.reversed().map { placement in
            let baseTitle: String
            if placement.kind == .custom, let fileName = placement.assetFileName {
                baseTitle = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
            } else {
                baseTitle = placement.kind.title
            }
            let occurrence = (titleCounts[baseTitle] ?? 0) + 1
            titleCounts[baseTitle] = occurrence
            let title = occurrence == 1 ? baseTitle : "\(baseTitle) \(occurrence)"
            return SceneObjectSummary(
                id: placement.id,
                title: title,
                symbol: placement.kind.symbol,
                detail: sceneObjectDetail(for: placement),
                isLiveEffect: placement.kind == .bloodWaterfall
            )
        }
        var result = Array(placements)
        if isLiveAppleEnabled {
            result.insert(
                SceneObjectSummary(
                    id: Self.liveAppleSceneID,
                    title: "Eldeki Elma",
                    symbol: "🍎",
                    detail: "Canlı CGI • Vision el takibi",
                    isLiveEffect: true
                ),
                at: 0
            )
        }
        sceneObjects = result
        savedPlaces = projectStore.savedPlaces
    }

    private func sceneObjectDetail(for placement: PlacementRecord) -> String {
        let surface: String
        switch placement.kind.placementSurface {
        case .floor: surface = "Zemin"
        case .horizontal: surface = "Yatay yüzey"
        case .wall: surface = "Duvar"
        case .ceiling: surface = "Tavan"
        }
        if placement.kind == .bloodWaterfall { return "Canlı CGI • Duvara sabit" }
        if placement.kind.emitsVirtualLight { return "Sanal ışık • \(surface)" }
        return surface
    }

    private func archiveSavedPlaceIfRequested() -> (message: String?, failed: Bool) {
        guard shouldArchiveAfterNextSave else { return (nil, false) }
        shouldArchiveAfterNextSave = false
        let name = pendingArchiveName
        pendingArchiveName = nil
        do {
            let summary = try projectStore.archiveCurrentProject(preferredName: name)
            savedPlaces = projectStore.savedPlaces
            return ("\(summary.name) Kayıtlı Mekânlar'a eklendi", false)
        } catch {
            return ("mekân arşivlenemedi: \(error.localizedDescription)", true)
        }
    }

    private func publishStatus(_ text: String, color: Color) {
        DispatchQueue.main.async { [weak self] in
            self?.statusText = text
            self?.trackingColor = color
        }
    }

    private func restoreRoomRealityIfPossible() {
        guard roomCoordinateSpaceIsActive,
              let preferredRealityThemeID,
              FileManager.default.fileExists(atPath: roomDataURL.path) else {
            roomRealityRenderer.isVisible = false
            setPhysicalSceneOcclusion(enabled: true)
            refreshPhysicalRoomOcclusionIfPossible()
            return
        }
        roomRealityRenderer.isVisible = false
        isRoomOutlineVisible = false
        setPhysicalSceneOcclusion(enabled: true)
        pendingRealityThemeAfterScan = preferredRealityThemeID
        if let trackingState = arView?.session.currentFrame?.camera.trackingState {
            _ = schedulePendingPostScanThemeIfReady(trackingState: trackingState)
        }
    }

    @discardableResult
    private func restoreRoomRealityAfterInterruptionIfReady(
        trackingState: ARCamera.TrackingState?
    ) -> Bool {
        guard shouldRestoreRoomRealityAfterInterruption else { return false }
        guard !isSessionInterrupted,
              roomCoordinateSpaceIsActive,
              let arView,
              let themeID = activeRealityThemeID ?? preferredRealityThemeID,
              FileManager.default.fileExists(atPath: roomDataURL.path) else {
            shouldRestoreRoomRealityAfterInterruption = false
            roomRealityRenderer.isVisible = false
            setPhysicalSceneOcclusion(enabled: true)
            return false
        }

        if let trackingState {
            guard case .normal = trackingState else { return false }
        }

        shouldRestoreRoomRealityAfterInterruption = false
        roomRealityRenderer.install(in: arView)
        selectRealityTheme(themeID)
        return true
    }

    private func cancelPendingPostScanTheme() {
        postScanThemeGeneration &+= 1
        pendingRealityThemeAfterScan = nil
        isPostScanThemeScheduled = false
    }

    /// RoomPlan görünümü tamamen kapandıktan ve ARKit normal takibe döndükten sonra
    /// oda geometrisini kurar. Kısa gecikme, iki ağır RealityKit/RoomPlan yaşam döngüsünün
    /// aynı ana iş parçacığı karesinde üst üste binmesini engeller.
    @discardableResult
    private func schedulePendingPostScanThemeIfReady(
        trackingState: ARCamera.TrackingState?
    ) -> Bool {
        guard let themeID = pendingRealityThemeAfterScan else { return false }
        guard let trackingState, case .normal = trackingState else { return true }
        guard !isPostScanThemeScheduled else { return true }

        isPostScanThemeScheduled = true
        postScanThemeGeneration &+= 1
        let generation = postScanThemeGeneration
        publishStatus("Oda gerçekliği hazırlanıyor...", color: .yellow)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            guard generation == self.postScanThemeGeneration,
                  self.pendingRealityThemeAfterScan == themeID else { return }
            self.isPostScanThemeScheduled = false
            guard
                  !self.isRoomScanActive,
                  !self.isSessionInterrupted,
                  let trackingState = self.arView?.session.currentFrame?.camera.trackingState,
                  case .normal = trackingState else { return }

            self.pendingRealityThemeAfterScan = nil
            if self.roomRealityRenderer.lastReport != nil,
               self.activeRealityThemeID == themeID {
                self.roomRealityRenderer.isVisible = true
                self.setPhysicalSceneOcclusion(enabled: true)
                let theme = RealityThemeCatalog.theme(withID: themeID)
                self.publishStatus("\(theme.title) oda gerçekliği yeniden hizalandı", color: .green)
                return
            }
            self.selectRealityTheme(themeID)
        }
        return true
    }

    @discardableResult
    private func refreshPhysicalRoomOcclusionIfPossible(
        allowWhileAIEnabled: Bool = false
    ) -> Bool {
        guard !isRoomScanActive,
              (!aiEnhancementEnabled || allowWhileAIEnabled),
              activeRealityThemeID == nil,
              roomCoordinateSpaceIsActive,
              let arView,
              FileManager.default.fileExists(atPath: roomDataURL.path) else {
            roomRealityRenderer.isPhysicalOcclusionVisible = false
            return false
        }

        roomRealityRenderer.install(in: arView)
        if roomRealityRenderer.hasPreparedPhysicalOcclusion {
            roomRealityRenderer.isPhysicalOcclusionVisible = true
            return true
        }
        do {
            let count = try roomRealityRenderer.preparePhysicalOcclusion(
                roomJSONURL: roomDataURL
            )
            roomRealityRenderer.isPhysicalOcclusionVisible = count > 0
            return count > 0
        } catch {
            roomRealityRenderer.isPhysicalOcclusionVisible = false
            return false
        }
    }

    private func setPhysicalSceneOcclusion(enabled: Bool) {
        guard let arView else { return }
        if enabled {
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
            arView.environment.sceneUnderstanding.options.insert(.collision)
        } else {
            arView.environment.sceneUnderstanding.options.remove(.occlusion)
            arView.environment.sceneUnderstanding.options.remove(.collision)
        }
    }
}

extension ARSessionController: @preconcurrency ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        updatePlacementGuidance(using: frame)
        updateBloodWaterfalls(timestamp: frame.timestamp)
        updateLiveAppleTracking(using: frame)
        if frame.timestamp - lastProjectorRefreshTimestamp >= 0.16 {
            lastProjectorRefreshTimestamp = frame.timestamp
            refreshProjectorLights()
        }
        submitFrameToAIIfNeeded(frame)
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        updateKnownFloor(from: anchors)
        var shouldScheduleAutomaticSave = false
        for anchor in anchors {
            guard let descriptor = PropKind.descriptor(from: anchor.name) else { continue }
            if supersededPropAnchorIDs.contains(anchor.identifier) {
                session.remove(anchor: anchor)
                continue
            }
            guard let placement = projectStore.placement(id: descriptor.id),
                  placement.kind == descriptor.kind else {
                // Never let a late relocalization callback resurrect a prop the user
                // has already deleted, or leave an orphan that poisons the next save.
                session.remove(anchor: anchor)
                continue
            }
            knownPropAnchorIDs.insert(anchor.identifier)
            managedPropAnchorsByPlacementID[descriptor.id] = anchor
            if pendingAutoSaveAnchorIDs.remove(anchor.identifier) != nil {
                shouldScheduleAutomaticSave = true
            }
            DispatchQueue.main.async { [weak self] in
                self?.render(prop: descriptor.kind, id: descriptor.id, for: anchor)
            }
        }
        if shouldScheduleAutomaticSave {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                guard let self, !self.isRoomScanActive, !self.isSessionInterrupted else { return }
                self.shouldSaveWorldMapWhenReady = true
                self.scheduleReadinessRecovery()
            }
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        updateKnownFloor(from: anchors)
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        floorSurfaceTracker.remove(anchors)
        if let cameraY = session.currentFrame?.camera.transform.columns.3.y {
            if let estimate = floorSurfaceTracker.estimate(cameraY: cameraY), estimate.isStable {
                lastKnownFloorY = estimate.y
            }
        }
        for anchor in anchors {
            guard let descriptor = PropKind.descriptor(from: anchor.name) else { continue }
            knownPropAnchorIDs.remove(anchor.identifier)
            pendingAutoSaveAnchorIDs.remove(anchor.identifier)
            if supersededPropAnchorIDs.remove(anchor.identifier) != nil {
                continue
            }
            if let placement = projectStore.placement(id: descriptor.id),
               placement.kind == descriptor.kind {
                // Keep the last known transform and the current visual alive. RoomPlan
                // and relocalization can remove an ARAnchor transiently; deleting the
                // entity here made valid props and lights vanish permanently.
                managedPropAnchorsByPlacementID[descriptor.id] = anchor
                if !isRoomScanActive, !isSessionInterrupted {
                    scheduleReadinessRecovery()
                }
                continue
            }
            managedPropAnchorsByPlacementID[descriptor.id] = nil
            detachRenderedPlacement(id: descriptor.id, clearSelection: true)
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        guard !isSessionInterrupted, !isRoomScanActive else { return }
        switch camera.trackingState {
        case .normal:
            isARReady = true
            didAttemptSessionFailureRecovery = false
            let anchorRecovery = restorePlacementAnchorsIfNeeded(
                allowCreatingMissingAnchors: false
            )
            if anchorRecovery.waitingForAnchor {
                scheduleReadinessRecovery()
                publishStatus(
                    "Sahne anchor'ları yeniden bağlanıyor; nesneler korunuyor",
                    color: .yellow
                )
                return
            }
            if savePendingWorldMapIfPossible(trackingState: camera.trackingState) {
                return
            }
            if shouldShowRoomOutlineWhenReady {
                shouldShowRoomOutlineWhenReady = false
                showRoomOutline()
                return
            }
            if schedulePendingPostScanThemeIfReady(trackingState: camera.trackingState) {
                return
            }
            if restoreRoomRealityAfterInterruptionIfReady(trackingState: camera.trackingState) {
                return
            }
            publishStatus("Takip hazır — dekor seçip yüzeye dokun", color: .green)
        case .notAvailable:
            isARReady = false
            publishStatus("Kamera takibi kullanılamıyor", color: .red)
        case .limited(let reason):
            // Limited tracking may still render an existing scene, but accepting a
            // new anchor here is the main source of visible placement drift.
            isARReady = false
            let message: String
            switch reason {
            case .initializing: message = "AR oturumu hazırlanıyor"
            case .excessiveMotion: message = "Telefonu daha yavaş hareket ettir"
            case .insufficientFeatures: message = "Daha aydınlık ve detaylı bir alana yönelt"
            case .relocalizing: message = "Kayıtlı sahne yeniden bulunuyor"
            @unknown default: message = "Takip sınırlı"
            }
            publishStatus(message, color: .yellow)
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        guard let arView, session === arView.session else {
            publishStatus("AR hatası: \(error.localizedDescription)", color: .red)
            return
        }

        isARReady = false
        guard !isRoomScanActive else {
            publishStatus(
                "Oda taraması sırasında AR durdu; taramayı kapatıp yeniden dene: "
                    + error.localizedDescription,
                color: .red
            )
            return
        }

        shouldRestoreRoomRealityAfterInterruption =
            shouldRestoreRoomRealityAfterInterruption
            || (
                roomCoordinateSpaceIsActive
                && activeRealityThemeID != nil
                && roomRealityRenderer.isVisible
            )
        shouldShowRoomOutlineWhenReady = shouldShowRoomOutlineWhenReady
            || isRoomOutlineVisible
        roomRealityRenderer.isVisible = false
        isRoomOutlineVisible = false
        setPhysicalSceneOcclusion(enabled: true)

        guard !didAttemptSessionFailureRecovery else {
            publishStatus(
                "AR yeniden başlatılamadı; uygulamayı yeniden aç: \(error.localizedDescription)",
                color: .red
            )
            return
        }

        didAttemptSessionFailureRecovery = true
        isSessionInterrupted = false
        configurationBeforeInterruption = nil
        session.delegateQueue = .main
        session.delegate = self
        session.run(session.configuration ?? configuration(), options: [])
        publishStatus(
            "AR oturumu durdu; içerikler korunarak otomatik yeniden başlatılıyor",
            color: .yellow
        )
    }

    func sessionWasInterrupted(_ session: ARSession) {
        guard !isSessionInterrupted else { return }

        readinessRecoveryGeneration &+= 1
        isARReady = false
        isSessionInterrupted = true
        configurationBeforeInterruption = session.configuration
        guard !isRoomScanActive else {
            publishStatus(
                "Oda taraması kesildi; taramayı kapatıp yeniden dene",
                color: .yellow
            )
            return
        }

        shouldRestoreRoomRealityAfterInterruption =
            roomCoordinateSpaceIsActive
            && activeRealityThemeID != nil
            && roomRealityRenderer.isVisible
        shouldShowRoomOutlineWhenReady = shouldShowRoomOutlineWhenReady
            || isRoomOutlineVisible
        roomRealityRenderer.isVisible = false
        isRoomOutlineVisible = false
        setPhysicalSceneOcclusion(enabled: true)
        publishStatus("AR oturumu kesildi — aynı alanda kalın", color: .yellow)
    }

    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        // Preserve both the scanned-room coordinate space and manually placed anchors.
        true
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        guard isSessionInterrupted else { return }

        isSessionInterrupted = false
        guard let arView, session === arView.session else {
            configurationBeforeInterruption = nil
            shouldRestoreRoomRealityAfterInterruption = false
            publishStatus("AR oturumu yeniden bağlanamadı", color: .red)
            return
        }

        if isRoomScanActive {
            configurationBeforeInterruption = nil
            publishStatus(
                "Oda taraması kesildi; taramayı kapatıp yeniden dene",
                color: .yellow
            )
            return
        }

        session.delegateQueue = .main
        session.delegate = self
        let resumeConfiguration = configurationBeforeInterruption
            ?? session.configuration
            ?? configuration()
        configurationBeforeInterruption = nil
        session.run(resumeConfiguration, options: [])
        scheduleReadinessRecovery()

        if pendingRealityThemeAfterScan != nil {
            _ = schedulePendingPostScanThemeIfReady(
                trackingState: session.currentFrame?.camera.trackingState
            )
            publishStatus("AR oturumu sürdürülüyor — oda gerçekliği yeniden hizalanıyor", color: .yellow)
            return
        }

        if shouldRestoreRoomRealityAfterInterruption {
            if !restoreRoomRealityAfterInterruptionIfReady(
                trackingState: session.currentFrame?.camera.trackingState
            ) {
                publishStatus(
                    "AR oturumu sürdürülüyor — oda yeniden hizalanıyor",
                    color: .yellow
                )
            }
        } else {
            setPhysicalSceneOcclusion(enabled: true)
            publishStatus("AR oturumu sürdürüldü", color: .yellow)
        }
    }
}

extension ARSessionController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // The placement/selection tap must not disable RealityKit's translation,
        // rotation and scale recognizers installed on manual props.
        true
    }
}

private struct SceneDepthSurfaceSample {
    let worldPoint: SIMD3<Float>
    let worldNormal: SIMD3<Float>?
    let depthMeters: Float
}

private struct BloodWaterfallParticle {
    let entity: ModelEntity
    let phase: Float
    let lateral: Float
    let depth: Float
}

private struct ProjectorSurfaceHit {
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
    let distanceMeters: Float
}

private struct PlacementSurfaceSolution {
    let transform: simd_float4x4
    let position: SIMD3<Float>
    let normal: SIMD3<Float>
    let source: PlacementSurfaceSource
    let depthMeters: Float?
}

private enum PlacementSurfaceSource: Equatable {
    case classifiedFloorPlane
    case classifiedFloorMesh
    case lidarMesh
    case arkitPlane
    case roomPlanGeometry
    case roomPlanLevel

    var title: String {
        switch self {
        case .classifiedFloorPlane: "ARKit zemin"
        case .classifiedFloorMesh: "LiDAR zemin"
        case .lidarMesh: "LiDAR yüzey"
        case .arkitPlane: "ARKit yüzey"
        case .roomPlanGeometry: "RoomPlan yüzey"
        case .roomPlanLevel: "RoomPlan kotu"
        }
    }
}

private struct FloorSurfaceEstimate {
    let y: Float
    let isStable: Bool
    let source: PlacementSurfaceSource
}

/// Maintains a metric floor level from classified AR planes, classified LiDAR mesh
/// faces and a completed RoomPlan scan. Unclassified horizontal planes are never
/// admitted: they are commonly desks, shelves or seats.
private final class FloorSurfaceTracker {
    private var roomFloorY: Float?
    private var classifiedPlaneLevels: [UUID: Float] = [:]
    private var classifiedMeshLevels: [UUID: Float] = [:]
    private var liveHistory: [Float] = []
    private var latestLiveSource: PlacementSurfaceSource = .classifiedFloorMesh

    func reset() {
        roomFloorY = nil
        classifiedPlaneLevels.removeAll()
        classifiedMeshLevels.removeAll()
        liveHistory.removeAll()
        latestLiveSource = .classifiedFloorMesh
    }

    func setRoomFloor(_ y: Float) {
        guard y.isFinite else { return }
        roomFloorY = y
    }

    func clearRoomFloor() {
        roomFloorY = nil
    }

    func remove(_ anchors: [ARAnchor]) {
        for anchor in anchors {
            classifiedPlaneLevels[anchor.identifier] = nil
            classifiedMeshLevels[anchor.identifier] = nil
        }
    }

    func update(with anchors: [ARAnchor], cameraY: Float) {
        guard cameraY.isFinite else { return }
        for anchor in anchors {
            if let plane = anchor as? ARPlaneAnchor {
                if plane.alignment == .horizontal,
                   plane.classification == .floor,
                   plane.transform.columns.3.y.isFinite {
                    classifiedPlaneLevels[plane.identifier] = plane.transform.columns.3.y
                } else {
                    classifiedPlaneLevels[plane.identifier] = nil
                }
            } else if let mesh = anchor as? ARMeshAnchor {
                if let level = Self.classifiedFloorLevel(in: mesh), level.isFinite {
                    classifiedMeshLevels[mesh.identifier] = level
                } else {
                    classifiedMeshLevels[mesh.identifier] = nil
                }
            }
        }

        let expectedFloor = cameraY - 1.35
        let planeCandidates = classifiedPlaneLevels.values.filter {
            $0 < cameraY - 0.30 && $0 > cameraY - 3.2
        }
        let meshCandidates = classifiedMeshLevels.values.filter {
            $0 < cameraY - 0.30 && $0 > cameraY - 3.2
        }
        let candidates: [Float]
        if !planeCandidates.isEmpty {
            candidates = planeCandidates
            latestLiveSource = .classifiedFloorPlane
        } else {
            candidates = meshCandidates
            latestLiveSource = .classifiedFloorMesh
        }
        guard let candidate = candidates.min(by: {
            abs($0 - expectedFloor) < abs($1 - expectedFloor)
        }) else { return }

        if let last = liveHistory.last, abs(last - candidate) > 0.18 {
            liveHistory.removeAll()
        }
        liveHistory.append(candidate)
        if liveHistory.count > 24 {
            liveHistory.removeFirst(liveHistory.count - 24)
        }
    }

    func estimate(cameraY: Float) -> FloorSurfaceEstimate? {
        let liveMedian = Self.median(liveHistory)
        let liveSpread: Float
        if let liveMedian {
            liveSpread = Self.median(liveHistory.map { abs($0 - liveMedian) }) ?? .greatestFiniteMagnitude
        } else {
            liveSpread = .greatestFiniteMagnitude
        }
        let minimumHistory = latestLiveSource == .classifiedFloorPlane ? 2 : 4
        let liveIsStable = liveHistory.count >= minimumHistory && liveSpread <= 0.035

        if let liveMedian, liveIsStable {
            if let roomFloorY, abs(roomFloorY - liveMedian) <= 0.08 {
                return FloorSurfaceEstimate(
                    y: (roomFloorY + liveMedian * 2) / 3,
                    isStable: true,
                    source: latestLiveSource
                )
            }
            return FloorSurfaceEstimate(
                y: liveMedian,
                isStable: true,
                source: latestLiveSource
            )
        }
        if let roomFloorY,
           roomFloorY < cameraY - 0.25,
           roomFloorY > cameraY - 3.2 {
            return FloorSurfaceEstimate(
                y: roomFloorY,
                isStable: true,
                source: .roomPlanLevel
            )
        }
        if let liveMedian {
            return FloorSurfaceEstimate(
                y: liveMedian,
                isStable: false,
                source: latestLiveSource
            )
        }
        return nil
    }

    private static func classifiedFloorLevel(in anchor: ARMeshAnchor) -> Float? {
        let geometry = anchor.geometry
        guard geometry.faces.count > 0 else { return nil }
        let maximumSamples = 240
        let step = max(1, geometry.faces.count / maximumSamples)
        var levels: [Float] = []
        levels.reserveCapacity(min(geometry.faces.count, maximumSamples))

        for faceIndex in stride(from: 0, to: geometry.faces.count, by: step) {
            guard classification(of: faceIndex, in: geometry) == .floor else { continue }
            let indices = vertexIndices(of: faceIndex, in: geometry)
            guard indices.count == 3 else { continue }
            let vertices = indices.map { vertex(at: $0, in: geometry) }
            let localCenter = (vertices[0] + vertices[1] + vertices[2]) / 3
            let worldCenter = anchor.transform * SIMD4(localCenter.x, localCenter.y, localCenter.z, 1)
            if worldCenter.y.isFinite { levels.append(worldCenter.y) }
        }
        guard levels.count >= 3 else { return nil }
        return median(levels)
    }

    private static func classification(
        of faceIndex: Int,
        in geometry: ARMeshGeometry
    ) -> ARMeshClassification {
        guard let source = geometry.classification,
              faceIndex >= 0, faceIndex < source.count else { return .none }
        let address = source.buffer.contents().advanced(
            by: source.offset + faceIndex * source.stride
        )
        let raw = Int(address.assumingMemoryBound(to: UInt8.self).pointee)
        return ARMeshClassification(rawValue: raw) ?? .none
    }

    private static func vertexIndices(of faceIndex: Int, in geometry: ARMeshGeometry) -> [Int] {
        let faces = geometry.faces
        let start = faceIndex * faces.indexCountPerPrimitive
        return (0..<faces.indexCountPerPrimitive).map { offset in
            let address = faces.buffer.contents().advanced(
                by: (start + offset) * faces.bytesPerIndex
            )
            if faces.bytesPerIndex == MemoryLayout<UInt16>.size {
                return Int(address.assumingMemoryBound(to: UInt16.self).pointee)
            }
            return Int(address.assumingMemoryBound(to: UInt32.self).pointee)
        }
    }

    private static func vertex(at index: Int, in geometry: ARMeshGeometry) -> SIMD3<Float> {
        let vertices = geometry.vertices
        let address = vertices.buffer.contents().advanced(
            by: vertices.offset + index * vertices.stride
        )
        let values = address.assumingMemoryBound(to: Float.self)
        return SIMD3(values[0], values[1], values[2])
    }

    private static func median(_ values: [Float]) -> Float? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        if sorted.count.isMultiple(of: 2) {
            return (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) * 0.5
        }
        return sorted[sorted.count / 2]
    }
}

private enum CineARError: LocalizedError {
    case worldMapUnavailable
    case duplicatePropAnchor(UUID)
    case sceneSnapshotMismatch(
        missingFromMap: Int,
        missingFromProject: Int,
        kindMismatch: Int
    )

    var errorDescription: String? {
        switch self {
        case .worldMapUnavailable:
            "Dünya haritası henüz hazır değil"
        case .duplicatePropAnchor(let id):
            "Dünya haritasında yinelenen dekor anchor'ı var: \(id.uuidString)"
        case .sceneSnapshotMismatch(
            let missingFromMap,
            let missingFromProject,
            let kindMismatch
        ):
            "worldmap/scene.json eşleşmiyor (haritada eksik: \(missingFromMap), "
                + "projede eksik: \(missingFromProject), tür farkı: \(kindMismatch))"
        }
    }
}
````

## `CineAR/ARViewContainer.swift`

````swift
import SwiftUI
import RealityKit

struct ARViewContainer: UIViewRepresentable {
    let controller: ARSessionController

    func makeUIView(context: Context) -> ARView {
        controller.makeARView()
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

````

## `CineAR/Assets.xcassets/AccentColor.colorset/Contents.json`

````json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.980",
          "green" : "0.529",
          "red" : "0.149"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

````

## `CineAR/Assets.xcassets/AppIcon.appiconset/Contents.json`

````json
{
  "images" : [
    {
      "filename" : "CineAR-AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
````

## `CineAR/Assets.xcassets/Contents.json`

````json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}

````

## `CineAR/BundledRoomRealityAssetProvider.swift`

````swift
import Foundation
import RealityKit

/// `RoomAssets` klasorundeki hazir USDZ modellerini RoomPlan rollerine baglar.
///
/// Provider bir varligi ilk kullanimda senkron olarak yukler ve prototipi bellekte
/// tutar. Her oda nesnesi icin prototipin recursive klonu uretilir; boyut ya da
/// dosya dogrulamasi basarisiz olursa renderer kendi prosedurel modeline doner.
@MainActor
final class BundledRoomRealityAssetProvider: RoomRealityAssetProviding {
    private struct Prototype {
        let entity: Entity
        let center: SIMD3<Float>
        let extents: SIMD3<Float>
    }

    private let bundle: Bundle
    private var prototypes: [String: Prototype] = [:]
    private var unavailableAssetNames = Set<String>()

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func makeEntity(
        for role: RealityObjectRole,
        theme: RealityTheme,
        targetDimensions: SIMD3<Float>
    ) -> Entity? {
        guard Self.isValidTargetDimensions(targetDimensions) else { return nil }
        guard let assetName = Self.assetName(for: role),
              let prototype = prototype(named: assetName) else {
            return makeFallbackEntity(for: role, theme: theme, size: targetDimensions)
        }

        let scale = targetDimensions / prototype.extents
        guard Self.isValidFitScale(scale) else {
            return makeFallbackEntity(for: role, theme: theme, size: targetDimensions)
        }

        let clone = prototype.entity.clone(recursive: true)
        clone.name = "cinear.roomAsset.model.\(assetName)"
        applyThemeMaterials(to: clone, role: role, theme: theme)

        // Ayrik bir kok, merkezleme ile non-uniform olcegi birbirinden ayirir.
        // Boylece prototipin kendi rotasyonu ve cocuk hiyerarsisi korunur.
        let centeredRoot = Entity()
        centeredRoot.name = "cinear.roomAsset.centered.\(assetName)"
        centeredRoot.addChild(clone)
        centeredRoot.position = -prototype.center

        let fittedRoot = Entity()
        fittedRoot.name = "cinear.roomAsset.fitted.\(assetName)"
        fittedRoot.addChild(centeredRoot)
        fittedRoot.scale = scale

        let result = Entity()
        result.name = "cinear.roomAsset.\(assetName)"
        result.addChild(fittedRoot)

        // USDZ hiyerarsisindeki beklenmeyen transformlarin bozuk/sonsuz bir
        // sahneye sizmasini engelle; tam uyum saglanmiyorsa prosedurel fallback.
        let fittedBounds = result.visualBounds(
            recursive: true,
            relativeTo: result,
            excludeInactive: false
        )
        guard Self.isValidBounds(fittedBounds) else {
            return makeFallbackEntity(for: role, theme: theme, size: targetDimensions)
        }

        return result
    }

    /// Loads a catalog model without replacing its authored PBR materials.
    /// A uniform fit preserves the real object's proportions while keeping its
    /// largest dimension inside the verified metre-sized mobile AR envelope.
    func makePhotorealEntity(
        assetName: String,
        maximumDimensions: SIMD3<Float>
    ) -> Entity? {
        guard Self.isValidTargetDimensions(maximumDimensions),
              let prototype = prototype(named: assetName) else { return nil }

        let ratios = maximumDimensions / prototype.extents
        let uniformScale = min(ratios.x, ratios.y, ratios.z)
        guard uniformScale.isFinite,
              uniformScale >= Self.minimumFitScale,
              uniformScale <= Self.maximumFitScale else { return nil }

        let clone = prototype.entity.clone(recursive: true)
        clone.name = "cinear.photoreal.model.\(assetName)"

        let centeredRoot = Entity()
        centeredRoot.name = "cinear.photoreal.centered.\(assetName)"
        centeredRoot.addChild(clone)
        centeredRoot.position = -prototype.center

        let fittedRoot = Entity()
        fittedRoot.name = "cinear.photoreal.fitted.\(assetName)"
        fittedRoot.addChild(centeredRoot)
        fittedRoot.scale = SIMD3(repeating: uniformScale)

        let result = Entity()
        result.name = "cinear.photoreal.\(assetName)"
        result.addChild(fittedRoot)
        let bounds = result.visualBounds(
            recursive: true,
            relativeTo: result,
            excludeInactive: false
        )
        return Self.isValidBounds(bounds) ? result : nil
    }
}

private extension BundledRoomRealityAssetProvider {
    static let minimumDimension: Float = 0.02
    static let maximumDimension: Float = 30
    static let minimumAssetExtent: Float = 0.0001
    static let maximumAssetExtent: Float = 10_000
    static let minimumFitScale: Float = 0.005
    static let maximumFitScale: Float = 200

    private func prototype(named assetName: String) -> Prototype? {
        if let cached = prototypes[assetName] { return cached }
        guard !unavailableAssetNames.contains(assetName),
              let url = assetURL(named: assetName) else {
            unavailableAssetNames.insert(assetName)
            return nil
        }

        do {
            let entity = try Entity.load(contentsOf: url)
            let measurementRoot = Entity()
            measurementRoot.addChild(entity)
            let bounds = measurementRoot.visualBounds(
                recursive: true,
                relativeTo: measurementRoot,
                excludeInactive: false
            )
            entity.removeFromParent()

            guard Self.isValidBounds(bounds) else {
                unavailableAssetNames.insert(assetName)
                return nil
            }

            let prototype = Prototype(
                entity: entity,
                center: bounds.center,
                extents: bounds.extents
            )
            prototypes[assetName] = prototype
            return prototype
        } catch {
            unavailableAssetNames.insert(assetName)
            return nil
        }
    }

    func assetURL(named assetName: String) -> URL? {
        // Blue-folder reference dizin yapisini bundle icinde korur. Kok aramasi,
        // klasor ileride normal bir Xcode grubuna cevrilirse de uyumluluk saglar.
        if let bundledURL = bundle.url(
            forResource: assetName,
            withExtension: "usdz",
            subdirectory: "RoomAssets"
        ) ?? bundle.url(forResource: assetName, withExtension: "usdz") {
            return bundledURL
        }

        guard let resourceURL = bundle.resourceURL else { return nil }
        let explicitURL = resourceURL
            .appendingPathComponent("RoomAssets", isDirectory: true)
            .appendingPathComponent(assetName)
            .appendingPathExtension("usdz")
        return FileManager.default.fileExists(atPath: explicitURL.path) ? explicitURL : nil
    }

    func makeFallbackEntity(
        for role: RealityObjectRole,
        theme: RealityTheme,
        size: SIMD3<Float>
    ) -> Entity {
        let root = Entity()
        root.name = "cinear.roomAsset.fallback.\(String(describing: role))"
        let recipes = theme.objectRecipes(for: role)
        let primary = recipes.primary.makeMaterial()
        let secondary = recipes.secondary.makeMaterial()
        let detail = recipes.detail.makeMaterial()

        switch role {
        case .table:
            let topHeight = max(size.y * 0.10, 0.04)
            addBox(to: root, size: [size.x, topHeight, size.z], position: [0, size.y * 0.45, 0], material: primary)
            let leg = max(min(size.x, size.z) * 0.08, 0.035)
            for x in [-size.x * 0.40, size.x * 0.40] {
                for z in [-size.z * 0.38, size.z * 0.38] {
                    addBox(to: root, size: [leg, size.y * 0.88, leg], position: [x, -size.y * 0.06, z], material: detail)
                }
            }
        case .chair:
            addBox(to: root, size: [size.x * 0.88, size.y * 0.12, size.z * 0.82], position: [0, -size.y * 0.04, 0], material: primary)
            addBox(to: root, size: [size.x * 0.88, size.y * 0.48, size.z * 0.10], position: [0, size.y * 0.26, -size.z * 0.36], material: primary)
            let leg = max(min(size.x, size.z) * 0.09, 0.025)
            for x in [-size.x * 0.34, size.x * 0.34] {
                for z in [-size.z * 0.30, size.z * 0.30] {
                    addBox(to: root, size: [leg, size.y * 0.44, leg], position: [x, -size.y * 0.28, z], material: detail)
                }
            }
        case .sofa:
            addBox(to: root, size: [size.x, size.y * 0.42, size.z * 0.88], position: [0, -size.y * 0.25, 0], material: primary)
            addBox(to: root, size: [size.x * 0.88, size.y * 0.58, size.z * 0.18], position: [0, size.y * 0.18, -size.z * 0.38], material: secondary)
            for x in [-size.x * 0.46, size.x * 0.46] {
                addBox(to: root, size: [size.x * 0.08, size.y * 0.62, size.z * 0.82], position: [x, -size.y * 0.10, 0], material: primary)
            }
        case .bed:
            addBox(to: root, size: [size.x, size.y * 0.28, size.z], position: [0, -size.y * 0.26, 0], material: detail)
            addBox(to: root, size: [size.x * 0.94, size.y * 0.30, size.z * 0.92], position: [0, size.y * 0.02, size.z * 0.02], material: secondary)
            addBox(to: root, size: [size.x, size.y * 0.82, size.z * 0.10], position: [0, size.y * 0.08, -size.z * 0.45], material: primary)
        case .storage:
            addBox(to: root, size: size, position: .zero, material: primary)
            for y in [-size.y * 0.25, 0, size.y * 0.25] {
                addBox(to: root, size: [size.x * 0.90, max(size.y * 0.025, 0.025), size.z * 0.12], position: [0, y, size.z * 0.46], material: secondary)
            }
        case .television:
            addBox(to: root, size: [size.x, size.y * 0.82, size.z * 0.32], position: [0, size.y * 0.08, 0], material: detail)
            addBox(to: root, size: [size.x * 0.92, size.y * 0.70, size.z * 0.08], position: [0, size.y * 0.08, size.z * 0.18], material: secondary)
            addBox(to: root, size: [size.x * 0.32, size.y * 0.14, size.z], position: [0, -size.y * 0.43, 0], material: primary)
        case .refrigerator, .dishwasher, .oven, .stove, .washerDryer:
            addBox(to: root, size: size, position: .zero, material: primary)
            addBox(to: root, size: [size.x * 0.88, size.y * 0.72, max(size.z * 0.025, 0.02)], position: [0, -size.y * 0.04, size.z * 0.51], material: secondary)
            addBox(to: root, size: [size.x * 0.65, max(size.y * 0.05, 0.025), max(size.z * 0.035, 0.025)], position: [0, size.y * 0.37, size.z * 0.53], material: detail)
        case .bathtub:
            addBox(to: root, size: [size.x, size.y * 0.52, size.z], position: [0, -size.y * 0.24, 0], material: primary)
            addBox(to: root, size: [size.x * 0.82, size.y * 0.20, size.z * 0.68], position: [0, size.y * 0.04, 0], material: secondary)
        case .sink:
            addBox(to: root, size: [size.x, size.y * 0.30, size.z], position: [0, size.y * 0.30, 0], material: secondary)
            addBox(to: root, size: [size.x * 0.42, size.y * 0.68, size.z * 0.42], position: [0, -size.y * 0.16, 0], material: primary)
        case .toilet:
            addBox(to: root, size: [size.x, size.y * 0.36, size.z * 0.75], position: [0, -size.y * 0.22, size.z * 0.10], material: secondary)
            addBox(to: root, size: [size.x * 0.82, size.y * 0.58, size.z * 0.30], position: [0, size.y * 0.20, -size.z * 0.32], material: primary)
        case .stairs:
            let steps = 6
            for index in 0..<steps {
                let fraction = Float(index + 1) / Float(steps)
                addBox(
                    to: root,
                    size: [size.x, size.y * fraction, size.z / Float(steps)],
                    position: [0, -size.y * 0.5 + size.y * fraction * 0.5, -size.z * 0.5 + size.z * (Float(index) + 0.5) / Float(steps)],
                    material: primary
                )
            }
        case .fireplace, .unknown:
            addBox(to: root, size: size, position: .zero, material: primary)
        }
        return root
    }

    func addBox(
        to parent: Entity,
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        material: PhysicallyBasedMaterial
    ) {
        let safeSize = SIMD3<Float>(
            max(size.x, 0.01),
            max(size.y, 0.01),
            max(size.z, 0.01)
        )
        let entity = ModelEntity(
            mesh: .generateBox(size: safeSize, cornerRadius: min(safeSize.x, safeSize.z) * 0.025),
            materials: [material]
        )
        entity.position = position
        parent.addChild(entity)
    }

    func applyThemeMaterials(
        to entity: Entity,
        role: RealityObjectRole,
        theme: RealityTheme
    ) {
        let recipes = theme.objectRecipes(for: role)
        let palette: [PhysicallyBasedMaterial] = [
            recipes.primary.makeMaterial(),
            recipes.secondary.makeMaterial(),
            recipes.detail.makeMaterial()
        ]
        applyThemeMaterialsRecursively(to: entity, palette: palette)
    }

    func applyThemeMaterialsRecursively(
        to entity: Entity,
        palette: [PhysicallyBasedMaterial]
    ) {
        if var model = entity.components[ModelComponent.self],
           !model.materials.isEmpty {
            model.materials = model.materials.indices.map { palette[$0 % palette.count] }
            entity.components.set(model)
        }
        for child in entity.children {
            applyThemeMaterialsRecursively(to: child, palette: palette)
        }
    }

    static func assetName(for role: RealityObjectRole) -> String? {
        switch role {
        case .bathtub: "bathtub"
        case .bed: "bedDouble"
        case .chair: "chairModernCushion"
        case .oven: "kitchenStove"
        case .refrigerator: "kitchenFridge"
        case .sink: "bathroomSink"
        case .sofa: "loungeDesignSofa"
        case .stairs: "stairs"
        case .storage: "bookcaseClosedWide"
        case .stove: "kitchenStoveElectric"
        case .table: "table"
        case .television: "televisionModern"
        case .toilet: "toilet"
        case .washerDryer: "washerDryerStacked"
        case .dishwasher, .fireplace, .unknown: nil
        }
    }

    static func isValidTargetDimensions(_ value: SIMD3<Float>) -> Bool {
        components(of: value).allSatisfy {
            $0.isFinite && $0 >= minimumDimension && $0 <= maximumDimension
        }
    }

    static func isValidBounds(_ bounds: BoundingBox) -> Bool {
        components(of: bounds.center).allSatisfy { $0.isFinite }
            && components(of: bounds.extents).allSatisfy {
                $0.isFinite && $0 >= minimumAssetExtent && $0 <= maximumAssetExtent
            }
    }

    static func isValidFitScale(_ value: SIMD3<Float>) -> Bool {
        components(of: value).allSatisfy {
            $0.isFinite && $0 >= minimumFitScale && $0 <= maximumFitScale
        }
    }

    static func approximatelyEqual(
        _ lhs: SIMD3<Float>,
        _ rhs: SIMD3<Float>
    ) -> Bool {
        zip(components(of: lhs), components(of: rhs)).allSatisfy { left, right in
            let tolerance = max(0.001, max(abs(left), abs(right)) * 0.005)
            return abs(left - right) <= tolerance
        }
    }

    static func components(of value: SIMD3<Float>) -> [Float] {
        [value.x, value.y, value.z]
    }
}
````

## `CineAR/CineARApp.swift`

````swift
import SwiftUI

@main
struct CineARApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

````

## `CineAR/ContentView.swift`

````swift
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var session = ARSessionController()
    @State private var showingRoomScanner = false
    @State private var showingAssetImporter = false
    @State private var showingPropLibrary = false
    @State private var showingAISettings = false
    @State private var showingSceneContents = false
    @State private var showingSavedPlaces = false
    @State private var showingCGIStudio = false
    @State private var roomScanResult: RoomScanResult?
    @State private var controlsExpanded = false
    @State private var sceneObjectPendingDeletion: SceneObjectSummary?
    @State private var savedPlacePendingDeletion: SavedPlaceSummary?
    @State private var newSavedPlaceName = ""

    var body: some View {
        ZStack {
            ARViewContainer(controller: session)
                .ignoresSafeArea()

            if session.isPlacingProp,
               !session.isRecording,
               !session.isRecordingTransitioning {
                placementReticle
            }

            if session.isRecording || session.isRecordingTransitioning {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture(count: 2) {
                        if session.isRecording {
                            session.stopRecording()
                        }
                    }
                    .accessibilityLabel("Kaydı bitirmek için iki kez dokun")
            } else {
                VStack(spacing: 12) {
                    statusBar
                    Spacer()
                    if session.isPlacingProp {
                        placementBar
                    } else {
                        if session.selectedLightSettings != nil {
                            lightControls
                        }
                        if controlsExpanded {
                            controls
                        } else {
                            compactControls
                        }
                    }
                }
                .padding()
            }
        }
        .statusBarHidden(session.isRecording || session.isRecordingTransitioning)
        .onChange(of: session.isPlacingProp) { oldValue, newValue in
            if oldValue, !newValue {
                controlsExpanded = false
            }
        }
        .fullScreenCover(isPresented: $showingRoomScanner, onDismiss: {
            session.resumeAfterRoomScan(result: roomScanResult)
            roomScanResult = nil
        }) {
            RoomScannerScreen(
                exportURL: session.roomModelURL,
                roomJSONURL: session.roomDataURL,
                arSession: session.sharedARSession
            ) { result in
                roomScanResult = result
            }
        }
        .fileImporter(
            isPresented: $showingAssetImporter,
            allowedContentTypes: [UTType(filenameExtension: "usdz") ?? .data]
        ) { result in
            switch result {
            case .success(let url):
                session.importUSDZ(from: url)
            case .failure(let error):
                session.reportAssetImportFailure(error)
            }
        }
        .sheet(isPresented: $showingPropLibrary) {
            propLibrary
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingAISettings) {
            aiSettings
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingSceneContents) {
            sceneContents
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingSavedPlaces) {
            savedPlacesLibrary
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingCGIStudio) {
            liveCGIStudio
                .presentationDetents([.medium, .large])
        }
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(session.trackingColor)
                .frame(width: 10, height: 10)
            Text(session.statusText)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
            Spacer()
        }
        .padding(12)
        .background(.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 14))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            roomRealityControls

            Text("Nesne seçildiğinde panel kapanır; yeşil takipte algılanmış zemine dokun")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PropKind.quickCases) { prop in
                        Button {
                            session.selectProp(prop)
                        } label: {
                            VStack(spacing: 4) {
                                Text(prop.symbol).font(.title2)
                                Text(prop.title).font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(session.selectedProp == prop ? Color.white : Color.primary)
                            .frame(width: 70, height: 54)
                            .background(
                                session.selectedProp == prop
                                    ? Color.accentColor.opacity(0.85)
                                    : Color.white.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        }
                    }
                }
            }

            Button {
                showingPropLibrary = true
            } label: {
                Label(
                    "Hazır 3B Nesne Kütüphanesi (\(PropKind.furnitureCases.count) parça)",
                    systemImage: "square.grid.3x3.fill"
                )
                .foregroundStyle(.white)
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
            }

            if !session.importedAssetURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(session.importedAssetURLs, id: \.self) { url in
                            Button {
                                session.selectImportedAsset(url)
                            } label: {
                                Label(
                                    url.deletingPathExtension().lastPathComponent,
                                    systemImage: "cube.transparent"
                                )
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    session.selectedAssetURL == url
                                        ? Color.accentColor.opacity(0.85)
                                        : Color.white.opacity(0.1),
                                    in: Capsule()
                                )
                            }
                        }
                    }
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                utilityButton(session.hasScannedRoom ? "Yeniden Tara" : "Oda Tara", "viewfinder") {
                    beginRoomScan()
                }
                .disabled(!RoomScannerController.isSupported || !session.isARReady)

                utilityButton("USDZ Ekle", "cube.transparent.fill") {
                    showingAssetImporter = true
                }

                utilityButton("Kaydet", "square.and.arrow.down") {
                    session.saveWorldMap()
                }
                utilityButton("Yükle", "arrow.clockwise.icloud") {
                    session.loadWorldMap()
                }
                utilityButton("Sahne Listesi", "list.bullet.rectangle") {
                    showingSceneContents = true
                }
                utilityButton("Mekânlar", "square.stack.3d.up.fill") {
                    showingSavedPlaces = true
                }
                utilityButton("Seçileni Sil", "trash") {
                    session.removeSelectedProp()
                }
                utilityButton("Tümünü Sil", "trash.slash") {
                    session.removeAllProps()
                }
                utilityButton("HEVC Çekim", "record.circle") {
                    session.startRecording()
                }
                utilityButton("AI Derinlik", "cpu.fill") {
                    showingAISettings = true
                    session.testAIServerConnection()
                }
                utilityButton("Sahne Işığı", "lightbulb.max.fill") {
                    session.showSceneLightControls()
                }
                utilityButton("Canlı CGI", "wand.and.stars") {
                    showingCGIStudio = true
                }

                if let url = session.lastRecordingURL {
                    ShareLink(item: url) {
                        utilityLabel("Çekimi Paylaş", "square.and.arrow.up")
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var roomRealityControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Oda Gerçekliği", systemImage: "viewfinder.circle.fill")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text(session.hasScannedRoom ? "Tarama hazır" : "Tarama gerekli")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(session.hasScannedRoom ? .green : .secondary)
                Button {
                    controlsExpanded = false
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.title3)
                }
                .accessibilityLabel("Kontrolleri küçült")
            }

            HStack(spacing: 8) {
                roomModeButton(
                    title: "Gerçek",
                    icon: "camera.fill",
                    isSelected: !session.isRoomOutlineVisible
                ) {
                    session.showOriginalReality()
                }

                roomModeButton(
                    title: "Beyaz Hatlar",
                    icon: "square.dashed.inset.filled",
                    isSelected: session.isRoomOutlineVisible
                ) {
                    session.showRoomOutline()
                }
                .disabled(!session.hasScannedRoom)
            }

            Text("Tarama sırasında ve Beyaz Hatlar modunda kamera kapanmaz; katı duvar çizilmez")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var aiSettings: some View {
        NavigationStack {
            Form {
                Section("SAM 2 + Depth Anything") {
                    Toggle(
                        "PC destekli AI occlusion",
                        isOn: Binding(
                            get: { session.aiEnhancementEnabled },
                            set: { session.setAIEnhancementEnabled($0) }
                        )
                    )

                    TextField(
                        "PC adresini buraya yaz",
                        text: Binding(
                            get: { session.aiServerAddress },
                            set: { session.setAIServerAddress($0) }
                        )
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                    Text("Etkin adres: \(session.aiServerAddress)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    LabeledContent("Durum") {
                        Text(session.aiEnhancementStatus.title)
                            .foregroundStyle(aiStatusColor)
                            .multilineTextAlignment(.trailing)
                    }

                    Button("PC bağlantısını test et") {
                        session.testAIServerConnection()
                    }
                    .disabled(AIEnhancementClient.serverURL(from: session.aiServerAddress) == nil)

                    Button("iPhone Yerel Ağ ayarını aç") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                }

                Section("Çalışma şekli") {
                    LabeledContent("Uygulama sürümü", value: appVersionText)

                    Text(
                        "iPhone kamera ve LiDAR derinliğini aynı Wi-Fi'daki PC'ye yollar. "
                            + "Depth Anything boşlukları tamamlar; SAM 2 nesne sınırlarını ayırır. "
                            + "Sonuç yalnız sanal nesnelerin gerçek insan ve mobilyaların arkasında "
                            + "doğru kesilmesi için görünmez derinlik ağı olarak kullanılır."
                    )
                    .font(.footnote)

                    Text("PC servisi kapalıysa ARKit'in yerel LiDAR occlusion sistemi çalışmaya devam eder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(
                        "PC terminalinde gösterilen http://...:8765 adresini eksiksiz gir. "
                            + "iPhone Safari'de aynı adresin sonuna /health ekleyerek aç. "
                            + "Safari'de açılmıyorsa iki cihaz aynı Wi-Fi'da değildir; "
                            + "Safari'de açılıp uygulamada açılmıyorsa CineAR için Yerel Ağ iznini etkinleştir."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("AI Derinlik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { showingAISettings = false }
                }
            }
        }
    }

    private var aiStatusColor: Color {
        switch session.aiEnhancementStatus {
        case .active: .green
        case .failed: .red
        case .waiting, .waitingForDepth: .orange
        case .disabled: .secondary
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")
            as? String ?? "?"
        return "\(version) (\(build))"
    }

    private func roomModeButton(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    isSelected ? Color.accentColor.opacity(0.88) : Color.white.opacity(0.10),
                    in: Capsule()
                )
        }
    }

    private var compactControls: some View {
        VStack(spacing: 8) {
            Button {
                beginRoomScan()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "viewfinder.circle.fill")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.hasScannedRoom ? "Odayı Yeniden Tara" : "Odayı Tara")
                            .font(.subheadline.weight(.bold))
                        Text(roomScanAvailabilityText)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.9), in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .disabled(!RoomScannerController.isSupported || !session.isARReady)
            .opacity(RoomScannerController.isSupported ? (session.isARReady ? 1 : 0.7) : 0.55)
            .accessibilityHint(roomScanAvailabilityText)

            HStack(spacing: 8) {
                compactButton("Kontroller", "slider.horizontal.3") {
                    controlsExpanded = true
                }
                compactButton("Nesneler", "shippingbox.fill") {
                    showingPropLibrary = true
                }
                compactButton("Sahne", "list.bullet.rectangle") {
                    showingSceneContents = true
                }
                compactButton("Mekânlar", "square.stack.3d.up.fill") {
                    showingSavedPlaces = true
                }
            }
        }
        .disabled(session.isRecordingTransitioning)
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var roomScanAvailabilityText: String {
        if !RoomScannerController.isSupported {
            return "Bu cihaz RoomPlan taramasını desteklemiyor"
        }
        if !session.isARReady {
            return "Kamera ve AR takibi hazırlanıyor…"
        }
        return session.hasScannedRoom ? "Yeni bir oda taraması başlat" : "Duvar, zemin ve büyük nesneleri tara"
    }

    private func beginRoomScan() {
        guard RoomScannerController.isSupported, session.isARReady else { return }
        session.pauseForRoomScan()
        showingRoomScanner = true
    }

    private var lightControls: some View {
        VStack(spacing: 9) {
            HStack {
                Label("Sanal Işık", systemImage: "lightbulb.max.fill")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Toggle(
                    "",
                    isOn: Binding(
                        get: { session.selectedLightSettings?.isEnabled ?? false },
                        set: { session.setSelectedLightEnabled($0) }
                    )
                )
                .labelsHidden()
            }

            if let settings = session.selectedLightSettings {
                Button {
                    if session.isAimingLight {
                        session.cancelSelectedLightTargeting()
                    } else {
                        session.beginSelectedLightTargeting()
                    }
                } label: {
                    Label(
                        session.isAimingLight ? "Hedef Seçimini İptal Et" : "Projektör Hedefini Seç",
                        systemImage: session.isAimingLight ? "xmark.circle" : "scope"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(session.isAimingLight ? .red : .blue)

                lightSliderRow(
                    title: "Güç",
                    valueText: "\(Int(settings.intensityLumens)) lm",
                    value: Binding(
                        get: { Double(session.selectedLightSettings?.intensityLumens ?? 6_000) },
                        set: { session.setSelectedLightIntensity(Float($0)) }
                    ),
                    range: 0...12_000,
                    step: 100
                )
                lightSliderRow(
                    title: "Sıcaklık",
                    valueText: "\(Int(settings.temperatureKelvin)) K",
                    value: Binding(
                        get: { Double(session.selectedLightSettings?.temperatureKelvin ?? 4_200) },
                        set: { session.setSelectedLightTemperature(Float($0)) }
                    ),
                    range: 2_000...6_500,
                    step: 100
                )
                lightSliderRow(
                    title: "Yatay yön",
                    valueText: "\(Int(settings.effectiveYawDegrees))°",
                    value: Binding(
                        get: { Double(session.selectedLightSettings?.effectiveYawDegrees ?? 0) },
                        set: { session.setSelectedLightYaw(Float($0)) }
                    ),
                    range: -180...180,
                    step: 1
                )
                lightSliderRow(
                    title: "Dikey eğim",
                    valueText: "\(Int(settings.effectiveTiltDegrees))°",
                    value: Binding(
                        get: { Double(session.selectedLightSettings?.effectiveTiltDegrees ?? 0) },
                        set: { session.setSelectedLightTilt(Float($0)) }
                    ),
                    range: -75...75,
                    step: 1
                )
                lightSliderRow(
                    title: "Hüzme genişliği",
                    valueText: "\(Int(settings.coneAngleDegrees))° spot",
                    value: Binding(
                        get: { Double(session.selectedLightSettings?.coneAngleDegrees ?? 18) },
                        set: { session.setSelectedLightConeAngle(Float($0)) }
                    ),
                    range: 8...90,
                    step: 1
                )
                lightSliderRow(
                    title: "Kenar yumuşaklığı",
                    valueText: "%\(Int(settings.effectiveBeamSoftness * 100))",
                    value: Binding(
                        get: { Double(session.selectedLightSettings?.effectiveBeamSoftness ?? 0.34) },
                        set: { session.setSelectedLightSoftness(Float($0)) }
                    ),
                    range: 0...1,
                    step: 0.01
                )
            }

            Text("Spot ışık sanal nesneleri aydınlatır; LiDAR yüzeyindeki yumuşak projektör izi kamera görünümünde hedef noktayı gösterir.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func lightSliderRow(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(spacing: 2) {
            HStack {
                Text(title).font(.caption.weight(.semibold))
                Spacer()
                Text(valueText).font(.caption.monospacedDigit())
            }
            Slider(
                value: value,
                in: range,
                step: step,
                onEditingChanged: { isEditing in
                    if !isEditing { session.persistSelectedLightSettings() }
                }
            )
        }
    }

    private func compactButton(
        _ title: String,
        _ icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.body)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
        }
    }

    private var placementBar: some View {
        HStack(spacing: 12) {
            Text(session.selectedProp.symbol).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(session.selectedProp.title) yerleştir")
                    .font(.subheadline.weight(.bold))
                Text(session.placementSurfaceMessage)
                    .font(.caption2)
                    .foregroundStyle(session.placementSurfaceColor)
            }
            Spacer()
            Button("İptal") { session.cancelPlacement() }
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var placementReticle: some View {
        GeometryReader { proxy in
            let point = session.placementReticlePoint
                ?? CGPoint(x: proxy.size.width * 0.5, y: proxy.size.height * 0.5)
            ZStack {
                Circle()
                    .stroke(session.placementSurfaceColor, lineWidth: 3)
                    .frame(width: 46, height: 46)
                Circle()
                    .fill(session.placementSurfaceColor)
                    .frame(width: 7, height: 7)
                Rectangle()
                    .fill(session.placementSurfaceColor)
                    .frame(width: 66, height: 1)
                Rectangle()
                    .fill(session.placementSurfaceColor)
                    .frame(width: 1, height: 66)
            }
            .position(point)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var sceneContents: some View {
        NavigationStack {
            Group {
                if session.sceneObjects.isEmpty {
                    ContentUnavailableView(
                        "Sahne Boş",
                        systemImage: "cube.transparent",
                        description: Text("Eklediğin nesneler ve canlı efektler burada listelenecek.")
                    )
                } else {
                    List {
                        Section("\(session.sceneObjects.count) sahne öğesi") {
                            ForEach(session.sceneObjects) { item in
                                HStack(spacing: 12) {
                                    Button {
                                        session.selectSceneObject(id: item.id)
                                        showingSceneContents = false
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text(item.symbol).font(.title2)
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(item.title)
                                                    .font(.body.weight(.semibold))
                                                Text(item.detail)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            if item.id == session.selectedEntityID {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.green)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    Button(role: .destructive) {
                                        sceneObjectPendingDeletion = item
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("\(item.title) öğesini sil")
                                }
                            }
                        }

                        Section {
                            Button(role: .destructive) {
                                session.removeAllProps()
                            } label: {
                                Label("Sahnedeki Her Şeyi Sil", systemImage: "trash.slash")
                            }
                        } footer: {
                            Text("Silme işlemi taranmış oda kaydını değil, sanal nesne ve efektleri kaldırır.")
                        }
                    }
                }
            }
            .navigationTitle("Sahne İçeriği")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { showingSceneContents = false }
                }
            }
            .alert(
                "Sahne öğesi silinsin mi?",
                isPresented: Binding(
                    get: { sceneObjectPendingDeletion != nil },
                    set: { if !$0 { sceneObjectPendingDeletion = nil } }
                ),
                presenting: sceneObjectPendingDeletion
            ) { item in
                Button("Sil", role: .destructive) {
                    session.removeSceneObject(id: item.id)
                    sceneObjectPendingDeletion = nil
                }
                Button("Vazgeç", role: .cancel) {
                    sceneObjectPendingDeletion = nil
                }
            } message: { item in
                Text("\(item.title) sahneden ve scene.json kaydından kaldırılacak.")
            }
        }
    }

    private var savedPlacesLibrary: some View {
        NavigationStack {
            List {
                Section("Yeni kayıt") {
                    TextField("Mekân adı (isteğe bağlı)", text: $newSavedPlaceName)
                    Button {
                        session.saveWorldMap(archiveName: newSavedPlaceName)
                        newSavedPlaceName = ""
                    } label: {
                        Label("Aktif Mekânı Kaydet", systemImage: "square.and.arrow.down.fill")
                    }
                    Text("Dünya haritası, tarama, nesneler, ışıklar ve özel USDZ dosyaları birlikte saklanır.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Kayıtlı mekânlar") {
                    if session.savedPlaces.isEmpty {
                        Text("Henüz arşivlenmiş mekân yok.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(session.savedPlaces) { place in
                            HStack(spacing: 12) {
                                Button {
                                    session.loadSavedPlace(id: place.id)
                                    showingSavedPlaces = false
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: place.hasRoomScan
                                            ? "viewfinder.circle.fill"
                                            : "cube.transparent")
                                            .font(.title2)
                                            .foregroundStyle(place.hasRoomScan ? .green : .blue)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(place.name)
                                                .font(.body.weight(.semibold))
                                            Text(
                                                "\(place.objectCount) öğe • "
                                                    + place.updatedAt.formatted(
                                                        date: .abbreviated,
                                                        time: .shortened
                                                    )
                                            )
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .foregroundStyle(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Button(role: .destructive) {
                                    savedPlacePendingDeletion = place
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("\(place.name) kaydını sil")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Kayıtlı Mekânlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { showingSavedPlaces = false }
                }
            }
            .alert(
                "Mekân kaydı silinsin mi?",
                isPresented: Binding(
                    get: { savedPlacePendingDeletion != nil },
                    set: { if !$0 { savedPlacePendingDeletion = nil } }
                ),
                presenting: savedPlacePendingDeletion
            ) { place in
                Button("Sil", role: .destructive) {
                    session.deleteSavedPlace(id: place.id)
                    savedPlacePendingDeletion = nil
                }
                Button("Vazgeç", role: .cancel) {
                    savedPlacePendingDeletion = nil
                }
            } message: { place in
                Text("\(place.name) arşivi kalıcı olarak silinecek; aktif sahne etkilenmeyecek.")
            }
        }
    }

    private var liveCGIStudio: some View {
        NavigationStack {
            Form {
                Section("Gerçek zamanlı efektler") {
                    Button {
                        session.selectProp(.bloodWaterfall)
                        showingCGIStudio = false
                    } label: {
                        Label("Kan Şelalesi Yerleştir", systemImage: "drop.triangle.fill")
                    }
                    Text("Başlangıç noktasını taranmış duvarda seç; akış dünya koordinatına sabitlenir ve sahne kaydıyla geri gelir.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle(
                        "Avuçta Canlı Elma",
                        isOn: Binding(
                            get: { session.isLiveAppleEnabled },
                            set: { session.setLiveAppleEnabled($0) }
                        )
                    )
                    Text("Vision el eklemlerini, LiDAR ise avuç derinliğini ölçer. Elma geçici canlı efekttir; sahneye sabitlenmez.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Türkçe sesli komut") {
                    Button {
                        session.toggleCGIVoiceCommands()
                    } label: {
                        Label(
                            session.isListeningForCGICommands ? "Dinlemeyi Durdur" : "Komut Dinle",
                            systemImage: session.isListeningForCGICommands ? "stop.circle.fill" : "mic.circle.fill"
                        )
                    }
                    Text("“Elimde elma olsun”, “elmayı kaldır” veya “kan şelalesi aksın” diyebilirsin.")
                        .font(.caption)
                    LabeledContent("Durum", value: session.liveCGIStatus)
                }
            }
            .navigationTitle("Canlı CGI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bitti") { showingCGIStudio = false }
                }
            }
        }
    }

    private var propLibrary: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(PropLibraryCategory.allCases) { category in
                        let props = PropKind.photorealCases.filter {
                            $0.photorealDescriptor?.category == category
                        }
                        if !props.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(category.title)
                                    .font(.headline)
                                LazyVGrid(
                                    columns: Array(
                                        repeating: GridItem(.flexible(), spacing: 10),
                                        count: 3
                                    ),
                                    spacing: 10
                                ) {
                                    ForEach(props) { prop in
                                        Button {
                                            session.selectProp(prop)
                                            showingPropLibrary = false
                                        } label: {
                                            VStack(spacing: 6) {
                                                Text(prop.symbol).font(.largeTitle)
                                                Text(prop.title)
                                                    .font(.caption.weight(.semibold))
                                                    .lineLimit(2)
                                                    .minimumScaleFactor(0.75)
                                                    .multilineTextAlignment(.center)
                                            }
                                            .frame(maxWidth: .infinity, minHeight: 92)
                                            .background(
                                                .thinMaterial,
                                                in: RoundedRectangle(cornerRadius: 14)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("30 Gerçekçi 3B Nesne")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { showingPropLibrary = false }
                }
            }
        }
    }

    private func utilityButton(
        _ title: String,
        _ icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            utilityLabel(title, icon)
        }
    }

    private func utilityLabel(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.body)
            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}
````

## `CineAR/Info.plist`

````xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleDisplayName</key>
	<string>CineAR</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$(MARKETING_VERSION)</string>
	<key>CFBundleVersion</key>
	<string>$(CURRENT_PROJECT_VERSION)</string>
	<key>ITSAppUsesNonExemptEncryption</key>
	<false/>
	<key>LSRequiresIPhoneOS</key>
	<true/>
	<key>NSCameraUsageDescription</key>
	<string>Gercek mekani taramak ve sanal seti goruntulemek icin kamera kullanilir.</string>
	<key>NSMicrophoneUsageDescription</key>
	<string>AR cekimi sirasinda ses kaydetmek ve canli CGI komutlarini algilamak icin mikrofon kullanilir.</string>
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>Elma ve kan selalesi gibi canli CGI efektlerini Turkce sesli komutlarla yonetmek icin konusma tanima kullanilir.</string>
	<key>NSLocalNetworkUsageDescription</key>
	<string>SAM 2 ve Depth Anything derinlik servisine ayni Wi-Fi agindaki bilgisayardan baglanmak icin yerel ag kullanilir.</string>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsLocalNetworking</key>
		<true/>
	</dict>
	<key>LSSupportsOpeningDocumentsInPlace</key>
	<true/>
	<key>UIFileSharingEnabled</key>
	<true/>
	<key>UIRequiredDeviceCapabilities</key>
	<array>
		<string>arkit</string>
	</array>
	<key>UILaunchScreen</key>
	<dict/>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
</dict>
</plist>
````

## `CineAR/ProfessionalRecorder.swift`

````swift
import AVFoundation
import CoreMedia
import Foundation
import ReplayKit

final class ProfessionalRecorder {
    enum RecorderError: LocalizedError {
        case captureUnavailable
        case alreadyRecording
        case notRecording
        case missingVideoFormat
        case invalidVideoDimensions
        case unsupportedVideoSettings
        case writerUnavailable
        case writerStartFailed(String)
        case sampleCaptureFailed(String)
        case sampleDataUnavailable
        case invalidSampleTimestamp
        case sampleAppendFailed(String)
        case noVideoSamples
        case emptyOutput

        var errorDescription: String? {
            switch self {
            case .captureUnavailable:
                "Ekran yakalama şu anda kullanılamıyor"
            case .alreadyRecording:
                "Başka bir kayıt işlemi zaten devam ediyor"
            case .notRecording:
                "Durdurulabilecek etkin bir kayıt yok"
            case .missingVideoFormat:
                "Video biçimi alınamadı"
            case .invalidVideoDimensions:
                "Geçersiz video boyutu alındı"
            case .unsupportedVideoSettings:
                "Bu cihaz seçilen HEVC kayıt ayarlarını desteklemiyor"
            case .writerUnavailable:
                "Video yazıcı hazırlanamadı"
            case .writerStartFailed(let detail):
                "Video yazıcı başlatılamadı: \(detail)"
            case .sampleCaptureFailed(let detail):
                "Görüntü veya ses yakalama hatası: \(detail)"
            case .sampleDataUnavailable:
                "Kayıt verisi kullanıma hazır değildi"
            case .invalidSampleTimestamp:
                "Kayıt verisinin zaman damgası geçersizdi"
            case .sampleAppendFailed(let detail):
                "Kayıt verisi MOV dosyasına yazılamadı: \(detail)"
            case .noVideoSamples:
                "Kayıt için hiç video karesi alınamadı"
            case .emptyOutput:
                "Oluşturulan MOV dosyası boş"
            }
        }
    }

    private enum State {
        case idle
        case starting
        case recording
        case stopping
    }

    private let recorder = RPScreenRecorder.shared()
    private let writingQueue = DispatchQueue(label: "com.cinear.capture.writer")
    private let fileManager = FileManager.default

    // These properties are confined to writingQueue.
    private var state: State = .idle
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var microphoneInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var firstTimestamp: CMTime?
    private var terminalError: Error?
    private var runtimeFailureHandler: ((Error) -> Void)?
    private var runtimeFailureWasReported = false

    func start(
        outputURL: URL,
        runtimeFailure: @escaping (Error) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard recorder.isAvailable else {
            complete(.failure(RecorderError.captureUnavailable), using: completion)
            return
        }

        var validationError: Error?
        writingQueue.sync {
            guard case .idle = state else {
                validationError = RecorderError.alreadyRecording
                return
            }
            self.outputURL = outputURL
            runtimeFailureHandler = runtimeFailure
            terminalError = nil
            runtimeFailureWasReported = false
            firstTimestamp = nil
            state = .starting
        }

        if let validationError {
            complete(.failure(validationError), using: completion)
            return
        }

        recorder.isMicrophoneEnabled = true
        recorder.startCapture(
            handler: { [weak self] sampleBuffer, sampleType, error in
                guard let self else { return }
                self.writingQueue.async {
                    if let error {
                        self.registerFailure(
                            RecorderError.sampleCaptureFailed(error.localizedDescription)
                        )
                        return
                    }
                    self.consume(sampleBuffer, type: sampleType)
                }
            },
            completionHandler: { [weak self] error in
                guard let self else { return }
                self.writingQueue.async {
                    if let error {
                        self.abortSession(removeOutput: true)
                        self.complete(.failure(error), using: completion)
                        return
                    }

                    guard case .starting = self.state else {
                        self.abortSession(removeOutput: true)
                        self.complete(.failure(RecorderError.alreadyRecording), using: completion)
                        return
                    }

                    self.state = .recording
                    self.complete(.success(()), using: completion)
                    self.reportRuntimeFailureIfNeeded()
                }
            }
        )
    }

    func stop(completion: @escaping (Result<URL, Error>) -> Void) {
        var validationError: Error?
        writingQueue.sync {
            guard case .recording = state else {
                validationError = RecorderError.notRecording
                return
            }
            state = .stopping
        }

        if let validationError {
            complete(.failure(validationError), using: completion)
            return
        }

        recorder.stopCapture { [weak self] captureError in
            guard let self else { return }
            self.writingQueue.async {
                self.finishCapture(captureError: captureError, completion: completion)
            }
        }
    }

    private func consume(_ sampleBuffer: CMSampleBuffer, type: RPSampleBufferType) {
        switch state {
        case .starting, .recording:
            break
        case .idle, .stopping:
            return
        }

        guard terminalError == nil else { return }
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            registerFailure(RecorderError.sampleDataUnavailable)
            return
        }

        if writer == nil, type == .video {
            do {
                try prepareWriter(using: sampleBuffer)
            } catch {
                registerFailure(error)
                return
            }
        }

        guard let writer else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard timestamp.isValid else {
            registerFailure(RecorderError.invalidSampleTimestamp)
            return
        }
        if firstTimestamp == nil {
            guard type == .video else { return }
            guard writer.startWriting() else {
                registerFailure(
                    RecorderError.writerStartFailed(
                        writer.error?.localizedDescription ?? "bilinmeyen yazıcı hatası"
                    )
                )
                return
            }
            firstTimestamp = timestamp
            writer.startSession(atSourceTime: timestamp)
        } else if let firstTimestamp, CMTimeCompare(timestamp, firstTimestamp) < 0 {
            // ReplayKit can deliver a buffered microphone sample from just before
            // the first video frame. It is outside this writer session.
            return
        }

        guard writer.status == .writing else {
            registerFailure(
                writer.error ?? RecorderError.writerStartFailed("yazıcı writing durumuna geçemedi")
            )
            return
        }

        switch type {
        case .video:
            append(sampleBuffer, to: videoInput, mediaName: "video")
        case .audioMic:
            append(sampleBuffer, to: microphoneInput, mediaName: "mikrofon")
        case .audioApp:
            break
        @unknown default:
            break
        }
    }

    private func append(
        _ sampleBuffer: CMSampleBuffer,
        to input: AVAssetWriterInput?,
        mediaName: String
    ) {
        guard let input, input.isReadyForMoreMediaData else { return }
        guard input.append(sampleBuffer) else {
            registerFailure(
                writer?.error
                    ?? RecorderError.sampleAppendFailed("\(mediaName) verisi reddedildi")
            )
            return
        }
    }

    private func prepareWriter(using sampleBuffer: CMSampleBuffer) throws {
        guard let outputURL else { throw RecorderError.writerUnavailable }
        guard let description = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            throw RecorderError.missingVideoFormat
        }
        let dimensions = CMVideoFormatDescriptionGetDimensions(description)
        guard dimensions.width > 0, dimensions.height > 0 else {
            throw RecorderError.invalidVideoDimensions
        }

        let compression: [String: Any] = [
            AVVideoAverageBitRateKey: 24_000_000,
            AVVideoExpectedSourceFrameRateKey: 30,
            AVVideoAllowFrameReorderingKey: false
        ]
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: Int(dimensions.width),
            AVVideoHeightKey: Int(dimensions.height),
            AVVideoCompressionPropertiesKey: compression
        ]
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        guard writer.canApply(
            outputSettings: videoSettings,
            forMediaType: .video
        ) else {
            throw RecorderError.unsupportedVideoSettings
        }

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 192_000
        ]
        guard writer.canApply(
            outputSettings: audioSettings,
            forMediaType: .audio
        ) else {
            throw RecorderError.writerUnavailable
        }
        let microphoneInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        microphoneInput.expectsMediaDataInRealTime = true

        guard writer.canAdd(videoInput), writer.canAdd(microphoneInput) else {
            throw RecorderError.writerUnavailable
        }
        writer.add(videoInput)
        writer.add(microphoneInput)

        self.writer = writer
        self.videoInput = videoInput
        self.microphoneInput = microphoneInput
    }

    private func registerFailure(_ error: Error) {
        guard terminalError == nil else { return }
        terminalError = error
        reportRuntimeFailureIfNeeded()
    }

    private func reportRuntimeFailureIfNeeded() {
        guard case .recording = state,
              !runtimeFailureWasReported,
              let terminalError,
              let runtimeFailureHandler else { return }
        runtimeFailureWasReported = true
        DispatchQueue.main.async {
            runtimeFailureHandler(terminalError)
        }
    }

    private func finishCapture(
        captureError: Error?,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        if terminalError == nil, let captureError {
            terminalError = captureError
        }

        guard let writer, let outputURL, firstTimestamp != nil else {
            let error = terminalError ?? RecorderError.noVideoSamples
            abortSession(removeOutput: true)
            complete(.failure(error), using: completion)
            return
        }

        guard writer.status == .writing else {
            let error = terminalError ?? writer.error ?? RecorderError.writerUnavailable
            abortSession(removeOutput: true)
            complete(.failure(error), using: completion)
            return
        }

        videoInput?.markAsFinished()
        microphoneInput?.markAsFinished()
        let recordedFailure = terminalError
        writer.finishWriting { [weak self] in
            guard let self else { return }
            self.writingQueue.async {
                let result: Result<URL, Error>
                if let recordedFailure {
                    result = .failure(recordedFailure)
                } else if writer.status != .completed {
                    result = .failure(writer.error ?? RecorderError.writerUnavailable)
                } else if !self.outputHasData(at: outputURL) {
                    result = .failure(RecorderError.emptyOutput)
                } else {
                    result = .success(outputURL)
                }

                let shouldRemoveOutput: Bool
                if case .failure = result {
                    shouldRemoveOutput = true
                } else {
                    shouldRemoveOutput = false
                }
                self.resetSession(removeOutput: shouldRemoveOutput)
                self.complete(result, using: completion)
            }
        }
    }

    private func outputHasData(at url: URL) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else { return false }
        return size.int64Value > 0
    }

    private func abortSession(removeOutput: Bool) {
        if writer?.status == .writing || writer?.status == .unknown {
            writer?.cancelWriting()
        }
        resetSession(removeOutput: removeOutput)
    }

    private func resetSession(removeOutput: Bool) {
        let abandonedURL = outputURL
        state = .idle
        writer = nil
        videoInput = nil
        microphoneInput = nil
        outputURL = nil
        firstTimestamp = nil
        terminalError = nil
        runtimeFailureHandler = nil
        runtimeFailureWasReported = false

        if removeOutput, let abandonedURL,
           fileManager.fileExists(atPath: abandonedURL.path) {
            try? fileManager.removeItem(at: abandonedURL)
        }
    }

    private func complete<Success>(
        _ result: Result<Success, Error>,
        using completion: @escaping (Result<Success, Error>) -> Void
    ) {
        DispatchQueue.main.async {
            completion(result)
        }
    }
}
````

## `CineAR/PropKind.swift`

````swift
import Foundation
import simd

enum PropPlacementSurface: String, Codable {
    case floor
    case horizontal
    case wall
    case ceiling
}

enum PropLibraryCategory: String, CaseIterable, Identifiable {
    case effects
    case furniture
    case storage
    case equipment
    case wall
    case lighting
    case electronics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .effects: "Canlı CGI"
        case .furniture: "Mobilya"
        case .storage: "Depolama"
        case .equipment: "Ekipman"
        case .wall: "Duvar"
        case .lighting: "Işık"
        case .electronics: "Elektronik"
        }
    }
}

struct PhotorealPropDescriptor {
    let assetName: String
    let dimensions: SIMD3<Float>
    let surface: PropPlacementSurface
    let category: PropLibraryCategory
    let emitsLight: Bool
}

enum PropKind: String, CaseIterable, Identifiable, Codable {
    // Lightweight legacy props remain decodable so existing saved scenes still load.
    case wall
    case stage
    case crate
    case lightPanel
    case chair
    case table
    case sofa
    case bed
    case bookcase
    case television
    case refrigerator
    case oven
    case stove
    case sink
    case bathtub
    case toilet
    case washerDryer
    case stairs
    case plant
    case floorLamp
    case rug
    case backdrop
    case custom
    case bloodWaterfall
    case apple

    // Curated Poly Haven CC0 photoreal catalog (30 objects).
    case metalOfficeDesk
    case schoolChair
    case schoolDesk
    case metalTrashCan
    case cardboardBox
    case plasticCrate
    case woodenCrate
    case blueBarrel
    case handTruck
    case drawerCabinet
    case filingCabinet
    case steelShelves
    case toolChest
    case plasticChair
    case woodenStool
    case wetFloorSign
    case fireExtinguisher
    case securityCamera
    case powerBox
    case payphone
    case wallClock
    case cagedCeilingLight
    case industrialPendant
    case ceilingFan
    case industrialWallLamp
    case cagedWallLight
    case deskLamp
    case classicLaptop
    case crtTelevision
    case boombox

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wall: "Duvar"
        case .stage: "Platform"
        case .crate: "Kasa"
        case .lightPanel: "Işık Paneli"
        case .chair: "Sandalye"
        case .table: "Masa"
        case .sofa: "Koltuk"
        case .bed: "Yatak"
        case .bookcase: "Kitaplık"
        case .television: "Televizyon"
        case .refrigerator: "Buzdolabı"
        case .oven: "Fırın"
        case .stove: "Ocak"
        case .sink: "Lavabo"
        case .bathtub: "Küvet"
        case .toilet: "Tuvalet"
        case .washerDryer: "Çamaşır Makinesi"
        case .stairs: "Merdiven"
        case .plant: "Salon Bitkisi"
        case .floorLamp: "Ayaklı Lamba"
        case .rug: "Halı"
        case .backdrop: "Fon Perdesi"
        case .custom: "USDZ"
        case .bloodWaterfall: "Kan Şelalesi"
        case .apple: "Elma"
        case .metalOfficeDesk: "Metal Ofis Masası"
        case .schoolChair: "Okul Sandalyesi"
        case .schoolDesk: "Okul Sırası"
        case .metalTrashCan: "Metal Çöp Kutuları"
        case .cardboardBox: "Yıpranmış Koli"
        case .plasticCrate: "Plastik Kasa"
        case .woodenCrate: "Ahşap Kasa"
        case .blueBarrel: "Depo Varili"
        case .handTruck: "Yük Arabası"
        case .drawerCabinet: "Raflı Çekmeceli Dolap"
        case .filingCabinet: "Vintage Çekmeceli Dolap"
        case .steelShelves: "Çelik Raf"
        case .toolChest: "Takım Sandığı"
        case .plasticChair: "Plastik Sandalye"
        case .woodenStool: "Ahşap Tabure"
        case .wetFloorSign: "Islak Zemin Tabelası"
        case .fireExtinguisher: "Yangın Tüpü"
        case .securityCamera: "Güvenlik Kamerası"
        case .powerBox: "Elektrik Panosu"
        case .payphone: "Eski Ankesörlü Telefon"
        case .wallClock: "Duvar Saati"
        case .cagedCeilingLight: "Kafesli Tavan Işığı"
        case .industrialPendant: "Endüstriyel Sarkıt"
        case .ceilingFan: "Tavan Vantilatörü"
        case .industrialWallLamp: "Endüstriyel Duvar Işığı"
        case .cagedWallLight: "Kafesli Duvar Işığı"
        case .deskLamp: "Masa Lambası"
        case .classicLaptop: "Klasik Dizüstü"
        case .crtTelevision: "Tüplü Televizyon"
        case .boombox: "Kasetçalar"
        }
    }

    var symbol: String {
        switch self {
        case .wall: "🧱"
        case .stage: "🎬"
        case .crate, .cardboardBox, .plasticCrate, .woodenCrate: "📦"
        case .lightPanel, .cagedCeilingLight, .industrialPendant,
             .industrialWallLamp, .cagedWallLight, .deskLamp: "💡"
        case .chair, .schoolChair, .plasticChair: "🪑"
        case .table, .metalOfficeDesk, .schoolDesk: "🗄️"
        case .sofa: "🛋️"
        case .bed: "🛏️"
        case .bookcase, .steelShelves: "📚"
        case .television, .crtTelevision: "📺"
        case .refrigerator: "🧊"
        case .oven: "♨️"
        case .stove: "🍳"
        case .sink: "🚰"
        case .bathtub: "🛁"
        case .toilet: "🚽"
        case .washerDryer: "🧺"
        case .stairs: "🪜"
        case .plant: "🪴"
        case .floorLamp: "🏮"
        case .rug: "🟫"
        case .backdrop: "🎞️"
        case .custom: "🎭"
        case .bloodWaterfall: "🩸"
        case .apple: "🍎"
        case .metalTrashCan: "🗑️"
        case .blueBarrel: "🛢️"
        case .handTruck: "🛒"
        case .drawerCabinet, .filingCabinet: "🗃️"
        case .toolChest: "🧰"
        case .woodenStool: "🪵"
        case .wetFloorSign: "⚠️"
        case .fireExtinguisher: "🧯"
        case .securityCamera: "📹"
        case .powerBox: "⚡"
        case .payphone: "☎️"
        case .wallClock: "🕒"
        case .ceilingFan: "🌀"
        case .classicLaptop: "💻"
        case .boombox: "📻"
        }
    }

    static let quickCases: [PropKind] = [
        .wall, .stage, .crate, .lightPanel, .bloodWaterfall, .apple, .custom
    ]
    static let effectCases: [PropKind] = [.bloodWaterfall, .apple]
    static let furnitureCases: [PropKind] = photorealCases

    static let photorealCases: [PropKind] = [
        .metalOfficeDesk, .schoolChair, .schoolDesk, .metalTrashCan,
        .cardboardBox, .plasticCrate, .woodenCrate, .blueBarrel,
        .handTruck, .drawerCabinet, .filingCabinet, .steelShelves,
        .toolChest, .plasticChair, .woodenStool, .wetFloorSign,
        .fireExtinguisher, .securityCamera, .powerBox, .payphone,
        .wallClock, .cagedCeilingLight, .industrialPendant, .ceilingFan,
        .industrialWallLamp, .cagedWallLight, .deskLamp, .classicLaptop,
        .crtTelevision, .boombox
    ]

    var photorealDescriptor: PhotorealPropDescriptor? {
        switch self {
        case .metalOfficeDesk:
            .init(assetName: "metal_office_desk", dimensions: [1.50, 0.76, 0.75], surface: .floor, category: .furniture, emitsLight: false)
        case .schoolChair:
            .init(assetName: "SchoolChair_01", dimensions: [0.48, 0.84, 0.52], surface: .floor, category: .furniture, emitsLight: false)
        case .schoolDesk:
            .init(assetName: "SchoolDesk_01", dimensions: [0.66, 0.78, 0.55], surface: .floor, category: .furniture, emitsLight: false)
        case .metalTrashCan:
            .init(assetName: "metal_trash_can", dimensions: [1.35, 0.65, 0.45], surface: .floor, category: .storage, emitsLight: false)
        case .cardboardBox:
            .init(assetName: "cardboard_box_01", dimensions: [0.45, 0.40, 0.58], surface: .horizontal, category: .storage, emitsLight: false)
        case .plasticCrate:
            .init(assetName: "plastic_crate_02", dimensions: [0.60, 0.34, 0.40], surface: .horizontal, category: .storage, emitsLight: false)
        case .woodenCrate:
            .init(assetName: "wooden_crate_02", dimensions: [0.55, 0.48, 1.15], surface: .horizontal, category: .storage, emitsLight: false)
        case .blueBarrel:
            .init(assetName: "Barrel_02", dimensions: [0.58, 0.90, 0.58], surface: .floor, category: .storage, emitsLight: false)
        case .handTruck:
            .init(assetName: "hand_truck", dimensions: [0.55, 1.30, 0.65], surface: .floor, category: .equipment, emitsLight: false)
        case .drawerCabinet:
            .init(assetName: "drawer_cabinet", dimensions: [0.90, 1.50, 0.50], surface: .floor, category: .storage, emitsLight: false)
        case .filingCabinet:
            .init(assetName: "vintage_wooden_drawer_01", dimensions: [0.86, 0.55, 0.46], surface: .floor, category: .storage, emitsLight: false)
        case .steelShelves:
            .init(assetName: "steel_frame_shelves_01", dimensions: [1.20, 1.84, 0.46], surface: .floor, category: .storage, emitsLight: false)
        case .toolChest:
            .init(assetName: "metal_tool_chest", dimensions: [0.76, 0.52, 0.46], surface: .horizontal, category: .equipment, emitsLight: false)
        case .plasticChair:
            .init(assetName: "plastic_monobloc_chair_01", dimensions: [0.56, 0.84, 0.58], surface: .floor, category: .furniture, emitsLight: false)
        case .woodenStool:
            .init(assetName: "wooden_stool_01", dimensions: [0.39, 0.46, 0.39], surface: .floor, category: .furniture, emitsLight: false)
        case .wetFloorSign:
            .init(assetName: "WetFloorSign_01", dimensions: [0.38, 0.62, 0.32], surface: .floor, category: .equipment, emitsLight: false)
        case .fireExtinguisher:
            .init(assetName: "korean_fire_extinguisher_01", dimensions: [0.25, 0.58, 0.30], surface: .floor, category: .equipment, emitsLight: false)
        case .securityCamera:
            .init(assetName: "security_camera_01", dimensions: [0.27, 0.20, 0.36], surface: .wall, category: .wall, emitsLight: false)
        case .powerBox:
            .init(assetName: "power_box_01", dimensions: [0.46, 0.66, 0.21], surface: .wall, category: .wall, emitsLight: false)
        case .payphone:
            .init(assetName: "korean_public_payphone_01", dimensions: [0.31, 0.55, 0.29], surface: .wall, category: .wall, emitsLight: false)
        case .wallClock:
            .init(assetName: "wall_clock", dimensions: [0.39, 0.39, 0.07], surface: .wall, category: .wall, emitsLight: false)
        case .cagedCeilingLight:
            .init(assetName: "caged_hanging_light", dimensions: [1.10, 0.72, 0.35], surface: .ceiling, category: .lighting, emitsLight: true)
        case .industrialPendant:
            .init(assetName: "hanging_industrial_lamp", dimensions: [0.55, 1.35, 0.55], surface: .ceiling, category: .lighting, emitsLight: true)
        case .ceilingFan:
            .init(assetName: "ceiling_fan", dimensions: [1.30, 0.46, 1.30], surface: .ceiling, category: .equipment, emitsLight: false)
        case .industrialWallLamp:
            .init(assetName: "industrial_wall_lamp", dimensions: [0.30, 0.44, 0.34], surface: .wall, category: .lighting, emitsLight: true)
        case .cagedWallLight:
            .init(assetName: "industrial_wall_sconce", dimensions: [0.28, 0.42, 0.32], surface: .wall, category: .lighting, emitsLight: true)
        case .deskLamp:
            .init(assetName: "desk_lamp_arm_01", dimensions: [0.34, 0.72, 0.46], surface: .horizontal, category: .lighting, emitsLight: true)
        case .classicLaptop:
            .init(assetName: "classic_laptop", dimensions: [0.38, 0.32, 0.30], surface: .horizontal, category: .electronics, emitsLight: false)
        case .crtTelevision:
            .init(assetName: "television_02", dimensions: [0.58, 0.48, 0.48], surface: .horizontal, category: .electronics, emitsLight: false)
        case .boombox:
            .init(assetName: "boombox", dimensions: [0.52, 0.31, 0.23], surface: .horizontal, category: .electronics, emitsLight: false)
        default:
            nil
        }
    }

    var placementSurface: PropPlacementSurface {
        if let surface = photorealDescriptor?.surface { return surface }
        switch self {
        case .wall, .lightPanel, .backdrop, .bloodWaterfall:
            return PropPlacementSurface.wall
        case .apple:
            return PropPlacementSurface.horizontal
        case .custom:
            return PropPlacementSurface.horizontal
        default:
            return PropPlacementSurface.floor
        }
    }

    var emitsVirtualLight: Bool {
        photorealDescriptor?.emitsLight == true || self == .lightPanel || self == .floorLamp
    }

    var bundledAssetName: String? {
        switch self {
        case .chair: "chairModernCushion"
        case .table: "table"
        case .sofa: "loungeDesignSofa"
        case .bed: "bedDouble"
        case .bookcase: "bookcaseClosedWide"
        case .television: "televisionModern"
        case .refrigerator: "kitchenFridge"
        case .oven: "kitchenStove"
        case .stove: "kitchenStoveElectric"
        case .sink: "bathroomSink"
        case .bathtub: "bathtub"
        case .toilet: "toilet"
        case .washerDryer: "washerDryerStacked"
        case .stairs: "stairs"
        default: nil
        }
    }

    var anchorName: String { "cinear.prop.\(rawValue)" }

    func anchorName(id: UUID) -> String {
        "\(anchorName).\(id.uuidString)"
    }

    static func from(anchorName: String?) -> PropKind? {
        guard let anchorName else { return nil }
        let parts = anchorName.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4,
              parts[0] == "cinear",
              parts[1] == "prop" else { return nil }
        return PropKind(rawValue: String(parts[2]))
    }

    static func descriptor(from anchorName: String?) -> (kind: PropKind, id: UUID)? {
        guard let anchorName,
              let kind = from(anchorName: anchorName),
              let idText = anchorName.split(separator: ".").last,
              let id = UUID(uuidString: String(idText)) else {
            return nil
        }
        return (kind, id)
    }
}
````

## `CineAR/RealityTheme.swift`

````swift
import RealityKit
import UIKit

/// Kullanıcının tek dokunuşla seçebileceği hazır oda görünümleri.
enum RealityThemeID: String, CaseIterable, Codable, Identifiable, Sendable {
    case modern
    case soundStage
    case sciFi
    case warmLoft

    var id: String { rawValue }
}

enum RealitySurfaceRole: Equatable, Sendable {
    case wall
    case floor
    case ceiling
    case door
    case window
    case opening
    case trim
}

enum RealityObjectRole: Equatable, Sendable {
    case bathtub
    case bed
    case chair
    case dishwasher
    case fireplace
    case oven
    case refrigerator
    case sink
    case sofa
    case stairs
    case storage
    case stove
    case table
    case television
    case toilet
    case washerDryer
    case unknown
}

/// Texture gerektirmeyen, hızlı oluşturulan bir PBR materyal tarifi.
/// Daha sonra aynı rollere USDZ içindeki dokulu materyaller bağlanabilir.
struct RealityMaterialRecipe: Sendable {
    let red: Float
    let green: Float
    let blue: Float
    let alpha: Float
    let roughness: Float
    let metallic: Float

    init(
        _ red: Float,
        _ green: Float,
        _ blue: Float,
        alpha: Float = 1,
        roughness: Float,
        metallic: Float = 0
    ) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
        self.roughness = roughness
        self.metallic = metallic
    }

    @MainActor
    func makeMaterial() -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        let color = UIColor(
            red: CGFloat(clamped(red)),
            green: CGFloat(clamped(green)),
            blue: CGFloat(clamped(blue)),
            alpha: CGFloat(clamped(alpha))
        )
        material.baseColor = .init(tint: color)
        material.roughness = .init(floatLiteral: clamped(roughness))
        material.metallic = .init(floatLiteral: clamped(metallic))
        if alpha < 0.999 {
            material.blending = .transparent(
                opacity: .init(floatLiteral: clamped(alpha))
            )
        }
        return material
    }

    private func clamped(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}

struct RealityTheme: Identifiable, Sendable {
    let id: RealityThemeID
    let title: String
    let subtitle: String
    let symbolName: String

    let wall: RealityMaterialRecipe
    let floor: RealityMaterialRecipe
    let ceiling: RealityMaterialRecipe
    let door: RealityMaterialRecipe
    let glass: RealityMaterialRecipe
    let opening: RealityMaterialRecipe
    let trim: RealityMaterialRecipe
    let furniturePrimary: RealityMaterialRecipe
    let furnitureSecondary: RealityMaterialRecipe
    let furnitureDetail: RealityMaterialRecipe
    let screen: RealityMaterialRecipe

    /// Taranan düzlemlerin kamerayı örtebilmesi için küçük bir fiziksel kalınlık.
    let surfaceThickness: Float

    func materialRecipe(for role: RealitySurfaceRole) -> RealityMaterialRecipe {
        switch role {
        case .wall: wall
        case .floor: floor
        case .ceiling: ceiling
        case .door: door
        case .window: glass
        case .opening: opening
        case .trim: trim
        }
    }

    func objectRecipes(
        for role: RealityObjectRole
    ) -> (
        primary: RealityMaterialRecipe,
        secondary: RealityMaterialRecipe,
        detail: RealityMaterialRecipe
    ) {
        switch role {
        case .television, .fireplace:
            (furnitureDetail, screen, trim)
        case .refrigerator, .dishwasher, .oven, .stove, .washerDryer:
            (furnitureSecondary, trim, furnitureDetail)
        case .bathtub, .sink, .toilet:
            (furnitureSecondary, furniturePrimary, trim)
        case .stairs:
            (floor, furnitureSecondary, trim)
        case .bed, .chair, .sofa, .storage, .table, .unknown:
            (furniturePrimary, furnitureSecondary, furnitureDetail)
        }
    }
}

enum RealityThemeCatalog {
    static let modern = RealityTheme(
        id: .modern,
        title: "Modern",
        subtitle: "Açık taş, doğal ahşap ve mat siyah ayrıntılar",
        symbolName: "square.grid.2x2.fill",
        wall: .init(0.78, 0.80, 0.79, roughness: 0.82),
        floor: .init(0.30, 0.19, 0.11, roughness: 0.68),
        ceiling: .init(0.88, 0.89, 0.87, roughness: 0.90),
        door: .init(0.21, 0.12, 0.07, roughness: 0.62),
        glass: .init(0.42, 0.72, 0.84, alpha: 0.28, roughness: 0.08),
        opening: .init(0.035, 0.045, 0.055, roughness: 0.88),
        trim: .init(0.055, 0.06, 0.065, roughness: 0.34, metallic: 0.52),
        furniturePrimary: .init(0.16, 0.30, 0.32, roughness: 0.72),
        furnitureSecondary: .init(0.86, 0.84, 0.78, roughness: 0.76),
        furnitureDetail: .init(0.035, 0.04, 0.045, roughness: 0.28, metallic: 0.38),
        screen: .init(0.025, 0.055, 0.075, roughness: 0.06, metallic: 0.12),
        surfaceThickness: 0.045
    )

    static let soundStage = RealityTheme(
        id: .soundStage,
        title: "Film Stüdyosu",
        subtitle: "Koyu akustik yüzeyler, gri set zemini ve metal ekipman",
        symbolName: "movieclapper.fill",
        wall: .init(0.075, 0.08, 0.09, roughness: 0.95),
        floor: .init(0.12, 0.125, 0.13, roughness: 0.76),
        ceiling: .init(0.045, 0.05, 0.058, roughness: 0.92),
        door: .init(0.055, 0.06, 0.07, roughness: 0.70, metallic: 0.20),
        glass: .init(0.24, 0.31, 0.36, alpha: 0.22, roughness: 0.12),
        opening: .init(0.012, 0.014, 0.018, roughness: 1),
        trim: .init(0.22, 0.23, 0.24, roughness: 0.30, metallic: 0.78),
        furniturePrimary: .init(0.11, 0.115, 0.12, roughness: 0.88),
        furnitureSecondary: .init(0.28, 0.29, 0.30, roughness: 0.62),
        furnitureDetail: .init(0.035, 0.038, 0.042, roughness: 0.24, metallic: 0.72),
        screen: .init(0.76, 0.80, 0.85, roughness: 0.10, metallic: 0.08),
        surfaceThickness: 0.055
    )

    static let sciFi = RealityTheme(
        id: .sciFi,
        title: "Bilimkurgu",
        subtitle: "Titanyum paneller, soğuk cam ve turkuaz teknoloji ayrıntıları",
        symbolName: "sparkles.rectangle.stack.fill",
        wall: .init(0.11, 0.15, 0.18, roughness: 0.32, metallic: 0.64),
        floor: .init(0.055, 0.075, 0.085, roughness: 0.24, metallic: 0.72),
        ceiling: .init(0.08, 0.12, 0.15, roughness: 0.26, metallic: 0.66),
        door: .init(0.17, 0.22, 0.25, roughness: 0.22, metallic: 0.78),
        glass: .init(0.05, 0.64, 0.74, alpha: 0.34, roughness: 0.05, metallic: 0.05),
        opening: .init(0.005, 0.018, 0.024, roughness: 0.52),
        trim: .init(0.06, 0.76, 0.82, roughness: 0.16, metallic: 0.48),
        furniturePrimary: .init(0.12, 0.17, 0.20, roughness: 0.34, metallic: 0.54),
        furnitureSecondary: .init(0.33, 0.39, 0.42, roughness: 0.26, metallic: 0.68),
        furnitureDetail: .init(0.025, 0.035, 0.04, roughness: 0.16, metallic: 0.82),
        screen: .init(0.04, 0.78, 0.88, roughness: 0.04, metallic: 0.12),
        surfaceThickness: 0.06
    )

    static let warmLoft = RealityTheme(
        id: .warmLoft,
        title: "Sıcak Loft",
        subtitle: "Tuğla tonları, koyu ahşap ve eskitilmiş metal",
        symbolName: "building.2.fill",
        wall: .init(0.45, 0.17, 0.09, roughness: 0.94),
        floor: .init(0.19, 0.105, 0.055, roughness: 0.78),
        ceiling: .init(0.32, 0.24, 0.18, roughness: 0.88),
        door: .init(0.12, 0.065, 0.035, roughness: 0.74),
        glass: .init(0.42, 0.58, 0.61, alpha: 0.26, roughness: 0.10),
        opening: .init(0.035, 0.026, 0.022, roughness: 0.94),
        trim: .init(0.10, 0.075, 0.06, roughness: 0.38, metallic: 0.62),
        furniturePrimary: .init(0.28, 0.13, 0.055, roughness: 0.76),
        furnitureSecondary: .init(0.43, 0.34, 0.24, roughness: 0.82),
        furnitureDetail: .init(0.075, 0.065, 0.058, roughness: 0.32, metallic: 0.70),
        screen: .init(0.05, 0.042, 0.035, roughness: 0.08, metallic: 0.14),
        surfaceThickness: 0.05
    )

    static let all: [RealityTheme] = [modern, soundStage, sciFi, warmLoft]

    static func theme(withID id: RealityThemeID) -> RealityTheme {
        all.first(where: { $0.id == id }) ?? modern
    }
}
````

## `CineAR/RoomAssets/LICENSE-KENNEY.txt`

````text
Kenney Furniture Kit 2.0

Created and distributed by Kenney: https://kenney.nl/
Source: https://kenney.nl/assets/furniture-kit

License: Creative Commons Zero (CC0 1.0 Universal)
https://creativecommons.org/publicdomain/zero/1.0/

The source package states that this content is free to use in personal,
educational, and commercial projects. Credit is not required. CineAR keeps
this notice in the application bundle for provenance and reproducibility.

The USDZ files in this folder were converted from the original Kenney GLB
files with Blender 4.5.0. Geometry and materials remain derived from the CC0
source models.
````

## `CineAR/RoomAssets/LICENSE-POLYHAVEN.txt`

````text
Poly Haven Photoreal Prop Collection for CineAR

Source catalog: https://polyhaven.com/models
License: Creative Commons Zero (CC0 1.0 Universal)
License page: https://polyhaven.com/license

Poly Haven publishes these assets as public domain material. They may be used,
modified, redistributed, and included in commercial applications without
attribution. CineAR keeps this notice for provenance and reproducibility.

The bundled USDZ files were generated from the official 1K glTF downloads with
Blender 4.5 LTS. Textures are capped at 1024 px for predictable iPhone memory use.

Included Poly Haven asset IDs (30):

metal_office_desk
SchoolChair_01
SchoolDesk_01
metal_trash_can
cardboard_box_01
plastic_crate_02
wooden_crate_02
Barrel_02
hand_truck
drawer_cabinet
vintage_wooden_drawer_01
steel_frame_shelves_01
metal_tool_chest
plastic_monobloc_chair_01
wooden_stool_01
WetFloorSign_01
korean_fire_extinguisher_01
security_camera_01
power_box_01
korean_public_payphone_01
wall_clock
caged_hanging_light
hanging_industrial_lamp
ceiling_fan
industrial_wall_lamp
industrial_wall_sconce
desk_lamp_arm_01
classic_laptop
television_02
boombox

Individual source pages follow the form:
https://polyhaven.com/a/<asset-id>
````

## `CineAR/RoomAssets/MANIFEST.sha256`

````text
db44c3823a4313fcb39cc3363de427390b1126dbfccbaede42dfc4c62cc832fe  Barrel_02.usdz
2de87dbd39ec292d8575aaf526160310ac090659d6cba1fb0b9d7b231f0cc643  bathroomSink.usdz
3a24cebb0eac7b5dbf190958aeda8e3599b38a9d51c826cf349f703a2c44ce53  bathtub.usdz
c658a28c0afb73daa53330d9747f0651056f172f990df8acecf29003511d0297  bedDouble.usdz
39d09d860911c9e51a807d33607cec97eb314929c717e848956175ab0f0e2e7f  bookcaseClosedWide.usdz
23d131aee04991d1b89989b6d74e2e769b70aca2d1cdd17a990e768019310e0b  boombox.usdz
b4834b13750c18ee2ba3da62fe4392257f66d06330b47966b42c316d0e227025  caged_hanging_light.usdz
f0968ac22285b3d7a9af0bfbe4576dc2f9074378dcfbbd2ec093064f9a5e48b0  cardboard_box_01.usdz
f8343f8c3647a46c87bfb2188ed5e943ffc32ada06e8dd155b94914bc6e5697d  ceiling_fan.usdz
11ae4610ca26984e5f1318c4aba81e5a9090e0c820e4969d4105bd75f147ea9e  chairModernCushion.usdz
f927c1c0cd84346380eb2aa8a720be3b40acb27e02881505619013f15a3f7145  classic_laptop.usdz
6dc22925edb49c4ea4580c5c92eae78901119f734f7e659537ea0db54d44b96a  desk_lamp_arm_01.usdz
351c5a13e7b4321717eb10ec9696825b1399a872aad41c3739dc8c4223f44f68  drawer_cabinet.usdz
fb69f9da5eee8a94b8751c34576f86385ed89e997873d549268774fe307b4486  hand_truck.usdz
abb5fb8f34f63408885db1bace875ce69fa7c2fcc3eb59c1741f5d1b5e42f937  hanging_industrial_lamp.usdz
41dd0ce90dbc114ac6bed1ff58a4ca9b9cf45526d44fcca75f958647bad34ea9  industrial_wall_lamp.usdz
c665e13f562047084407f0fb42e12dbf10db3ccaec6ce1e1ea1bfac9cc10bbee  industrial_wall_sconce.usdz
a69f54abdfe4d08aa9408acd80b5d43f8d8126762456988c113a9ae5f94729b7  kitchenFridge.usdz
b8162bd10dd56e6936cd0f4035a7cfe158f9ea46bd11c14c0b8e1f5e5121da68  kitchenStove.usdz
b6607fcdfb518b204779961d1fb87a138436236a64438a81c6fcdcdc5606b4ba  kitchenStoveElectric.usdz
0f329ca78bfbb62c158761c8b28bbc78a03481f0987ddeff60820f427810af4a  korean_fire_extinguisher_01.usdz
e25b910f745ebfa2e27bc4ac3a88fd87c9b8707be76290121916377e3b076a72  korean_public_payphone_01.usdz
e1ff365a2245f802cd0c31f6972927d8b3a82a4356a46a1f525e79d58558d3ad  loungeDesignSofa.usdz
8e54007f0ddd27d5173e7f4931cdd5792322f6fe39143cfa3bfa5e98ab944511  metal_office_desk.usdz
ddf665fc24dbda1019d726c54288afc71500758c5bddd3289dc4cb87fc194bba  metal_tool_chest.usdz
d253968b18ad9982405358c23428602936c0c8342e1d225fdd4041e854619871  metal_trash_can.usdz
c11bdb1dbad63f969123893423f44a7865558d5883759efac6d3e3697907a7a9  plastic_crate_02.usdz
6866f6d1b1d3323d522d261a89b6a9c79907c3ae5a8b6c7d9d1daf3d9204ce3a  plastic_monobloc_chair_01.usdz
247cb86f3662b3cdc532229875c3e2ac56d986d5044b967cc51e9499d6fb60a0  power_box_01.usdz
738a489ba9b5aebb46539e4c1a5e22488709b3804b21f3deaf1c72677fcff4f6  SchoolChair_01.usdz
b21c081a220d72d0f837170f3dbe6c319db62910efa54b5d7f7bd7bced252596  SchoolDesk_01.usdz
ee59094614b7e7a096dab1f7fd934b6dc9d5cc1b277382418481ebe896ade92a  security_camera_01.usdz
683484e342a13f68b78dda26ab97e0861d0ff36cbe2bbe39e4b4162b3cdb953b  stairs.usdz
a809a38664d4e8a65bb067d89a9f74985c1bc24c297b855fa14af4eed807700b  steel_frame_shelves_01.usdz
2e84220a7d8db7ca03254c303be3f017ed5c07a080e86f9d94b15a18688af6d0  table.usdz
dc44f800926690dc281aed2f7fccb9340d70e253395c26ee59a80af3e097eaea  television_02.usdz
a1f811cf0f1e9b4d8f3ca52e6ac0783d33e04809d97a8badda1a432e3b269819  televisionModern.usdz
b6b52edf4f9d1403a261bf2ab56dd86f7a92840d0346ea23663f17510d972ff9  toilet.usdz
e9f71c22852b4d505872ee41211c7e52297f09a683309a3f50fb36e3328468fe  vintage_wooden_drawer_01.usdz
9b83332d0db22eab9b514ee5a727acad1d846545785f763c558786e5bc165767  wall_clock.usdz
76d9e6d877d7003c51a503a1c6f890a7b85e9430363daa01f65a2cbb8fd72a16  washerDryerStacked.usdz
080f512792bcbfdaf913200c3b1e3f1a162c46b16d1ab655ae1b965617c74601  WetFloorSign_01.usdz
842aedb3aa03d4fa34d5e78eb6e7cdf67a2e0da8a26d389b05181bfc494bee8b  wooden_crate_02.usdz
56fe820ab98f0bad3ba2fdaef340dd9a015b8020802b4859172d343445dba69f  wooden_stool_01.usdz
````

## `CineAR/RoomRealityRenderer.swift`

````swift
import Foundation
import RealityKit
import RoomPlan
import simd

/// Gerçek USDZ kataloğu eklendiğinde prosedürel mobilyaların yerini alacak uzantı noktası.
/// Sağlanan entity kendi merkezinde olmalı ve `targetDimensions` sınırına sığmalıdır.
@MainActor
protocol RoomRealityAssetProviding: AnyObject {
    func makeEntity(
        for role: RealityObjectRole,
        theme: RealityTheme,
        targetDimensions: SIMD3<Float>
    ) -> Entity?
}

struct RoomRealityRenderReport: Sendable {
    let wallCount: Int
    let floorCount: Int
    let ceilingCount: Int
    let portalCount: Int
    let objectCount: Int
    let skippedElementCount: Int
    /// Düzensiz poligonlar, compile-safe ince kutu şeritleriyle yaklaşıklandı.
    let polygonApproximationCount: Int
    let inferredPortalAssociationCount: Int
    let unmatchedPortalCount: Int
    let suppressedNestedObjectCount: Int

    var renderedElementCount: Int {
        wallCount + floorCount + ceilingCount + portalCount + objectCount
    }

    var usesPolygonApproximation: Bool {
        polygonApproximationCount > 0
    }

    var geometryNotice: String? {
        guard usesPolygonApproximation else { return nil }
        return "\(polygonApproximationCount) düzensiz yüzey ince kutu şeritleriyle yaklaşıklandı; eğri yüzeyler düzlemselleştirildi"
    }
}

enum RoomRealityRendererError: LocalizedError {
    case invalidAlignmentTransform
    case emptyRoom
    case roomFileIsNotLocal

    var errorDescription: String? {
        switch self {
        case .invalidAlignmentTransform:
            "Tarama ile AR sahnesi arasındaki hizalama matrisi geçersiz"
        case .emptyRoom:
            "Taramada dönüştürülebilecek bir oda öğesi bulunamadı"
        case .roomFileIsNotLocal:
            "room.json yerel bir dosya olmalıdır"
        }
    }
}

/// RoomPlan'in parametrik sonucunu tek bir RealityKit kökü altında sanal sete çevirir.
/// Bu kök manuel eklenen dekor anchor'larından bağımsızdır.
@MainActor
final class RoomRealityRenderer {
    let rootEntity: AnchorEntity

    private var contentEntity = Entity()
    private let physicalOcclusionRootEntity: AnchorEntity
    private var physicalOcclusionContentEntity = Entity()
    private let assetProvider: (any RoomRealityAssetProviding)?
    private weak var installedARView: ARView?
    private var lastRoom: CapturedRoom?
    private var lastAlignmentTransform = matrix_identity_float4x4
    private var generatedBoxCount = 0

    /// RoomPlan can return very dense polygons and duplicate classifications. Keeping a
    /// hard upper bound prevents a malformed or unusually detailed scan from exhausting
    /// the device while RealityKit is creating the replacement room.
    private static let maximumGeneratedBoxCount = 600
    private static let maximumWalls = 24
    private static let maximumFloors = 8
    private static let maximumPortalsPerKind = 24
    private static let maximumObjects = 48
    private static let maximumSurfaceSegments = 16
    private static let maximumIrregularBands = 12
    private static let unitBoxMesh = MeshResource.generateBox(size: 1)
    private static let roundedUnitBoxMesh = MeshResource.generateBox(
        size: SIMD3<Float>(repeating: 1),
        cornerRadius: 0.02
    )
    private static let unitBoxCollisionShape = ShapeResource.generateBox(
        size: SIMD3<Float>(repeating: 1)
    )

    private(set) var selectedThemeID: RealityThemeID = .modern
    private(set) var lastReport: RoomRealityRenderReport?
    private(set) var hasPreparedOutline = false
    private(set) var hasPreparedPhysicalOcclusion = false

    init(assetProvider: (any RoomRealityAssetProviding)? = nil) {
        self.assetProvider = assetProvider
        rootEntity = AnchorEntity(world: .zero)
        physicalOcclusionRootEntity = AnchorEntity(world: .zero)
        rootEntity.name = "cinear.reality.room.root"
        contentEntity.name = "cinear.reality.room.content"
        rootEntity.addChild(contentEntity)
        physicalOcclusionRootEntity.name = "cinear.reality.physical-occlusion.root"
        physicalOcclusionContentEntity.name = "cinear.reality.physical-occlusion.content"
        physicalOcclusionRootEntity.addChild(physicalOcclusionContentEntity)
        physicalOcclusionRootEntity.isEnabled = false
    }

    var isVisible: Bool {
        get { rootEntity.isEnabled }
        set { rootEntity.isEnabled = newValue }
    }

    var isPhysicalOcclusionVisible: Bool {
        get { physicalOcclusionRootEntity.isEnabled }
        set {
            physicalOcclusionRootEntity.isEnabled = newValue && hasPreparedPhysicalOcclusion
        }
    }

    /// Renderer kökünü ARView'a yalnız bir kez takar; mevcut manuel dekorlara dokunmaz.
    func install(in arView: ARView) {
        if installedARView !== arView {
            installedARView?.scene.removeAnchor(rootEntity)
            installedARView?.scene.removeAnchor(physicalOcclusionRootEntity)
        }
        if rootEntity.scene !== arView.scene {
            rootEntity.scene?.removeAnchor(rootEntity)
            arView.scene.addAnchor(rootEntity)
        }
        if physicalOcclusionRootEntity.scene !== arView.scene {
            physicalOcclusionRootEntity.scene?.removeAnchor(physicalOcclusionRootEntity)
            arView.scene.addAnchor(physicalOcclusionRootEntity)
        }
        installedARView = arView
    }

    func removeFromScene() {
        installedARView?.scene.removeAnchor(rootEntity)
        installedARView?.scene.removeAnchor(physicalOcclusionRootEntity)
        installedARView = nil
    }

    /// Returns the closest visible RoomPlan replacement surface below a screen point.
    /// ARKit raycasts only know about live planes/mesh; they cannot hit this renderer's
    /// virtual floor, walls, or reconstructed furniture.
    func placementHit(in arView: ARView, at point: CGPoint) -> CollisionCastHit? {
        guard installedARView === arView, isVisible else { return nil }
        return arView.hitTest(point, query: .all, mask: .all).first {
            belongsToRenderedRoom($0.entity)
        }
    }

    func clear() {
        contentEntity.removeFromParent()
        contentEntity = Entity()
        contentEntity.name = "cinear.reality.room.content"
        rootEntity.addChild(contentEntity)
        physicalOcclusionContentEntity.removeFromParent()
        physicalOcclusionContentEntity = Entity()
        physicalOcclusionContentEntity.name = "cinear.reality.physical-occlusion.content"
        physicalOcclusionRootEntity.addChild(physicalOcclusionContentEntity)
        physicalOcclusionRootEntity.isEnabled = false
        lastRoom = nil
        lastReport = nil
        hasPreparedOutline = false
        hasPreparedPhysicalOcclusion = false
        lastAlignmentTransform = matrix_identity_float4x4
        contentEntity.transform = .identity
    }

    /// Gerçek kamera görünümünde RoomPlan'ın tanıdığı mobilyaları görünmez derinlik
    /// yazıcılarına çevirir. Böylece örneğin gerçek bir masa, arkasındaki sanal
    /// dekoru canlı LiDAR mesh'i kısa süreli kaçırsa bile doğru biçimde örter.
    @discardableResult
    func preparePhysicalOcclusion(
        roomJSONURL: URL,
        alignmentTransform: simd_float4x4 = matrix_identity_float4x4
    ) throws -> Int {
        let room = try Self.loadRoomJSON(from: roomJSONURL)
        guard Self.isValidAffineTransform(alignmentTransform) else {
            throw RoomRealityRendererError.invalidAlignmentTransform
        }

        let stagingEntity = Entity()
        stagingEntity.name = "cinear.reality.physical-occlusion.content"
        stagingEntity.transform = Transform(matrix: alignmentTransform)

        let objects = Array(room.objects.prefix(Self.maximumObjects))
        var objectsByID: [UUID: CapturedRoom.Object] = [:]
        for object in objects where objectsByID[object.identifier] == nil {
            objectsByID[object.identifier] = object
        }
        let suppressedIDs = nestedObjectIDsToSuppress(objectsByID: objectsByID)
        var count = 0
        for object in objects where !suppressedIDs.contains(object.identifier) {
            guard let occluder = makePhysicalOcclusionEntity(object) else { continue }
            stagingEntity.addChild(occluder)
            count += 1
        }

        physicalOcclusionContentEntity.removeFromParent()
        physicalOcclusionContentEntity = stagingEntity
        physicalOcclusionRootEntity.addChild(physicalOcclusionContentEntity)
        hasPreparedPhysicalOcclusion = count > 0
        physicalOcclusionRootEntity.isEnabled = count > 0
        return count
    }

    /// `alignmentTransform`, taramadaki dünya koordinatlarını etkin ARSession koordinatlarına taşır.
    /// Aynı ARSession sürdürüldüğünde identity matrisi yeterlidir.
    @discardableResult
    func render(
        room: CapturedRoom,
        theme: RealityTheme,
        alignmentTransform: simd_float4x4 = matrix_identity_float4x4
    ) throws -> RoomRealityRenderReport {
        guard Self.isValidAffineTransform(alignmentTransform) else {
            throw RoomRealityRendererError.invalidAlignmentTransform
        }

        generatedBoxCount = 0

        let stagingEntity = Entity()
        stagingEntity.name = "cinear.reality.room.content"
        stagingEntity.transform = Transform(matrix: alignmentTransform)

        let walls = Array(room.walls.prefix(Self.maximumWalls))
        let floors = Array(room.floors.prefix(Self.maximumFloors))
        let doors = Array(room.doors.prefix(Self.maximumPortalsPerKind))
        let windows = Array(room.windows.prefix(Self.maximumPortalsPerKind))
        let openings = Array(room.openings.prefix(Self.maximumPortalsPerKind))
        let objects = Array(room.objects.prefix(Self.maximumObjects))
        let apertures = doors + windows + openings
        let portalAssociations = associate(apertures: apertures, with: walls)
        var wallCount = 0
        var floorCount = 0
        var ceilingCount = 0
        var portalCount = 0
        var objectCount = 0
        var skippedCount =
            (room.walls.count - walls.count)
            + (room.floors.count - floors.count)
            + (room.doors.count - doors.count)
            + (room.windows.count - windows.count)
            + (room.openings.count - openings.count)
            + (room.objects.count - objects.count)
        var polygonApproximationCount = 0
        var suppressedNestedObjectCount = 0

        for wall in walls {
            let children = portalAssociations.aperturesByWallID[wall.identifier] ?? []
            if let entity = makeWallEntity(wall, apertures: children, theme: theme) {
                stagingEntity.addChild(entity)
                wallCount += 1
                if Self.requiresPolygonApproximation(wall) {
                    polygonApproximationCount += 1
                }
            } else {
                skippedCount += 1
            }
        }

        for floor in floors {
            if let entity = makePlanarSurfaceEntity(floor, role: .floor, theme: theme) {
                stagingEntity.addChild(entity)
                floorCount += 1
                if Self.requiresPolygonApproximation(floor) {
                    polygonApproximationCount += 1
                }
            } else {
                skippedCount += 1
            }
        }

        if let ceilingY = inferredCeilingY(walls: walls, floors: floors) {
            if floors.isEmpty {
                if let ceiling = makeFallbackCeilingEntity(
                    from: walls,
                    ceilingY: ceilingY,
                    theme: theme
                ) {
                    stagingEntity.addChild(ceiling)
                    ceilingCount = 1
                    polygonApproximationCount += 1
                }
            } else {
                for floor in floors {
                    if let ceiling = makeCeilingEntity(
                        from: floor,
                        ceilingY: ceilingY,
                        theme: theme
                    ) {
                        stagingEntity.addChild(ceiling)
                        ceilingCount += 1
                        if Self.requiresPolygonApproximation(floor) {
                            polygonApproximationCount += 1
                        }
                    }
                }
            }
        }

        for door in doors {
            let role: RealitySurfaceRole
            if case .door(let isOpen) = door.category, isOpen {
                role = .opening
            } else {
                role = .door
            }
            if let entity = makePortalEntity(door, role: role, theme: theme) {
                stagingEntity.addChild(entity)
                portalCount += 1
                if Self.requiresPolygonApproximation(door) {
                    polygonApproximationCount += 1
                }
            } else {
                skippedCount += 1
            }
        }

        for window in windows {
            if let entity = makePortalEntity(window, role: .window, theme: theme) {
                stagingEntity.addChild(entity)
                portalCount += 1
                if Self.requiresPolygonApproximation(window) {
                    polygonApproximationCount += 1
                }
            } else {
                skippedCount += 1
            }
        }

        for opening in openings {
            if let entity = makePortalEntity(opening, role: .opening, theme: theme) {
                stagingEntity.addChild(entity)
                portalCount += 1
                if Self.requiresPolygonApproximation(opening) {
                    polygonApproximationCount += 1
                }
            } else {
                skippedCount += 1
            }
        }

        var objectsByID: [UUID: CapturedRoom.Object] = [:]
        for object in objects where objectsByID[object.identifier] == nil {
            objectsByID[object.identifier] = object
        }
        let suppressedObjectIDs = nestedObjectIDsToSuppress(objectsByID: objectsByID)
        suppressedNestedObjectCount = suppressedObjectIDs.count
        for object in objects {
            if suppressedObjectIDs.contains(object.identifier) { continue }
            if let entity = makeObjectEntity(object, theme: theme) {
                stagingEntity.addChild(entity)
                objectCount += 1
            } else {
                skippedCount += 1
            }
        }

        let report = RoomRealityRenderReport(
            wallCount: wallCount,
            floorCount: floorCount,
            ceilingCount: ceilingCount,
            portalCount: portalCount,
            objectCount: objectCount,
            skippedElementCount: skippedCount,
            polygonApproximationCount: polygonApproximationCount,
            inferredPortalAssociationCount: portalAssociations.inferredCount,
            unmatchedPortalCount: portalAssociations.unmatchedCount,
            suppressedNestedObjectCount: suppressedNestedObjectCount
        )
        guard report.renderedElementCount > 0 else {
            throw RoomRealityRendererError.emptyRoom
        }

        contentEntity.removeFromParent()
        contentEntity = stagingEntity
        rootEntity.addChild(contentEntity)
        selectedThemeID = theme.id
        hasPreparedOutline = false
        lastRoom = room
        lastAlignmentTransform = alignmentTransform
        lastReport = report
        return report
    }

    /// Aynı taramayı bozmadan yalnız materyal/şekil temasını değiştirir.
    @discardableResult
    func apply(theme: RealityTheme) throws -> RoomRealityRenderReport {
        guard let lastRoom else { throw RoomRealityRendererError.emptyRoom }
        return try render(
            room: lastRoom,
            theme: theme,
            alignmentTransform: lastAlignmentTransform
        )
    }

    @discardableResult
    func render(
        roomJSONURL: URL,
        theme: RealityTheme,
        alignmentTransform: simd_float4x4 = matrix_identity_float4x4
    ) throws -> RoomRealityRenderReport {
        let room = try Self.loadRoomJSON(from: roomJSONURL)
        return try render(
            room: room,
            theme: theme,
            alignmentTransform: alignmentTransform
        )
    }

    /// Kamerayı kapatmadan RoomPlan sonucunu ince beyaz hatlar halinde gösterir.
    /// Görsel parçalar collision üretmez; yüzey başına tek görünmez collider kullanılır.
    /// Böylece hem çizim maliyeti düşük kalır hem de kullanıcı taranmış zeminin tamamına
    /// dekor yerleştirebilir.
    @discardableResult
    func renderOutline(
        roomJSONURL: URL,
        alignmentTransform: simd_float4x4 = matrix_identity_float4x4
    ) throws -> RoomRealityRenderReport {
        let room = try Self.loadRoomJSON(from: roomJSONURL)
        return try renderOutline(room: room, alignmentTransform: alignmentTransform)
    }

    @discardableResult
    func renderOutline(
        room: CapturedRoom,
        alignmentTransform: simd_float4x4 = matrix_identity_float4x4
    ) throws -> RoomRealityRenderReport {
        guard Self.isValidAffineTransform(alignmentTransform) else {
            throw RoomRealityRendererError.invalidAlignmentTransform
        }

        generatedBoxCount = 0
        let stagingEntity = Entity()
        stagingEntity.name = "cinear.reality.room.content"
        stagingEntity.transform = Transform(matrix: alignmentTransform)

        let walls = Array(room.walls.prefix(Self.maximumWalls))
        let floors = Array(room.floors.prefix(Self.maximumFloors))
        let doors = Array(room.doors.prefix(Self.maximumPortalsPerKind))
        let windows = Array(room.windows.prefix(Self.maximumPortalsPerKind))
        let openings = Array(room.openings.prefix(Self.maximumPortalsPerKind))
        let objects = Array(room.objects.prefix(Self.maximumObjects))

        let whiteLine = RealityMaterialRecipe(
            1, 1, 1,
            alpha: 0.72,
            roughness: 0.18
        ).makeMaterial()
        let objectLine = RealityMaterialRecipe(
            0.82, 0.94, 1,
            alpha: 0.58,
            roughness: 0.18
        ).makeMaterial()

        var wallCount = 0
        var floorCount = 0
        var portalCount = 0
        var objectCount = 0
        var skippedCount =
            (room.walls.count - walls.count)
            + (room.floors.count - floors.count)
            + (room.doors.count - doors.count)
            + (room.windows.count - windows.count)
            + (room.openings.count - openings.count)
            + (room.objects.count - objects.count)

        for surface in walls {
            if let entity = makeSurfaceOutlineEntity(surface, material: whiteLine) {
                stagingEntity.addChild(entity)
                wallCount += 1
            } else {
                skippedCount += 1
            }
        }
        for surface in floors {
            if let entity = makeSurfaceOutlineEntity(surface, material: whiteLine) {
                stagingEntity.addChild(entity)
                floorCount += 1
            } else {
                skippedCount += 1
            }
        }
        for surface in doors + windows + openings {
            if let entity = makeSurfaceOutlineEntity(surface, material: whiteLine) {
                stagingEntity.addChild(entity)
                portalCount += 1
            } else {
                skippedCount += 1
            }
        }

        var objectsByID: [UUID: CapturedRoom.Object] = [:]
        for object in objects where objectsByID[object.identifier] == nil {
            objectsByID[object.identifier] = object
        }
        let suppressedObjectIDs = nestedObjectIDsToSuppress(objectsByID: objectsByID)
        for object in objects where !suppressedObjectIDs.contains(object.identifier) {
            if let entity = makeObjectOutlineEntity(object, material: objectLine) {
                stagingEntity.addChild(entity)
                objectCount += 1
            } else {
                skippedCount += 1
            }
        }

        let report = RoomRealityRenderReport(
            wallCount: wallCount,
            floorCount: floorCount,
            ceilingCount: 0,
            portalCount: portalCount,
            objectCount: objectCount,
            skippedElementCount: skippedCount,
            polygonApproximationCount: 0,
            inferredPortalAssociationCount: 0,
            unmatchedPortalCount: 0,
            suppressedNestedObjectCount: suppressedObjectIDs.count
        )
        guard report.renderedElementCount > 0 else {
            throw RoomRealityRendererError.emptyRoom
        }

        contentEntity.removeFromParent()
        contentEntity = stagingEntity
        rootEntity.addChild(contentEntity)
        hasPreparedOutline = true
        lastRoom = room
        lastAlignmentTransform = alignmentTransform
        lastReport = report
        return report
    }

    static func loadRoomJSON(from url: URL) throws -> CapturedRoom {
        guard url.isFileURL else { throw RoomRealityRendererError.roomFileIsNotLocal }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try JSONDecoder().decode(CapturedRoom.self, from: data)
    }

    func inferredCeilingLevel(roomJSONURL: URL) throws -> Float? {
        let room = try Self.loadRoomJSON(from: roomJSONURL)
        return inferredCeilingY(walls: room.walls, floors: room.floors)
    }

    static func saveRoomJSON(_ room: CapturedRoom, to url: URL) throws {
        guard url.isFileURL else { throw RoomRealityRendererError.roomFileIsNotLocal }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(room)
        try data.write(to: url, options: [.atomic])
    }
}

// MARK: - Room surfaces

private extension RoomRealityRenderer {
    struct ApertureRect {
        let minX: Float
        let maxX: Float
        let minY: Float
        let maxY: Float
    }

    struct PlanarBounds {
        let minX: Float
        let maxX: Float
        let minY: Float
        let maxY: Float

        var width: Float { maxX - minX }
        var height: Float { maxY - minY }
        var center: SIMD2<Float> {
            [(minX + maxX) * 0.5, (minY + maxY) * 0.5]
        }
    }

    struct PortalAssociations {
        var aperturesByWallID: [UUID: [CapturedRoom.Surface]] = [:]
        var inferredCount = 0
        var unmatchedCount = 0
    }

    func makeSurfaceOutlineEntity(
        _ surface: CapturedRoom.Surface,
        material: PhysicallyBasedMaterial
    ) -> Entity? {
        guard let bounds = Self.surfaceBounds(surface),
              Self.isValidAffineTransform(surface.transform) else { return nil }

        let root = Entity()
        root.name = "cinear.reality.outline.surface.\(surface.identifier.uuidString)"
        root.transform = Transform(matrix: surface.transform)
        let lineWidth: Float = 0.018
        let lineDepth: Float = 0.035
        let center = bounds.center
        let countBefore = generatedBoxCount

        addBox(
            to: root,
            size: [bounds.width, lineWidth, lineDepth],
            position: [center.x, bounds.minY, 0],
            material: material,
            includeCollision: false
        )
        addBox(
            to: root,
            size: [bounds.width, lineWidth, lineDepth],
            position: [center.x, bounds.maxY, 0],
            material: material,
            includeCollision: false
        )
        addBox(
            to: root,
            size: [lineWidth, bounds.height, lineDepth],
            position: [bounds.minX, center.y, 0],
            material: material,
            includeCollision: false
        )
        addBox(
            to: root,
            size: [lineWidth, bounds.height, lineDepth],
            position: [bounds.maxX, center.y, 0],
            material: material,
            includeCollision: false
        )

        let collider = Entity()
        collider.name = "cinear.reality.outline.surface.collider"
        collider.position = [center.x, center.y, 0]
        collider.scale = [bounds.width, bounds.height, 0.04]
        collider.components.set(
            CollisionComponent(shapes: [Self.unitBoxCollisionShape])
        )
        root.addChild(collider)
        return generatedBoxCount > countBefore ? root : nil
    }

    func makeWallEntity(
        _ wall: CapturedRoom.Surface,
        apertures: [CapturedRoom.Surface],
        theme: RealityTheme
    ) -> Entity? {
        guard let bounds = Self.surfaceBounds(wall),
              Self.isValidAffineTransform(wall.transform) else { return nil }

        let root = Entity()
        root.name = "cinear.reality.wall.\(wall.identifier.uuidString)"
        root.transform = Transform(matrix: wall.transform)

        let wallMaterial = theme.materialRecipe(for: .wall).makeMaterial()
        let cutouts = apertures.compactMap {
            apertureRect($0, relativeTo: wall, wallBounds: bounds)
        }
        let polygon = Self.localPolygon(for: wall) ?? Self.rectanglePolygon(bounds)
        let wallSegmentCount = addPlanarFill(
            to: root,
            polygon: polygon,
            bounds: bounds,
            cutouts: cutouts,
            thickness: theme.surfaceThickness,
            material: wallMaterial
        )

        if generatedBoxCount < 320 {
            let baseboardHeight = min(max(bounds.height * 0.025, 0.035), 0.09)
            _ = addPlanarFill(
                to: root,
                polygon: polygon,
                bounds: bounds,
                cutouts: cutouts,
                thickness: theme.surfaceThickness * 1.45,
                material: theme.materialRecipe(for: .trim).makeMaterial(),
                yClip: (lower: bounds.minY, upper: bounds.minY + baseboardHeight),
                zOffset: theme.surfaceThickness * 0.18,
                cornerRadius: 0.006
            )
        }
        guard wallSegmentCount > 0 else { return nil }
        return root
    }

    func makePlanarSurfaceEntity(
        _ surface: CapturedRoom.Surface,
        role: RealitySurfaceRole,
        theme: RealityTheme
    ) -> Entity? {
        guard let bounds = Self.surfaceBounds(surface),
              Self.isValidAffineTransform(surface.transform) else { return nil }

        let root = Entity()
        root.name = "cinear.reality.surface.\(surface.identifier.uuidString)"
        root.transform = Transform(matrix: surface.transform)
        let polygon = Self.localPolygon(for: surface) ?? Self.rectanglePolygon(bounds)
        let segmentCount = addPlanarFill(
            to: root,
            polygon: polygon,
            bounds: bounds,
            cutouts: [],
            thickness: theme.surfaceThickness,
            material: theme.materialRecipe(for: role).makeMaterial()
        )
        return segmentCount > 0 ? root : nil
    }

    func inferredCeilingY(
        walls: [CapturedRoom.Surface],
        floors: [CapturedRoom.Surface]
    ) -> Float? {
        let wallTops = walls.compactMap { wall -> Float? in
            guard let bounds = Self.surfaceBounds(wall),
                  Self.isValidAffineTransform(wall.transform) else { return nil }
            let top = wall.transform * SIMD4<Float>(bounds.center.x, bounds.maxY, 0, 1)
            return top.y.isFinite ? top.y : nil
        }.sorted()
        guard !wallTops.isEmpty else { return nil }

        let medianTop = wallTops[wallTops.count / 2]
        let floorLevels = floors.compactMap { floor -> Float? in
            guard Self.isValidAffineTransform(floor.transform) else { return nil }
            let y = floor.transform.columns.3.y
            return y.isFinite ? y : nil
        }.sorted()

        let floorY: Float
        if floorLevels.isEmpty {
            let wallBottoms = walls.compactMap { wall -> Float? in
                guard let bounds = Self.surfaceBounds(wall),
                      Self.isValidAffineTransform(wall.transform) else { return nil }
                let bottom = wall.transform * SIMD4<Float>(bounds.center.x, bounds.minY, 0, 1)
                return bottom.y.isFinite ? bottom.y : nil
            }.sorted()
            guard !wallBottoms.isEmpty else { return nil }
            floorY = wallBottoms[wallBottoms.count / 2]
        } else {
            floorY = floorLevels[floorLevels.count / 2]
        }

        let roomHeight = medianTop - floorY
        guard roomHeight >= 1.7, roomHeight <= 6.5 else { return nil }
        return medianTop
    }

    func makeCeilingEntity(
        from floor: CapturedRoom.Surface,
        ceilingY: Float,
        theme: RealityTheme
    ) -> Entity? {
        guard let bounds = Self.surfaceBounds(floor),
              Self.isValidAffineTransform(floor.transform), ceilingY.isFinite else { return nil }
        var transform = floor.transform
        transform.columns.3.y = ceilingY

        let root = Entity()
        root.name = "cinear.reality.ceiling.\(floor.identifier.uuidString)"
        root.transform = Transform(matrix: transform)
        let polygon = Self.localPolygon(for: floor) ?? Self.rectanglePolygon(bounds)
        let segmentCount = addPlanarFill(
            to: root,
            polygon: polygon,
            bounds: bounds,
            cutouts: [],
            thickness: theme.surfaceThickness,
            material: theme.materialRecipe(for: .ceiling).makeMaterial()
        )
        return segmentCount > 0 ? root : nil
    }

    func makeFallbackCeilingEntity(
        from walls: [CapturedRoom.Surface],
        ceilingY: Float,
        theme: RealityTheme
    ) -> Entity? {
        var points: [SIMD3<Float>] = []
        for wall in walls {
            guard let bounds = Self.surfaceBounds(wall),
                  Self.isValidAffineTransform(wall.transform) else { continue }
            let polygon = Self.localPolygon(for: wall) ?? Self.rectanglePolygon(bounds)
            for corner in polygon {
                let point = wall.transform * SIMD4<Float>(corner.x, corner.y, 0, 1)
                guard point.x.isFinite, point.z.isFinite else { continue }
                points.append([point.x, ceilingY, point.z])
            }
        }
        guard let first = points.first else { return nil }

        var minX = first.x
        var maxX = first.x
        var minZ = first.z
        var maxZ = first.z
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minZ = min(minZ, point.z)
            maxZ = max(maxZ, point.z)
        }
        let width = maxX - minX
        let depth = maxZ - minZ
        guard width >= 0.5, depth >= 0.5, width <= 15, depth <= 15 else { return nil }

        let root = Entity()
        root.name = "cinear.reality.ceiling.inferred"
        root.position = [(minX + maxX) * 0.5, ceilingY, (minZ + maxZ) * 0.5]
        guard addBox(
            to: root,
            size: [width, theme.surfaceThickness, depth],
            position: .zero,
            material: theme.materialRecipe(for: .ceiling).makeMaterial()
        ) else { return nil }
        return root
    }

    func makePortalEntity(
        _ surface: CapturedRoom.Surface,
        role: RealitySurfaceRole,
        theme: RealityTheme
    ) -> Entity? {
        guard let bounds = Self.surfaceBounds(surface),
              Self.isValidAffineTransform(surface.transform) else { return nil }

        let width = bounds.width
        let height = bounds.height
        let center = bounds.center
        let root = Entity()
        root.name = "cinear.reality.portal.\(surface.identifier.uuidString)"
        root.transform = Transform(matrix: surface.transform)
        var didAddGeometry = false

        let panelThickness = theme.surfaceThickness * 0.62
        if role != .opening {
            let polygon = Self.localPolygon(for: surface) ?? Self.rectanglePolygon(bounds)
            let panelCornerRadius: Float = Self.isAxisAlignedRectangle(polygon)
                ? (role == .door ? 0.012 : 0.004)
                : 0
            didAddGeometry = addPlanarFill(
                to: root,
                polygon: polygon,
                bounds: bounds,
                cutouts: [],
                thickness: panelThickness,
                material: theme.materialRecipe(for: role).makeMaterial(),
                zOffset: theme.surfaceThickness * 0.62,
                cornerRadius: panelCornerRadius
            ) > 0
        }

        let trimWidth = min(max(min(width, height) * 0.035, 0.025), 0.075)
        let trimDepth = theme.surfaceThickness * 1.35
        let trimMaterial = theme.materialRecipe(for: .trim).makeMaterial()
        let z = theme.surfaceThickness * 0.78

        if addBox(
            to: root,
            size: [trimWidth, height + trimWidth, trimDepth],
            position: [bounds.minX - trimWidth * 0.5, center.y, z],
            material: trimMaterial,
            cornerRadius: 0.005
        ) { didAddGeometry = true }
        if addBox(
            to: root,
            size: [trimWidth, height + trimWidth, trimDepth],
            position: [bounds.maxX + trimWidth * 0.5, center.y, z],
            material: trimMaterial,
            cornerRadius: 0.005
        ) { didAddGeometry = true }
        if addBox(
            to: root,
            size: [width + trimWidth * 2, trimWidth, trimDepth],
            position: [center.x, bounds.maxY + trimWidth * 0.5, z],
            material: trimMaterial,
            cornerRadius: 0.005
        ) { didAddGeometry = true }
        if role == .window || role == .opening {
            if addBox(
                to: root,
                size: [width + trimWidth * 2, trimWidth, trimDepth],
                position: [center.x, bounds.minY - trimWidth * 0.5, z],
                material: trimMaterial,
                cornerRadius: 0.005
            ) { didAddGeometry = true }
        }
        return didAddGeometry ? root : nil
    }

    func apertureRect(
        _ aperture: CapturedRoom.Surface,
        relativeTo wall: CapturedRoom.Surface,
        wallBounds: PlanarBounds
    ) -> ApertureRect? {
        guard let apertureBounds = Self.surfaceBounds(aperture),
              Self.isValidAffineTransform(aperture.transform),
              Self.isValidAffineTransform(wall.transform) else { return nil }

        let relativeTransform = simd_inverse(wall.transform) * aperture.transform
        guard Self.isValidAffineTransform(relativeTransform) else { return nil }
        let aperturePolygon = Self.localPolygon(for: aperture)
            ?? Self.rectanglePolygon(apertureBounds)
        let transformedCorners = aperturePolygon.compactMap { corner -> SIMD2<Float>? in
            let point = relativeTransform * SIMD4<Float>(corner.x, corner.y, 0, 1)
            guard point.x.isFinite, point.y.isFinite else { return nil }
            return [point.x, point.y]
        }
        guard let first = transformedCorners.first,
              transformedCorners.count == aperturePolygon.count else { return nil }

        var apertureMinX = first.x
        var apertureMaxX = first.x
        var apertureMinY = first.y
        var apertureMaxY = first.y
        for point in transformedCorners.dropFirst() {
            apertureMinX = min(apertureMinX, point.x)
            apertureMaxX = max(apertureMaxX, point.x)
            apertureMinY = min(apertureMinY, point.y)
            apertureMaxY = max(apertureMaxY, point.y)
        }
        let margin: Float = 0.012

        let minX = max(apertureMinX - margin, wallBounds.minX)
        let maxX = min(apertureMaxX + margin, wallBounds.maxX)
        let minY = max(apertureMinY - margin, wallBounds.minY)
        let maxY = min(apertureMaxY + margin, wallBounds.maxY)
        guard maxX - minX > 0.015, maxY - minY > 0.015 else { return nil }
        return ApertureRect(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }

    @discardableResult
    func addPlanarFill(
        to root: Entity,
        polygon: [SIMD2<Float>],
        bounds: PlanarBounds,
        cutouts: [ApertureRect],
        thickness: Float,
        material: PhysicallyBasedMaterial,
        yClip: (lower: Float, upper: Float)? = nil,
        zOffset: Float = 0,
        cornerRadius: Float = 0
    ) -> Int {
        guard generatedBoxCount < Self.maximumGeneratedBoxCount else { return 0 }
        var xBoundaries = [bounds.minX, bounds.maxX]
        for cutout in cutouts {
            xBoundaries.append(cutout.minX)
            xBoundaries.append(cutout.maxX)
        }

        if !Self.isAxisAlignedRectangle(polygon) {
            let stripCount = min(
                max(Int((bounds.width / 0.18).rounded(.up)), 1),
                Self.maximumIrregularBands
            )
            if stripCount > 1 {
                for index in 1..<stripCount {
                    xBoundaries.append(
                        bounds.minX + bounds.width * Float(index) / Float(stripCount)
                    )
                }
            }
        }
        xBoundaries.sort()
        xBoundaries = xBoundaries.reduce(into: []) { result, value in
            if let last = result.last, abs(last - value) < 0.004 { return }
            result.append(value)
        }

        guard xBoundaries.count >= 2 else { return 0 }
        var segmentCount = 0
        for index in 0..<(xBoundaries.count - 1) {
            guard segmentCount < Self.maximumSurfaceSegments,
                  generatedBoxCount < Self.maximumGeneratedBoxCount else {
                return segmentCount
            }
            let bandMinX = xBoundaries[index]
            let bandMaxX = xBoundaries[index + 1]
            let bandWidth = bandMaxX - bandMinX
            guard bandWidth > 0.012 else { continue }

            let midpoint = (bandMinX + bandMaxX) * 0.5
            let polygonIntervals = Self.verticalIntervals(in: polygon, atX: midpoint)
            let blocked = cutouts
                .filter { midpoint > $0.minX && midpoint < $0.maxX }
                .map { (lower: $0.minY, upper: $0.maxY) }
                .sorted { $0.lower < $1.lower }
            let merged = Self.mergeIntervals(blocked)

            for polygonInterval in polygonIntervals {
                let allowedLower = max(
                    polygonInterval.lower,
                    yClip?.lower ?? polygonInterval.lower
                )
                let allowedUpper = min(
                    polygonInterval.upper,
                    yClip?.upper ?? polygonInterval.upper
                )
                guard allowedUpper - allowedLower > 0.012 else { continue }

                var cursor = allowedLower
                for interval in merged {
                    guard interval.upper > allowedLower,
                          interval.lower < allowedUpper else { continue }
                    let blockLower = max(interval.lower, allowedLower)
                    let blockUpper = min(interval.upper, allowedUpper)
                    if blockLower > cursor {
                        guard segmentCount < Self.maximumSurfaceSegments else {
                            return segmentCount
                        }
                        if addPlanarSegment(
                            to: root,
                            minX: bandMinX,
                            maxX: bandMaxX,
                            minY: cursor,
                            maxY: blockLower,
                            thickness: thickness,
                            material: material,
                            zOffset: zOffset,
                            cornerRadius: cornerRadius
                        ) {
                            segmentCount += 1
                        }
                    }
                    cursor = max(cursor, blockUpper)
                }
                if cursor < allowedUpper {
                    guard segmentCount < Self.maximumSurfaceSegments else {
                        return segmentCount
                    }
                    if addPlanarSegment(
                        to: root,
                        minX: bandMinX,
                        maxX: bandMaxX,
                        minY: cursor,
                        maxY: allowedUpper,
                        thickness: thickness,
                        material: material,
                        zOffset: zOffset,
                        cornerRadius: cornerRadius
                    ) {
                        segmentCount += 1
                    }
                }
            }
        }
        return segmentCount
    }

    func addPlanarSegment(
        to root: Entity,
        minX: Float,
        maxX: Float,
        minY: Float,
        maxY: Float,
        thickness: Float,
        material: PhysicallyBasedMaterial,
        zOffset: Float,
        cornerRadius: Float
    ) -> Bool {
        let width = maxX - minX
        let height = maxY - minY
        guard width > 0.012, height > 0.012 else { return false }
        return addBox(
            to: root,
            size: [width, height, thickness],
            position: [(minX + maxX) * 0.5, (minY + maxY) * 0.5, zOffset],
            material: material,
            cornerRadius: cornerRadius
        )
    }

    static func verticalIntervals(
        in polygon: [SIMD2<Float>],
        atX x: Float
    ) -> [(lower: Float, upper: Float)] {
        guard polygon.count >= 3 else { return [] }
        var intersections: [Float] = []
        for index in polygon.indices {
            let start = polygon[index]
            let end = polygon[(index + 1) % polygon.count]
            let crossesForward = start.x <= x && end.x > x
            let crossesBackward = end.x <= x && start.x > x
            guard crossesForward || crossesBackward else { continue }
            let deltaX = end.x - start.x
            guard abs(deltaX) > 0.000_001 else { continue }
            let t = (x - start.x) / deltaX
            let y = start.y + (end.y - start.y) * t
            if y.isFinite { intersections.append(y) }
        }
        intersections.sort()
        intersections = intersections.reduce(into: []) { result, value in
            if let last = result.last, abs(last - value) < 0.002 { return }
            result.append(value)
        }

        var intervals: [(lower: Float, upper: Float)] = []
        var index = 0
        while index + 1 < intersections.count {
            let lower = intersections[index]
            let upper = intersections[index + 1]
            if upper - lower > 0.012 {
                intervals.append((lower: lower, upper: upper))
            }
            index += 2
        }
        return intervals
    }

    func associate(
        apertures: [CapturedRoom.Surface],
        with walls: [CapturedRoom.Surface]
    ) -> PortalAssociations {
        var result = PortalAssociations()
        var wallsByID: [UUID: CapturedRoom.Surface] = [:]
        for wall in walls where wallsByID[wall.identifier] == nil {
            wallsByID[wall.identifier] = wall
        }

        for aperture in apertures {
            if let parentID = aperture.parentIdentifier, wallsByID[parentID] != nil {
                result.aperturesByWallID[parentID, default: []].append(aperture)
                continue
            }

            guard let wall = closestCoplanarWall(to: aperture, walls: walls) else {
                result.unmatchedCount += 1
                continue
            }
            result.aperturesByWallID[wall.identifier, default: []].append(aperture)
            result.inferredCount += 1
        }
        return result
    }

    func closestCoplanarWall(
        to aperture: CapturedRoom.Surface,
        walls: [CapturedRoom.Surface]
    ) -> CapturedRoom.Surface? {
        guard let apertureBounds = Self.surfaceBounds(aperture),
              Self.isValidAffineTransform(aperture.transform) else { return nil }
        let apertureCenterLocal = SIMD4<Float>(
            apertureBounds.center.x,
            apertureBounds.center.y,
            0,
            1
        )
        let apertureCenterWorld = aperture.transform * apertureCenterLocal
        let apertureNormal = SIMD3<Float>(
            aperture.transform.columns.2.x,
            aperture.transform.columns.2.y,
            aperture.transform.columns.2.z
        )
        let apertureNormalLength = simd_length(apertureNormal)
        guard apertureNormalLength > 0.000_1 else { return nil }

        var best: (wall: CapturedRoom.Surface, score: Float)?
        for wall in walls where wall.story == aperture.story {
            guard let wallBounds = Self.surfaceBounds(wall),
                  Self.isValidAffineTransform(wall.transform) else { continue }
            let wallNormal = SIMD3<Float>(
                wall.transform.columns.2.x,
                wall.transform.columns.2.y,
                wall.transform.columns.2.z
            )
            let wallNormalLength = simd_length(wallNormal)
            guard wallNormalLength > 0.000_1 else { continue }
            let normalAlignment = abs(simd_dot(
                apertureNormal / apertureNormalLength,
                wallNormal / wallNormalLength
            ))
            guard normalAlignment >= 0.96 else { continue }

            let localCenter = simd_inverse(wall.transform) * apertureCenterWorld
            guard localCenter.x.isFinite, localCenter.y.isFinite, localCenter.z.isFinite,
                  abs(localCenter.z) <= 0.18,
                  localCenter.x >= wallBounds.minX - 0.15,
                  localCenter.x <= wallBounds.maxX + 0.15,
                  localCenter.y >= wallBounds.minY - 0.15,
                  localCenter.y <= wallBounds.maxY + 0.15,
                  apertureRect(
                    aperture,
                    relativeTo: wall,
                    wallBounds: wallBounds
                  ) != nil else { continue }

            let score = abs(localCenter.z) + (1 - normalAlignment) * 0.5
            if let currentBest = best {
                if score < currentBest.score { best = (wall, score) }
            } else {
                best = (wall, score)
            }
        }
        return best?.wall
    }

    static func surfaceBounds(_ surface: CapturedRoom.Surface) -> PlanarBounds? {
        if let polygon = localPolygon(for: surface), let first = polygon.first {
            var minX = first.x
            var maxX = first.x
            var minY = first.y
            var maxY = first.y
            for point in polygon.dropFirst() {
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
            }
            guard maxX - minX >= 0.02, maxY - minY >= 0.02,
                  maxX - minX <= 30, maxY - minY <= 30 else { return nil }
            return PlanarBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
        }

        guard let dimensions = planarDimensions(surface.dimensions) else { return nil }
        return PlanarBounds(
            minX: -dimensions.x * 0.5,
            maxX: dimensions.x * 0.5,
            minY: -dimensions.y * 0.5,
            maxY: dimensions.y * 0.5
        )
    }

    static func localPolygon(
        for surface: CapturedRoom.Surface
    ) -> [SIMD2<Float>]? {
        guard surface.polygonCorners.count >= 3,
              surface.polygonCorners.count <= 256 else { return nil }
        var polygon: [SIMD2<Float>] = []
        for corner in surface.polygonCorners {
            guard corner.x.isFinite, corner.y.isFinite, corner.z.isFinite,
                  abs(corner.x) <= 50, abs(corner.y) <= 50, abs(corner.z) <= 5 else {
                return nil
            }
            let point = SIMD2<Float>(corner.x, corner.y)
            if let last = polygon.last, simd_distance(last, point) < 0.002 { continue }
            polygon.append(point)
        }
        if polygon.count >= 2,
           let first = polygon.first,
           let last = polygon.last,
           simd_distance(first, last) < 0.002 {
            polygon.removeLast()
        }
        guard polygon.count >= 3 else { return nil }

        var doubledArea: Float = 0
        for index in polygon.indices {
            let start = polygon[index]
            let end = polygon[(index + 1) % polygon.count]
            doubledArea += start.x * end.y - end.x * start.y
        }
        guard abs(doubledArea) >= 0.000_8 else { return nil }
        return polygon
    }

    static func rectanglePolygon(_ bounds: PlanarBounds) -> [SIMD2<Float>] {
        [
            [bounds.minX, bounds.minY],
            [bounds.maxX, bounds.minY],
            [bounds.maxX, bounds.maxY],
            [bounds.minX, bounds.maxY]
        ]
    }

    static func isAxisAlignedRectangle(_ polygon: [SIMD2<Float>]) -> Bool {
        guard polygon.count == 4 else { return false }
        for index in polygon.indices {
            let start = polygon[index]
            let end = polygon[(index + 1) % polygon.count]
            let delta = end - start
            guard abs(delta.x) < 0.004 || abs(delta.y) < 0.004 else { return false }
        }
        return true
    }

    static func requiresPolygonApproximation(_ surface: CapturedRoom.Surface) -> Bool {
        if surface.curve != nil { return true }
        guard !surface.polygonCorners.isEmpty else { return false }
        guard let polygon = localPolygon(for: surface) else { return true }
        return !isAxisAlignedRectangle(polygon)
    }

    static func mergeIntervals(
        _ intervals: [(lower: Float, upper: Float)]
    ) -> [(lower: Float, upper: Float)] {
        var merged: [(lower: Float, upper: Float)] = []
        for interval in intervals {
            guard let last = merged.last else {
                merged.append(interval)
                continue
            }
            if interval.lower <= last.upper + 0.004 {
                merged[merged.count - 1].upper = max(last.upper, interval.upper)
            } else {
                merged.append(interval)
            }
        }
        return merged
    }
}

// MARK: - Recognized room objects

private extension RoomRealityRenderer {
    func makePhysicalOcclusionEntity(_ object: CapturedRoom.Object) -> Entity? {
        guard let size = Self.objectDimensions(object.dimensions),
              Self.isValidAffineTransform(object.transform) else { return nil }

        let root = Entity()
        root.name = "cinear.reality.physical-occlusion.object.\(object.identifier.uuidString)"
        root.transform = Transform(matrix: object.transform)

        switch Self.role(for: object.category) {
        case .table:
            let topHeight = min(max(size.y * 0.10, 0.035), 0.12)
            let legWidth = min(max(min(size.x, size.z) * 0.09, 0.025), 0.10)
            let legHeight = max(size.y - topHeight, 0.03)
            addPhysicalOcclusionBox(
                to: root,
                size: [size.x, topHeight, size.z],
                position: [0, size.y * 0.5 - topHeight * 0.5, 0]
            )
            let insetX = max(size.x * 0.5 - legWidth, 0)
            let insetZ = max(size.z * 0.5 - legWidth, 0)
            for x in [-insetX, insetX] {
                for z in [-insetZ, insetZ] {
                    addPhysicalOcclusionBox(
                        to: root,
                        size: [legWidth, legHeight, legWidth],
                        position: [x, -topHeight * 0.5, z]
                    )
                }
            }
        case .chair:
            let seatHeight = size.y * 0.48
            let seatThickness = min(max(size.y * 0.10, 0.035), 0.10)
            let legWidth = min(max(min(size.x, size.z) * 0.09, 0.018), 0.055)
            addPhysicalOcclusionBox(
                to: root,
                size: [size.x * 0.92, seatThickness, size.z * 0.86],
                position: [0, -size.y * 0.5 + seatHeight, 0]
            )
            addPhysicalOcclusionBox(
                to: root,
                size: [size.x * 0.92, size.y * 0.48, max(size.z * 0.10, 0.035)],
                position: [0, size.y * 0.25, -size.z * 0.40]
            )
            let insetX = max(size.x * 0.40, 0)
            let insetZ = max(size.z * 0.34, 0)
            for x in [-insetX, insetX] {
                for z in [-insetZ, insetZ] {
                    addPhysicalOcclusionBox(
                        to: root,
                        size: [legWidth, seatHeight, legWidth],
                        position: [x, -size.y * 0.5 + seatHeight * 0.5, z]
                    )
                }
            }
        case .unknown:
            return nil
        case .bathtub, .bed, .dishwasher, .fireplace, .oven, .refrigerator,
             .sink, .sofa, .stairs, .storage, .stove, .television, .toilet,
             .washerDryer:
            addPhysicalOcclusionBox(to: root, size: size, position: .zero)
        }
        return root.children.isEmpty ? nil : root
    }

    func addPhysicalOcclusionBox(
        to root: Entity,
        size: SIMD3<Float>,
        position: SIMD3<Float>
    ) {
        // RoomPlan dimensions are semantic envelopes, not millimeter-accurate meshes.
        // A small inward bias prevents the envelope from cutting a virtual prop that
        // is resting exactly on a table/seat edge. Live ARKit or AI depth still owns
        // the precise foreground boundary.
        let inset: Float = 0.05
        let biasedSize = SIMD3<Float>(
            max(size.x - inset, 0.015),
            max(size.y - inset, 0.015),
            max(size.z - inset, 0.015)
        )
        let box = ModelEntity(
            mesh: Self.unitBoxMesh,
            materials: [OcclusionMaterial()]
        )
        box.name = "cinear.reality.physical-occlusion.box"
        box.scale = biasedSize
        box.position = position
        root.addChild(box)
    }

    func makeObjectOutlineEntity(
        _ object: CapturedRoom.Object,
        material: PhysicallyBasedMaterial
    ) -> Entity? {
        guard let size = Self.objectDimensions(object.dimensions),
              Self.isValidAffineTransform(object.transform) else { return nil }

        let root = Entity()
        root.name = "cinear.reality.outline.object.\(object.identifier.uuidString)"
        root.transform = Transform(matrix: object.transform)
        let half = size * 0.5
        let lineWidth: Float = 0.018
        let countBefore = generatedBoxCount

        for y in [-half.y, half.y] {
            for z in [-half.z, half.z] {
                addBox(
                    to: root,
                    size: [size.x, lineWidth, lineWidth],
                    position: [0, y, z],
                    material: material,
                    includeCollision: false
                )
            }
        }
        for x in [-half.x, half.x] {
            for z in [-half.z, half.z] {
                addBox(
                    to: root,
                    size: [lineWidth, size.y, lineWidth],
                    position: [x, 0, z],
                    material: material,
                    includeCollision: false
                )
            }
        }
        for x in [-half.x, half.x] {
            for y in [-half.y, half.y] {
                addBox(
                    to: root,
                    size: [lineWidth, lineWidth, size.z],
                    position: [x, y, 0],
                    material: material,
                    includeCollision: false
                )
            }
        }

        let collider = Entity()
        collider.name = "cinear.reality.outline.object.collider"
        collider.scale = size
        collider.components.set(
            CollisionComponent(shapes: [Self.unitBoxCollisionShape])
        )
        root.addChild(collider)
        return generatedBoxCount > countBefore ? root : nil
    }

    func nestedObjectIDsToSuppress(
        objectsByID: [UUID: CapturedRoom.Object]
    ) -> Set<UUID> {
        var suppressed: Set<UUID> = []
        for child in objectsByID.values {
            guard let parentID = child.parentIdentifier,
                  let parent = objectsByID[parentID],
                  parent.identifier != child.identifier,
                  let childSize = Self.objectDimensions(child.dimensions),
                  let parentSize = Self.objectDimensions(parent.dimensions),
                  Self.isValidAffineTransform(child.transform),
                  Self.isValidAffineTransform(parent.transform) else { continue }

            let childToParent = simd_inverse(parent.transform) * child.transform
            guard Self.isValidAffineTransform(childToParent) else { continue }
            let parentHalfSize = parentSize * 0.5
            let tolerance: Float = 0.035
            var isContained = true
            for x in [-childSize.x * 0.5, childSize.x * 0.5] {
                for y in [-childSize.y * 0.5, childSize.y * 0.5] {
                    for z in [-childSize.z * 0.5, childSize.z * 0.5] {
                        let point = childToParent * SIMD4<Float>(x, y, z, 1)
                        let outsideX = abs(point.x) > parentHalfSize.x + tolerance
                        let outsideY = abs(point.y) > parentHalfSize.y + tolerance
                        let outsideZ = abs(point.z) > parentHalfSize.z + tolerance
                        if outsideX || outsideY || outsideZ {
                            isContained = false
                            break
                        }
                    }
                    if !isContained { break }
                }
                if !isContained { break }
            }
            guard isContained else { continue }

            let childVolume = childSize.x * childSize.y * childSize.z
            let parentVolume = parentSize.x * parentSize.y * parentSize.z
            guard parentVolume > 0.000_001 else { continue }
            let volumeRatio = childVolume / parentVolume
            if child.category == parent.category {
                suppressed.insert(child.identifier)
            } else if volumeRatio >= 0.72 {
                // Daha özgül çocuk modeli, neredeyse aynı hacimdeki genel ebeveyn kutusunun yerini alır.
                suppressed.insert(parent.identifier)
            }
        }
        return suppressed
    }

    func makeObjectEntity(
        _ object: CapturedRoom.Object,
        theme: RealityTheme
    ) -> Entity? {
        guard let dimensions = Self.objectDimensions(object.dimensions),
              Self.isValidAffineTransform(object.transform) else { return nil }

        let role = Self.role(for: object.category)
        let root = Entity()
        root.name = "cinear.reality.object.\(object.identifier.uuidString)"
        root.transform = Transform(matrix: object.transform)

        if let suppliedEntity = assetProvider?.makeEntity(
            for: role,
            theme: theme,
            targetDimensions: dimensions
        ) {
            suppliedEntity.name = "cinear.reality.asset.\(object.identifier.uuidString)"
            root.addChild(suppliedEntity)
            let placementCollider = Entity()
            placementCollider.name = "cinear.reality.asset.collider.\(object.identifier.uuidString)"
            placementCollider.scale = dimensions
            placementCollider.components.set(
                CollisionComponent(shapes: [Self.unitBoxCollisionShape])
            )
            root.addChild(placementCollider)
            return root
        }

        let recipes = theme.objectRecipes(for: role)
        let primary = recipes.primary.makeMaterial()
        let secondary = recipes.secondary.makeMaterial()
        let detail = recipes.detail.makeMaterial()
        let generatedBoxCountBeforeObject = generatedBoxCount

        switch role {
        case .table:
            buildTable(root, dimensions, primary, detail)
        case .chair:
            buildChair(root, dimensions, primary, detail)
        case .sofa:
            buildSofa(root, dimensions, primary, secondary)
        case .bed:
            buildBed(root, dimensions, primary, secondary, detail)
        case .storage:
            buildStorage(root, dimensions, primary, detail)
        case .television:
            buildTelevision(root, dimensions, secondary, primary, detail)
        case .fireplace:
            buildFireplace(root, dimensions, primary, secondary, detail)
        case .stairs:
            buildStairs(root, dimensions, primary)
        case .bathtub:
            buildBathtub(root, dimensions, primary, secondary)
        case .sink:
            buildSink(root, dimensions, primary, secondary, detail)
        case .toilet:
            buildToilet(root, dimensions, primary, secondary)
        case .refrigerator, .dishwasher, .oven, .stove, .washerDryer:
            buildAppliance(root, dimensions, primary, secondary, detail, role: role)
        case .unknown:
            addBox(
                to: root,
                size: dimensions,
                position: .zero,
                material: primary,
                cornerRadius: min(dimensions.x, dimensions.z) * 0.035
            )
        }
        return generatedBoxCount > generatedBoxCountBeforeObject ? root : nil
    }

    func buildTable(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ detail: PhysicallyBasedMaterial
    ) {
        let topHeight = min(max(size.y * 0.09, 0.035), 0.12)
        let legWidth = min(max(min(size.x, size.z) * 0.09, 0.025), 0.10)
        let legHeight = max(size.y - topHeight, 0.03)
        addBox(
            to: root,
            size: [size.x, topHeight, size.z],
            position: [0, size.y * 0.5 - topHeight * 0.5, 0],
            material: primary,
            cornerRadius: 0.018
        )
        let insetX = max(size.x * 0.5 - legWidth, 0)
        let insetZ = max(size.z * 0.5 - legWidth, 0)
        for x in [-insetX, insetX] {
            for z in [-insetZ, insetZ] {
                addBox(
                    to: root,
                    size: [legWidth, legHeight, legWidth],
                    position: [x, -topHeight * 0.5, z],
                    material: detail,
                    cornerRadius: 0.008
                )
            }
        }
    }

    func buildChair(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ detail: PhysicallyBasedMaterial
    ) {
        let seatHeight = size.y * 0.48
        let seatThickness = min(max(size.y * 0.10, 0.035), 0.10)
        let legWidth = min(max(min(size.x, size.z) * 0.09, 0.018), 0.055)
        addBox(
            to: root,
            size: [size.x * 0.88, seatThickness, size.z * 0.82],
            position: [0, -size.y * 0.5 + seatHeight, 0],
            material: primary,
            cornerRadius: 0.025
        )
        let backHeight = max(size.y - seatHeight, 0.04)
        addBox(
            to: root,
            size: [size.x * 0.88, backHeight, max(size.z * 0.09, 0.025)],
            position: [0, size.y * 0.5 - backHeight * 0.5, -size.z * 0.41],
            material: primary,
            cornerRadius: 0.025
        )
        let legHeight = max(seatHeight - seatThickness * 0.5, 0.025)
        for x in [-size.x * 0.34, size.x * 0.34] {
            for z in [-size.z * 0.31, size.z * 0.31] {
                addBox(
                    to: root,
                    size: [legWidth, legHeight, legWidth],
                    position: [x, -size.y * 0.5 + legHeight * 0.5, z],
                    material: detail,
                    cornerRadius: 0.005
                )
            }
        }
    }

    func buildSofa(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ secondary: PhysicallyBasedMaterial
    ) {
        addBox(
            to: root,
            size: [size.x, size.y * 0.32, size.z * 0.82],
            position: [0, -size.y * 0.34, 0],
            material: primary,
            cornerRadius: min(size.x, size.z) * 0.04
        )
        addBox(
            to: root,
            size: [size.x * 0.78, size.y * 0.20, size.z * 0.66],
            position: [0, -size.y * 0.10, size.z * 0.06],
            material: secondary,
            cornerRadius: min(size.x, size.z) * 0.045
        )
        addBox(
            to: root,
            size: [size.x * 0.82, size.y * 0.52, size.z * 0.20],
            position: [0, size.y * 0.20, -size.z * 0.39],
            material: secondary,
            cornerRadius: 0.04
        )
        for x in [-size.x * 0.455, size.x * 0.455] {
            addBox(
                to: root,
                size: [size.x * 0.09, size.y * 0.50, size.z * 0.88],
                position: [x, -size.y * 0.08, 0],
                material: primary,
                cornerRadius: 0.035
            )
        }
    }

    func buildBed(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ secondary: PhysicallyBasedMaterial,
        _ detail: PhysicallyBasedMaterial
    ) {
        addBox(
            to: root,
            size: [size.x, size.y * 0.25, size.z],
            position: [0, -size.y * 0.375, 0],
            material: detail,
            cornerRadius: 0.02
        )
        addBox(
            to: root,
            size: [size.x * 0.96, size.y * 0.28, size.z * 0.90],
            position: [0, -size.y * 0.12, size.z * 0.03],
            material: secondary,
            cornerRadius: 0.06
        )
        addBox(
            to: root,
            size: [size.x, size.y * 0.72, max(size.z * 0.08, 0.04)],
            position: [0, size.y * 0.14, -size.z * 0.46],
            material: primary,
            cornerRadius: 0.025
        )
    }

    func buildStorage(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ detail: PhysicallyBasedMaterial
    ) {
        addBox(to: root, size: size, position: .zero, material: primary, cornerRadius: 0.018)
        let seam = max(size.x * 0.012, 0.008)
        addBox(
            to: root,
            size: [seam, size.y * 0.90, 0.012],
            position: [0, 0, size.z * 0.5 + 0.007],
            material: detail,
            cornerRadius: 0.002
        )
        for x in [-size.x * 0.12, size.x * 0.12] {
            addBox(
                to: root,
                size: [max(size.x * 0.018, 0.012), size.y * 0.12, 0.018],
                position: [x, 0, size.z * 0.5 + 0.016],
                material: detail,
                cornerRadius: 0.005
            )
        }
    }

    func buildTelevision(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ frame: PhysicallyBasedMaterial,
        _ screen: PhysicallyBasedMaterial,
        _ detail: PhysicallyBasedMaterial
    ) {
        let depth = max(size.z, 0.035)
        addBox(to: root, size: [size.x, size.y, depth], position: .zero, material: frame, cornerRadius: 0.018)
        addBox(
            to: root,
            size: [size.x * 0.94, size.y * 0.90, 0.012],
            position: [0, 0, depth * 0.5 + 0.007],
            material: screen,
            cornerRadius: 0.008
        )
        addBox(
            to: root,
            size: [size.x * 0.28, max(size.y * 0.035, 0.012), size.z * 0.70],
            position: [0, -size.y * 0.52, 0],
            material: detail,
            cornerRadius: 0.006
        )
    }

    func buildFireplace(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ secondary: PhysicallyBasedMaterial,
        _ detail: PhysicallyBasedMaterial
    ) {
        let sideWidth = size.x * 0.18
        let headerHeight = size.y * 0.20
        addBox(
            to: root,
            size: [size.x * 0.62, size.y * 0.58, max(size.z * 0.12, 0.025)],
            position: [0, -size.y * 0.10, size.z * 0.51],
            material: secondary,
            cornerRadius: 0.008
        )
        for x in [-size.x * 0.41, size.x * 0.41] {
            addBox(
                to: root,
                size: [sideWidth, size.y, size.z],
                position: [x, 0, 0],
                material: primary,
                cornerRadius: 0.012
            )
        }
        addBox(
            to: root,
            size: [size.x * 0.82, headerHeight, size.z],
            position: [0, size.y * 0.40, 0],
            material: primary,
            cornerRadius: 0.012
        )
        addBox(
            to: root,
            size: [size.x, size.y * 0.10, size.z * 1.08],
            position: [0, -size.y * 0.45, size.z * 0.02],
            material: detail,
            cornerRadius: 0.01
        )
    }

    func buildStairs(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ material: PhysicallyBasedMaterial
    ) {
        let stepCount = 8
        let stepDepth = size.z / Float(stepCount)
        for index in 0..<stepCount {
            let factor = Float(index + 1) / Float(stepCount)
            let stepHeight = size.y * factor
            let z = -size.z * 0.5 + stepDepth * (Float(index) + 0.5)
            addBox(
                to: root,
                size: [size.x, stepHeight, stepDepth * 1.02],
                position: [0, -size.y * 0.5 + stepHeight * 0.5, z],
                material: material,
                cornerRadius: 0.006
            )
        }
    }

    func buildBathtub(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ secondary: PhysicallyBasedMaterial
    ) {
        let rim = min(max(min(size.x, size.z) * 0.10, 0.035), 0.14)
        addBox(
            to: root,
            size: [size.x, size.y * 0.62, size.z],
            position: [0, -size.y * 0.19, 0],
            material: primary,
            cornerRadius: min(size.x, size.z) * 0.10
        )
        addBox(
            to: root,
            size: [max(size.x - rim * 2, 0.03), max(size.y * 0.18, 0.025), max(size.z - rim * 2, 0.03)],
            position: [0, size.y * 0.20, 0],
            material: secondary,
            cornerRadius: min(size.x, size.z) * 0.08
        )
    }

    func buildSink(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ secondary: PhysicallyBasedMaterial,
        _ detail: PhysicallyBasedMaterial
    ) {
        addBox(
            to: root,
            size: [size.x, size.y * 0.24, size.z],
            position: [0, size.y * 0.30, 0],
            material: primary,
            cornerRadius: 0.04
        )
        addBox(
            to: root,
            size: [size.x * 0.64, size.y * 0.10, size.z * 0.62],
            position: [0, size.y * 0.43, 0],
            material: secondary,
            cornerRadius: 0.035
        )
        addBox(
            to: root,
            size: [size.x * 0.42, size.y * 0.70, size.z * 0.46],
            position: [0, -size.y * 0.15, 0],
            material: primary,
            cornerRadius: 0.025
        )
        addBox(
            to: root,
            size: [max(size.x * 0.04, 0.015), size.y * 0.20, max(size.z * 0.04, 0.015)],
            position: [0, size.y * 0.50, -size.z * 0.20],
            material: detail,
            cornerRadius: 0.006
        )
    }

    func buildToilet(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ secondary: PhysicallyBasedMaterial
    ) {
        addBox(
            to: root,
            size: [size.x * 0.84, size.y * 0.36, size.z * 0.72],
            position: [0, -size.y * 0.24, size.z * 0.09],
            material: primary,
            cornerRadius: min(size.x, size.z) * 0.16
        )
        addBox(
            to: root,
            size: [size.x, size.y * 0.12, size.z * 0.82],
            position: [0, -size.y * 0.02, size.z * 0.08],
            material: secondary,
            cornerRadius: min(size.x, size.z) * 0.17
        )
        addBox(
            to: root,
            size: [size.x * 0.82, size.y * 0.54, size.z * 0.34],
            position: [0, size.y * 0.23, -size.z * 0.31],
            material: primary,
            cornerRadius: 0.04
        )
    }

    func buildAppliance(
        _ root: Entity,
        _ size: SIMD3<Float>,
        _ primary: PhysicallyBasedMaterial,
        _ secondary: PhysicallyBasedMaterial,
        _ detail: PhysicallyBasedMaterial,
        role: RealityObjectRole
    ) {
        addBox(to: root, size: size, position: .zero, material: primary, cornerRadius: 0.025)
        let faceDepth = max(size.z * 0.018, 0.012)
        let faceHeight: Float = role == .stove ? size.y * 0.12 : size.y * 0.72
        addBox(
            to: root,
            size: [size.x * 0.88, faceHeight, faceDepth],
            position: [0, role == .stove ? size.y * 0.43 : -size.y * 0.04, size.z * 0.5 + faceDepth * 0.55],
            material: secondary,
            cornerRadius: 0.018
        )
        let controlHeight = min(max(size.y * 0.08, 0.025), 0.10)
        addBox(
            to: root,
            size: [size.x * 0.72, controlHeight, faceDepth * 1.2],
            position: [0, size.y * 0.36, size.z * 0.5 + faceDepth * 1.2],
            material: detail,
            cornerRadius: 0.008
        )
    }
}

// MARK: - Shared helpers

private extension RoomRealityRenderer {
    @discardableResult
    func addBox(
        to parent: Entity,
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        material: PhysicallyBasedMaterial,
        cornerRadius: Float = 0.003,
        includeCollision: Bool = true
    ) -> Bool {
        guard generatedBoxCount < Self.maximumGeneratedBoxCount,
              size.x.isFinite, size.y.isFinite, size.z.isFinite,
              position.x.isFinite, position.y.isFinite, position.z.isFinite,
              cornerRadius.isFinite else { return false }

        let safeSize = SIMD3<Float>(
            max(abs(size.x), 0.005),
            max(abs(size.y), 0.005),
            max(abs(size.z), 0.005)
        )
        guard safeSize.x <= 100, safeSize.y <= 100, safeSize.z <= 100 else {
            return false
        }

        // All procedural pieces share one mesh. Per-entity scale preserves dimensions
        // without allocating hundreds of independent MeshResource objects.
        let mesh = cornerRadius > 0.000_1 ? Self.roundedUnitBoxMesh : Self.unitBoxMesh
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.scale = safeSize
        entity.position = position
        // The visual mesh is a shared unit box whose entity scale supplies its actual
        // dimensions. Reusing the matching unit collision shape keeps hundreds of room
        // pieces cheap while making the scanned room available to placement hit tests.
        if includeCollision {
            entity.collision = CollisionComponent(shapes: [Self.unitBoxCollisionShape])
        }
        parent.addChild(entity)
        generatedBoxCount += 1
        return true
    }

    func belongsToRenderedRoom(_ entity: Entity) -> Bool {
        var candidate: Entity? = entity
        while let current = candidate {
            if current === rootEntity { return true }
            candidate = current.parent
        }
        return false
    }

    static func planarDimensions(_ dimensions: SIMD3<Float>) -> SIMD2<Float>? {
        guard dimensions.x.isFinite, dimensions.y.isFinite,
              abs(dimensions.x) >= 0.02, abs(dimensions.y) >= 0.02,
              abs(dimensions.x) <= 30, abs(dimensions.y) <= 30 else { return nil }
        return SIMD2(abs(dimensions.x), abs(dimensions.y))
    }

    static func objectDimensions(_ dimensions: SIMD3<Float>) -> SIMD3<Float>? {
        guard dimensions.x.isFinite, dimensions.y.isFinite, dimensions.z.isFinite,
              abs(dimensions.x) >= 0.02,
              abs(dimensions.y) >= 0.02,
              abs(dimensions.z) >= 0.02,
              abs(dimensions.x) <= 30,
              abs(dimensions.y) <= 30,
              abs(dimensions.z) <= 30 else { return nil }
        return SIMD3(abs(dimensions.x), abs(dimensions.y), abs(dimensions.z))
    }

    static func isFinite(_ matrix: simd_float4x4) -> Bool {
        let values = [
            matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z, matrix.columns.0.w,
            matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z, matrix.columns.1.w,
            matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z, matrix.columns.2.w,
            matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z, matrix.columns.3.w
        ]
        return values.allSatisfy { $0.isFinite }
    }

    static func isValidAffineTransform(_ matrix: simd_float4x4) -> Bool {
        guard isFinite(matrix),
              abs(matrix.columns.0.w) <= 0.000_1,
              abs(matrix.columns.1.w) <= 0.000_1,
              abs(matrix.columns.2.w) <= 0.000_1,
              abs(matrix.columns.3.w - 1) <= 0.000_1 else { return false }

        let linear = simd_float3x3(columns: (
            SIMD3(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z),
            SIMD3(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z),
            SIMD3(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z)
        ))
        let determinant = simd_determinant(linear)
        guard determinant.isFinite, abs(determinant) > 0.000_001 else { return false }

        let length0 = simd_length(linear.columns.0)
        let length1 = simd_length(linear.columns.1)
        let length2 = simd_length(linear.columns.2)
        for length in [length0, length1, length2] {
            guard length.isFinite, length >= 0.000_1, length <= 1_000 else { return false }
        }
        let axis0 = linear.columns.0 / length0
        let axis1 = linear.columns.1 / length1
        let axis2 = linear.columns.2 / length2
        guard abs(simd_dot(axis0, axis1)) <= 0.01,
              abs(simd_dot(axis0, axis2)) <= 0.01,
              abs(simd_dot(axis1, axis2)) <= 0.01 else { return false }
        return true
    }

    static func role(for category: CapturedRoom.Object.Category) -> RealityObjectRole {
        switch category {
        case .bathtub: .bathtub
        case .bed: .bed
        case .chair: .chair
        case .dishwasher: .dishwasher
        case .fireplace: .fireplace
        case .oven: .oven
        case .refrigerator: .refrigerator
        case .sink: .sink
        case .sofa: .sofa
        case .stairs: .stairs
        case .storage: .storage
        case .stove: .stove
        case .table: .table
        case .television: .television
        case .toilet: .toilet
        case .washerDryer: .washerDryer
        @unknown default: .unknown
        }
    }
}
````

## `CineAR/RoomScanner.swift`

````swift
import ARKit
import RoomPlan
import SwiftUI
import UIKit

enum RoomScanResult: Equatable, Sendable {
    case success(URL)
    case cancelled
    case failure(String)
}

enum CapturedRoomStoreError: LocalizedError {
    case missingStagedArtifact(String)
    case commitFailed(original: String, rollback: String?)

    var errorDescription: String? {
        switch self {
        case .missingStagedArtifact(let filename):
            return "Geçici oda dosyası bulunamadı: \(filename)"
        case .commitFailed(let original, let rollback):
            guard let rollback else {
                return "Oda dosyaları kullanıma alınamadı: \(original)"
            }
            return "Oda dosyaları kullanıma alınamadı: \(original). Önceki sürüm geri yüklenemedi: \(rollback)"
        }
    }
}

/// Keeps RoomPlan's semantic JSON in a staged transaction until the user accepts the scan.
/// The live renderer consumes this JSON directly. Generating an additional RoomPlan USDZ
/// during preview teardown caused an avoidable memory spike on real devices, so stale
/// `room.usdz` archives are removed when a new semantic scan is committed.
struct CapturedRoomStore {
    struct StagedArtifacts: Equatable, Sendable {
        let roomJSONURL: URL
    }

    let modelURL: URL
    let roomJSONURL: URL

    private let fileManager: FileManager

    init(
        modelURL: URL,
        roomJSONURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.modelURL = modelURL
        self.roomJSONURL = roomJSONURL ?? Self.defaultRoomJSONURL(for: modelURL)
        self.fileManager = fileManager
    }

    static func defaultRoomJSONURL(for modelURL: URL) -> URL {
        modelURL.deletingLastPathComponent().appendingPathComponent("room.json")
    }

    func loadCapturedRoom() throws -> CapturedRoom {
        let data = try Data(contentsOf: roomJSONURL, options: [.mappedIfSafe])
        return try JSONDecoder().decode(CapturedRoom.self, from: data)
    }

    func stage(_ room: CapturedRoom) throws -> StagedArtifacts {
        try prepareParentDirectory(for: roomJSONURL)

        let identifier = UUID().uuidString
        let stagedJSONURL = temporarySibling(
            of: roomJSONURL,
            identifier: identifier,
            pathExtension: "json"
        )
        let artifacts = StagedArtifacts(roomJSONURL: stagedJSONURL)

        do {
            // Keep the mobile critical path compact. Pretty-printing and key sorting
            // temporarily duplicate a large RoomPlan result without helping the renderer.
            let roomData = try JSONEncoder().encode(room)
            try roomData.write(to: stagedJSONURL, options: .atomic)
            return artifacts
        } catch {
            discard(artifacts)
            throw error
        }
    }

    /// Atomically installs the semantic room and restores the previous JSON on failure.
    func commit(_ staged: StagedArtifacts) throws {
        try requireStagedFile(at: staged.roomJSONURL)

        let identifier = UUID().uuidString
        let jsonBackupURL = backupSibling(of: roomJSONURL, identifier: identifier)
        let hadJSON = fileManager.fileExists(atPath: roomJSONURL.path)
        var installedJSON = false

        do {
            if hadJSON {
                try fileManager.copyItem(at: roomJSONURL, to: jsonBackupURL)
            }

            try install(staged.roomJSONURL, at: roomJSONURL)
            installedJSON = true

            removeIfPresent(jsonBackupURL)
            removeIfPresent(modelURL)
        } catch {
            let originalMessage = error.localizedDescription
            var rollbackMessages: [String] = []

            if installedJSON {
                do {
                    try restore(
                        finalURL: roomJSONURL,
                        backupURL: jsonBackupURL,
                        previouslyExisted: hadJSON
                    )
                } catch {
                    rollbackMessages.append(error.localizedDescription)
                }
            }

            discard(staged)
            removeIfPresent(jsonBackupURL)
            throw CapturedRoomStoreError.commitFailed(
                original: originalMessage,
                rollback: rollbackMessages.isEmpty ? nil : rollbackMessages.joined(separator: "; ")
            )
        }
    }

    func discard(_ staged: StagedArtifacts) {
        removeIfPresent(staged.roomJSONURL)
    }

    private func prepareParentDirectory(for url: URL) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private func temporarySibling(
        of url: URL,
        identifier: String,
        pathExtension: String
    ) -> URL {
        url.deletingLastPathComponent()
            .appendingPathComponent(".RoomScan-\(identifier)-\(UUID().uuidString)")
            .appendingPathExtension(pathExtension)
    }

    private func backupSibling(of url: URL, identifier: String) -> URL {
        url.deletingLastPathComponent()
            .appendingPathComponent(".RoomScanBackup-\(identifier)-\(url.lastPathComponent)")
    }

    private func requireStagedFile(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw CapturedRoomStoreError.missingStagedArtifact(url.lastPathComponent)
        }
    }

    private func install(_ stagedURL: URL, at finalURL: URL) throws {
        if fileManager.fileExists(atPath: finalURL.path) {
            _ = try fileManager.replaceItemAt(finalURL, withItemAt: stagedURL)
        } else {
            try fileManager.moveItem(at: stagedURL, to: finalURL)
        }
    }

    private func restore(
        finalURL: URL,
        backupURL: URL,
        previouslyExisted: Bool
    ) throws {
        if fileManager.fileExists(atPath: finalURL.path) {
            try fileManager.removeItem(at: finalURL)
        }
        if previouslyExisted {
            try fileManager.moveItem(at: backupURL, to: finalURL)
        }
    }

    private func removeIfPresent(_ url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.removeItem(at: url)
    }
}

private struct CapturedRoomStageOutcome: Sendable {
    let artifacts: CapturedRoomStore.StagedArtifacts?
    let failureMessage: String?
}

@MainActor
final class RoomScannerController: NSObject, ObservableObject {
    static var isSupported: Bool { RoomCaptureSession.isSupported }

    @Published private(set) var statusText = "Odayı yavaşça tarayın"
    @Published private(set) var isProcessing = false
    @Published private(set) var exportSucceeded = false
    @Published private(set) var failureMessage: String?

    let captureView: RoomCaptureView
    let roomJSONURL: URL

    private let roomStore: CapturedRoomStore
    private let configuration = RoomCaptureSession.Configuration()
    private let preservesSharedARSession: Bool
    private var shouldExport = true
    private var isSessionRunning = false
    private var isTornDown = false
    private var pendingArtifacts: CapturedRoomStore.StagedArtifacts?
    private var scanGeneration: UInt64 = 0
    private var stagingTask: Task<CapturedRoomStageOutcome, Never>?

    init(
        exportURL: URL,
        roomJSONURL: URL? = nil,
        arSession: ARSession? = nil
    ) {
        let store = CapturedRoomStore(
            modelURL: exportURL,
            roomJSONURL: roomJSONURL
        )
        self.roomStore = store
        self.roomJSONURL = store.roomJSONURL
        self.preservesSharedARSession = arSession != nil
        if let arSession {
            self.captureView = RoomCaptureView(frame: .zero, arSession: arSession)
        } else {
            self.captureView = RoomCaptureView(frame: .zero)
        }
        super.init()
        captureView.captureSession.delegate = self
        captureView.delegate = self
    }

    init?(coder: NSCoder) {
        fatalError("RoomScannerController yalnızca init(exportURL:) ile oluşturulabilir")
    }

    func encode(with coder: NSCoder) {
        // RoomCaptureViewDelegate, NSCoding uyumluluğu ister. Bu controller arşivlenmez.
    }

    func start() {
        guard Self.isSupported else {
            recordFailure("RoomPlan için LiDAR destekli cihaz gerekli")
            return
        }
        guard !isTornDown, !isSessionRunning, !isProcessing else { return }

        scanGeneration &+= 1
        stagingTask?.cancel()
        stagingTask = nil
        shouldExport = true
        discardPendingExport()
        exportSucceeded = false
        failureMessage = nil
        statusText = "Odayı yavaşça tarayın"
        isSessionRunning = true
        captureView.captureSession.run(configuration: configuration)
    }

    func finish() {
        guard isSessionRunning, !isProcessing else { return }

        shouldExport = true
        isProcessing = true
        statusText = "3B oda modeli işleniyor..."
        isSessionRunning = false
        stopCaptureSession()
    }

    func cancel() {
        teardownForDismissal()
    }

    func commitExport() -> URL? {
        guard exportSucceeded, let pendingArtifacts else {
            recordFailure("Kaydedilecek oda modeli bulunamadı")
            return nil
        }

        do {
            try roomStore.commit(pendingArtifacts)
            self.pendingArtifacts = nil
            return roomStore.roomJSONURL
        } catch {
            recordFailure("Oda taraması kullanıma alınamadı: \(error.localizedDescription)")
            return nil
        }
    }

    private func recordFailure(_ message: String) {
        scanGeneration &+= 1
        stagingTask?.cancel()
        stagingTask = nil
        shouldExport = false
        discardPendingExport()
        exportSucceeded = false
        isProcessing = false
        isSessionRunning = false
        failureMessage = message
        statusText = message
    }

    private func discardPendingExport() {
        guard let pendingArtifacts else { return }
        roomStore.discard(pendingArtifacts)
        self.pendingArtifacts = nil
    }

    func teardownForDismissal(discardPendingExport shouldDiscard: Bool = true) {
        guard !isTornDown else { return }
        isTornDown = true
        scanGeneration &+= 1
        stagingTask?.cancel()
        stagingTask = nil
        shouldExport = false
        isProcessing = false
        if isSessionRunning {
            isSessionRunning = false
            stopCaptureSession()
        }
        captureView.delegate = nil
        captureView.captureSession.delegate = nil
        if shouldDiscard {
            discardPendingExport()
        }
    }

    private func stopCaptureSession() {
        if preservesSharedARSession {
            captureView.captureSession.stop(pauseARSession: false)
        } else {
            captureView.captureSession.stop()
        }
    }
}

extension RoomScannerController: @preconcurrency RoomCaptureSessionDelegate {
    func captureSession(
        _ session: RoomCaptureSession,
        didEndWith data: CapturedRoomData,
        error: Error?
    ) {
        guard let error else { return }
        let message = "Tarama hatası: \(error.localizedDescription)"
        let generation = scanGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.scanGeneration == generation,
                  self.shouldExport else { return }
            self.recordFailure(message)
        }
    }
}

extension RoomScannerController: @preconcurrency RoomCaptureViewDelegate {
    func captureView(
        shouldPresent roomDataForProcessing: CapturedRoomData,
        error: Error?
    ) -> Bool {
        guard shouldExport else { return false }
        guard let error else { return true }

        let message = "Tarama hatası: \(error.localizedDescription)"
        let generation = scanGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.scanGeneration == generation,
                  self.shouldExport else { return }
            self.recordFailure(message)
        }
        return false
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        guard shouldExport, isProcessing, !isSessionRunning, !isTornDown else { return }

        let modelURL = roomStore.modelURL
        let roomJSONURL = roomStore.roomJSONURL
        let callbackError = error?.localizedDescription
        scanGeneration &+= 1
        let generation = scanGeneration
        stagingTask?.cancel()

        statusText = "Oda verisi güvenli biçimde hazırlanıyor..."
        let worker = Task.detached(priority: .userInitiated) {
            guard !Task.isCancelled else {
                return CapturedRoomStageOutcome(artifacts: nil, failureMessage: nil)
            }
            if let callbackError {
                return CapturedRoomStageOutcome(
                    artifacts: nil,
                    failureMessage: callbackError
                )
            }
            do {
                let store = CapturedRoomStore(
                    modelURL: modelURL,
                    roomJSONURL: roomJSONURL
                )
                let artifacts = try store.stage(processedResult)
                guard !Task.isCancelled else {
                    store.discard(artifacts)
                    return CapturedRoomStageOutcome(artifacts: nil, failureMessage: nil)
                }
                return CapturedRoomStageOutcome(
                    artifacts: artifacts,
                    failureMessage: nil
                )
            } catch {
                return CapturedRoomStageOutcome(
                    artifacts: nil,
                    failureMessage: error.localizedDescription
                )
            }
        }
        stagingTask = worker

        Task { @MainActor [weak self] in
            let outcome = await worker.value
            guard let self else {
                if let artifacts = outcome.artifacts {
                    CapturedRoomStore(
                        modelURL: modelURL,
                        roomJSONURL: roomJSONURL
                    ).discard(artifacts)
                }
                return
            }
            guard self.scanGeneration == generation,
                  self.shouldExport,
                  !self.isTornDown else {
                if let artifacts = outcome.artifacts {
                    self.roomStore.discard(artifacts)
                }
                return
            }
            self.stagingTask = nil

            self.discardPendingExport()
            if let artifacts = outcome.artifacts {
                self.pendingArtifacts = artifacts
                self.statusText = "Oda modeli ve mekân verisi hazır"
                self.exportSucceeded = true
                self.failureMessage = nil
                self.isProcessing = false
            } else if let failureMessage = outcome.failureMessage {
                self.recordFailure(
                    "Oda verisi dışa aktarılamadı: " + failureMessage
                )
            }
        }
    }
}

struct RoomScannerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner: RoomScannerController
    @State private var didReportResult = false
    private let onComplete: (RoomScanResult) -> Void

    init(
        exportURL: URL,
        roomJSONURL: URL? = nil,
        arSession: ARSession? = nil,
        onComplete: @escaping (RoomScanResult) -> Void = { _ in }
    ) {
        self.onComplete = onComplete
        _scanner = StateObject(
            wrappedValue: RoomScannerController(
                exportURL: exportURL,
                roomJSONURL: roomJSONURL,
                arSession: arSession
            )
        )
    }

    var body: some View {
        ZStack {
            RoomCaptureContainer(controller: scanner)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Text(scanner.statusText)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if scanner.isProcessing {
                        ProgressView()
                    }
                    Button {
                        reportAndDismiss(
                            scanner.failureMessage.map(RoomScanResult.failure) ?? .cancelled
                        )
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

                Spacer()

                if scanner.exportSucceeded {
                    Button("Taramayı Kullan") {
                        guard let url = scanner.commitExport() else { return }
                        reportAndDismiss(.success(url))
                    }
                        .buttonStyle(CineARPrimaryButtonStyle(color: .green))
                } else if scanner.failureMessage != nil {
                    HStack(spacing: 12) {
                        if RoomScannerController.isSupported {
                            Button("Tekrar Tara") { scanner.start() }
                                .buttonStyle(CineARPrimaryButtonStyle(color: .blue))
                        }
                        Button("Kapat") {
                            reportAndDismiss(
                                scanner.failureMessage.map(RoomScanResult.failure) ?? .cancelled
                            )
                        }
                        .buttonStyle(CineARPrimaryButtonStyle(color: .red))
                    }
                } else {
                    Button {
                        scanner.finish()
                    } label: {
                        Label("Taramayı Bitir", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(scanner.isProcessing || !RoomScannerController.isSupported)
                    .buttonStyle(CineARPrimaryButtonStyle(color: .blue))
                }
            }
            .padding()
        }
        .onAppear { scanner.start() }
        .onDisappear {
            guard !didReportResult else { return }
            didReportResult = true
            let result = scanner.failureMessage.map(RoomScanResult.failure) ?? .cancelled
            scanner.cancel()
            onComplete(result)
        }
    }

    private func reportAndDismiss(_ result: RoomScanResult) {
        guard !didReportResult else { return }
        didReportResult = true

        switch result {
        case .success:
            scanner.teardownForDismissal(discardPendingExport: false)
        case .cancelled, .failure:
            scanner.cancel()
        }
        onComplete(result)
        dismiss()
    }
}

private struct RoomCaptureContainer: UIViewRepresentable {
    let controller: RoomScannerController

    final class Coordinator {
        weak var controller: RoomScannerController?

        init(controller: RoomScannerController) {
            self.controller = controller
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> RoomCaptureView {
        controller.captureView
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}

    static func dismantleUIView(_ uiView: RoomCaptureView, coordinator: Coordinator) {
        coordinator.controller?.teardownForDismissal()
    }
}

struct CineARPrimaryButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(color.opacity(configuration.isPressed ? 0.65 : 0.95), in: Capsule())
    }
}
````

## `CineAR/SceneProjectStore.swift`

````swift
import ARKit
import CryptoKit
import Foundation
import RealityKit
import simd

struct SceneProject: Codable {
    static let currentVersion = 4

    var version = currentVersion
    var name = "Ana Set"
    var createdAt = Date()
    var updatedAt = Date()
    var placements: [PlacementRecord] = []
    var worldMapChecksum: String?
}

struct PlacementRecord: Codable, Identifiable {
    let id: UUID
    let kind: PropKind
    var assetFileName: String?
    var transform: StoredTransform
    var lightSettings: VirtualLightSettings? = nil
}

struct VirtualLightSettings: Codable, Equatable {
    static let defaultFixture = VirtualLightSettings(
        isEnabled: true,
        // Strong enough to remain visibly distinct from RealityKit's automatic
        // environment lighting while still leaving headroom for art direction.
        intensityLumens: 6_000,
        temperatureKelvin: 4_200,
        coneAngleDegrees: 18,
        yawDegrees: 0,
        tiltDegrees: 0,
        beamSoftness: 0.34
    )

    var isEnabled: Bool
    var intensityLumens: Float
    var temperatureKelvin: Float
    var coneAngleDegrees: Float
    // Optional for forward compatibility with version-3 scenes created before
    // steerable fixtures were introduced.
    var yawDegrees: Float?
    var tiltDegrees: Float?
    // Version-4 projector data is optional so scenes saved by earlier releases
    // continue to decode without migration failures. The target is stored in the
    // restored AR world coordinate system and therefore survives world-map reloads.
    var beamSoftness: Float?
    var targetPosition: [Float]?
    var targetNormal: [Float]?

    init(
        isEnabled: Bool,
        intensityLumens: Float,
        temperatureKelvin: Float,
        coneAngleDegrees: Float,
        yawDegrees: Float? = nil,
        tiltDegrees: Float? = nil,
        beamSoftness: Float? = nil,
        targetPosition: [Float]? = nil,
        targetNormal: [Float]? = nil
    ) {
        self.isEnabled = isEnabled
        self.intensityLumens = intensityLumens
        self.temperatureKelvin = temperatureKelvin
        self.coneAngleDegrees = coneAngleDegrees
        self.yawDegrees = yawDegrees
        self.tiltDegrees = tiltDegrees
        self.beamSoftness = beamSoftness
        self.targetPosition = targetPosition
        self.targetNormal = targetNormal
    }

    var effectiveYawDegrees: Float { yawDegrees ?? 0 }
    var effectiveTiltDegrees: Float { tiltDegrees ?? 0 }
    var effectiveBeamSoftness: Float { beamSoftness ?? 0.34 }

    var projectorTarget: SIMD3<Float>? {
        guard let targetPosition,
              targetPosition.count == 3,
              targetPosition.allSatisfy(\.isFinite) else { return nil }
        return SIMD3(targetPosition[0], targetPosition[1], targetPosition[2])
    }

    var projectorTargetNormal: SIMD3<Float>? {
        guard let targetNormal,
              targetNormal.count == 3,
              targetNormal.allSatisfy(\.isFinite) else { return nil }
        let normal = SIMD3(targetNormal[0], targetNormal[1], targetNormal[2])
        guard simd_length_squared(normal) > 0.000_001 else { return nil }
        return simd_normalize(normal)
    }

    var isValid: Bool {
        let yawIsValid = yawDegrees.map { $0.isFinite && (-180...180).contains($0) } ?? true
        let tiltIsValid = tiltDegrees.map { $0.isFinite && (-75...75).contains($0) } ?? true
        let softnessIsValid = beamSoftness.map { $0.isFinite && (0...1).contains($0) } ?? true
        let targetIsValid = targetPosition.map {
            $0.count == 3 && $0.allSatisfy(\.isFinite)
        } ?? true
        let targetNormalIsValid = targetNormal.map {
            guard $0.count == 3, $0.allSatisfy(\.isFinite) else { return false }
            return simd_length_squared(SIMD3($0[0], $0[1], $0[2])) > 0.000_001
        } ?? true
        return intensityLumens.isFinite && (0...12_000).contains(intensityLumens)
            && temperatureKelvin.isFinite && (2_000...6_500).contains(temperatureKelvin)
            && coneAngleDegrees.isFinite && (8...120).contains(coneAngleDegrees)
            && yawIsValid
            && tiltIsValid
            && softnessIsValid
            && targetIsValid
            && targetNormalIsValid
    }
}

struct StoredWorldMapSnapshot {
    let data: Data
    let project: SceneProject
}

struct RecoveredWorldMapSnapshot {
    let snapshot: StoredWorldMapSnapshot
    let discardedPlacementCount: Int
    let discardedAnchorCount: Int
}

struct SavedPlaceSummary: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    var objectCount: Int
    var hasRoomScan: Bool
}

struct StoredTransform: Codable {
    var translation: [Float]
    var rotation: [Float]
    var scale: [Float]

    init(_ transform: Transform) {
        translation = [transform.translation.x, transform.translation.y, transform.translation.z]
        rotation = [
            transform.rotation.vector.x,
            transform.rotation.vector.y,
            transform.rotation.vector.z,
            transform.rotation.vector.w
        ]
        scale = [transform.scale.x, transform.scale.y, transform.scale.z]
    }

    var realityKitTransform: Transform {
        Transform(
            scale: SIMD3(scale[0], scale[1], scale[2]),
            rotation: simd_normalize(
                simd_quatf(
                    ix: rotation[0],
                    iy: rotation[1],
                    iz: rotation[2],
                    r: rotation[3]
                )
            ),
            translation: SIMD3(translation[0], translation[1], translation[2])
        )
    }
}

enum SceneProjectStoreError: LocalizedError {
    case unsupportedProjectVersion(Int)
    case invalidTransform(UUID)
    case duplicatePlacement(UUID)
    case missingPlacement(UUID)
    case invalidAssetFileName(String)
    case unsupportedAssetType
    case invalidLightSettings(UUID)
    case worldMapOutOfDate
    case worldMapChecksumMismatch
    case emptyWorldMap
    case savedPlaceNotFound(UUID)
    case invalidSavedPlace(UUID)

    var errorDescription: String? {
        switch self {
        case .unsupportedProjectVersion(let version):
            "scene.json sürümü desteklenmiyor (sürüm \(version))"
        case .invalidTransform(let id):
            "\(id.uuidString) kimlikli dekorun dönüşüm verisi geçersiz"
        case .duplicatePlacement(let id):
            "scene.json içinde yinelenen dekor kimliği var: \(id.uuidString)"
        case .missingPlacement(let id):
            "\(id.uuidString) kimlikli dekor proje kaydında bulunamadı"
        case .invalidAssetFileName(let name):
            "Geçersiz 3B model dosya adı: \(name)"
        case .unsupportedAssetType:
            "Yalnızca USDZ dosyaları içe aktarılabilir"
        case .invalidLightSettings(let id):
            "\(id.uuidString) kimlikli ışık ayarları geçersiz"
        case .worldMapOutOfDate:
            "Sahne son harita kaydından sonra değişmiş; önce yeniden Kaydet'e dokunun"
        case .worldMapChecksumMismatch:
            "worldmap ve scene.json aynı kayıt sürümüne ait değil"
        case .emptyWorldMap:
            "Dünya haritası dosyası boş"
        case .savedPlaceNotFound(let id):
            "Kayıtlı mekân bulunamadı: \(id.uuidString)"
        case .invalidSavedPlace:
            "Kayıtlı mekân dosyaları eksik veya birbiriyle eşleşmiyor"
        }
    }
}

final class SceneProjectStore {
    private let fileManager = FileManager.default

    private(set) var project: SceneProject
    private(set) var initializationError: Error? = nil
    private(set) var initializationNotice: String? = nil

    init() {
        project = SceneProject()
        do {
            try fileManager.createDirectory(
                at: projectDirectory,
                withIntermediateDirectories: true
            )
            try fileManager.createDirectory(
                at: savedPlacesDirectory,
                withIntermediateDirectories: true
            )
            if fileManager.fileExists(atPath: projectURL.path) {
                project = try Self.decodeProject(from: projectURL)
            }
        } catch {
            let decodingError = error
            do {
                let recoveredCount = try rebuildCorruptProjectFromWorldMap()
                initializationNotice = "Bozuk scene.json yedeklendi; "
                    + "dünya haritasından \(recoveredCount) nesne kurtarıldı"
            } catch {
                initializationError = decodingError
            }
        }
    }

    var projectDirectory: URL {
        projectsRootDirectory
            .appendingPathComponent("MainSet", isDirectory: true)
    }

    var projectsRootDirectory: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("CineARProjects", isDirectory: true)
    }

    var savedPlacesDirectory: URL {
        projectsRootDirectory.appendingPathComponent("SavedPlaces", isDirectory: true)
    }

    var projectURL: URL { projectDirectory.appendingPathComponent("scene.json") }
    var worldMapURL: URL { projectDirectory.appendingPathComponent("worldmap.arexperience") }
    var roomModelURL: URL { projectDirectory.appendingPathComponent("room.usdz") }
    var roomDataURL: URL { projectDirectory.appendingPathComponent("room.json") }
    var recordingsDirectory: URL {
        projectDirectory.appendingPathComponent("Recordings", isDirectory: true)
    }
    var assetsDirectory: URL {
        projectDirectory.appendingPathComponent("Assets", isDirectory: true)
    }

    var savedPlaces: [SavedPlaceSummary] {
        let directories = (try? fileManager.contentsOfDirectory(
            at: savedPlacesDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return directories.compactMap { directory in
            guard ((try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false)
            else { return nil }
            return try? Self.decodeSavedPlaceManifest(
                from: directory.appendingPathComponent("place.json")
            )
        }.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt { return lhs.name < rhs.name }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    @discardableResult
    func archiveCurrentProject(preferredName: String? = nil) throws -> SavedPlaceSummary {
        let snapshot = try worldMapSnapshotForLoading()
        let identifier = UUID()
        let stagingURL = savedPlacesDirectory.appendingPathComponent(
            ".staging-\(identifier.uuidString)",
            isDirectory: true
        )
        let destinationURL = savedPlaceDirectory(id: identifier)
        try fileManager.createDirectory(at: savedPlacesDirectory, withIntermediateDirectories: true)
        removeIfPresent(stagingURL)
        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)

        let now = Date()
        let suppliedName = preferredName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let summary = SavedPlaceSummary(
            id: identifier,
            name: suppliedName.flatMap { $0.isEmpty ? nil : $0 } ?? Self.defaultSavedPlaceName(now),
            createdAt: now,
            updatedAt: now,
            objectCount: snapshot.project.placements.count,
            hasRoomScan: fileManager.fileExists(atPath: roomDataURL.path)
        )

        do {
            try Self.encode(snapshot.project).write(
                to: stagingURL.appendingPathComponent("scene.json"),
                options: .atomic
            )
            try snapshot.data.write(
                to: stagingURL.appendingPathComponent("worldmap.arexperience"),
                options: .atomic
            )
            if fileManager.fileExists(atPath: roomDataURL.path) {
                try fileManager.copyItem(
                    at: roomDataURL,
                    to: stagingURL.appendingPathComponent("room.json")
                )
            }
            if fileManager.fileExists(atPath: assetsDirectory.path) {
                try fileManager.copyItem(
                    at: assetsDirectory,
                    to: stagingURL.appendingPathComponent("Assets", isDirectory: true)
                )
            }
            try Self.encodeSavedPlaceManifest(summary).write(
                to: stagingURL.appendingPathComponent("place.json"),
                options: .atomic
            )
            try fileManager.moveItem(at: stagingURL, to: destinationURL)
            return summary
        } catch {
            removeIfPresent(stagingURL)
            throw error
        }
    }

    /// Validates a saved scene before replacing the active working set. The current
    /// set is backed up for the duration of the transaction and restored on failure.
    func installSavedPlace(id: UUID) throws -> StoredWorldMapSnapshot {
        let sourceDirectory = savedPlaceDirectory(id: id)
        guard fileManager.fileExists(atPath: sourceDirectory.path) else {
            throw SceneProjectStoreError.savedPlaceNotFound(id)
        }
        let manifest = try Self.decodeSavedPlaceManifest(
            from: sourceDirectory.appendingPathComponent("place.json")
        )
        guard manifest.id == id else { throw SceneProjectStoreError.invalidSavedPlace(id) }

        let candidate = try Self.decodeProject(
            from: sourceDirectory.appendingPathComponent("scene.json")
        )
        let worldMapData = try Data(
            contentsOf: sourceDirectory.appendingPathComponent("worldmap.arexperience")
        )
        guard !worldMapData.isEmpty,
              candidate.worldMapChecksum == Self.checksum(for: worldMapData) else {
            throw SceneProjectStoreError.invalidSavedPlace(id)
        }
        guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: ARWorldMap.self,
            from: worldMapData
        ) else {
            throw SceneProjectStoreError.invalidSavedPlace(id)
        }
        let placementKinds = Dictionary(uniqueKeysWithValues: candidate.placements.map {
            ($0.id, $0.kind)
        })
        let anchorDescriptors = worldMap.anchors.compactMap {
            PropKind.descriptor(from: $0.name)
        }
        var anchorKinds: [UUID: PropKind] = [:]
        for descriptor in anchorDescriptors {
            guard anchorKinds.updateValue(descriptor.kind, forKey: descriptor.id) == nil else {
                throw SceneProjectStoreError.invalidSavedPlace(id)
            }
        }
        guard anchorKinds == placementKinds else {
            throw SceneProjectStoreError.invalidSavedPlace(id)
        }
        for placement in candidate.placements where placement.kind == .custom {
            guard let fileName = placement.assetFileName,
                  fileManager.fileExists(atPath: sourceDirectory
                    .appendingPathComponent("Assets", isDirectory: true)
                    .appendingPathComponent(fileName).path) else {
                throw SceneProjectStoreError.invalidSavedPlace(id)
            }
        }

        let backupDirectory = projectsRootDirectory.appendingPathComponent(
            ".active-backup-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        let managedNames = ["scene.json", "worldmap.arexperience", "room.json", "Assets"]
        do {
            for name in managedNames {
                let activeURL = projectDirectory.appendingPathComponent(name)
                if fileManager.fileExists(atPath: activeURL.path) {
                    try fileManager.moveItem(
                        at: activeURL,
                        to: backupDirectory.appendingPathComponent(name)
                    )
                }
            }
            for name in managedNames {
                let archivedURL = sourceDirectory.appendingPathComponent(name)
                guard fileManager.fileExists(atPath: archivedURL.path) else { continue }
                try fileManager.copyItem(
                    at: archivedURL,
                    to: projectDirectory.appendingPathComponent(name)
                )
            }
            project = candidate
            initializationError = nil
            removeIfPresent(backupDirectory)
            return StoredWorldMapSnapshot(data: worldMapData, project: candidate)
        } catch {
            for name in managedNames {
                removeIfPresent(projectDirectory.appendingPathComponent(name))
                let backupURL = backupDirectory.appendingPathComponent(name)
                if fileManager.fileExists(atPath: backupURL.path) {
                    try? fileManager.moveItem(
                        at: backupURL,
                        to: projectDirectory.appendingPathComponent(name)
                    )
                }
            }
            removeIfPresent(backupDirectory)
            throw error
        }
    }

    func deleteSavedPlace(id: UUID) throws {
        let directory = savedPlaceDirectory(id: id)
        guard fileManager.fileExists(atPath: directory.path) else {
            throw SceneProjectStoreError.savedPlaceNotFound(id)
        }
        try fileManager.removeItem(at: directory)
    }

    private func savedPlaceDirectory(id: UUID) -> URL {
        savedPlacesDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private func removeIfPresent(_ url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.removeItem(at: url)
    }

    /// The shared ARSession keeps the same coordinate space while RoomPlan scans.
    /// If RoomPlan's transition temporarily omits manual anchors from the live frame,
    /// their last committed world transforms remain valid reconciliation candidates.
    func storedManagedAnchors() -> [ARAnchor] {
        do {
            let data = try Data(contentsOf: worldMapURL)
            guard !data.isEmpty,
                  let worldMap = try NSKeyedUnarchiver.unarchivedObject(
                      ofClass: ARWorldMap.self,
                      from: data
                  ) else { return [] }
            return worldMap.anchors.filter {
                $0.name?.hasPrefix("cinear.prop.") == true
            }
        } catch {
            return []
        }
    }

    private func rebuildCorruptProjectFromWorldMap() throws -> Int {
        let identifier = UUID().uuidString
        let backupURL = projectDirectory.appendingPathComponent(
            "scene-corrupt-\(identifier).json"
        )
        if fileManager.fileExists(atPath: projectURL.path) {
            try fileManager.copyItem(at: projectURL, to: backupURL)
        }

        var recoveredPlacements: [PlacementRecord] = []
        var seenIDs = Set<UUID>()
        if let data = try? Data(contentsOf: worldMapURL),
           !data.isEmpty,
           let worldMap = try? NSKeyedUnarchiver.unarchivedObject(
               ofClass: ARWorldMap.self,
               from: data
           ) {
            for anchor in worldMap.anchors {
                guard let descriptor = PropKind.descriptor(from: anchor.name),
                      descriptor.kind != .custom,
                      seenIDs.insert(descriptor.id).inserted else { continue }
                recoveredPlacements.append(
                    PlacementRecord(
                        id: descriptor.id,
                        kind: descriptor.kind,
                        assetFileName: nil,
                        transform: Self.recoveredDefaultTransform(for: descriptor.kind),
                        lightSettings: descriptor.kind.emitsVirtualLight
                            ? VirtualLightSettings.defaultFixture
                            : nil
                    )
                )
            }
        }

        var recoveredProject = SceneProject()
        recoveredProject.placements = recoveredPlacements
        // Force one synchronized world-map save. The old map is still available as
        // an anchor source, but its previous JSON checksum can no longer be trusted.
        recoveredProject.worldMapChecksum = nil
        try Self.validate(recoveredProject)
        let data = try Self.encode(recoveredProject)
        try data.write(to: projectURL, options: .atomic)
        project = recoveredProject
        initializationError = nil
        return recoveredPlacements.count
    }

    private static func recoveredDefaultTransform(for _: PropKind) -> StoredTransform {
        return StoredTransform(
            Transform(
                scale: [1, 1, 1],
                rotation: simd_quatf(angle: 0, axis: [0, 1, 0]),
                translation: .zero
            )
        )
    }

    var importedModelURLs: [URL] {
        (try? fileManager.contentsOfDirectory(
            at: assetsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey]
        ).filter {
            $0.pathExtension.lowercased() == "usdz"
                && ((try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false)
        }.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }) ?? []
    }

    func importModel(from sourceURL: URL) throws -> URL {
        guard sourceURL.isFileURL, sourceURL.pathExtension.lowercased() == "usdz" else {
            throw SceneProjectStoreError.unsupportedAssetType
        }
        try fileManager.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)

        let rawBaseName = sourceURL.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = rawBaseName.isEmpty ? "Model" : rawBaseName
        var destination = assetsDirectory.appendingPathComponent(baseName)
            .appendingPathExtension("usdz")
        var suffix = 2
        while fileManager.fileExists(atPath: destination.path) {
            destination = assetsDirectory.appendingPathComponent("\(baseName)-\(suffix)")
                .appendingPathExtension("usdz")
            suffix += 1
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
        return destination
    }

    func modelURL(fileName: String) throws -> URL {
        guard fileName == URL(fileURLWithPath: fileName).lastPathComponent,
              !fileName.isEmpty,
              URL(fileURLWithPath: fileName).pathExtension.lowercased() == "usdz" else {
            throw SceneProjectStoreError.invalidAssetFileName(fileName)
        }
        return assetsDirectory.appendingPathComponent(fileName)
    }

    func placement(id: UUID) -> PlacementRecord? {
        project.placements.first { $0.id == id }
    }

    func upsert(_ placement: PlacementRecord) throws {
        try commit(invalidateWorldMap: true) { candidate in
            if let index = candidate.placements.firstIndex(where: { $0.id == placement.id }) {
                candidate.placements[index] = placement
            } else {
                candidate.placements.append(placement)
            }
        }
    }

    func updateTransforms(_ transforms: [UUID: Transform]) throws {
        if let initializationError { throw initializationError }
        guard !transforms.isEmpty else { return }
        try commit(invalidateWorldMap: false) { candidate in
            for (id, transform) in transforms {
                guard let index = candidate.placements.firstIndex(where: { $0.id == id }) else {
                    throw SceneProjectStoreError.missingPlacement(id)
                }
                candidate.placements[index].transform = StoredTransform(transform)
            }
        }
    }

    func updateLightSettings(id: UUID, settings: VirtualLightSettings) throws {
        try commit(invalidateWorldMap: false) { candidate in
            guard let index = candidate.placements.firstIndex(where: { $0.id == id }) else {
                throw SceneProjectStoreError.missingPlacement(id)
            }
            guard candidate.placements[index].kind.emitsVirtualLight, settings.isValid else {
                throw SceneProjectStoreError.invalidLightSettings(id)
            }
            candidate.placements[index].lightSettings = settings
        }
    }

    func remove(id: UUID) throws {
        try commit(invalidateWorldMap: true) { candidate in
            guard candidate.placements.contains(where: { $0.id == id }) else {
                throw SceneProjectStoreError.missingPlacement(id)
            }
            candidate.placements.removeAll { $0.id == id }
        }
    }

    func removeAll() throws {
        try commit(invalidateWorldMap: true) { candidate in
            candidate.placements.removeAll()
        }
    }

    /// A new RoomPlan scan has a new spatial source of truth. Keep placements,
    /// but force the user to save a matching ARWorldMap before a later reload.
    func invalidateWorldMapForRoomScan() throws {
        try commit(invalidateWorldMap: true) { _ in }
    }

    @discardableResult
    func saveWorldMapData(
        _ data: Data,
        retainingPlacementIDs: Set<UUID>? = nil
    ) throws -> Int {
        if let initializationError { throw initializationError }
        guard !data.isEmpty else { throw SceneProjectStoreError.emptyWorldMap }
        try fileManager.createDirectory(at: projectDirectory, withIntermediateDirectories: true)

        var candidate = project
        let originalPlacementCount = candidate.placements.count
        if let retainingPlacementIDs {
            candidate.placements.removeAll { !retainingPlacementIDs.contains($0.id) }
        }
        candidate.version = SceneProject.currentVersion
        candidate.updatedAt = Date()
        candidate.worldMapChecksum = Self.checksum(for: data)
        try Self.validate(candidate)
        let projectData = try Self.encode(candidate)

        // The map is written first. If the following JSON write fails, the previous
        // JSON checksum will reject this new map instead of loading a mismatched pair.
        try data.write(to: worldMapURL, options: .atomic)
        try projectData.write(to: projectURL, options: .atomic)
        project = candidate
        initializationError = nil
        return originalPlacementCount - candidate.placements.count
    }

    func worldMapSnapshotForLoading() throws -> StoredWorldMapSnapshot {
        let candidate = try Self.decodeProject(from: projectURL)
        let data = try Data(contentsOf: worldMapURL)
        guard !data.isEmpty else { throw SceneProjectStoreError.emptyWorldMap }

        if candidate.version >= SceneProject.currentVersion {
            guard let expectedChecksum = candidate.worldMapChecksum else {
                throw SceneProjectStoreError.worldMapOutOfDate
            }
            guard expectedChecksum == Self.checksum(for: data) else {
                throw SceneProjectStoreError.worldMapChecksumMismatch
            }
        }
        return StoredWorldMapSnapshot(data: data, project: candidate)
    }

    /// Repairs a scene/map pair left between the JSON and world-map writes.
    /// A placement without a matching world anchor cannot be positioned safely,
    /// so only that orphan is discarded; every matching placement is preserved.
    func recoverWorldMapSnapshot() throws -> RecoveredWorldMapSnapshot {
        var candidate = try Self.decodeProject(from: projectURL)
        let storedData = try Data(contentsOf: worldMapURL)
        guard !storedData.isEmpty,
              let worldMap = try NSKeyedUnarchiver.unarchivedObject(
                  ofClass: ARWorldMap.self,
                  from: storedData
              ) else {
            throw SceneProjectStoreError.emptyWorldMap
        }

        let placementKinds = Dictionary(uniqueKeysWithValues: candidate.placements.map {
            ($0.id, $0.kind)
        })
        var matchingAnchors: [UUID: ARAnchor] = [:]
        var managedAnchorCount = 0
        for anchor in worldMap.anchors {
            guard anchor.name?.hasPrefix("cinear.prop.") == true else { continue }
            managedAnchorCount += 1
            guard let descriptor = PropKind.descriptor(from: anchor.name) else { continue }
            guard placementKinds[descriptor.id] == descriptor.kind,
                  matchingAnchors[descriptor.id] == nil else { continue }
            matchingAnchors[descriptor.id] = anchor
        }

        let originalPlacementCount = candidate.placements.count
        candidate.placements.removeAll { matchingAnchors[$0.id] == nil }
        let survivingIDs = Set(candidate.placements.map(\.id))
        let unmanagedAnchors = worldMap.anchors.filter {
            $0.name?.hasPrefix("cinear.prop.") != true
        }
        let managedAnchors = candidate.placements.compactMap { matchingAnchors[$0.id] }
        worldMap.anchors = unmanagedAnchors + managedAnchors

        // Defensive check: all managed anchors left in the repaired map must belong
        // to the placements that survived the intersection above.
        guard managedAnchors.allSatisfy({ anchor in
            guard let descriptor = PropKind.descriptor(from: anchor.name) else { return false }
            return survivingIDs.contains(descriptor.id)
        }) else {
            throw SceneProjectStoreError.worldMapChecksumMismatch
        }

        let repairedData = try NSKeyedArchiver.archivedData(
            withRootObject: worldMap,
            requiringSecureCoding: true
        )
        candidate.version = SceneProject.currentVersion
        candidate.updatedAt = Date()
        candidate.worldMapChecksum = Self.checksum(for: repairedData)
        try Self.validate(candidate)
        let projectData = try Self.encode(candidate)
        try repairedData.write(to: worldMapURL, options: .atomic)
        try projectData.write(to: projectURL, options: .atomic)
        project = candidate
        initializationError = nil

        return RecoveredWorldMapSnapshot(
            snapshot: StoredWorldMapSnapshot(data: repairedData, project: candidate),
            discardedPlacementCount: originalPlacementCount - candidate.placements.count,
            discardedAnchorCount: max(0, managedAnchorCount - managedAnchors.count)
        )
    }

    func activate(_ snapshot: StoredWorldMapSnapshot) {
        project = snapshot.project
        initializationError = nil
    }

    func nextRecordingURL() throws -> URL {
        try fileManager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let suffix = UUID().uuidString.prefix(6)
        return recordingsDirectory.appendingPathComponent(
            "CineAR-\(formatter.string(from: Date()))-\(suffix).mov"
        )
    }

    private func commit(
        invalidateWorldMap: Bool,
        mutation: (inout SceneProject) throws -> Void
    ) throws {
        if let initializationError { throw initializationError }
        var candidate = project
        try mutation(&candidate)
        candidate.version = SceneProject.currentVersion
        candidate.updatedAt = Date()
        if invalidateWorldMap {
            candidate.worldMapChecksum = nil
        }
        try Self.validate(candidate)
        let data = try Self.encode(candidate)
        try fileManager.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        try data.write(to: projectURL, options: .atomic)
        project = candidate
    }

    private static func encode(_ project: SceneProject) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(project)
    }

    private static func encodeSavedPlaceManifest(_ summary: SavedPlaceSummary) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(summary)
    }

    private static func decodeSavedPlaceManifest(from url: URL) throws -> SavedPlaceSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SavedPlaceSummary.self, from: Data(contentsOf: url))
    }

    private static func defaultSavedPlaceName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMM yyyy HH:mm"
        return "Mekân \(formatter.string(from: date))"
    }

    private static func decodeProject(from url: URL) throws -> SceneProject {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var project = try decoder.decode(SceneProject.self, from: Data(contentsOf: url))
        if project.version < 4 {
            // Earlier renderers stored a half-height offset in the placement entity.
            // Version 4 uses a contact-plane pivot, so retaining that legacy offset
            // would make every restored object float above its anchor.
            for index in project.placements.indices {
                guard project.placements[index].transform.translation.count == 3 else { continue }
                project.placements[index].transform.translation = [0, 0, 0]
                if var light = project.placements[index].lightSettings {
                    if abs(light.coneAngleDegrees - 72) < 0.01 {
                        light.coneAngleDegrees = 18
                    }
                    if light.beamSoftness == nil { light.beamSoftness = 0.34 }
                    project.placements[index].lightSettings = light
                }
            }
            project.version = 4
            project.updatedAt = Date()
        }
        try validate(project)
        return project
    }

    private static func validate(_ project: SceneProject) throws {
        guard project.version > 0, project.version <= SceneProject.currentVersion else {
            throw SceneProjectStoreError.unsupportedProjectVersion(project.version)
        }

        var ids = Set<UUID>()
        for placement in project.placements {
            guard ids.insert(placement.id).inserted else {
                throw SceneProjectStoreError.duplicatePlacement(placement.id)
            }
            guard isValid(placement.transform) else {
                throw SceneProjectStoreError.invalidTransform(placement.id)
            }
            if placement.kind == .custom {
                guard let fileName = placement.assetFileName,
                      fileName == URL(fileURLWithPath: fileName).lastPathComponent,
                      URL(fileURLWithPath: fileName).pathExtension.lowercased() == "usdz" else {
                    throw SceneProjectStoreError.invalidAssetFileName(
                        placement.assetFileName ?? "(eksik)"
                    )
                }
            }
            if let lightSettings = placement.lightSettings {
                guard placement.kind.emitsVirtualLight, lightSettings.isValid else {
                    throw SceneProjectStoreError.invalidLightSettings(placement.id)
                }
            }
        }
    }

    private static func isValid(_ transform: StoredTransform) -> Bool {
        guard transform.translation.count == 3,
              transform.rotation.count == 4,
              transform.scale.count == 3,
              transform.translation.allSatisfy(\.isFinite),
              transform.rotation.allSatisfy(\.isFinite),
              transform.scale.allSatisfy(\.isFinite),
              transform.scale.allSatisfy({ $0 > 0.0001 }) else { return false }

        let rotationMagnitudeSquared = transform.rotation.reduce(Float.zero) {
            $0 + ($1 * $1)
        }
        return rotationMagnitudeSquared > 0.000001
    }

    private static func checksum(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
````

## `codemagic.yaml`

````yaml
workflows:
  cinear-testflight:
    name: CineAR - TestFlight
    instance_type: mac_mini_m2
    max_build_duration: 120

    integrations:
      app_store_connect: Apple

    environment:
      groups:
        # Codemagic UI'da Secret olmasi gerekmez:
        # APP_STORE_APPLE_ID
        - cinear_config

      ios_signing:
        distribution_type: app_store
        bundle_identifier: com.cinear.virtualproduction

      vars:
        BUNDLE_ID: "com.cinear.virtualproduction"
        XCODE_PROJECT: "CineAR.xcodeproj"
        XCODE_SCHEME: "CineAR"
      xcode: 26.4

    scripts:
      - name: Validate project and required variables
        script: |
          #!/bin/bash
          set -euo pipefail

          required_variables=(
            APP_STORE_APPLE_ID
          )

          for variable_name in "${required_variables[@]}"; do
            if [[ -z "${!variable_name:-}" ]]; then
              echo "Missing Codemagic environment variable: ${variable_name}" >&2
              exit 1
            fi
          done

          if [[ ! "$APP_STORE_APPLE_ID" =~ ^[0-9]+$ ]]; then
            echo "APP_STORE_APPLE_ID must be the numeric Apple ID from App Store Connect." >&2
            exit 1
          fi

          if [[ ! -d "$CM_BUILD_DIR/$XCODE_PROJECT" ]]; then
            echo "Xcode project not found: $CM_BUILD_DIR/$XCODE_PROJECT" >&2
            exit 1
          fi

          build_settings="$(
            xcodebuild \
              -project "$CM_BUILD_DIR/$XCODE_PROJECT" \
              -scheme "$XCODE_SCHEME" \
              -configuration Release \
              -showBuildSettings
          )"
          project_bundle_id="$(
            awk -F ' = ' \
              '/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = / && !found { print $2; found=1 }' \
              <<< "$build_settings"
          )"

          if [[ "$project_bundle_id" != "$BUNDLE_ID" ]]; then
            echo "Bundle ID mismatch. Project: ${project_bundle_id:-not found}; workflow: $BUNDLE_ID" >&2
            exit 1
          fi

      - name: Apply provisioning profile
        script: xcode-project use-profiles

      - name: Increment build number from App Store Connect
        script: |
          #!/bin/bash
          set -euo pipefail
          cd "$CM_BUILD_DIR"

          set +e
          latest_build_output="$(
            # Keep diagnostic logs on stderr; stdout contains only the build number.
            app-store-connect get-latest-build-number "$APP_STORE_APPLE_ID" \
              --platform IOS \
              --all-versions
          )"
          latest_build_status=$?
          set -e

          if [[ $latest_build_status -ne 0 ]]; then
            echo "App Store Connect build number query failed." >&2
            exit "$latest_build_status"
          fi

          latest_build_number="$(
            printf '%s' "$latest_build_output" | tr -d '[:space:]'
          )"

          if [[ -z "$latest_build_number" ]]; then
            latest_build_number=0
            echo "No existing App Store Connect build found; starting at build 1."
          elif [[ ! "$latest_build_number" =~ ^[0-9]+$ ]]; then
            echo "App Store Connect returned an invalid build number: $latest_build_output" >&2
            exit 1
          fi

          next_build_number="$((10#$latest_build_number + 1))"
          xcrun agvtool new-version -all "$next_build_number"
          echo "CineAR build number: $next_build_number"

      - name: Build Release archive and IPA
        script: |
          xcode-project build-ipa \
            --project "$CM_BUILD_DIR/$XCODE_PROJECT" \
            --scheme "$XCODE_SCHEME" \
            --config Release \
            --clean

    artifacts:
      - build/ios/ipa/*.ipa
      - build/ios/xcarchive/*.xcarchive
      - /tmp/xcodebuild_logs/*.log
      - $HOME/Library/Developer/Xcode/DerivedData/**/Build/**/*.dSYM

    publishing:
      app_store_connect:
        auth: integration
        # The internal group uses App Store Connect automatic distribution.
        # Publishing uploads the IPA; Apple assigns processed builds to the group.
        submit_to_app_store: false
````

## `Docs/CODEMAGIC.md`

````markdown
# CineAR Codemagic ve TestFlight kurulumu

Bu depo, `cinear-testflight` is akisi ile Release `.xcarchive` ve imzali `.ipa`
uretir ve basarili IPA'yi App Store Connect'e yukler. `CineAR Internal Testers`
grubunda otomatik dagitim etkin olmalidir; islenen build'i gruba Apple atar. Is
akisi manuel baslatilir; depoya her kod gonderildiginde kendiliginden yayin
yapmaz.

## Apple tarafinda bir kez yapilacaklar

Bu adimlari Apple Developer Program uyesi olan hesap sahibi veya gerekli
yetkilere sahip ekip uyesi yapmalidir.

1. Apple Developer > Certificates, Identifiers & Profiles > Identifiers
   bolumunde Explicit App ID olusturun. Bundle ID tam olarak
   `com.cinear.virtualproduction` olmalidir.
2. App Store Connect > Apps > `+` > New App ile CineAR kaydi olusturun ve ayni
   Bundle ID'yi secin. SKU serbesttir; ornegin `CINEAR-IOS-001`.
3. App Store Connect > Users and Access > Integrations > App Store Connect API
   bolumunde `App Manager` yetkili ayri bir API key olusturun. `.p8` dosyasini
   hemen indirin; Apple bu dosyanin yalnizca bir kez indirilmesine izin verir.
   Issuer ID ve Key ID degerlerini not edin.
4. CineAR uygulamasinda TestFlight > Internal Testing altinda adi tam olarak
   `CineAR Internal Testers` olan bir grup olusturun, otomatik dagitimi
   etkinlestirin ve test edecek App Store Connect kullanicilarini ekleyin.
5. App Store Connect > CineAR > General > App Information altindaki sayisal
   Apple ID'yi not edin. Bu deger Bundle ID degildir.

## Codemagic Apple entegrasyonu ve degisken grubu

Team settings > Integrations > Apple Developer Portal altinda App Store Connect
API anahtarini `Apple` adiyla baglayin. Anahtarin App Manager yetkisi olmalidir.
`codemagic.yaml`, imzalama ve yayinlama icin bu entegrasyonu dogrudan kullanir;
API private key'ini uygulama environment variables ekranina tekrar eklemeyin.

Codemagic'te Git deposunu ekledikten sonra App settings > Environment variables
altinda `cinear_config` grubunu olusturun.

| Degisken | Deger |
| --- | --- |
| `APP_STORE_APPLE_ID` | App Store Connect'teki CineAR uygulamasinin sayisal Apple ID'si |

Apple ID gizli bir anahtar degildir; `Secret` secilmesi gerekmez. Entegrasyon,
grup ve degisken adlari buyuk/kucuk harf dahil burada yazildigi gibi olmalidir.

## Ilk derleme

1. `codemagic.yaml` dosyasinin deponun kokunde oldugunu kontrol edin.
2. Codemagic uygulama sayfasinda **Check for configuration file** ile YAML'i
   yeniden taratin.
3. **Start new build** secin, gonderilen dali ve `CineAR - TestFlight` is
   akisini secerek derlemeyi baslatin.
4. Is akisi sirasiyla yapilandirmayi kontrol eder, App Store profili ve dagitim
   sertifikasini Apple'dan getirir/olusturur, App Store Connect'teki en yuksek
   build numarasini bir artirir, Release archive ve IPA olusturur ve TestFlight'a
   yukler.
5. Apple'in build islemesi tamamlaninca App Store Connect > CineAR > TestFlight
   ekranindan durumu kontrol edin. Ilk build'de ihracat uygunlugu veya beta test
   bilgileri icin Apple ek alanlar isterse bunlari App Store Connect'te doldurun.

YAML'deki `submit_to_app_store: false` nedeniyle bu akisin App Store production
incelemesine uygulama gondermesi mumkun degildir.

## Sik rastlanan hatalar

- `Bundle ID mismatch`: Xcode projesi ve YAML ayni
  `com.cinear.virtualproduction` kimligini kullanmiyor.
- `Missing Codemagic environment variable`: `cinear_config` grubunun adi,
  `APP_STORE_APPLE_ID` degiskeni veya dal erisimi yanlis.
- Certificate/profile hatasi: `Apple` entegrasyonunun etkin oldugunu, API key
  rolunun `App Manager` oldugunu ve Apple Developer uyeliginin aktif oldugunu
  kontrol edin.
- App bulunamadi/build numarasi alinamadi: `APP_STORE_APPLE_ID` alanina sayisal
  App Store Connect Apple ID yerine Bundle ID yazilmis olabilir.
- Build ic grupta gorunmuyor: `CineAR Internal Testers` grubunda otomatik
  dagitimin etkin oldugunu kontrol edin veya build'i App Store Connect'ten
  gruba elle ekleyin.

## Resmi kaynaklar

- [Codemagic: Native iOS apps](https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/)
- [Codemagic: Automatic iOS code signing](https://docs.codemagic.io/yaml-code-signing/alternative-code-signing-methods/)
- [Codemagic: App Store Connect publishing](https://docs.codemagic.io/yaml-publishing/app-store-connect/)
- [Codemagic CLI: build-ipa](https://github.com/codemagic-ci-cd/cli-tools/blob/master/docs/xcode-project/build-ipa.md)
- [Codemagic CLI: latest build number](https://github.com/codemagic-ci-cd/cli-tools/blob/master/docs/app-store-connect/get-latest-build-number.md)
````

## `Docs/DEVICE_TEST.md`

````markdown
# CineAR cihaz kabul testi

## Hedef donanim

- LiDAR destekli iPhone Pro
- Tripod ve elde kullanim
- Dokulu, iyi aydinlatilmis en az 4 x 4 metre test alani
- On, orta ve arka planda gercek nesneler

## Fonksiyon testi

1. Uygulama acilir acilmaz alt panelde `Odayi Tara` dugmesinin gorundugunu dogrula.
   Odayi RoomPlan ile tamamen tara; `room.json` olustugunu ve `Taramayi Bitir`
   sonrasinda uygulamanin kapanmadigini dogrula.
2. Tarama sirasinda yalniz RoomPlan'in beyaz/seffaf kilavuzlarinin gorundugunu;
   tarama onayindan sonra opak duvar, zemin veya mobilya kaplamasi olusmadigini dogrula.
3. Tarama boyunca kamera hareketinin akici oldugunu, ana gorunume donuste gercek
   insanlarin ve mobilyalarin tamamen gorunur kaldigini kontrol et.
   Ana gorunume dondukten sonra AR durumu en gec 10 saniye icinde hazir olmali;
   yeni bir tracking callback'i gelmese de kutuphane ve yerlestirme kullanilabilmeli.
4. `Beyaz Hatlar`i ac; duvar, zemin, kapi/pencere ve taninan buyuk objelerin yalniz
   ince seffaf hatlarla gorundugunu, kameranin kapanmadigini ve `Gercek` secilince
   butun hatlarin kayboldugunu dogrula.
5. Kasa'yi sec. Alt panel otomatik kapanmali; once zeminin panelin daha once kapattigi
   alt bolgesine, sonra orta ve uzak bolgesine dokun. Parmak hareket ederken hedef
   dokunulan noktayi izlemeli; takip/derinlik beklerken sari, masa veya koltuk gibi
   zemin olmayan yatay yuzeyde kirmizi, dogrulanmis zeminde yesil olmali. Yesil
   durumda kaynak ve metre cinsinden derinlik gorunmeli. Her zemin dokunusunda kasa gorunmeli.
   Ayni testi once `Gercek`, sonra `Beyaz Hatlar` modunda tekrarla.
6. 30 parcalik gercekci kutuphanenin Mobilya, Depolama, Ekipman, Duvar, Isik ve
   Elektronik bolumlerini ac. Her bolumden en az iki model yerlestir; 1K PBR dokular
   gorunmeli, boyutlar gercekci olmali ve modeller yuzeyin altina gomulmemeli.
   Dokunustan hemen sonra katalog boyutunda yedek geometri gorunmeli; USDZ acilinca
   ayni konumda gercek modelle degismeli. Tek bir bozuk USDZ sahneyi tamamen gorunmez
   birakmamali; yedek model ve acik hata mesaji kalmali.
   Gecerli modellerde `olcusu okunamadi` mesaji ve katalog boyutunda mavi kutu
   kalmamali; sahneye henuz anchor edilmemis USDZ hiyerarsisi da olculebilmeli.
   Yerlesimden sonra buyuk panel yerine dort dugmeli kompakt dock gorunmeli.
7. Zemin nesnesini zemine, dizustu bilgisayari masa tablasina, kamerayi duvara ve
   kafesli armaturu tavana yerlestir. Yanlis yuzey turundeki ilk carpismayi atlayip
   dogru yuzeyi buldugunu; RoomPlan kaydindan sonra uzak zemin ve tavan noktalarinda
   kayitli duzlem yedeginin calistigini dogrula. Zemin nesnesi seciliyken masa
   tablasina dokun; nesne masaya yerlestirilmemeli. Ayni noktada `yatay yuzey`
   nesnesi secildiginde masa bilincli olarak kabul edilmeli.
8. Tavan veya duvar isigini sec. `Sanal Isik` panelinde ac/kapat, 0-12000 lumen,
   2000-6500 K, yatay yon, dikey egim, 8-90 derece huzme ve kenar yumusakligi
   kontrollerini uctan uca degistir. Yeni isik 6000 lumen ve dar 18 derece spotla
   baslamali. `Projektor Hedefini Sec`e basip once zemine, sonra duvara dokun;
   isik ekseni secilen dunya noktasina donmeli. Saydam spot izi hedef yuzeye oturmali,
   aci daraldikca kuculmeli, mesafe arttikca buyumeli ve egik yuzeyde elips olmali.
   Gercek kamera pikselleri fiziksel olarak degismemeli; spot katmani kamera
   gorunumunde belirgin olmali, gercek bir masa isin onune girdiginde derinlik
   occlusion'i izi ortmeli. Sanal dekorlardaki aydinlanma ve golge de degismeli.
   Kaydet, uygulamayi kapat, yukle; hedef noktasi dahil ayni degerlerin geri geldigini dogrula.
9. Takip `limited` iken veya kalici duzlem bulunmadan zemin noktasina dokun;
   uygulama nesneyi kamera onunde tahmini bir noktaya koymamali, yerlestirme modunu
   acik tutup zemini yavasca tarama mesaji gostermeli. Takip `normal` ve duzlem
   hazir oldugunda ayni dokunus nesneyi zemine sabitlemeli. RoomPlan taramasi
   tamamlandiktan sonra ARKit'in ayri bir plane anchor uretmedigi uzak zemin
   noktalarinda da kayitli zemin seviyesiyle yerlestirme calismali.
10. Duvar, platform ve en az iki farkli USDZ model yerlestir; modellerin zemine temas
   golgesini ve kamera hareketinde anchor konumunu korudugunu dogrula. Modelin en alt
   gorunur noktasi zeminden 0-5 mm yukarida olmali. Modeli 0.5x ve 2x olcekle;
   taban zemine sabit kalmali, havaya kalkmamali veya zemine gomulmemeli.
11. Model uzerinde surukleme yapildiginda dunya konumu degismemeli; dondurme ve
   olceklendirme calismali. Donus/olcek sonrasinda projeyi kaydet.
12. Yeni dekor yerlestirdikten sonra manuel `Kaydet`e basmadan uygulamayi tamamen
    kapat, ayni alanda ac ve projeyi yukle; dekor anchor'i otomatik kayitla gelmeli.
    Ayrica yeni tarama sonrasinda otomatik uretilen dunya haritasi `Yukle` ile acilmali.
    Arka arkaya uc farkli kutuphane nesnesi yerlestir; otomatik kayit sirasinda
    `worldmap/scene.json eslesmiyor` hatasi gorulmemeli.
    Bu nesneler sahnedeyken yeniden `Oda Tara` yapip taramayi kullan; eski dekorlar
    korunmali ve yeni oda haritasi ayni hatayi vermeden otomatik kaydedilmeli.
    Gecersiz bir test `scene.json` ile uygulamayi ac; dosya `scene-corrupt-*.json`
    olarak yedeklenmeli, taninan dunya anchor'lari kurtarilmali ve yeni kayit kilitlenmemeli.
13. Relocalization tamamlandiktan sonra dekorlarin referans isaretlerine gore
   konum farkini olc.
14. Bir oyuncuyu sanal dekorun onunden ve arkasindan gecir; `Gercek` ve `Beyaz Hatlar`
   modlarinda insan derinlik maskesinin acik kaldigini ve kenar hatalarini kaydet.
   RoomPlan'in masa olarak tanidigi gercek bir masanin arkasina sanal dekor koy;
   masa tablasi ve ayaklari dekoru dogru bolgelerde ortmeli, masa alti tamamen kapali
   bir kutu gibi gorunmemeli.
15. PC'de `AIService/run_server.ps1` calistir. `AI Derinlik` ekraninda yerel IP'yi
    kontrol et; alan ilk kurulumda gercek deger olarak `http://192.168.1.12:8765` icermeli
    ve ekran baglantiyi otomatik test etmeli. Basarili test AI anahtarini otomatik
    acmali. Durumun
    once `Aktif` veya `PC bagli - LiDAR karesi bekleniyor`, scene depth geldiginde
    `Aktif` oldugunu; gecikmenin ve SAM maske
    sayisinin sifirdan buyuk oldugunu dogrula. Masa kenari ile on/arka insan testini
    tekrar et; AI kapaliyken ve acikken video kaydi alip kenar hatasini karsilastir.
    RTX 3050'de 1500 ms'yi asan fakat 6000 ms'nin altinda kalan basarili HTTP sonucu
    baglanti hatasi sayilmamali; dunya-koordinatli AI mesh'i yine uygulanmali.
    Servisi kapatinca eski AI mesh'i kaybolmali ve ARKit occlusion devam etmeli.
16. `Sahne Listesi`ni ac; tum dekor, isik ve CGI efektlerinin ayri satirda gorundugunu
    dogrula. Listeden bir nesneyi sec, sonra cop kutusuyla sil; yalniz o nesne ve
    anchor'i kaybolmali. `Tumunu Sil` ile tum sanal objelerin silindigini test et.
17. En az iki farkli odayi tara ve her birinde `Kaydet`e bas. `Kayitli Mekanlar`
    listesinde ad, tarih, tarama simgesi ve nesne sayisi gorunmeli. Ilk kaydi yukle;
    `room.json`, dunya haritasi, nesneler, projektor hedefleri ve ozel USDZ'ler birlikte
    geri gelmeli. Ikinci arsivi sil; aktif sahne etkilenmemeli.
18. `Canli CGI` icinden kan selalesini secip taranmis duvara dokun. Akis duvarin
    baslangic noktasinda kalmali, damlalar hareket etmeli, gercek bir kisi/nesne onune
    girdiginde derinlik occlusion calismali. Kaydet-yukle sonrasinda efekt ayni dunya
    konumunda yeniden baslamali.
19. `Avucta Canli Elma`yi ac; acik avucu kameraya goster ve eli on/arka/yana hareket
    ettir. Elma LiDAR derinliginde avucu izlemeli, ani olcumlerde sicrama yapmamali ve
    el 0.42 saniyeden uzun kaybolursa gizlenmeli. `Elimde elma olsun`, `elmayi kaldir`
    ve `kan selalesi aksin` komutlarini Turkce test et; dugme yedegi de calismali.
20. Uygulamayi arka plana alip geri getir; AR takibi normale donmeli ve manuel
    objeler yerinde kalmali. Gecici AR hatasinda otomatik yeniden baslatma mesaji
    gorulmeli ve `Oda Tara` yalniz takip yeniden hazir oldugunda etkinlesmeli.
    Anchor gecici kaldirilirsa nesne/armatur silinmemeli; canli anchor geri gelmezse
    son dunya donusumunde otomatik yeniden baglanmali. Kesintiden once `Beyaz Hatlar`
    aciksa takip duzelince hatlar tekrar gorunmeli.
21. Tripodda 10 dakika, elde 5 dakika kesintisiz HEVC kayit al.
22. MOV dosyasinda kare dusmesi, ses senkronu ve cihaz isinmasini kontrol et.

## Baslangic kabul esikleri

- Tripod konum kaymasi: 10 dakikada 2 cm'den az
- Elde relocalization hatasi: 5 cm'den az
- Manuel dekor anchor'i ile dokunulan gercek yuzey hizasi: referans noktalarda 2 cm'den az
- Modelin gercek alt siniri ile zemin arasindaki dikey bosluk: 5 mm'den az
- Projektor hedef merkezinin dokunulan dunya noktasindan farki: 3 cm'den az
- Kapi ve pencere boslugu kenar hatasi: 5 cm'den az
- Kayit: hedef cihazda sabit 30 fps, gorunur tekrar eden kare olmamali
- Ses-goruntu senkron farki: 40 ms'den az
- Kritik termal durum veya uygulama kapanmasi: olmamali

Bu degerler ilk saha hedefleridir. Olculen sonuclar cihaz modeli, iOS surumu,
isik, mekan dokusu ve sahne buyuklugu ile birlikte kaydedilmelidir.

## Film tesliminden once eksik olanlar

- Lens intrinsics/distortion profilinin cekimle birlikte kaydi
- Timecode ve harici ses kayit cihaziyla senkron
- 10-bit HDR/Log ve renk yonetimi
- ProRes veya kayipsiza yakin renderer cikisi
- Derinlik maskesi, clean plate ve alpha/segmentation pass ciktilari
- Gercek nesne silme icin sahneye ozel ML modeli ve temporal stabilizasyon
- GPU/CPU/termal profilleme ve birden cok iPhone modelinde regresyon testi
````

## `Docs/ICON_PROMPT.md`

````markdown
# CineAR uygulama ikonu

Uygulama ikonu Codex'in yerleşik ImageGen aracıyla üretildi. Xcode'da kullanılan
son dosya:

`CineAR/Assets.xcassets/AppIcon.appiconset/CineAR-AppIcon-1024.png`

## Son üretim promptu

```text
Use case: logo-brand
Asset type: iOS App Store icon, 1024 x 1024 square
Primary request: create a premium cinematic augmented-reality icon for an app named CineAR
Subject: a bold camera aperture/lens symbol seamlessly combined with a simple perspective wireframe room and one solid 3D cube anchored inside it
Style/medium: polished high-end 3D icon, minimal, instantly readable at small size, professional virtual-production aesthetic
Composition/framing: centered emblem, strong silhouette, generous safe area, full-bleed square artwork; do not bake rounded corners because iOS applies its own mask
Lighting/mood: dark cinematic depth with subtle volumetric glow
Color palette: near-black navy background, electric cyan spatial-grid accents, restrained warm amber highlight
Materials/textures: refined glass and brushed metal, crisp edges, controlled reflections
Constraints: no words, no letters, no typography, no watermark, no people, no photorealistic room clutter, opaque background, high contrast, app-store-ready
```

Dosya 1024 x 1024 piksele yeniden örneklendi; sRGB, 8-bit RGB ve şeffaflıksız
PNG olarak kaydedildi. iOS yuvarlatılmış köşe maskesini kurulum sırasında uygular.
````

## `README.md`

````markdown
# CineAR Virtual Production Prototype

CineAR, iPhone uzerinde gercek zamanli sanal dekor ve set onizlemesi icin gelistirilen
yerel bir iOS uygulamasidir. Swift, ARKit, RealityKit, RoomPlan, AVFoundation ve
ReplayKit tabanlidir.

## Gereksinimler

- macOS ve Xcode 15 veya daha yeni bir surum
- iOS 17 veya daha yeni surumlu gercek iPhone
- Oda taramasi ve en iyi occlusion sonucu icin LiDAR destekli iPhone Pro

AR kamera sistemi Simulator'da test edilemez. Xcode'da `CineAR` target'inin
Signing & Capabilities bolumunden bir Apple Development Team secilmelidir.

Mac olmadan dagitim icin depo kokundeki `codemagic.yaml` kullanilabilir. Apple
Developer ekibinin bir kez yapacagi kurulum `Docs/CODEMAGIC.md` dosyasindadir.
Varsayilan Bundle ID `com.cinear.virtualproduction` ve hedef yalnizca iPhone'dur.

## Mevcut sistem

- Yatay/dikey yuzey algilama ve dunya koordinatlarina AR anchor yerlestirme
- LiDAR cihazlarda mesh reconstruction ve scene depth
- Person segmentation with depth ile scene depth'i birlikte kullanip insan ve gercek
  mekan mesh'iyle occlusion
- Istege bagli PC destekli SAM 2.1 Tiny + Depth Anything V2 Small derinlik fuz yonu;
  iPhone kamera ve LiDAR karesini ayni Wi-Fi'daki RTX bilgisayara yollar, LiDAR ile
  metreye kalibre edilen sonuc RealityKit'te gorunmez occlusion mesh'i olur
- AI servisi kapali veya ulasilamazsa stale AI mesh'ini kaldirip kesintisiz olarak
  cihazdaki ARKit scene depth, person depth ve LiDAR mesh occlusion'a geri donme
- RoomPlan ile ayni AR oturumunda semantik oda taramasi; mobil bellek dostu `room.json` cikisi
- RoomPlan donusunde callback beklemeden mevcut kamera frame'ini yoklayan AR hazirlik kurtarmasi
- Yeni taramadan sonra takip normale donunce `room.json` ile eslesen dunya haritasini otomatik kaydetme
- Tarama sirasinda RoomPlan'in hafif, beyaz ve seffaf kilavuz cizgileri
- Tarama sonrasinda opak oda kaplamasi olmadan gercek kamera goruntusu
- `Oda Gercekligi` icinde gercek kamera ile hafif `Beyaz Hatlar` modu arasinda gecis
- Beyaz hatlarin altinda, tum taranmis zemin ve duvarlari dokunulabilir yapan gorunmez collider'lar
- Poly Haven kaynakli 1K PBR dokulu 30 fotogercekci CC0 USDZ dekor; mobilya,
  depolama, ekipman, duvar/tavan elemanlari, aydinlatma ve elektronik kategorileri
- Eski kayitlari bozmamak icin 14 Kenney USDZ ve 4 hafif dekorla geriye donuk uyumluluk
- Bundle yolu veya USDZ normalize islemi basarisiz olsa bile her semantik kategori icin
  gercek sekilli prosedurel yedek model; yerlestirme sessizce kaybolmaz
- Fotogercekci veya kullanici USDZ'si acilirken katalog olcusunde gorunur anlik yedek;
  dosya hazir olunca ayni dunya anchor'i ve kullanici donusumu korunarak gercek modelle degisim
- Anchor edilmeden yapilan USDZ olcumunde inactive cocuklari da hesaba katma; RealityKit'in
  sifir boyut dondurup 30 modelin tamamini mavi yedek kutuya dusurmesini engelleme
- Ilk acilista ve yerlestirme sonrasinda kamerayi acik birakan kompakt alt kontrol dock'u
- Nesne secilince paneli kapatan, zeminin tamamini dokunulabilir yapan yerlestirme modu
- Her katalog nesnesi icin ayri zemin, yatay yuzey, duvar veya tavan yerlestirme kurali
- Tavan/duvar/masa lambalarinda ac-kapat, 0-12000 lumen, 2000-6500 K renk
  sicakligi, -180/+180 derece yatay yon, -75/+75 derece dikey egim,
  8-90 derece huzme ve kenar yumusakligi; yeni isiklar dar 18 derece spotla baslar
- `Projektor Hedefini Sec` ile zemine, masaya veya duvara dokunup SpotLight'i tam
  dunya koordinatina yoneltme; mesafe ve aciya gore olceklenen, egik yuzeyde elipse
  donusen yumusak isik izi kamera gorunumunde hedef noktayi belirginlestirir
- Yeni sanal lambalarda otomatik ortam aydinlatmasina karsi fark edilir 6000 lumen baslangic gucu
- `Sahne Isigi` dugmesi mevcut son isigi dogrudan ayara acar; sahnede isik yoksa
  tavan isigi yerlestirme modunu baslatir, boylece kontrol paneli gizli kalmaz
- Dekor konumunu dunya anchor'ina kilitleyip yalniz dondurme ve olceklendirmeye izin verme
- Yalniz normal takipte ve kalici ARKit/RoomPlan yuzeyi uzerinde yerlestirme; kamera-onu
  tahmini noktalar reddedilerek nesnenin yuzmesi engellenir
- `.floor` sinifli ARKit duzlemi, `.floor` sinifli LiDAR mesh yuzleri, RoomPlan zemin
  kotu ve dokunulan pikseldeki orta/yuksek guvenli `smoothedSceneDepth` olcumunu
  birlestiren kati zemin cozucu; masa gibi siniflandirilmamis yatay yuzey zemine gecmez
- Parmakla dokunulan noktayi izleyen yesil/sari/kirmizi hedef gostergesi ve metre
  cinsinden derinlik geri bildirimi
- USDZ'nin gercek alt/ust/arka gorsel sinirini yuzey temas pivotuna alan donusum;
  dondurme ve olceklendirme sonrasinda modelin tabani zeminden kopmaz veya gomulmez
- RoomPlan'in tanidigi masa, sandalye ve buyuk mobilyalari gercek kamera gorunumunde
  gorunmez derinlik geometrisine cevirerek sanal nesnelerde kalici occlusion
- Zemin dekorlarinda yari seffaf temas golgesi ve daha dengeli PBR malzemeler
- Yeni dekor anchor'i oturuma eklendiginde dunya haritasini otomatik guncelleme
- RoomPlan gecisi veya relocalization bir uygulama anchor'ini gecici kaldirirsa gorseli
  silmeden canli anchor'a yeniden baglama; geri gelmeyen anchor'i son guvenilir dunya
  donusumunde otomatik yeniden olusturma
- Yeni anchor ile ARKit harita snapshot'i arasindaki zamanlama farkini uzlastirip
  `worldmap/scene.json` uyusmazligini otomatik yeniden deneme ve eski kaydi kurtarma
- Decode edilemeyen `scene.json` dosyasini silmeden `scene-corrupt-*.json` olarak
  yedekleyip dunya haritasi anchor'larindan taninan dekorlari yeniden kurma
- Files uzerinden USDZ dekor kutuphanesine model aktarma
- ARWorldMap, anchor ve dekor transformlarini kalici proje olarak kaydetme
- `Sahne Listesi` ile sahnedeki tum nesne, isik ve CGI efektlerini ada gore secme;
  tek tek onayla silme veya sanal sahnenin tamamini temizleme
- Her manuel `Kaydet` ve tamamlanan oda taramasinda `scene.json`, dunya haritasi,
  `room.json` ve o mekana ait ozel USDZ'leri dogrulanmis ayri arsiv olarak saklama
- `Kayitli Mekanlar` listesinden tarih/nesne sayisini gorme, onceki mekani yukleme
  veya aktif sahneyi etkilemeden arsiv kaydini silme
- Kayitli mekanda relocalization
- Duvara anchor edilen, uygulama yeniden acildiginda sahne kaydiyla geri gelen
  hareketli kan selalesi CGI efekti
- Vision el-eklem takibi ile LiDAR avuc derinligini birlestirip elmayi elde canli
  izleme; insan/scene-depth occlusion ve zamansal konum yumusatma
- `Elimde elma olsun`, `elmayi kaldir` ve `kan selalesi aksin` Turkce sesli
  komutlari; ses kullanilamayan ortamlar icin ayni islemlerin dugmeleri
- Arayuzsiz cekim modu; ekrana iki kez dokunarak kaydi bitirme
- HEVC video ve 48 kHz AAC mikrofon sesini `.mov` dosyasina yazma
- Son cekimi iOS Share Sheet ile disari aktarma

## Calistirma

1. `CineAR.xcodeproj` dosyasini Xcode ile acin.
2. Bundle Identifier'i size ait benzersiz bir degerle degistirin.
3. Signing icin Team secin ve uygulamayi gercek iPhone'a yukleyin.
4. Ana ekranin altindaki her zaman gorunen `Odayi Tara` dugmesiyle tum duvarlari,
   kapi/pencereleri ve odadaki buyuk objeleri tarayin. AR henuz hazir degilse dugme
   uzerinde bekleme nedeni gorunur; tamamlanmis tarama varsa dugme `Odayi Yeniden Tara`
   olarak degisir.
5. Tarama onaylandiginda gercek kamera goruntusune donulur; taranan yuzeylerin
   opak modelleri kamera uzerine cizilmez. Gerektiginde `Beyaz Hatlar` ile taranan
   sinirlari seffaf olarak acip yeniden `Gercek` moduna donebilirsiniz.
6. Kompakt dock'taki `Nesneler` ile kutuphaneyi acin; hizli dekorlardan birini,
   `Hazir 3B Nesne Kutuphanesi` icindeki 30 fotogercekci parcadan
   birini veya `USDZ Ekle` ile kisisel bir model secin.
7. Kontrol paneli otomatik kapandiginda hedefi istediginiz noktaya surukleyin.
   Hedef yesil ve metre degeri gorunurken zemine, yatay yuzeye, duvara veya tavana
   dokunun. Zemin nesnelerinde masa/koltuk gibi bir yuzey kirmizi olur. Kararli yuzey
   yoksa uygulama nesneyi kamera onunde tahmini bir noktaya
   koymaz; hedef yuzeyi yavasca taramanizi ister. Tamamlanmis bir RoomPlan taramasi varsa
   kayitli zemin ve tavan duzlemleri tam alan icin guvenli yedek olarak kullanilir. Konum dunya anchor'ina kilitlenir;
   modeli dondurebilir ve olceklendirebilirsiniz. Yerlesimden sonra yalniz kompakt
   dock geri gelir; ayrintili araclar `Kontroller` ile acilir.

8. Bir lamba yerlestirildiginde veya tekrar secildiginde `Sanal Isik` panelinden
   `Projektor Hedefini Sec`e basin ve isin vuracagi yuzeye dokunun. Guc, renk
   sicakligi, spot acisi, kenar yumusakligi ve acik/kapali durumu degistirilebilir.
   RealityKit SpotLight sanal dekorlari ve golgelerini fiziksel olarak aydinlatir;
   gercek kamera pikseli yeniden isiklandirilmaz, fakat LiDAR yuzeyine oturan saydam
   projektor izi kamera gorunumunde ayni hedefi gosterir ve gercek derinlikle ortulur.
9. Tarama sonrasinda ilk dunya haritasi ve her yeni dekor anchor'i otomatik kaydedilir.
   Dondurme/olceklendirme degisikliklerinden sonra `Kaydet` tusuna basin; takip hazir
   degilse istek siraya alinir ve otomatik tamamlanir. Manuel kayit `Kayitli Mekanlar`
   icinde ayri bir arsiv olusturur; listeden eski tarama ve o taramaya ait nesneler
   birlikte geri yuklenir.
10. `Sahne` listesinden eklenmis nesneyi secin veya cop kutusuyla tek basina silin.
    `Canli CGI` ekraninda kan selalesini secip taranmis duvara dokunun; `Avucta Canli
    Elma`yi acip elinizi kameraya gosterin. Isterseniz ayni islemleri Turkce sesli
    komutla baslatin.
11. `HEVC Cekim` tusuna basin. Kayit sirasinda arayuz gizlenir; bitirmek icin
   ekrana iki kez dokunun.

## PC AI derinlik denemesi

RTX bilgisayarda once `AIService/setup_windows.ps1`, sonra
`AIService/run_server.ps1` calistirilir. Konsolda yazan yerel IP, uygulamadaki
`Kontroller > AI Derinlik` alaninda dogrulanir; ekran acilinca baglanti otomatik
test edilir ve basariliysa AI anahtari acilir. `PC bagli - LiDAR karesi bekleniyor` mesaji
sunucu baglantisinin basarili oldugunu, telefonun henuz scene-depth karesi uretmedigini
belirtir. Ayrintili komutlar ve model secimi `AIService/README.md`
dosyasindadir. Kamera/derinlik yalniz kullanicinin girdigi yerel adrese gonderilir;
bulut servisi kullanilmaz. Baglanti kurulamazsa iPhone Safari'de ayni adresin
`/health` yolu acilir ve uygulamadaki `iPhone Yerel Ag ayarini ac` dugmesinden
CineAR izni kontrol edilir.

Bu kurulumda dogrulanan PC adresi `http://192.168.1.12:8765` uygulamaya gercek
baslangic degeri olarak yazilir ve AI ekrani acilinca otomatik test edilir. Adres
DHCP nedeniyle degisirse terminaldeki yeni adres ayni alana yazilabilir; Safari'de
kullanilan `/health` son ekli adres yapistirilsa da uygulama sunucu kokunu ayiklar.
Hotspot veya Wi-Fi degistiginde betik yeniden baslatilir; varsayilan ag gecidine sahip
etkin Wi-Fi/Ethernet adresi otomatik secilir ve VMware gibi sanal adaptorler atlanir.

AI acikken hassas canli derinlik ile kaba RoomPlan mobilya kutulari ayni anda
occlusion yazmaz. Bu, masa kenarinda sanal nesnenin yariya kesilmesini engeller;
AI kapatilirsa hafif ice alinmis RoomPlan yedegi tekrar etkinlesir.
RTX 3050 sinifi bir PC'de SAM 2 + Depth Anything kareleri tipik olarak 2-3 saniye
surer; istemci 6 saniyeye kadar gecerli dunya-koordinatli sonucu kabul eder ve
olculen toplam gecikmeyi durum alaninda gosterir.

## Proje dosyalari

Uygulama Documents altinda su yapida calisir:

```text
CineARProjects/MainSet/
  scene.json
  worldmap.arexperience
  room.json
  Assets/*.usdz
  Recordings/*.mov
CineARProjects/SavedPlaces/<UUID>/
  place.json
  scene.json
  worldmap.arexperience
  room.json
  Assets/*.usdz
```

`scene.json`, dekor kimliklerini, temas-pivotlu yerel transformlarini, projektor hedef
koordinatini ve sanal isik ayarlarini; `room.json`, RoomPlan'in
semantik yuzey/obje verisini; `worldmap.arexperience` ise ARKit'in mekansal
haritasini ve anchor'larini saklar. Normal kamera gorunumunde `room.json` opak bir
oda modeli olarak cizilmez; veri sonraki semantik ozellikler icin korunur. Tarama
kapanirken gereksiz bellek yukune yol acan ikinci bir RoomPlan `room.usdz` arsivi
uretilmez.

`SavedPlaces` altindaki her klasor bagimsiz ve once dogrulanan bir mekansal anlik
goruntudur. Yukleme sirasinda checksum, anchor/dekor eslesmesi ve ozel USDZ varligi
kontrol edilir; aktif `MainSet` ancak bu kontroller gecerse islemsel olarak degistirilir.

## Uretim siniri

Bu surum profesyonel sistemin cihazda calisabilir temelidir; nihai film teslim
kalitesi cihaz testi olmadan ilan edilmemelidir. ReplayKit tabanli compositing
cikisi HEVC'dir. ProRes, genlock, harici timecode, lens distortion calibration,
10-bit log/HDR ve piksel seviyesinde temiz plate uretimi icin sonraki asamada
ozel Metal renderer ve AVFoundation kamera yakalama hattina gecilmelidir.

Bu surumde Poly Haven'dan donusturulmus 30 CC0, 1K PBR USDZ model vardir.
Modeller kullanici tarafindan kategorili kutuphaneden secilir, gercekci metre
boyutlarina normalize edilir ve kendi yuzey turune oturtulur. Eski projeler icin
Kenney Furniture Kit'ten 14 CC0 USDZ ve 4 hafif dekor kaynakta korunur.
Kaynak/lisans `CineAR/RoomAssets/LICENSE-POLYHAVEN.txt` ve
`CineAR/RoomAssets/LICENSE-KENNEY.txt`, tekrar uretim/dogrulama araclari `Tools/`
altindadir. 1K doku siniri mobil bellek ve yukleme gecikmesini kontrol altinda tutar;
2K/4K masaustu VFX paketi hedeflenmemistir. Eski opak oda tema renderer'i kaynakta deneysel
olarak korunur; ana arayuzde onun yerine akici `Gercek` / `Beyaz Hatlar` gecisi vardir.
Kamera goruntusundeki gercek mobilyayi yapay
zekayla silip arka plani tamamlama (video inpainting) bu surumde yoktur; sanal
yuzeyler, RoomPlan mobilya derinlik vekilleri ve derinlik/insan occlusion'i kullanilir.

Ayrintili kabul kriterleri icin `Docs/DEVICE_TEST.md` dosyasina bakin.
````

## `Tools/convert_kenney_to_usdz.py`

````python
"""Convert the selected CC0 Kenney Furniture Kit GLB files to RealityKit USDZ.

Run with Blender 4.5 or newer:
  blender --background --factory-startup --python Tools/convert_kenney_to_usdz.py -- \
    "<Kenney>/Models/GLTF format" "CineAR/RoomAssets"
"""

from pathlib import Path
import sys

import bpy


ASSET_NAMES = (
    "bathtub",
    "bedDouble",
    "chairModernCushion",
    "kitchenStove",
    "kitchenFridge",
    "bathroomSink",
    "loungeDesignSofa",
    "stairs",
    "bookcaseClosedWide",
    "kitchenStoveElectric",
    "table",
    "televisionModern",
    "toilet",
    "washerDryerStacked",
)


def arguments() -> tuple[Path, Path]:
    try:
        separator = sys.argv.index("--")
        source_value, output_value = sys.argv[separator + 1 : separator + 3]
    except (ValueError, IndexError) as error:
        raise SystemExit("Expected: -- <Kenney GLTF directory> <output directory>") from error

    source = Path(source_value).resolve()
    output = Path(output_value).resolve()
    if not source.is_dir():
        raise SystemExit(f"GLTF source directory does not exist: {source}")
    output.mkdir(parents=True, exist_ok=True)
    return source, output


def convert(source: Path, output: Path, name: str) -> None:
    input_url = source / f"{name}.glb"
    output_url = output / f"{name}.usdz"
    if not input_url.is_file():
        raise RuntimeError(f"Missing source model: {input_url}")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    imported = bpy.ops.import_scene.gltf(filepath=str(input_url))
    if "FINISHED" not in imported:
        raise RuntimeError(f"GLB import failed: {input_url}")

    meshes = [item for item in bpy.context.scene.objects if item.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh found in: {input_url}")

    exported = bpy.ops.wm.usd_export(
        filepath=str(output_url),
        selected_objects_only=False,
        visible_objects_only=True,
        export_animation=False,
        export_hair=False,
        export_uvmaps=True,
        rename_uvmaps=True,
        export_mesh_colors=True,
        export_normals=True,
        export_materials=True,
        export_subdivision="IGNORE",
        export_armatures=False,
        export_shapekeys=False,
        use_instancing=False,
        evaluation_mode="RENDER",
        generate_preview_surface=True,
        generate_materialx_network=False,
        convert_orientation=True,
        export_global_forward_selection="NEGATIVE_Z",
        export_global_up_selection="Y",
        export_textures=True,
        export_textures_mode="NEW",
        overwrite_textures=True,
        relative_paths=True,
        xform_op_mode="TRS",
        root_prim_path="/CineARAsset",
        export_custom_properties=False,
        author_blender_name=False,
        convert_world_material=False,
        allow_unicode=False,
        export_meshes=True,
        export_lights=False,
        export_cameras=False,
        export_curves=False,
        export_points=False,
        export_volumes=False,
        triangulate_meshes=True,
        quad_method="SHORTEST_DIAGONAL",
        ngon_method="BEAUTY",
        usdz_downscale_size="1024",
        merge_parent_xform=True,
        convert_scene_units="METERS",
        meters_per_unit=1.0,
    )
    if "FINISHED" not in exported or not output_url.is_file():
        raise RuntimeError(f"USDZ export failed: {output_url}")
    if output_url.stat().st_size < 512:
        raise RuntimeError(f"USDZ output is unexpectedly small: {output_url}")
    print(f"CINEAR_USDZ {name} {output_url.stat().st_size}")


def main() -> None:
    source, output = arguments()
    for asset_name in ASSET_NAMES:
        convert(source, output, asset_name)


if __name__ == "__main__":
    main()
````

## `Tools/convert_polyhaven_to_usdz.py`

````python
"""Convert CineAR's curated Poly Haven CC0 glTF props to mobile USDZ.

Run with Blender 4.5 or newer:
  blender --background --factory-startup --python Tools/convert_polyhaven_to_usdz.py -- \
    ".asset-cache/polyhaven" "CineAR/RoomAssets"
"""

from pathlib import Path
import sys

import bpy


ASSET_IDS = (
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
    "boombox",
)


def arguments() -> tuple[Path, Path]:
    try:
        separator = sys.argv.index("--")
        source_value, output_value = sys.argv[separator + 1 : separator + 3]
    except (ValueError, IndexError) as error:
        raise SystemExit("Expected: -- <Poly Haven source directory> <output directory>") from error

    source = Path(source_value).resolve()
    output = Path(output_value).resolve()
    if not source.is_dir():
        raise SystemExit(f"Source directory does not exist: {source}")
    output.mkdir(parents=True, exist_ok=True)
    return source, output


def convert(source: Path, output: Path, asset_id: str) -> None:
    asset_directory = source / asset_id
    candidates = sorted(asset_directory.glob("*_1k.gltf"))
    if len(candidates) != 1:
        raise RuntimeError(f"Expected one 1K glTF for {asset_id}, found {len(candidates)}")

    input_url = candidates[0]
    output_url = output / f"{asset_id}.usdz"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    imported = bpy.ops.import_scene.gltf(filepath=str(input_url))
    if "FINISHED" not in imported:
        raise RuntimeError(f"glTF import failed: {input_url}")

    meshes = [item for item in bpy.context.scene.objects if item.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh found in: {input_url}")

    # Animation rigs are not needed for static AR props and add runtime overhead.
    for item in list(bpy.context.scene.objects):
        if item.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(item, do_unlink=True)

    exported = bpy.ops.wm.usd_export(
        filepath=str(output_url),
        selected_objects_only=False,
        visible_objects_only=True,
        export_animation=False,
        export_hair=False,
        export_uvmaps=True,
        rename_uvmaps=True,
        export_mesh_colors=True,
        export_normals=True,
        export_materials=True,
        export_subdivision="IGNORE",
        export_armatures=False,
        export_shapekeys=False,
        use_instancing=False,
        evaluation_mode="RENDER",
        generate_preview_surface=True,
        generate_materialx_network=False,
        convert_orientation=True,
        export_global_forward_selection="NEGATIVE_Z",
        export_global_up_selection="Y",
        export_textures=True,
        export_textures_mode="NEW",
        overwrite_textures=True,
        relative_paths=True,
        xform_op_mode="TRS",
        root_prim_path="/CineARAsset",
        export_custom_properties=False,
        author_blender_name=False,
        convert_world_material=False,
        allow_unicode=False,
        export_meshes=True,
        export_lights=False,
        export_cameras=False,
        export_curves=False,
        export_points=False,
        export_volumes=False,
        triangulate_meshes=True,
        quad_method="SHORTEST_DIAGONAL",
        ngon_method="BEAUTY",
        usdz_downscale_size="1024",
        merge_parent_xform=True,
        convert_scene_units="METERS",
        meters_per_unit=1.0,
    )
    if "FINISHED" not in exported or not output_url.is_file():
        raise RuntimeError(f"USDZ export failed: {output_url}")
    if output_url.stat().st_size < 1024:
        raise RuntimeError(f"USDZ output is unexpectedly small: {output_url}")
    print(f"CINEAR_USDZ {asset_id} {output_url.stat().st_size}")


def main() -> None:
    source, output = arguments()
    for asset_id in ASSET_IDS:
        convert(source, output, asset_id)


if __name__ == "__main__":
    main()
````

## `Tools/fetch_polyhaven_props.ps1`

````powershell
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
````

## `Tools/generate_all_in_one_markdown.ps1`

`````powershell
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
    & git -C $repoRoot ls-files --cached --others --exclude-standard
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
[void]$builder.AppendLine("CineAR; LiDAR destekli iPhone ile bir odayı RoomPlan üzerinden tarayan, gerçek kamera görüntüsünü opak tarama kaplamalarıyla örtmeden isteğe bağlı beyaz hatlarla gösteren ve 30 fotogerçekçi CC0 dekoru zemine, yatay yüzeye, duvara veya tavana yerleştiren yerel iOS uygulamasıdır. Dekorlar döndürülebilir, ölçeklendirilebilir ve ARWorldMap tabanlı proje olarak saklanabilir; sanal ışıkların gücü, sıcaklığı ve açısı ayarlanabilir.")
[void]$builder.AppendLine()
[void]$builder.AppendLine("## Teknoloji ve ana yetenekler")
[void]$builder.AppendLine()
[void]$builder.AppendLine("- Swift + SwiftUI kullanıcı arayüzü")
[void]$builder.AppendLine("- ARKit dünya takibi, düzlem algılama, raycast, scene reconstruction ve occlusion")
[void]$builder.AppendLine("- Aynı Wi-Fi'daki PC'de SAM 2.1 Tiny + Depth Anything V2 Small; LiDAR metre kalibrasyonlu görünmez RealityKit occlusion mesh'i")
[void]$builder.AppendLine("- RoomPlan ile semantik oda taraması ve ``room.json`` üretimi")
[void]$builder.AppendLine("- RoomPlan dönüşünde mevcut frame'i yoklayan deterministik AR hazır olma kurtarması")
[void]$builder.AppendLine("- Yeni taramadan sonra normal takip gelir gelmez otomatik ve eşlenmiş ARWorldMap kaydı")
[void]$builder.AppendLine("- Gerçek kamera görünümü, insan/mesh occlusion, tarama sırasında RoomPlan kılavuzları ve sonrasında isteğe bağlı hafif Beyaz Hatlar modu")
[void]$builder.AppendLine("- Poly Haven kaynaklı 1K PBR dokulu 30 fotogerçekçi CC0 USDZ varlığı ve yüzey türüne göre yerleştirme")
[void]$builder.AppendLine("- Tavan/duvar/masa ışıklarında güç, renk sıcaklığı, yatay yön, dikey eğim, hüzme genişliği ve kalıcı sahne kaydı")
[void]$builder.AppendLine("- USDZ yükleme/normalize hatasında kategoriye uygun prosedürel model fallback'i; görünmez veya yarım kalan yerleştirme yok")
[void]$builder.AppendLine("- Kamerayı açık tutan kompakt alt dock ve yalnız istenince açılan ayrıntılı kontrol paneli")
[void]$builder.AppendLine("- AR düzlemi bulunamadığında ekran ışınını bilinen veya tahmini zeminle kesiştiren yerleştirme fallback'i")
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
[void]$builder.AppendLine("| ``RoomRealityRenderer`` | Düşük maliyetli beyaz oda hatları, görünmez yüzey collider'ları ve deneysel tema renderer'ı |")
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
[void]$builder.AppendLine("4. Tarayıcı kapandığında opak oda geometrisi çizilmeden gerçek kamera görünümüne dönülür; kullanıcı isterse **Beyaz Hatlar** ile tarama sınırlarını açar.")
[void]$builder.AppendLine("5. Kullanıcı kompakt dock'tan hızlı dekor, 30 parçalık fotogerçekçi kütüphane veya kendi USDZ varlığını seçer; büyük panel otomatik kapanır ve yerleştirmeden sonra kompakt dock geri gelir.")
[void]$builder.AppendLine("6. Kullanıcı zemine dokunur; AR düzlemi yoksa dokunma ışını bilinen veya kamera yüksekliğinden tahmin edilen zeminle kesiştirilir.")
[void]$builder.AppendLine("7. RealityKit gesture'larıyla dekor taşınır, döndürülür ve ölçeklenir.")
[void]$builder.AppendLine("8. İlk world map tarama sonrasında otomatik kaydedilir; sonraki **Kaydet** istekleri takip hazır değilse sıraya alınır. **HEVC Çekim** video/ses çıktısı üretir.")
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
`````

## `Tools/render_usdz_thumbnails.py`

````python
"""Render quick Blender thumbnails from the final bundled USDZ files."""

from pathlib import Path
import sys

import bpy
from mathutils import Vector


def arguments() -> tuple[Path, Path, tuple[str, ...]]:
    try:
        separator = sys.argv.index("--")
        asset_value, output_value = sys.argv[separator + 1 : separator + 3]
    except (ValueError, IndexError) as error:
        raise SystemExit("Expected: -- <RoomAssets directory> <thumbnail directory>") from error
    assets = Path(asset_value).resolve()
    output = Path(output_value).resolve()
    output.mkdir(parents=True, exist_ok=True)
    requested = tuple(sys.argv[separator + 3 :])
    return assets, output, requested


def look_at(item: bpy.types.Object, target: Vector) -> None:
    item.rotation_euler = (target - item.location).to_track_quat("-Z", "Y").to_euler()


def render(url: Path, output: Path) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if "FINISHED" not in bpy.ops.wm.usd_import(filepath=str(url)):
        raise RuntimeError(f"USDZ import failed: {url}")
    meshes = [item for item in bpy.context.scene.objects if item.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh found: {url}")

    points = [item.matrix_world @ Vector(corner) for item in meshes for corner in item.bound_box]
    minimum = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
    maximum = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
    size = maximum - minimum
    factor = 2.2 / max(size)
    center = (minimum + maximum) * 0.5
    top_level_items = [item for item in bpy.context.scene.objects if item.parent is None]
    bpy.ops.object.empty_add(type="PLAIN_AXES")
    container = bpy.context.object
    container.name = "ThumbnailAssetRoot"
    for item in top_level_items:
        item.parent = container
    container.scale = (factor, factor, factor)
    container.location = -center * factor
    container.location.z += size.z * factor * 0.5

    bpy.ops.object.camera_add(location=(4.2, -6.2, 3.7))
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.6
    look_at(camera, Vector((0, 0, 0.8)))
    bpy.context.scene.camera = camera

    for location, energy, size_value in [((4, -4, 6), 950, 5), ((-4, -1, 3), 500, 4)]:
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.data.energy = energy
        light.data.shape = "DISK"
        light.data.size = size_value
        look_at(light, Vector((0, 0, 0.7)))

    bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, -0.015))
    floor = bpy.context.object
    floor_material = bpy.data.materials.new("ThumbnailFloor")
    floor_material.diffuse_color = (0.055, 0.065, 0.08, 1)
    floor.data.materials.append(floor_material)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("ThumbnailWorld")
    scene.world.color = (0.025, 0.03, 0.045)
    scene.render.filepath = str(output / f"{url.stem}.png")
    bpy.ops.render.render(write_still=True)
    print("CINEAR_THUMBNAIL", scene.render.filepath)


def main() -> None:
    assets, output, requested = arguments()
    urls = [assets / f"{name}.usdz" for name in requested] if requested else sorted(assets.glob("*.usdz"))
    for url in urls:
        if not url.is_file():
            raise RuntimeError(f"USDZ not found: {url}")
        render(url, output)


if __name__ == "__main__":
    main()
````

## `Tools/validate_usdz_assets.py`

````python
"""Headless Blender smoke test for every bundled CineAR USDZ asset."""

from math import isfinite
from pathlib import Path
import sys

import bpy
from mathutils import Vector


def asset_directory() -> Path:
    try:
        separator = sys.argv.index("--")
        return Path(sys.argv[separator + 1]).resolve()
    except (ValueError, IndexError) as error:
        raise SystemExit("Expected: -- <RoomAssets directory>") from error


def validate(url: Path) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    imported = bpy.ops.wm.usd_import(filepath=str(url))
    if "FINISHED" not in imported:
        raise RuntimeError(f"USDZ import failed: {url}")

    meshes = [item for item in bpy.context.scene.objects if item.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh in USDZ: {url}")

    for item in meshes:
        item.data.calc_loop_triangles()
    vertices = sum(len(item.data.vertices) for item in meshes)
    triangles = sum(len(item.data.loop_triangles) for item in meshes)
    material_slots = sum(len(item.material_slots) for item in meshes)
    points = [item.matrix_world @ Vector(corner) for item in meshes for corner in item.bound_box]
    minimum = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
    maximum = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
    size = maximum - minimum
    if vertices <= 0 or triangles <= 0:
        raise RuntimeError(f"Empty geometry in USDZ: {url}")
    if not all(isfinite(value) and value > 0.0001 for value in size):
        raise RuntimeError(f"Invalid visual bounds in USDZ: {url}, size={tuple(size)}")
    if material_slots <= 0:
        raise RuntimeError(f"No material slots in USDZ: {url}")

    print(
        "CINEAR_USDZ_OK",
        url.name,
        f"meshes={len(meshes)}",
        f"vertices={vertices}",
        f"triangles={triangles}",
        f"materials={material_slots}",
        "size=" + "x".join(f"{value:.4f}" for value in size),
    )


def main() -> None:
    directory = asset_directory()
    urls = sorted(directory.glob("*.usdz"))
    if not urls:
        raise SystemExit(f"No USDZ files found: {directory}")
    for url in urls:
        validate(url)


if __name__ == "__main__":
    main()
````
