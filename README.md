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
- RoomPlan ile ayni AR oturumunda semantik oda taramasi; mobil bellek dostu `room.json` cikisi
- Tarama sirasinda RoomPlan'in hafif, beyaz ve seffaf kilavuz cizgileri
- Tarama sonrasinda opak oda kaplamasi olmadan gercek kamera goruntusu
- Sandalye, masa, koltuk, yatak ve cihazlar dahil 14 yerlesik CC0 USDZ dekor
- Nesne secilince paneli kapatan, zeminin tamamini dokunulabilir yapan yerlestirme modu
- Dekorlari surukleme, dondurme ve olceklendirme
- Duzlem bulunamasa bile dokunulan ekran isininda serbest yerlestirme fallback'i
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
5. Tarama onaylandiginda gercek kamera goruntusune donulur; taranan yuzeylerin
   opak modelleri kamera uzerine cizilmez.
6. Hizli dekorlardan birini, `Hazir 3B Nesne Kutuphanesi` icindeki 14 modelden
   birini veya `USDZ Ekle` ile kisisel bir model secin.
7. Kontrol paneli otomatik kapandiginda zeminin istediginiz noktasina dokunun;
   sonra modeli parmak hareketleriyle duzenleyin.
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
  Assets/*.usdz
  Recordings/*.mov
```

`scene.json`, dekor kimliklerini ve yerel transformlarini; `room.json`, RoomPlan'in
semantik yuzey/obje verisini; `worldmap.arexperience` ise ARKit'in mekansal
haritasini ve anchor'larini saklar. Normal kamera gorunumunde `room.json` opak bir
oda modeli olarak cizilmez; veri sonraki semantik ozellikler icin korunur. Tarama
kapanirken gereksiz bellek yukune yol acan ikinci bir RoomPlan `room.usdz` arsivi
uretilmez.

## Uretim siniri

Bu surum profesyonel sistemin cihazda calisabilir temelidir; nihai film teslim
kalitesi cihaz testi olmadan ilan edilmemelidir. ReplayKit tabanli compositing
cikisi HEVC'dir. ProRes, genlock, harici timecode, lens distortion calibration,
10-bit log/HDR ve piksel seviyesinde temiz plate uretimi icin sonraki asamada
ozel Metal renderer ve AVFoundation kamera yakalama hattina gecilmelidir.

Bu surumde Kenney Furniture Kit'ten donusturulmus 14 CC0 USDZ model vardir.
Modeller kullanici tarafindan kutuphaneden secilir, gercekci metre boyutlarina
normalize edilir ve zemine oturtulur. Kaynak/lisans `CineAR/RoomAssets/LICENSE-KENNEY.txt`,
tekrar uretim ve dogrulama araclari `Tools/` altindadir. Bu yerlesik paket mobil
uyumlu low-poly kutuphanedir; fotogercekci, 2K/4K dokulu profesyonel set paketi
degildir. `RoomRealityAssetProviding`, sonraki lisansli/fotogercekci USDZ kataloglarini
ayni rollere takmak icin hazirdir. Eski opak oda tema renderer'i kaynakta deneysel
olarak korunur ancak akicilik ve insan gorunurlugu icin ana arayuzde otomatik acilmaz.
Kamera goruntusundeki gercek mobilyayi yapay
zekayla silip arka plani tamamlama (video inpainting) bu surumde yoktur; sanal
yuzeyler ve derinlik/insan occlusion'i kullanilir.

Ayrintili kabul kriterleri icin `Docs/DEVICE_TEST.md` dosyasina bakin.
