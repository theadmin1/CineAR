# SynapMantis Virtual Production

SynapMantis, iPhone uzerinde gercek zamanli sanal dekor ve set onizlemesi icin gelistirilen
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

Dagitimdan once `cinear-preflight` imzasiz iPhone Release derlemesi ve Swift
regresyonlarini calistirir; TestFlight'a yukleme yapmaz. Ayrintilar
[Codemagic on kontrol](Docs/CODEMAGIC.md) ve [yerel test kaydi](Docs/PREFLIGHT_AUDIT.md).

## Mevcut sistem

- 0.20.2: Yeni 13 fotogercekci model, iPhone RealityKit'in dogrudan destekledigi
  tek `UsdPreviewSurface` malzeme agiyla Blender uzerinden yeniden paketlendi;
  MaterialX aglari kaldirildi, renk/normal/puruzluluk/metal dokulari USDZ icine
  alindi ve kaplamasiz yedek sekilde kalma regresyonu giderildi. Ozel AR duvar
  gorunumu uzun varlik listesinin ustune tasindi ve yatay secim kartlariyla acikca
  gorunur oldu. Dokulu tugla ve dokulu ahsap dahil 14 duvar gorunumu sunulur.
- 0.20.1: Ozel AR alaninin sonlu taban cokgeni artik dolap, koltuk ve diger zemin
  nesneleri icin tek dokunusla kullanilan kalici bir yerlestirme yuzeyidir. Backrooms
  halisi duvar-zemin birlesim golgesini kapatmaz; nesne temas golgeleri gercek alt
  sinira gore daha gorunur ve kararlidir. Yeni 13 fotogercekci USDZ, RealityKit'in
  kaplamalari cihazda guvenilir acmasi icin tek katmanli Y-up sahneye duzlestirildi;
  tum texture yollari paket icine alindi ve agir haritalar mobil JPEG'e donusturuldu.
- 0.20.0: Ozel AR Backrooms kiti artik Yasu'nun dokuz duvar kagidi, dort tavan
  ve bir hali PBR malzemesini; ayrica 3DTextures.me klasik CC0 duvar kaplamasini
  1K mobil paketler olarak sunar. Malzeme menusu duvar varyantini ve ona eslesen
  tavani degistirir; renk/normal/puruzluluk haritalari metre tabanli UV ile tekrar
  eder ve arka planda yuklenirken sahneyi dondurmaz. Eskimis dolap, vintage bavul,
  tasinabilir kasetcalar, vintage telsiz, eskimis ahsap koltuk, ofis not defterleri
  ve guvenlik lambasi eklendi. Katalog 52 gercekci parcaya, cevrimdisi paket 80
  USDZ'ye cikti. Yeni kaynaklar CC0 veya CC BY 4.0 lisanslidir.
- 0.19.0: Ozel AR'a tek dokunuslu Backrooms kiti eklendi: sari yipranmis duvar,
  koyu kirli hali, acik tavan ve `Backrooms Sari` sinematik filtresi birlikte
  uygulanir. Tavana yerlestirilen yeni gercekci floresan 8000 lumen genis sicak
  isikla baslar; dusuk poligonlu saydam huzmesi ve hedef izi LiDAR ortmesini korur.
  Sanal duvar kapisi artik fiziksel arka plan derinligiyle yanlis reddedilmez,
  cokgenin ic tarafinda olusur ve kanada dokununca animasyonlu acilip kapanir.
  Uc yeni CC0 tablo ve Backrooms floresaniyla fotogercekci katalog 44 parcaya,
  cevrimdisi paket 58 USDZ'ye cikti. Yeni ve onceki Ozel AR tablo/lamba USDZ'leri
  iPhone RealityKit icin acik Y-up eksenine normalize edildi; yukleme sirasinda
  her biri taninabilir prosedurel yedekle aninda gorunur.
- 0.18.1: Ozel AR duvar ve tavanlari artik kendi sonlu, dunya koordinatina sabit
  collider'larinda tek dokunusla dekor kabul eder; fiziksel arka plani olcen LiDAR
  bu sanal yuzey secimini yanlislikla iptal etmez. Asili tablo ve modern tavan lambasi
  yuksek detayli USDZ acilirken taninabilir, dusuk maliyetli bir yedek modelle aninda
  gorunur. Duz cizimlerde ilk nokta, 30 cm guven araligindaki kararlı RoomPlan/ARKit
  zemin kotuna oturur; gercek egimli yuzeyler egimli kalir. Duvar govdesi LiDAR zemin
  sapmasindan bosluk birakmamak icin taban duzleminin 10 cm altina uzar. Bitmis alanda
  mavi taslak cizgileri kaldirilir ve zeminle birlesim icin yalniz cokgenin ic tarafinda,
  kapi acikliklarini kapatmayan tek katmanli mobil temas golgesi kullanilir.
- 0.18.0: Ayri `Ozel AR` modu eklendi. Kullanici LiDAR ile duz veya egimli bir
  yuzeyde 3-24 kose cizer; alan kapaninca cevre duvarlari dunya koordinatinda
  sabitlenir. Alan icinde iki noktayla ek duvar cizilebilir, duvara gercek aciklik
  olusturan olculu kapi eklenebilir ve kapi kanadi dokunusla animasyonlu acilip
  kapanir. Duvar yuksekligi, kalinligi ve beyaz/beton/tugla malzemesi ayarlanir.
  Istege bagli tavan, cizilen cokgenin sinirlarina tam uyar ve secilen duvar
  yuksekliginde olusur; tavan armaturleri de bu sonlu sanal yuzeye sabitlenebilir.
  Moda ozel hizli varlik seti; mevcut ankesorlu telefon, yuk arabasi ve mimari
  ekipmana ek olarak yeni 1K PBR modern tavan lambasi ile duvara asilan sanat
  cercevesini dogrudan sunar. Yeni USDZ'ler 1.9 MB altinda tutulmustur.
  Normal nesne kutuphanesindeki duvar dekorlari Ozel AR duvarlarinin sonlu collision
  yuzeyine yerlestirilebilir. Alanlar, duvarlar, tavanlar, kapilar ve acik/kapali durumu
  `scene.json` ile mekana kaydolur; ARWorldMap ve referans hizalama duzeltmesiyle
  birlikte ayni fiziksel koordinata geri gelir. Canli LiDAR/kisi derinligi bu
  sanal yapilarda da gercek insan ve nesneleri onde tutar.
- 0.17.17: RoomPlan taramasi bittikten sonra ayni ARSession'in dunya baslangici ve
  mevcut anchor'lari korunurken `sceneDepth`, kisi derinligi ve LiDAR mesh occlusion
  ayarlari yeniden etkinlestiriliyor. Boylece 0.17.15'te duzeltilen koordinat
  sabitlemesi korunurken gercek el, insan ve duvar onundeki nesneler sanal duvarin
  onune gecebilir. Ham derinlik bulunmayan destekli kombinasyonlarda yumusatilmis
  LiDAR derinligi de anlik ortme icin kullanilir.
- 0.17.16: Uygulamanin ana ekran ve kullaniciya gorunen adi `SynapMantis` oldu.
  AppIcon, siyah zemin uzerinde beyaz, kose hatli ve teknolojik mantis siluetiyle
  yenilendi. App Store
  baglantisini, Codemagic arsiv yollarini ve mevcut cihaz projelerini korumak icin
  teknik Xcode target'i, bundle kimligi ve veri klasoru adlari degistirilmedi.
- 0.17.15: Taranmis oda varken duvar dekorlari artik RoomPlan'in yaklasik duvar
  duzlemini temas noktasi olarak kullanmaz; iPhone'un ayni anda olctugu gercek LiDAR
  noktasi anchor temasidir. RoomPlan yalnizca kararlı duvar yonu ve sonlu siniri
  saglar. Tam duvar kaplamalari da kapi/pencere kesimlerini korurken en fazla 5 cm'lik
  dogrulanmis LiDAR duzlem farkiyla fiziksel duvara oturtulur. Bu, yandan bakildiginda
  telefonun yuzmesi ve kaplamanin pervaz uzerinde parallax kaymasi regresyonunu giderir.
- 0.17.14: Canli LiDAR ortme aginin yuzey arkasi payi 8-25 mm'den 1.4-3 mm'ye
  indirildi. Sanal kaplamanin 6 mm ondeki yuzeyi gorunur kalirken gercek duvar
  saati, cerceve ve raf gibi yaklasik 1 cm veya daha fazla cikintilar artik
  kaplamanin onunde kalir.
  Disaridan eklenen kok `Entity` hiyerarsili USDZ dosyalari da cihazda acilir;
  yerel yukleme zaman asimi 25 saniyedir. Paketteki 58 cevrimdisi USDZ'nin ad,
  checksum, ZIP/USD sahne butunlugu ile uygulama ve IPA icine kopyalanmasi Codemagic
  tarafindan derlemeden once ve sonra dogrulanir; bu katalog PC baglantisi kullanmaz.
- 0.17.13: RoomPlan taramasi biterken halen calisan ortak `ARSession` artik yeni
  bir yapilandirmayla tekrar calistirilmaz. Boylece tarama sirasinda kurulan dunya
  koordinat sistemi korunur; taranmis oda kullanici baska bir odaya yurudugunde
  kamerayla birlikte gelmez. RealityKit oda ve fiziksel occlusion kokleri ayni
  kesintisiz dunya koordinat sistemine yeniden baglanir. ARKit takibi gecici olarak
  sinirlanirsa oda yanlis kamera pozunda suruklenmek yerine gizlenir ve normal takip
  dondugunde hazir geometrisi ayni dunya konumunda yeniden gosterilir.
- 0.17.12: Tarama boyunca gorulen en genis duvar kapsami artik yuksek-su-izi
  olarak korunur; RoomPlan kose birlestirirken gecici olarak 4 duvari 1 duvara
  dusururse bu kare onceki taramayi silemez. Bitis islemi de islenmis sonuc canli
  duvar uzunlugunun buyuk bolumunu kaybetmisse kapsami yuksek canli sonucu saklar.
  Kayitli sonlu duvar, iPhone 15 Pro Max'te tek bir dusuk guvenli depth pikseli
  yuzunden reddedilmez; yalniz gercekten daha yakinda olculen bir on nesne secimi
  engeller. RoomPlan/ARPlane/LiDAR ayni duvari tarif ediyorsa cok kareli kilit
  sifirlanmaz, kilit suresi 2.25 saniyedir ve 256 duvar parcasi desteklenir.
- 0.17.11: Eski guvenilir RoomPlan sensor akisi geri getirildi. Tarama dugmesine
  basildiginda kararlı ortak `ARSession` yeniden yapilandirilmadan dogrudan RoomPlan'a
  devredilir; 50 ms'lik ilk kare bekleme zinciri kaldirildi. Her canli geometri
  karesi kayit yedegi icin korunurken yalniz arayuz yazilari 250 ms aralikla yenilenir.
  RoomPlan'in birlestirip sadelestirdigi kullanilabilir islenmis sonuc, toplam duvar
  uzunlugu azaldi diye reddedilmez. Eksik taramayi her zaman bitirme davranisi korunur.
- 0.17.10: `Taramayi Bitir` artik tam oda, zemin+duvar veya kalite onayi
  beklemeden calisir. RoomPlan'in buldugu tek bir duvar, zemin ya da nesne bile
  kismi tarama olarak saklanabilir. Henuz hic geometri yoksa tarama yine sonlanir;
  onceki kayit korunur ve kullanici kilitli bir tarama dongusunde birakilmaz.
- 0.17.9: RoomPlan artik kapali bir oda cevrimi, dort duvar, kose baglantisi,
  alti bolgeli gorus veya bekleme suresi istemez. En az bir gecerli zemin ve bir
  duvar bulundugunda taranan kisim hemen kullanilabilir; RoomPlan'in yaklas, isigi
  ac veya yavasla onerileri bitirme dugmesini kilitlemez. Duvar degistirirken gelen
  gecici bos kare son gecerli taramayi silmez. Son isleme duvar uzunlugunun %10'undan
  fazlasini kaybederse bitirme anindaki canli tarama korunur.
- 0.17.8: RoomPlan taramasi artik yalniz tahmin edilen duvar boyutuna guvenmez;
  kameranin her duvarin sol/orta/sag ve alt/ust bolgelerine gercekten baktigini
  ayri olarak izler. Dort anlamli duvar, en az 12 saniyelik gozlem ve konum/acisi
  kararlı duvarlar olmadan tarama tamamlanmaz. Taramaya girerken canli occlusion,
  scene-depth ve insan segmentasyonu sensor isleri kapatilir; ayni dunya koordinati
  korunarak RoomPlan'a temiz LiDAR/kamera butcesi birakilir. Kamera piksel tamponunu
  kilitleyen ozel isik analizi kaldirildi ve RoomPlan'in kendi yonlendirmesi kullanildi.
  Son isleme duvar sayisini, yonunu veya kose baglantisini bozarsa onaylanan canli
  sonuc korunur.
- 0.17.7: Kamera izin aciklamasi LiDAR oda taramasi ve sanal dekor kullanimi
  acikca belirtilerek yenilendi. Codemagic kaynak `Info.plist`, imzasiz `.app`,
  imzali `.xcarchive` ve son IPA icindeki gercek paket icin gizlilik anahtarlarini
  dogrular; eksik veya belirsiz metinde TestFlight yuklemesinden once build durur.
- 0.17.6: `Taramayi Bitir` aninda onaylanan canli oda korunur. Isleme sonrasi
  kose/duvar parcasi sayisinin degismesi tek basina taramayi reddettirmez.
  Gecerli zemin/duvar kaybolur veya toplam duvar uzunlugunun %10'undan fazlasi
  kaybedilirse onaylanan canli veri, acik uyari ve ayri kullanma dugmesiyle sunulur.
  Gercek RoomPlan hatalari basari sayilmaz; `Taramayi Kullan` oncesi eski kayit korunur.
- Duvar dekorlari tek ham LiDAR pikseline degil sonlu ARKit/RoomPlan duvar duzlemine
  baglanir. Eksik/dusuk guvenli derinlik kayitli duvari reddetmez; belirgin bicimde
  daha yakinda olculen on nesne arka duvar secimini engeller. Ayni fiziksel duvari
  gosteren RoomPlan/ARPlane/LiDAR kareleri birlikte kilitlenir ve temas noktasi son duzleme izduser. Kurtarmada guncel AR anchor
  donusumu korunur; mevcut hatali konumlu nesneler otomatik tasinmaz.
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
  yerel ARKit mesh'ini taze ham LiDAR derinlik geometrisiyle tamamlama
- Kettle, kumas yigini ve ust uste nesneler icin RoomPlan nesne sinifindan bagimsiz
  anlik ortme: en fazla 256 x 192 derinlik ornegi, orta/yuksek guvenli olcumler,
  on nesne-arka duvar arasini kapatmayan kenar filtresi ve 8-25 mm derinlik toleransi.
  Tek arka plan isi ve tek asenkron mesh yuklemesi; en fazla 30 Hz, isinma veya
  gecikmede dusuk cozunurluk/15 Hz. 100 ms'den eski veya kamera pozundan kopan
  yuzey kaldirilir; ARKit mesh/person ortmesi yedek olarak acik kalir.
  LiDAR cihazda kaba RoomPlan mobilya kutulari ek ortucu olarak kullanilmaz.
  Koordinat panelindeki guven yuzdesi o anki derinlik orneklerine aittir; odanin
  tamamlanma orani degildir. Bu ozellik RoomPlan'in kaydedilen semantik oda modelini
  ayrintili bir nesne taramasina donusturmez. Parlak/cam/cok koyu yuzeylerde
  sensorun olcemedigi bolgeler icin kusursuz ortme garanti edilemez.
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
- Tarama ekraninda canli zemin/duvar/nesne sayaci; hic geometri olmasa bile taramayi
  sonlandirma ve bulunan tek duvar, zemin veya nesneyi kismi sonuc olarak kullanabilme
- RoomPlan'in yerel yaklas/uzaklas, yavasla, isigi artir ve dusuk dokulu yuzey
  yonlendirmelerini Turkce gosterme; AR takip sinirliyken olcumu tamamlanmis saymama
- Her 750 ms'de 32 x 24 luma ornegiyle dusuk maliyetli karanlik/parlama denetimi;
  pencere veya dogrudan lamba kaynakli yuksek dinamik aralikta perde/isik yonu uyarisi
- RoomPlan kose/duvarlari birlestirirken gecici olarak eksilen karelerin onceki genis
  taramayi silmesini engelleyen toplam-duvar-uzunlugu yuksek-su-izi; son islenmis
  sonuc kapsamin %85'inden azini tutarsa onaylanan canli geometriyi koruma
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
- 49 Poly Haven CC0 model, iki Poly Haven duvar kaplamasi ve bir 3DTextures.me
  CC0 Backrooms kaplamasindan olusan 52 parcali gercekci 1K PBR katalog; mobilya,
  depolama, ekipman, duvar/tavan elemanlari, aydinlatma ve elektronik kategorileri
- Eski kayitlari bozmamak icin 14 Kenney USDZ ve 4 hafif dekorla geriye donuk uyumluluk
- Bundle yolu veya USDZ normalize islemi basarisiz olsa bile her semantik kategori icin
  gercek sekilli prosedurel yedek model; yerlestirme sessizce kaybolmaz
- Fotogercekci veya kullanici USDZ'si acilirken katalog olcusunde gorunur anlik yedek;
  10 saniye zaman asimi ve oturum ici model onbellegiyle sonsuz `yukleniyor` durumunu
  engelleme; dosya hazir olunca ayni dunya anchor'inda gercek modelle degisim
- Anchor edilmeden yapilan USDZ olcumunde inactive cocuklari da hesaba katma; RealityKit'in
  sifir boyut dondurup katalog modellerini mavi yedek kutuya dusurmesini engelleme
- Iki gercek deri/vintage koltuk, modern deri berjer, mermer orta sehpa, ahsap konsol
  ve saksili sukulent iceren yeni mobil dekor paketi; model basina 1K doku, 60 bin
  ucgen ve 8 MB dogrulama butcesi
- Ayni oturumda yalniz son kullanilan sekiz fotogercekci modeli tutan LRU onbellek;
  aktif sahne nesnelerini bozmadan kullanilmayan kaynak klonlarini bellekten cikarma
- Duvar kategorisindeki tugla, ahsap ve Backrooms kaplamalar tek dokunusla taranan duvarin
  genisligine, yuksekligine ve duzlemsel sinir poligonuna otomatik oturur.
  RoomPlan kapi/pencere/acikliklari ilgili duvarla eslestirilip geometriden kesilir;
  yedek gorunum ve dokunma geometrisi de bu bosluklari acik birakir.
  Kaplama duzlemi taranan duvarla aynidir; dokunma derinligi tum duvari one cekmez.
  Eski kayitli kaplamalar bu degisiklikle tasinmaz; hatali olanlar yeniden yerlestirilmelidir.
  On yuz 6 mm onde, kalan 54 mm duvarin icinde kalir. Duvar buyudukce desen uzamaz:
  tugla icin 1,5 m, ahsap icin 2 m, Backrooms icin 1,25 m tasarim karosu metre tabanli UV ile tekrar eder.
  Otomatik kaplamada olcek/dondurme kilitlidir; taranan bosluklar yerinden kaymaz.
  Duvar olcusu, poligon ve kesimler scene.json'a kaydedilir; eski moduler kaplama
  kayitlari degistirilmez. Yeni kaplama icin tamamlanmis, hizalanmis oda taramasi gerekir.
  Egri duvarlar desteklenmez; karmasik geometri butceyi asarsa kapali panel uretilmez.
  Uc kaynak USDZ sablonu dusuk maliyetlidir; otomatik
  kaplama tek mesh/materyal ve en fazla 512 disbukey parca kullanir. Geometri sadece
  yerlestirme/yukleme sirasinda uretilir. LiDAR ve insan occlusion'i acik kalir;
  taramada bulunmayan bosluklar ve sensor kaynakli kesilmeler cihazda kontrol edilmelidir.
- Ilk acilista ve yerlestirme sonrasinda kamerayi acik birakan kompakt alt kontrol dock'u
- Canli kamera ve sanal dekorlari birlikte etkileyen Dogal, Sinema, Teal & Orange,
  Noir, Gerilim, Ruya ve Backrooms Sari film filtreleri; renk, kontrast, parlaklik, ton ve vinyet
  ayarlari ReplayKit HEVC kaydina da islenir
- Nesne secilince paneli kapatan, zeminin tamamini dokunulabilir yapan yerlestirme modu
- Her katalog nesnesi icin ayri zemin, yatay yuzey, duvar veya tavan yerlestirme kurali
- Duvar kataloglari gorunur beyaz hatlara bagli kalmadan sonlu RoomPlan/ARKit/mesh
  duvarina yerlesir; olculemeyen veya duzlemle uyusmayan mevcut derinlik pikseli
  reddedilir. Derinlik akisinin tamamen yoklugunda sonlu duvar yedegi kullanilir.
  Fiziksel olcek ve duvar golgesi korunur
- Tavan/duvar/masa lambalarinda ac-kapat, 0-12000 lumen, 2000-6500 K renk
  sicakligi, -180/+180 derece yatay yon, -75/+75 derece dikey egim,
  8-90 derece huzme ve kenar yumusakligi; yeni isiklar dar 18 derece spotla baslar
- `Projektor Hedefini Sec` ile zemine, masaya veya duvara dokunup SpotLight'i tam
  dunya koordinatina yoneltme; hedef secilmeden gercek yuzeye yapay iz cizilmez.
  Hedef secildiginde iz en fazla 1,2 metre yaricapli, dusuk opaklikli ve egik
  yuzeyde sinirli elips olarak gosterilir; boylece LiDAR yuzeyinde katı beyaz leke
  ve parcalanma olusmaz
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
   zemin ve yeterli duvar kapsama alani gorulmeden `Taramayi Bitir` etkinlesmez.
   Sari kalite satiri parlama, karanlik, hizli hareket, dusuk dokulu yuzey, eksik
   duvar kosesi veya degismeye devam eden olcuyu bildirir. Pencere/lambayi dogrudan
   kadraja almak yerine isigi arkaya alip duvarin iki ucunu ve komsu kosesini capraz
   acidan tarayin; kalite satiri yesile donunce taramayi bitirin.
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
   `Hazir 3B Nesne Kutuphanesi` icindeki 52 fotogercekci parcadan
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
   gercek kamera pikseli yeniden isiklandirilmaz. Hedef secildiginde LiDAR yuzeyine
   oturan kucuk ve dusuk opaklikli projektor onizlemesi ayni hedefi gosterir; hedef
   secilmediyse kamerada yapay beyaz yuzey cizilmez.
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
SynapMantis izni kontrol edilir.

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

Bu surumde Poly Haven'dan alinmis 49 CC0 model, iki Poly Haven duvar paneli ve
3DTextures.me kaynakli bir CC0 Backrooms paneli olmak uzere 52 adet 1K PBR katalog
varligi vardir. Yasu'nun CC BY 4.0 Backrooms paketindeki dokuz duvar, dort tavan ve
bir hali malzemesi Ozel AR tarafinda renderer sablonu olarak kullanilir.
Modeller kullanici tarafindan kategorili kutuphaneden secilir, gercekci metre
boyutlarina normalize edilir, sahne listesinde `genislik x yukseklik x derinlik`
olarak gosterilir ve olculmus katalog modellerinin olcegi kilitlenir. Eski projeler icin
Kenney Furniture Kit'ten 14 CC0 USDZ ve 4 hafif dekor kaynakta korunur.
Kaynak/lisans `CineAR/RoomAssets/LICENSE-POLYHAVEN.txt` ve
`CineAR/RoomAssets/LICENSE-KENNEY.txt`, `CineAR/RoomAssets/LICENSE-BACKROOMS.txt`,
tekrar uretim/dogrulama araclari `Tools/`
altindadir. 1K doku siniri mobil bellek ve yukleme gecikmesini kontrol altinda tutar;
2K/4K masaustu VFX paketi hedeflenmemistir. Eski opak oda tema renderer'i kaynakta deneysel
olarak korunur; ana arayuzde onun yerine akici `Gercek` / `Beyaz Hatlar` gecisi vardir.
Kamera goruntusundeki gercek mobilyayi yapay
zekayla silip arka plani tamamlama (video inpainting) bu surumde yoktur; sanal
yuzeyler, RoomPlan mobilya derinlik vekilleri ve derinlik/insan occlusion'i kullanilir.

Ayrintili kabul kriterleri icin `Docs/DEVICE_TEST.md` dosyasina bakin.

### Duvar kaplamalarini yeniden uretme

`Tools/fetch_wall_textures.ps1` resmi Poly Haven 1K dokularini MD5 kontroluyle
indirir (Powered by Poly Haven: https://polyhaven.com). Blender 4.5+ ile:

```powershell
powershell -ExecutionPolicy Bypass -File Tools/fetch_wall_textures.ps1
blender --background --factory-startup --python-exit-code 1 --python Tools/generate_wall_assets.py -- .asset-cache/wall-textures CineAR/RoomAssets
blender --background --factory-startup --python-exit-code 1 --python Tools/validate_usdz_assets.py -- CineAR/RoomAssets wall_cladding_brick wall_cladding_wood
```

USDZ dosyalari yeniden uretildiginde `MANIFEST.sha256` ozetleri de yenilenmelidir.

### Ozel AR mimari varliklarini yeniden uretme

Modern tavan lambasi, Backrooms floresani, dort asili sanat cercevesi ve yedi yeni
gercekci dekor Poly Haven'in resmi 1K native USD paketlerinden alinir. Indirilen ana
sahne ve tum dokular API MD5 degerleriyle dogrulanir. Ilk komut dogrulanmis Y-up
kaynagi hazirlar; ikinci komut MaterialX aglarini RealityKit uyumlu tek
`UsdPreviewSurface` agina cevirip mobil USDZ'yi uretir:

```sh
python3 -m pip install usd-core==26.8
python3 Tools/package_polyhaven_usd_to_usdz.py --cache .asset-cache/polyhaven-usd --output CineAR/RoomAssets
blender --background --factory-startup --python-exit-code 1 --python Tools/convert_polyhaven_native_usd_to_usdz.py -- .asset-cache/polyhaven-usd CineAR/RoomAssets
```

Backrooms PBR sablonlari, resmi kaynak paketleri `.asset-cache/backrooms-materials`
altindayken OpenUSD ve ImageMagick ile yeniden uretilebilir:

```powershell
$env:PYTHONPATH = (Resolve-Path '.tools-cache/usd-core').Path
python Tools/generate_backrooms_material_assets.py --source .asset-cache/backrooms-materials --output CineAR/RoomAssets
powershell -ExecutionPolicy Bypass -File Tools/update_asset_manifest.ps1
```

Her yeni mimari model icin 8 MiB kesin paket siniri vardir. Uygulama calisirken
indirme yapmaz; tum modeller kaynakta ve uretilen uygulamada checksum ile dogrulanir.

### Otomatik duvar kaplama testleri

`WallCladdingGeometry.swift` oda poligonunu ucgenleyip acikliklari cikarir;
kesimler arasinda ortak metre tabanli doku koordinatlari kullanir. Hesaplama
testleri kapilar, pencereler, ust uste binen acikliklar, ters duvar yonu, icbukey
ve egimli sinirlar, kaydet/yukle ve doku tekrarini kapsar. Swift kurulu bir ortamda:

```sh
swiftc -D WALL_GEOMETRY_TESTS CineAR/WallCladdingGeometry.swift Tools/test_wall_cladding_geometry.swift -o /tmp/cinear-wall-tests
/tmp/cinear-wall-tests
```

Codemagic ayni testi IPA derlemesinden once calistirir. Bu test RoomPlan/RealityKit
cihaz dogrulamasinin yerini almaz; cihaz adimlari `Docs/DEVICE_TEST.md` icindedir.

### Cevrimdisi 3B katalog testi

Hazir modeller uygulama paketinin icindedir ve PC ya da ag baglantisi kullanmaz.
Kaynak katalog adlarini, 80 USDZ checksum'ini ve paket butunlugunu yerelde denetlemek icin:

```sh
python3 Tools/test_bundled_assets.py --assets CineAR/RoomAssets --manifest CineAR/RoomAssets/MANIFEST.sha256 --prop-kind CineAR/PropKind.swift
```
