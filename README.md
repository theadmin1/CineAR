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
- RoomPlan ile parametrik oda taramasi ve `room.usdz` cikisi
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
4. `Oda Tara` ile seti tarayip 3B modeli olusturun.
5. Hazir bir dekor veya `USDZ Ekle` ile kisisel bir model secin.
6. Yuzeye dokunarak modeli yerlestirin; parmak hareketleriyle duzenleyin.
7. Mekan taramasi yeterince ayrintili oldugunda `Kaydet` tusuna basin.
8. `HEVC Cekim` tusuna basin. Kayit sirasinda arayuz gizlenir; bitirmek icin
   ekrana iki kez dokunun.

## Proje dosyalari

Uygulama Documents altinda su yapida calisir:

```text
CineARProjects/MainSet/
  scene.json
  worldmap.arexperience
  room.usdz
  Assets/*.usdz
  Recordings/*.mov
```

`scene.json`, dekor kimliklerini ve yerel transformlarini; `worldmap.arexperience`
ise ARKit'in mekansal haritasini ve anchor'larini saklar.

## Uretim siniri

Bu surum profesyonel sistemin cihazda calisabilir temelidir; nihai film teslim
kalitesi cihaz testi olmadan ilan edilmemelidir. ReplayKit tabanli compositing
cikisi HEVC'dir. ProRes, genlock, harici timecode, lens distortion calibration,
10-bit log/HDR ve piksel seviyesinde temiz plate uretimi icin sonraki asamada
ozel Metal renderer ve AVFoundation kamera yakalama hattina gecilmelidir.

Bu depoda hazir profesyonel USDZ dekor paketi bulunmaz. Dahili dekorlar kodla
uretilen basit prototip geometrileridir; harici modeller `USDZ Ekle` ile alinir.
RoomPlan ciktisi su anda referans/proje dosyasi olarak saklanir ve AR render
sahnesini otomatik olarak yeniden kurmaz. Gercek mobilya silme/inpainting ve
otomatik nesne degistirme bu surumun kapsami disindadir.

Ayrintili kabul kriterleri icin `Docs/DEVICE_TEST.md` dosyasina bakin.
