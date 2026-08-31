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
    kontrol et; alan ilk kurulumda gercek deger olarak `http://192.168.1.9:8765` icermeli
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
