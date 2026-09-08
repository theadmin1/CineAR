# 0.17.6 yerel on kontrol kaydi

Tarih: 2026-09-08. Bu belge cihaz kabul testi veya iOS build basarisi belgesi degildir.

## Gercekten calistirilan kontroller

- Resmi Swift 6.0.3 Ubuntu 24.04 x86_64 arsivinin Swift imzasi dogrulandi.
  Sistem Swift kurulumu degistirilmedi; derleyici gecici test klasorunde kullanildi.
- `Tools/run_swift_regressions.py`: Swift 5 dil modu, uyarilar hata kabul edilerek
  uc paket hem `-Onone` hem `-O` ile derlendi ve calistirildi. Alti calistirma da gecti.
- Duvar kaplama geometrisi: her modda `WALL_CLADDING_GEOMETRY_OK: 42722 checks`.
- Anlik derinlik geometrisi: her iki modda basarili.
- Tarama onayi / duvar temas politikasi: her iki modda basarili; 360 duvar yonunde
  duzleme izdusus, bozuk olcum, on/arka derinlik ayrimi ve isleme sonrasi kayip dahil.
- Uygulamanin 16 Swift kaynak dosyasi Swift derleyicisinin parse kontrolunden gecti.
- Codemagic YAML parse edildi; on kontrol akisi manuel, Release/iPhone hedefli,
  imzasiz ve Apple entegrasyonu/yayinlama/degisken grubu olmadan tanimlandi.

## Bu incelemede eklenen korumalar

- Islenmis odada kabul edilebilen duvar uzunlugu kaybi %35'ten %10'a indirildi;
  daha buyuk kayipta onaylanmis canli tarama acik uyariyla korunur.
- Duzleme izdusus fonksiyonuna tasma/sonlu sayi kontrolleri eklendi.
- `cinear-preflight` akisi dagitim is akisindan ayrildi. Imza, IPA export,
  App Store Connect ve TestFlight adimlarini calistirmaz.

## Henuz dogrulanmayanlar

- Xcode 26.4 ve iPhone SDK'si ile API/tur denetimi, link ve kaynak derlemesi.
  Linux parse kontrolu Apple framework'lerini tur denetiminden gecirmez.
- iPhone 15 Pro Max'te taramayi bitir/kullan akisi ve duvar anchor kaymasi.
- LiDAR ortmesinin hareket, termal yuk ve ReplayKit kaydi altindaki performansi.

Sonraki adim: [Codemagic on kontrol akisini](CODEMAGIC.md) ayni aday commit uzerinde
calistir. Basarili olmadan TestFlight dagitimi icin hazir kabul etme. Imzasiz build
basarisi da [fiziksel cihaz testlerinin](DEVICE_TEST.md) yerine gecmez.

Bu inceleme sirasinda GitHub push veya uzak Codemagic build baslatilmadi.
