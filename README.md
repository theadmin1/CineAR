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
