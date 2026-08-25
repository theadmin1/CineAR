# CineAR cihaz kabul testi

## Hedef donanim

- LiDAR destekli iPhone Pro
- Tripod ve elde kullanim
- Dokulu, iyi aydinlatilmis en az 4 x 4 metre test alani
- On, orta ve arka planda gercek nesneler

## Fonksiyon testi

1. Odayi RoomPlan ile tamamen tara; `room.json` olustugunu ve `Taramayi Bitir`
   sonrasinda uygulamanin kapanmadigini dogrula.
2. Tarama sirasinda yalniz RoomPlan'in beyaz/seffaf kilavuzlarinin gorundugunu;
   tarama onayindan sonra opak duvar, zemin veya mobilya kaplamasi olusmadigini dogrula.
3. Tarama boyunca kamera hareketinin akici oldugunu, ana gorunume donuste gercek
   insanlarin ve mobilyalarin tamamen gorunur kaldigini kontrol et.
4. Kasa'yi sec. Alt panel otomatik kapanmali; once zeminin panelin daha once kapattigi
   alt bolgesine, sonra orta ve uzak bolgesine dokun. Her dokunusta kasa gorunmeli.
5. Hazir 3B Nesne Kutuphanesi'nden sandalye, masa, koltuk, yatak ve iki cihaz secip
   yerlestir. Boyutlar gercekci olmali ve modeller zeminin altina gomulmemeli.
6. Duvar, platform ve en az iki farkli USDZ model yerlestir; manuel objelerin
   konumunun ve parmak hareketlerinin korundugunu dogrula.
7. Modelleri tasi, dondur ve olceklendir; projeyi kaydet.
8. Uygulamayi tamamen kapat, ayni alanda ac ve projeyi yukle.
9. Relocalization tamamlandiktan sonra dekorlarin referans isaretlerine gore
   konum farkini olc.
10. Bir oyuncuyu sanal dekorun onunden ve arkasindan gecir; kenar ve derinlik
   hatalarini kaydet.
11. `Tumunu Sil` ile tum manuel objelerin silindigini test et.
12. Uygulamayi arka plana alip geri getir; AR takibi normale donmeli ve manuel
    objeler yerinde kalmali. Gecici AR hatasinda otomatik yeniden baslatma mesaji
    gorulmeli ve `Oda Tara` yalniz takip yeniden hazir oldugunda etkinlesmeli.
13. Tripodda 10 dakika, elde 5 dakika kesintisiz HEVC kayit al.
14. MOV dosyasinda kare dusmesi, ses senkronu ve cihaz isinmasini kontrol et.

## Baslangic kabul esikleri

- Tripod konum kaymasi: 10 dakikada 2 cm'den az
- Elde relocalization hatasi: 5 cm'den az
- Manuel dekor ile dokunulan gercek yuzey hizasi: referans noktalarda 3 cm'den az
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
