# CineAR cihaz kabul testi

## Hedef donanim

- LiDAR destekli iPhone Pro
- Tripod ve elde kullanim
- Dokulu, iyi aydinlatilmis en az 4 x 4 metre test alani
- On, orta ve arka planda gercek nesneler

## Fonksiyon testi

1. Odayi RoomPlan ile tamamen tara ve `room.usdz` olustugunu Files uygulamasinda
   dogrula.
2. Duvar, platform ve en az iki farkli USDZ model yerlestir.
3. Modelleri tasi, dondur ve olceklendir; projeyi kaydet.
4. Uygulamayi tamamen kapat, ayni alanda ac ve projeyi yukle.
5. Relocalization tamamlandiktan sonra dekorlarin referans isaretlerine gore
   konum farkini olc.
6. Bir oyuncuyu sanal dekorun onunden ve arkasindan gecir; kenar ve derinlik
   hatalarini kaydet.
7. Tripodda 10 dakika, elde 5 dakika kesintisiz HEVC kayit al.
8. MOV dosyasinda kare dusmesi, ses senkronu ve cihaz isinmasini kontrol et.

## Baslangic kabul esikleri

- Tripod konum kaymasi: 10 dakikada 2 cm'den az
- Elde relocalization hatasi: 5 cm'den az
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

