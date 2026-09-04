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
- Istege bagli PC destekli Depth Anything V2 Small + opsiyonel SAM 2.1 Tiny altyapisi;
  LiDAR bulunmayan uygun cihazlarda statik derinlik yedegi, sonraki yapay zeka
  efektlerinde ise yerel sunucu olarak kullanilmak uzere baglanti destegi korunur
- AI servisi kapali veya ulasilamazsa stale AI mesh'ini kaldirip kesintisiz olarak
  cihazdaki ARKit scene depth, person depth ve LiDAR mesh occlusion'a geri donme
- Karede kisi maskesi goruldugunde gecikmeli PC mesh'ini aninda devre disi birakip
  ARKit person-depth'i one alma; kisi kaybolana kadar uzak sonucu sahneye uygulamama
- LiDAR destekli iPhone'da zaten cizilmeyen PC derinlik karesi icin kamera JPEG'i
  hazirlayip gondermeme; ana goruntu is parcacigindaki periyodik takilmayi kaldirip
  kamera ile ayni ana ait yerel mesh'i tek occlusion kaynagi olarak kullanma
- Yerlesim sirasinda uzak AI occlusion'ini durdurma; AR anchor kesinlesmeden modeli
  gostermeme, 350 ms'den eski veya kamera pozuyla sikica uyusmayan AI karesini reddetme ve
  LiDAR/AI derinliklerini ust uste cizmeden nesne kesilmesini engelleme
- RTX 3050 hizli profilinde 322 px Depth Anything, varsayilan kapali SAM ve 500 ms
  istek araligi; sunucu hazir olmadan CUDA isitmasi ve LiDAR metre tamponunun
  cozunurlugunu dusurmeden daha dusuk gecikme
- PC veya bulut gerektirmeyen `Zemin Olcer`: siniflandirilmis LiDAR/ARKit zemin kotu,
  merkez piksel derinligi, gorus-cizgisi zemin mesafesi, kamera yuksekligi, egim,
  X/Y/Z koordinatlari ve 25 cm aralikli 4 x 4 metre saydam dunya grid'i
- RoomPlan ile ayni AR oturumunda semantik oda taramasi; mobil bellek dostu `room.json` cikisi
- Tarama ekraninda canli zemin/duvar/nesne sayaci; en az bir zemin ve bir duvar
  bulunmadan hatali veya bos taramayi bitirmeyi engelleme
- RoomPlan acikken ana AR denetleyicisindeki yerlestirme, efekt, projektor, AI ve
  LiDAR siniflandirma islerini durdurma; bilgi sayacini 250 ms aralikla yenileyerek
  kamera ve beyaz tarama cizgilerine kare butcesini birakma
- RoomPlan acilirken kararlı AR karesini bekleme; `worldTrackingFailure` sonrasinda
  paylasilan oturumu guvenli yeniden calistiran ve Turkce yonlendirme veren tekrar deneme
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
  10 saniye zaman asimi ve oturum ici model onbellegiyle sonsuz `yukleniyor` durumunu
  engelleme; dosya hazir olunca ayni dunya anchor'inda gercek modelle degisim
- Anchor edilmeden yapilan USDZ olcumunde inactive cocuklari da hesaba katma; RealityKit'in
  sifir boyut dondurup 30 modelin tamamini mavi yedek kutuya dusurmesini engelleme
- Ilk acilista ve yerlestirme sonrasinda kamerayi acik birakan kompakt alt kontrol dock'u
- Canli kamera ve sanal dekorlari birlikte etkileyen Dogal, Sinema, Teal & Orange,
  Noir, Gerilim ve Ruya film filtreleri; renk, kontrast, parlaklik, ton ve vinyet
  ayarlari ReplayKit HEVC kaydina da islenir
- Nesne secilince paneli kapatan, zeminin tamamini dokunulabilir yapan yerlestirme modu
- Her katalog nesnesi icin ayri zemin, yatay yuzey, duvar veya tavan yerlestirme kurali
- Duvar kataloglari gorunur beyaz hatlara bagli kalmadan sonlu RoomPlan/ARKit/LiDAR
  duvarina yerlesir; varsa dokunulan derinlik pikseli uyusmazligi reddeder, gecici
  derinlik kesintisi yerlestirmeyi kilitlemez. Fiziksel olcek ve duvar golgesi korunur
- Tavan/duvar/masa lambalarinda ac-kapat, 0-12000 lumen, 2000-6500 K renk
  sicakligi, -180/+180 derece yatay yon, -75/+75 derece dikey egim,
  8-90 derece huzme ve kenar yumusakligi; yeni isiklar dar 18 derece spotla baslar
- `Projektor Hedefini Sec` ile zemine, masaya veya duvara dokunup SpotLight'i tam
  dunya koordinatina yoneltme; mesafe ve aciya gore olceklenen, egik yuzeyde elipse
  donusen yumusak isik izi kamera gorunumunde hedef noktayi belirginlestirir
- Yeni sanal lambalarda otomatik ortam aydinlatmasina karsi fark edilir 6000 lumen baslangic gucu
- `Sahne Isigi` dugmesi mevcut son isigi dogrudan ayara acar; sahnede isik yoksa
  tavan isigi yerlestirme modunu baslatir, boylece kontrol paneli gizli kalmaz
- Isik panelinde her ekran boyunda gorunen kapatma dugmesi ve kaydirilabilir ayarlar;
  kapatirken isik degerlerini kaydetme ve hedef secim modunu sonlandirma; isik kapali
  iken SpotLight gucunu sifirlama, projektor izini kaldirma ve armaturu karartma
- Dekor konumunu dunya anchor'ina kilitleme; secili her nesne icin temas noktasini
  bozmayan yuzde 25-300 boyut kaydiricisi, artir/azalt ve 1:1 sifirlama; olculu
  kataloglarda yanlislikla olcek bozulmasin diye pinch yerine kontrollu panel,
  ozel/olcusuz dekorlarda ek olarak dondurme ve pinch olceklendirme
- Yalniz haritalama `extending/mapped`, takip normal ve kamera en az 240 ms sabitken
  kalici ARKit/RoomPlan yuzeyine yerlestirme; hareketli kare anchor'i ve kamera-onu
  tahmini noktalar reddedilerek nesnenin yuzmesi engellenir
- Dokunulan yuzeyi tek karede kabul etmek yerine en az 260 ms boyunca alti ayri
  LiDAR/ARKit olcumunde konum ve normal tutarliligi arama; derinlik sicrayan kareleri
  ayiklayip yalniz cok-kareli yuzey kilidi olusunca dunya anchor'i ekleme
- `.floor` sinifli ARKit duzlemi, `.floor` sinifli LiDAR mesh yuzleri, RoomPlan zemin
  kotu ve dokunulan pikseldeki orta/yuksek guvenli `smoothedSceneDepth` olcumunu
  birlestiren kati zemin cozucu; masa gibi siniflandirilmamis yatay yuzey zemine gecmez
- Tavan armaturlerinde yalniz `.ceiling` sinifli sonlu ARKit yuzeyi veya kalibre
  RoomPlan tavan kotunu kabul etme; dolap ustu ve yuksek raflari tavan saymama
- Parmakla dokunulan noktayi izleyen yesil/sari/kirmizi hedef gostergesi ve metre
  cinsinden derinlik geri bildirimi
- USDZ'nin gercek alt/ust/arka gorsel sinirini yuzey temas pivotuna alan donusum;
  dondurme ve olceklendirme sonrasinda modelin tabani zeminden kopmaz veya gomulmez
- RoomPlan'in tanidigi masa, sandalye ve buyuk mobilyalari gercek kamera gorunumunde
  gorunmez derinlik geometrisine cevirerek sanal nesnelerde kalici occlusion
- Modelin gercek gorsel sinirindan uretilen iki katmanli yumusak temas golgesi;
  saydamligi iki kez uygulamayan gorunur materyal, tavan armaturu temas golgesi ve
  nesne boyut panelinden dogrudan yuzde 0-200 golge ayari
- Telefon zeminde sabitken o seviyeyi Minecraft benzeri `Y 97.00` katmani olarak
  kilitleyen, tavani ayni koordinatta olcen kalici sistem; tamamlanmis RoomPlan taramasi
  varsa cok-ornekli zemin/tavan kotu eski veya hatali tek-poz kalibrasyonu otomatik duzeltir
- Siniflandirilmis ARKit duzlemi veya LiDAR mesh yeterince kararli oldugunda zemin ve
  tavani otomatik kilitleme; manuel tavan olcumunde once sonlu `.ceiling` duzlemini,
  sonra yumusatilmis egim esikli merkez derinligini kullanma
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
- Kalici bir duvar kosesini `Referans Kaydet` ile sahneye saklama; daha sonra mekani
  yukleyip ayni noktaya `Referansla Hizala` ile dokununca dekor anchor'larini, RoomPlan
  yuzeylerini, zemin/tavan kotlarini ve projektor hedeflerini birlikte duzeltme
- Duvara anchor edilen, uygulama yeniden acildiginda sahne kaydiyla geri gelen
  hareketli kan selalesi CGI efekti; yalniz sonlu, dikey duvar geometrisi ile
  dokunulan LiDAR derinligi eslestiginde yerlestirme
- Vision el-eklem takibinin goruntu yonu/aspect-fill koordinatlarini ARKit ekranina
  donusturup kisi derinligiyle avuc konumunu metre cinsinden olcme; gecikmis kareyi
  ve 30 cm'den buyuk derinlik sicramasini reddedip elmayi sabit dunya kokunde yumusatma
- `Elimde elma olsun`, `elmayi kaldir` ve `kan selalesi aksin` Turkce sesli
  komutlari; Turkce baglam ifadeleri, gorunur izin/hata durumu, Ayarlar kisayolu ve
  cihaz-ici tanima yeterli olmadiginda Apple'in ag destekli tanimasina izin verme
- Uygulama acilisinda sessiz App Store surum denetimi ve `Kontroller > Guncelleme`
  uzerinden manuel kontrol; yeni surumde guvenli App Store yonlendirmesi, beta
  kurulumunda TestFlight acma destegi
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
   olarak degisir. Tarama ekranindaki `Zemin / Duvar / Nesne` sayacinda en az bir
   zemin ve bir duvar gorulmeden `Taramayi Bitir` etkinlesmez.
   `Koordinat` dugmesiyle olceri acin. Uygulama siniflandirilmis LiDAR/ARKit zemini ve
   tavani yeterince kararli gorurse kotlari otomatik kilitler. Gerekirse `Zemini Bul · Y97`ye basip telefonu ekrani
   zemine, arka kamerasi tavana bakacak sekilde bir saniye sabit birakin; bu fiziksel
   seviye `Y 97.00` olur. Ardindan `Tavani Olc` ile merkez artiyi bos tavana tutun;
   tavan katmani ve metre cinsinden oda yuksekligi ayni koordinatta hesaplanir.
   Beyaz grid zemine sabitlenir, kirmizi X ve mavi Z eksenleri ilk dogrulanan noktayi
   sifir kabul eder. `X/Z Sifirla` yatay baslangici yeniler. Kirmizi durum, merkez
   pikselde masa/koltuk gibi bir nesnenin gercek zemini kapattigini belirtir.
5. Tarama onaylandiginda gercek kamera goruntusune donulur; taranan yuzeylerin
   opak modelleri kamera uzerine cizilmez. Gerektiginde `Beyaz Hatlar` ile taranan
   sinirlari seffaf olarak acip yeniden `Gercek` moduna donebilirsiniz.
6. Kompakt dock'taki `Nesneler` ile kutuphaneyi acin; hizli dekorlardan birini,
   `Hazir 3B Nesne Kutuphanesi` icindeki 30 fotogercekci parcadan
   birini veya `USDZ Ekle` ile kisisel bir model secin.
7. Kontrol paneli otomatik kapandiginda hedefi istediginiz noktaya surukleyin.
   Hedef yesil ve metre degeri gorunurken zemine, yatay yuzeye, duvara veya tavana
   dokunun. Uygulama dokunustan sonra telefonu kisa sure sabit tutarken ayni noktayi
   alti karede olcer; yalniz konum ve yuzey normali uyusursa nesneyi sabitler.
   Zemin nesnelerinde masa/koltuk gibi bir yuzey kirmizi olur. Kararli yuzey
   yoksa uygulama nesneyi kamera onunde tahmini bir noktaya
   koymaz; hedef yuzeyi yavasca taramanizi ister. Tamamlanmis bir RoomPlan taramasi varsa
   kayitli zemin ve tavan duzlemleri tam alan icin guvenli yedek olarak kullanilir. Konum dunya anchor'ina kilitlenir;
   nesneyi tekrar secip boyut panelinden yuzde 25-300 araliginda buyutup
   kucultebilirsiniz; `1:1` gercek katalog boyutuna dondurur. Yuzey temas noktasi
   olcek degisirken sabit kalir. Yerlesimden sonra yalniz kompakt dock geri gelir;
   ayrintili araclar `Kontroller` ile acilir.

8. Bir lamba yerlestirildiginde veya tekrar secildiginde `Sanal Isik` panelinden
   `Projektor Hedefini Sec`e basin ve isin vuracagi yuzeye dokunun. Guc, renk
   sicakligi, spot acisi, kenar yumusakligi ve acik/kapali durumu degistirilebilir.
   RealityKit SpotLight sanal dekorlari ve golgelerini fiziksel olarak aydinlatir;
   gercek kamera pikseli yeniden isiklandirilmaz, fakat LiDAR yuzeyine oturan saydam
   projektor izi kamera gorunumunde ayni hedefi gosterir ve gercek derinlikle ortulur.
   Kompakt dock'taki `Film` satirindan alti canli renk gorunumunden birini secin;
   ayni ekrandaki `Temas golgesi` kaydiricisi nesne golgesini yuzde 0-200 arasinda
   ayarlar. Bu degerler mekana kaydedilir ve HEVC ekran kaydinda gorunur.
9. Tarama sonrasinda ilk dunya haritasi ve her yeni dekor anchor'i otomatik kaydedilir.
   Dondurme/olceklendirme degisikliklerinden sonra `Kaydet` tusuna basin; takip hazir
   degilse istek siraya alinir ve otomatik tamamlanir. Manuel kayit `Kayitli Mekanlar`
   icinde ayri bir arsiv olusturur; listeden eski tarama ve o taramaya ait nesneler
   birlikte geri yuklenir. Ilk kayitta degismeyecek, belirgin bir duvar kosesine
   `Referans Kaydet` ile dokunun. Mekani daha sonra yuklediginizde otomatik takip tam
   oturmazsa `Referansla Hizala`ya basin ve fiziksel olarak ayni noktaya dokunun;
   uygulama tum sahneyi tek bir koordinat duzeltmesiyle yeniden sabitler ve kaydeder.
10. `Sahne` listesinden eklenmis nesneyi secin veya cop kutusuyla tek basina silin.
    `Canli CGI` ekraninda kan selalesini secip hedef yesile dondugunde gorunur duvara
    dokunun; `Avucta Canli Elma`yi acip avucunuzu kameraya gosterin. Sesli komut icin
    mikrofon ve konusma izinlerini verip ayni islemleri Turkce baslatin.
11. `Kontroller > Guncelleme` ile surumu denetleyin. App Store surumu hazirsa
    `Guncelle`, TestFlight beta kurulumuysa `TestFlight'i Ac` secenegi gorunur.
    iOS guvenlik kurali geregi uygulama IPA'yi kendi icinden kurmaz.
12. `HEVC Cekim` tusuna basin. Kayit sirasinda arayuz gizlenir; bitirmek icin
    ekrana iki kez dokunun.

## PC AI derinlik denemesi

RTX bilgisayarda once `AIService/setup_windows.ps1`, sonra
`AIService/run_server.ps1` calistirilir. Konsolda yazan yerel IP, uygulamadaki
`Kontroller > AI Derinlik` ekraninda Bonjour ile otomatik bulunur ve `/health` ile
dogrulanir; basariliysa AI anahtari acilir. `PC bagli - LiDAR karesi bekleniyor` mesaji
sunucu baglantisinin basarili oldugunu, telefonun henuz scene-depth karesi uretmedigini
belirtir. Ayrintili komutlar ve model secimi `AIService/README.md`
dosyasindadir. Kamera/derinlik yalniz kullanicinin girdigi yerel adrese gonderilir;
bulut servisi kullanilmaz. Baglanti kurulamazsa iPhone Safari'de ayni adresin
`/health` yolu acilir ve uygulamadaki `iPhone Yerel Ag ayarini ac` dugmesinden
CineAR izni kontrol edilir.

Kayitli PC adresi yalniz yedektir. Adres DHCP nedeniyle degisirse veya hotspot/Wi-Fi
degistirilirse sunucu varsayilan rotayi 5 saniyede bir denetler, Bonjour yayinini yeni
IP ile yeniler ve iPhone adresi elle giris istemeden alir. Ilk acilista etkin
Wi-Fi/Ethernet adresi otomatik secilir ve VMware gibi sanal adaptorler atlanir.
Bonjour engellenirse terminaldeki adres ayni alana elle yazilabilir; Safari'de
kullanilan `/health` son ekli adres yapistirilsa da uygulama sunucu kokunu ayiklar.

LiDAR destekli iPhone'da PC'ye canli kamera karesi gonderilmez; PC derinligi bu
cihazlarda kamera ile ayni ana ait olmadigi icin sabitlemeyi iyilestirmez. Canli
LiDAR mesh ve insan derinligi dogrudan cihazda kullanilir. LiDAR bulunmayan bir
cihazda PC yolu statik geometri yedegi olarak calismaya devam eder.

AI acikken hassas canli derinlik ile kaba RoomPlan mobilya kutulari ayni anda
occlusion yazmaz. Bu, masa kenarinda sanal nesnenin yariya kesilmesini engeller;
AI kapatilirsa hafif ice alinmis RoomPlan yedegi tekrar etkinlesir.
RTX 3050 sinifi bir PC'de her karede SAM 2 calistirmak gercek zamanli degildir. Bu
nedenle varsayilan hizli profil 322 px Depth Anything + LiDAR kullanir; SAM kalite
modu elle acilir. Istemci yalniz 350 ms icinde gelen ve guncel kamera pozuyla sikica
uyusan sonucu kabul eder, diger karelerde yerel LiDAR/person-depth'e doner.

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

`scene.json`, dekor kimliklerini, temas-pivotlu yerel transformlarini, nesne olceklerini,
film filtresini, temas golgesi gucunu, kalibre edilmis zemin/tavan kotlarini, projektor
hedef koordinatini ve sanal isik ayarlarini; `room.json`, RoomPlan'in
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
boyutlarina normalize edilir, sahne listesinde `genislik x yukseklik x derinlik`
olarak gosterilir ve olculmus katalog modellerinin olcegi kilitlenir. Eski projeler icin
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
