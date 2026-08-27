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
   Ana gorunume dondukten sonra AR durumu en gec 10 saniye icinde hazir olmali;
   yeni bir tracking callback'i gelmese de kutuphane ve yerlestirme kullanilabilmeli.
4. `Beyaz Hatlar`i ac; duvar, zemin, kapi/pencere ve taninan buyuk objelerin yalniz
   ince seffaf hatlarla gorundugunu, kameranin kapanmadigini ve `Gercek` secilince
   butun hatlarin kayboldugunu dogrula.
5. Kasa'yi sec. Alt panel otomatik kapanmali; once zeminin panelin daha once kapattigi
   alt bolgesine, sonra orta ve uzak bolgesine dokun. Her dokunusta kasa gorunmeli.
   Ayni testi once `Gercek`, sonra `Beyaz Hatlar` modunda tekrarla.
6. 30 parcalik gercekci kutuphanenin Mobilya, Depolama, Ekipman, Duvar, Isik ve
   Elektronik bolumlerini ac. Her bolumden en az iki model yerlestir; 1K PBR dokular
   gorunmeli, boyutlar gercekci olmali ve modeller yuzeyin altina gomulmemeli.
   Yerlesimden sonra buyuk panel yerine dort dugmeli kompakt dock gorunmeli.
7. Zemin nesnesini zemine, dizustu bilgisayari masa tablasina, kamerayi duvara ve
   kafesli armaturu tavana yerlestir. Yanlis yuzey turundeki ilk carpismayi atlayip
   dogru yuzeyi buldugunu; RoomPlan kaydindan sonra uzak zemin ve tavan noktalarinda
   kayitli duzlem yedeginin calistigini dogrula.
8. Tavan veya duvar isigini sec. `Sanal Isik` panelinde ac/kapat, 0-12000 lumen,
   2000-6500 K, yatay yon, dikey egim ve 15-120 derece huzme kontrollerini uctan
   uca degistir. Isik hedefinin hem saga-sola hem yukari-asagi dondugunu dogrula.
   Gercek kamera pikselleri degismemeli; sanal dekorlardaki aydinlanma ve golge
   degismeli. Kaydet, uygulamayi kapat, yukle ve ayni degerlerin geri geldigini dogrula.
9. Takip `limited` iken veya kalici duzlem bulunmadan zemin noktasina dokun;
   uygulama nesneyi kamera onunde tahmini bir noktaya koymamali, yerlestirme modunu
   acik tutup zemini yavasca tarama mesaji gostermeli. Takip `normal` ve duzlem
   hazir oldugunda ayni dokunus nesneyi zemine sabitlemeli. RoomPlan taramasi
   tamamlandiktan sonra ARKit'in ayri bir plane anchor uretmedigi uzak zemin
   noktalarinda da kayitli zemin seviyesiyle yerlestirme calismali.
10. Duvar, platform ve en az iki farkli USDZ model yerlestir; modellerin zemine temas
   golgesini ve kamera hareketinde anchor konumunu korudugunu dogrula.
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
    girip baglantiyi test et ve sistemi ac. Durumun `Aktif`, gecikmenin ve SAM maske
    sayisinin sifirdan buyuk oldugunu dogrula. Masa kenari ile on/arka insan testini
    tekrar et; AI kapaliyken ve acikken video kaydi alip kenar hatasini karsilastir.
    Servisi kapatinca eski AI mesh'i kaybolmali ve ARKit occlusion devam etmeli.
16. `Tumunu Sil` ile tum manuel objelerin silindigini test et.
17. Uygulamayi arka plana alip geri getir; AR takibi normale donmeli ve manuel
    objeler yerinde kalmali. Gecici AR hatasinda otomatik yeniden baslatma mesaji
    gorulmeli ve `Oda Tara` yalniz takip yeniden hazir oldugunda etkinlesmeli.
18. Tripodda 10 dakika, elde 5 dakika kesintisiz HEVC kayit al.
19. MOV dosyasinda kare dusmesi, ses senkronu ve cihaz isinmasini kontrol et.

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
