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
- Person segmentation with depth ve gercek mekan mesh'i ile occlusion
- RoomPlan ile ayni AR oturumunda semantik oda taramasi; `room.json` ve `.model` `room.usdz` cikisi
- Taranan duvar, zemin, tavan, kapi, pencere ve taninan mobilyalari tek dokunusla yeniden kurma
- Modern, Film Studyosu, Bilimkurgu ve Sicak Loft hazir oda temalari
- RoomPlan obje rollerine otomatik oturan 14 yerlesik, tema renkli CC0 USDZ mobilya/cihaz modeli
- Eksik veya bozuk USDZ icin uygulamayi durdurmayan prosedurel 3B model fallback'i
- Tema ile gercek gorunum arasinda aninda gecis; manuel eklenen objeleri bagimsiz koruma
- Dekorlari surukleme, dondurme ve olceklendirme
- Files uzerinden USDZ dekor kutuphanesine model aktarma
- ARWorldMap, anchor ve dekor transformlarini kalici proje olarak kaydetme
- Kayitli mekanda relocalization
- Arayuzsiz cekim modu; ekrana iki kez dokunarak kaydi bitirme
- HEVC video ve 48 kHz AAC mikrofon sesini `.mov` dosyasina yazma
- Son cekimi iOS Share Sheet ile disari aktarma

## Calistirma

1. `CineAR.xcodeproj` dosyasini Xcode ile acin.
2. Bundle Identifier'i size ait benzersiz bir degerle degistirin.
3. Signing icin Team secin ve uygulamayi gercek iPhone'a yukleyin.
4. `Oda Tara` ile tum duvarlari, kapi/pencereleri ve odadaki buyuk objeleri tarayin.
5. Tarama onaylandiginda varsayilan Modern tema otomatik uygulanir; ustteki
   `Oda Gercekligi` satirindan baska bir tema veya `Gercek` gorunumunu secin.
6. Hazir bir dekor veya `USDZ Ekle` ile kisisel bir model secin.
7. Yuzeye dokunarak modeli yerlestirin; parmak hareketleriyle duzenleyin.
8. Mekan taramasi yeterince ayrintili oldugunda `Kaydet` tusuna basin.
9. `HEVC Cekim` tusuna basin. Kayit sirasinda arayuz gizlenir; bitirmek icin
   ekrana iki kez dokunun.

## Proje dosyalari

Uygulama Documents altinda su yapida calisir:

```text
CineARProjects/MainSet/
  scene.json
  worldmap.arexperience
  room.json
  room.usdz
  Assets/*.usdz
  Recordings/*.mov
```

`scene.json`, dekor kimliklerini ve yerel transformlarini; `room.json`, RoomPlan'in
semantik yuzey/obje verisini; `worldmap.arexperience` ise ARKit'in mekansal
haritasini ve anchor'larini saklar.

## Uretim siniri

Bu surum profesyonel sistemin cihazda calisabilir temelidir; nihai film teslim
kalitesi cihaz testi olmadan ilan edilmemelidir. ReplayKit tabanli compositing
cikisi HEVC'dir. ProRes, genlock, harici timecode, lens distortion calibration,
10-bit log/HDR ve piksel seviyesinde temiz plate uretimi icin sonraki asamada
ozel Metal renderer ve AVFoundation kamera yakalama hattina gecilmelidir.

Bu surumde dort hazir tema, Kenney Furniture Kit'ten donusturulmus 14 CC0 USDZ
model ve RoomPlan'in kalan obje siniflari icin performans odakli prosedurel fallback
modeller vardir. USDZ'ler gercek mesh ve coklu materyal tasir; secilen temanin PBR
paletine otomatik boyanir. Kaynak/lisans `CineAR/RoomAssets/LICENSE-KENNEY.txt`,
tekrar uretim ve dogrulama araclari `Tools/` altindadir. Bu yerlesik paket mobil
uyumlu low-poly kutuphanedir; fotogercekci, 2K/4K dokulu profesyonel set paketi
degildir. `RoomRealityAssetProviding`, sonraki lisansli/fotogercekci USDZ kataloglarini
ayni rollere takmak icin hazirdir. Kamera goruntusundeki gercek mobilyayi yapay
zekayla silip arka plani tamamlama (video inpainting) bu surumde yoktur; sanal
yuzeyler ve derinlik/insan occlusion'i kullanilir.

Ayrintili kabul kriterleri icin `Docs/DEVICE_TEST.md` dosyasina bakin.
