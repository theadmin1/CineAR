# CineAR cihaz kabul testi

## Hedef donanim

- LiDAR destekli iPhone Pro
- Tripod ve elde kullanim
- Dokulu, iyi aydinlatilmis en az 4 x 4 metre test alani
- On, orta ve arka planda gercek nesneler

## Fonksiyon testi

1. Odayi RoomPlan ile tamamen tara; `room.json` olustugunu ve `Taramayi Bitir`
   sonrasinda uygulamanin kapanmadigini dogrula.
2. Modern temanin tarama onayindan sonra otomatik acildigini; duvar, zemin,
   tavan, kapi/pencere bosluklari ve taninan buyuk objelerle hizalandigini kontrol et.
   Sandalye, masa/yatak ve bir cihaz kategorisinde yerlesik USDZ modelin gercek
   objenin merkezine ve RoomPlan boyutlarina oturdugunu ayri ayri olc.
3. Dort temayi arka arkaya sec, sonra `Gercek` gorunumune don. Tema degisiminde
   geometri kaymasi, sahne kopyalanmasi veya uygulama kapanmasi olmamali.
4. Modern tema acikken taranmis zemin, duvar ve taninan bir mobilyanin gorunen
   yuzeyine ayri ayri dokunarak kasa/isik yerlestir. Nesne dokunulan sanal yuzeyde
   gorunmeli; duvar ve isik panelleri dik kalip kameraya bakan yone hizalanmali.
5. Duvar, platform ve en az iki farkli USDZ model yerlestir. Tema degistirirken
   bu manuel objelerin konumunun ve parmak hareketlerinin korundugunu dogrula.
6. Modelleri tasi, dondur ve olceklendir; projeyi kaydet.
7. Uygulamayi tamamen kapat, ayni alanda ac ve projeyi yukle.
8. Relocalization tamamlandiktan sonra tema ve dekorlarin referans isaretlerine gore
   konum farkini olc.
9. Bir oyuncuyu sanal dekorun onunden ve arkasindan gecir; kenar ve derinlik
   hatalarini kaydet.
10. `Tumunu Sil` ile yalniz manuel objelerin silindigini, oda temasinin kaldigini test et.
11. Uygulamayi arka plana alip geri getir; AR takibi normale donmeli, tema ve manuel
    objeler yerinde kalmali. Gecici AR hatasinda otomatik yeniden baslatma mesaji
    gorulmeli ve `Oda Tara` yalniz takip yeniden hazir oldugunda etkinlesmeli.
12. Tripodda 10 dakika, elde 5 dakika kesintisiz HEVC kayit al.
13. MOV dosyasinda kare dusmesi, ses senkronu ve cihaz isinmasini kontrol et.

## Baslangic kabul esikleri

- Tripod konum kaymasi: 10 dakikada 2 cm'den az
- Elde relocalization hatasi: 5 cm'den az
- Tema yuzeyi ile gercek duvar/zemin hizasi: referans noktalarda 3 cm'den az
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
