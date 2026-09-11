# CineAR cihaz kabul testi

## Hedef donanim

- LiDAR destekli iPhone Pro
- Tripod ve elde kullanim
- Dokulu, iyi aydinlatilmis en az 4 x 4 metre test alani
- On, orta ve arka planda gercek nesneler

## Fonksiyon testi

1. Uygulama acilir acilmaz alt panelde `Odayi Tara` dugmesinin gorundugunu dogrula.
   Odayi RoomPlan ile tamamen tara; `room.json` olustugunu ve `Taramayi Bitir`
   sonrasinda uygulamanin kapanmadigini dogrula.
   Canli sayacta zemin, duvar ve nesne adetleri artmali; zemin veya duvar sifirken
   `Taramayi Bitir` pasif kalmali. Tek, kisa bir duvar parcasi bulundugunda da dugme
   pasif kalmali; en az dort anlamli duvar, komsu duvar yonleri, birbirine baglanan
   kose cevrimi ve en az 12 saniyelik kararlilasma suresi tamamlanmalidir. Her
   duvarin sol/orta/sag ve alt/ust bolgelerine gercekten bakilmadan kalite satiri
   yesil olmamali; `Gercek gorus` yuzdesi ve `Dogrulanan duvar 0/4...4/4`
   ilerlemesi gorunmelidir.
   Tarama acilirken RoomPlan baslamadan once dunya takibinin hazirlanmasini bekledigini
   ve `World tracking failure` ham hata metninin gorunmedigini kontrol et. Takibi
   bilerek zayiflatip `Tekrar Tara`ya basinca paylasilan AR oturumu yeniden calismali.
2. Tarama sirasinda yalniz RoomPlan'in beyaz/seffaf kilavuzlarinin gorundugunu;
   tarama onayindan sonra opak duvar, zemin veya mobilya kaplamasi olusmadigini dogrula.
3. Tarama boyunca kamera hareketinin akici oldugunu, ana gorunume donuste gercek
   insanlarin ve mobilyalarin tamamen gorunur kaldigini kontrol et.
   Ana gorunume dondukten sonra AR durumu en gec 10 saniye icinde hazir olmali;
   yeni bir tracking callback'i gelmese de kutuphane ve yerlestirme kullanilabilmeli.
   Karanlik odada RoomPlan `isigi artir`, duz ve dokusuz duvarda `dusuk dokulu yuzey`,
   hizli kamera hareketinde `yavasla` yonlendirmesi Turkce gorunmeli. Uygulama tarama
   sirasinda kamera piksel tamponunu ayri bir isik analizi icin kilitlememeli; pencere
   veya guclu lambadan gecerken kamera onizlemesinde gozle gorulur kare dusmesi olmamali.
4. `Beyaz Hatlar`i ac; duvar, zemin, kapi/pencere ve taninan buyuk objelerin yalniz
   ince seffaf hatlarla gorundugunu, kameranin kapanmadigini ve `Gercek` secilince
   butun hatlarin kayboldugunu dogrula.
5. Kasa'yi sec. Alt panel otomatik kapanmali; once zeminin panelin daha once kapattigi
   alt bolgesine, sonra orta ve uzak bolgesine dokun. Parmak hareket ederken hedef
   dokunulan noktayi izlemeli; takip/derinlik beklerken sari, masa veya koltuk gibi
   zemin olmayan yatay yuzeyde kirmizi, dogrulanmis zeminde yesil olmali. Yesil
   durumda kaynak ve metre cinsinden derinlik gorunmeli. Her zemin dokunusunda kasa gorunmeli.
   Ayni testi once `Gercek`, sonra `Beyaz Hatlar` modunda tekrarla.
6. 38 parcalik gercekci kutuphanenin Mobilya, Depolama, Ekipman, Dekor, Duvar, Isik ve
   Elektronik bolumlerini ac. Her bolumden en az iki model yerlestir; 1K PBR dokular
   gorunmeli, boyutlar gercekci olmali ve modeller yuzeyin altina gomulmemeli.
   Dokunustan hemen sonra katalog boyutunda yedek geometri gorunmeli; USDZ acilinca
   ayni konumda gercek modelle degismeli. Tek bir bozuk USDZ sahneyi tamamen gorunmez
   birakmamali; yedek model ve acik hata mesaji kalmali.
   Gecerli modellerde `olcusu okunamadi` mesaji ve katalog boyutunda mavi kutu
   kalmamali; sahneye henuz anchor edilmemis USDZ hiyerarsisi da olculebilmeli.
   Yerlesimden sonra buyuk panel yerine dort dugmeli kompakt dock gorunmeli.
   Deri Koltuk, Vintage Chester Koltuk, Modern Deri Berjer, Mermer Orta Sehpa,
   Modern Ahsap Konsol ve Saksili Sukulent modellerini sirayla ac. Yukleme sirasinda
   kamera takilmamali; dokuzdan fazla farkli gercekci model acildiginda eski onbellek
   girdileri atilmali, sahneye yerlestirilmis nesneler ise gorunur kalmali.
   Kapi ve pencereli bir odayi tara. `Tugla Duvar Kaplama` ve `Ahsap Duvar Kaplama`
   icin duvarin farkli noktalarina dokun; her seferinde ayni duvarin tum olcusune
   oturmali, kapi/pencere/acikliklar hem yukleme yedeginde hem son malzemede acik
   kalmali. Baska duvarin acikligi yanlis kesilmemeli; dogrudan pencere veya acik
   kapiya dokunmak o boslugun onune kaplama yerlestirmemeli.
   6 cm govdenin 54 mm'si duvarin icinde, on yuz 6 mm onde olmali. Yedek modelden
   USDZ materyaline geciste boyut/konum veya kesimler degismemeli.
   2 m ve 4 m genisligindeki iki duvari kapla: tugla/ahsap desenlerinin metre olcusu
   ayni kalmali, genis duvarda daha fazla tekrar gorunmeli; kesimlerde desen atlamamali.
   Kaplamayi sec; olcek dugmeleri kapali olmali, dondurme kaplamayi cevirmemeli.
   Kaydet, kapat/ac ve relocalization sonrasi olculer, kesimler ve materyal korunmali.
   Eski kayitli moduler kaplamanin eski transformuyla yuklendigini de kontrol et.
   Taramasiz veya egri duvarda anlamli uyari gorunmeli. Capraz/egimli ust sinirda
   poligon disina tasma olmamali; cok karmasik/bozuk veride kati dikdortgen yedek
   cizilmemeli. Beyaz Hatlar acik/kapali ve duvarin iki yonunde secimi dene.
   Duvar onunden bir kisi gecsin, onune sandalye koy: kisi/mobilya kaplamanin
   onunde kalmali. Acili gorus, farkli isik ve puruzlu duvarda kesilme/titreme,
   FPS ve isinmayi kaydet. 6 mm pay sensor gurultusune karsi garanti degildir.
   Taramada hic algilanmayan bir pencere otomatik kesilemez; eksik tarama varsa
   yeniden tara. Eski Duvar ve Ankesorlu Telefon
   modellerinin onceki duvar-onu yerlestirmesini korudugunu da kontrol et.
7. Zemin nesnesini zemine, dizustu bilgisayari masa tablasina, kamerayi duvara ve
   kafesli armaturu tavana yerlestir. Yanlis yuzey turundeki ilk carpismayi atlayip
   dogru yuzeyi buldugunu; RoomPlan kaydindan sonra uzak zemin ve tavan noktalarinda
   kayitli duzlem yedeginin calistigini dogrula. Beyaz Hatlar kapaliyken de kayitli
   sonlu duvara ve kalibre edilmis tavana yerlestirme yapilabilmeli. Zemin nesnesi seciliyken masa
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
   gorunur noktasi zeminden 0-5 mm yukarida olmali. Nesneyi secip boyut panelini
   yuzde 25, 50, 100, 200 ve 300 konumlarinda dene; eksi/arti ve `1:1` dugmeleri de
   ayni degeri vermeli. Her olcekte taban zemine sabit kalmali, havaya kalkmamali veya
   zemine gomulmemeli. Kaydet/yukle sonrasinda yuzde degeri ve fiziksel boyut korunmali.
   `Film & Golge` ekraninda alti filtrenin her birini sec; kamera ve sanal nesneler
   birlikte degismeli, arayuz renkleri degismemeli. Temas golgesini yuzde 0, 100 ve
   200'de dene; HEVC kaydinda secilen filtre gorunmeli. Mekani kaydedip yukleyince
   filtre ve golge gucu geri gelmeli.
11. Model uzerinde surukleme yapildiginda dunya konumu degismemeli; dondurme ve
   boyut paneli calismali. Katalog nesnesinde yanlislikla pinch boyutu bozmamali;
   kullanicinin ekledigi ozel USDZ'de pinch olceklendirme de calismali. Donus/olcek
   sonrasinda projeyi kaydet.
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
15. PC'de `AIService/run_server.ps1` calistir. Terminalde `CineAR Bonjour: advertising`
    satirinin guncel yerel IP'yi gosterdigini dogrula. `AI Derinlik` ekranini ac;
    `Adres kaynagi` once `PC araniyor`, ardindan `Otomatik bulundu` olmali ve terminaldeki
    IP elle yazilmadan etkin adrese gelmeli. Basarili test AI anahtarini otomatik acmali.
    PC servisi acikken farkli Wi-Fi/hotspot'a gec; terminalde Bonjour yayininin en gec
    5 saniye icinde yeni IP ile tekrarlandigini ve uygulamadaki `PC'yi otomatik bul`
    ile yeni DHCP adresinin alindigini dogrula. Bonjour engellenmis
    bir agda elle adres girisinin yedek olarak calistigini da kontrol et. Durumun
    once `Aktif` veya `PC bagli - LiDAR karesi bekleniyor`, scene depth geldiginde
    `Aktif` oldugunu; gecikmenin ve SAM maske
    sayisinin sifirdan buyuk oldugunu dogrula. Masa kenari ile on/arka insan testini
    tekrar et; AI kapaliyken ve acikken video kaydi alip kenar hatasini karsilastir.
    Sunucu acikken `benchmark_server.py` testinin ilk istek dahil 350 ms sinirini
    gecmesini dogrula. Bu siniri asan sonuc sahneye uygulanmamali; uygulama yerel
    LiDAR/person-depth occlusion'ina geri donmeli.
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
    konumunda yeniden baslamali. Duvarin onundeki mobilyaya veya henüz taranmamis bos
    alana dokunuldugunda efekt yerlestirilmemeli; hedef ancak sonlu duvar ile LiDAR
    derinligi ayni noktayi gosterdiginde yesile donmeli.
19. `Avucta Canli Elma`yi ac; acik avucu kameraya goster ve eli on/arka/yana hareket
    ettir. Elma LiDAR derinliginde avucu izlemeli, ani olcumlerde sicrama yapmamali ve
    el 0.42 saniyeden uzun kaybolursa gizlenmeli. Portre ve yatay yonlerde avuc yerine
    ekranin baska bolgesine gitmemeli; 30 cm'den buyuk tek karelik derinlik sicramasi
    elmayi tasimamali. `Elimde elma olsun`, `elmayi kaldir` ve `kan selalesi aksin`
    komutlarini Turkce test et; ilk kullanimda iki izin istemi gorunmeli, reddedilen
    izin icin Ayarlar kisayolu ve anlasilir hata metni cikmali, dugme yedegi de calismali.
20. Uygulamayi arka plana alip geri getir; AR takibi normale donmeli ve manuel
    objeler yerinde kalmali. Gecici AR hatasinda otomatik yeniden baslatma mesaji
    gorulmeli ve `Oda Tara` yalniz takip yeniden hazir oldugunda etkinlesmeli.
    Anchor gecici kaldirilirsa nesne/armatur silinmemeli; canli anchor geri gelmezse
    son dunya donusumunde otomatik yeniden baglanmali. Kesintiden once `Beyaz Hatlar`
    aciksa takip duzelince hatlar tekrar gorunmeli.
21. Tripodda 10 dakika, elde 5 dakika kesintisiz HEVC kayit al.
22. MOV dosyasinda kare dusmesi, ses senkronu ve cihaz isinmasini kontrol et.
23. PC AI kapaliyken `Koordinat` panelini ac. `Telefonla Zemin Y97`ye bas, telefonu
    ekrani zemine ve arka kamerasi tavana bakacak sekilde bir saniye sabit birak.
    Zemin `Y 97.00` olmali; telefonu kaldirinca kamera katmani fiziksel yukseklik kadar
    artmali. `Tavani Olc` ile merkez artiyi bos tavana tut; tavan katmani eksi 97 ile
    gosterilen oda yuksekligi metre olcumuyle 3 cm icinde uyusmali. Uygulamayi kaydet,
    kapat ve dunya haritasini yukle; zemin/tavan katmanlari ayni kalmali. 25 cm grid'in
    zemine sabit kaldigini, X/Z degerlerinin `X/Z Sifirla` sonrasinda sifira yaklastigini
    ve metreyle kontrol edilen 1 m referans uzunlugunda hatanin 2 cm'den az oldugunu dogrula.
    Merkez noktayi masa uzerine getirince durum kirmizi olup `ondeki nesne zemini
    kapatiyor` demeli; zemin karari PC baglantisindan etkilenmemeli.
24. PC AI acikken `Kasa` sec. Yerlesim boyunca AI durumu beklemede olmali; zemine
    dokununca kasa dunya sifirindan veya kameradan kayarak gelmemeli, yalnizca AR
    anchor kesinlestigi nihai noktada gorunmeli. PC yaniti 350 ms'yi asarsa yerel
    LiDAR'a donmeli; kasa titrememeli, kaybolmamali ve alt/ust yarisi kesilmemeli.
    Varsayilan PC `/health` cevabinda `sam_enabled:false`, `depth_input_size:322` ve
    sifirdan buyuk `warmup_milliseconds` gorulmeli.
25. `Kontroller > Guncelleme`ye bas. Internet varken denetim sekiz saniye icinde
    sonuc vermeli. TestFlight yapisinda `TestFlight'i Ac`, yayindaki App Store
    surumunden eski bir build'de `Guncelle`, en yeni surumde `CineAR guncel`
    gorunmeli. Internet kapaliyken uygulama acilmaya devam etmeli ve manuel kontrolde
    anlasilir hata mesaji cikmali.
26. Ankesorlu telefon gibi bir duvar katalog nesnesini yaklasik 1 metre mesafeden
    taranmis duvara yerlestir. Kamerayla 1-4 metre arasinda yana yururken arka yuzun
    duvardan ayrilmadigini, fiziksel olcegin degismedigini ve temas golgesinin duvar
    uzerinde kaldigini dogrula. Sonsuz duzlem veya farkli derinlikteki duvar kabul
    edilmemeli. LiDAR pikseli varsa sonlu duvarla uyusmali; gecici derinlik karesi
    yokken kayitli RoomPlan/ARKit duvari yine yesil olup dokunulabilmeli.
27. Sahne listesindeki katalog modellerinin `genislik x yukseklik x derinlik` metre
    degerlerini fiziksel referansla karsilastir. Pinch hareketi olculmus katalog
    modellerini buyutup kucultmemeli. Zemin ve duvar temas golgelerinde sert tek bir
    leke yerine yumusak ic/dis katman gorulmeli; ortam aydinligi degistiginde golge
    yogunlugu ani sicrama yapmadan uyarlanmali.
28. RoomPlan taramasindan once bilerek 10-15 cm hatali telefon zemin/tavan kalibrasyonu
    olustur, sonra odayi tam tara. Tarama bitince RoomPlan kotlari hatali tek-poz olcumu
    duzeltmeli ve zemin `Y 97.00` kalmali. Model secip telefonu hedefte sabit tut;
    `Doğrulandı` yesil olmadan dokunma kabul edilmemeli. Ayni USDZ'yi ikinci kez
    yerlestirmek onbellekten hizli acilmali; bozuk model 10 saniye sonunda yedek modele
    gecip `yukleniyor`da kalmamali. Bir kisi nesnenin onunden yururken yerel person-depth
    kisiyi onde tutmali; 350 ms'den gec PC derinligi goruntuye uygulanmamali. Tavan
    armaturu dolap veya yuksek raf ustune degil, yalniz siniflandirilmis ya da kalibre
    edilmis gercek tavan kotuna yerlestirilebilmeli.

## Anlik LiDAR ortmesi regresyonu

Bu kontroller gercek LiDAR iPhone'da yapilmalidir; Swift geometri testleri kamera,
RealityKit derinlik testi ve termal performans yerine gecmez.

1. Duvara sanal saat koy; mat bir kettle veya kutuyu gercekte onune yerlestir.
   Telefonla saga/sola egil: saat yalniz gorus hattinda kalan kisimlarda gorunmeli,
   tamamen kapandigi acida hic gorunmemeli. Ardindan gercek nesneyi hareket ettir;
   eski konumunda kalici gorunmez delik kalmamali. Parlak kettle ile de tekrar et,
   dusuk guvenli yuzeylerdeki sensor kayiplarini ayri kaydet.
2. Kumas yigini ve uzerinde kutu bulunan masanin arkasina sanal nesne yerlestir.
   Ortme RoomPlan'in dikdortgen mobilya kutusuna degil olculen gorunen yuzeye
   uymali; kutu-duvar arasindaki bosluk ucgenle kapatilmamali. RoomPlan kaydinda
   ayrintili kumas geometrisi beklenmez; bu test canli goruntu icindir.
3. Ayni testi dikey/yatay telefon yonunde, yaklasip uzaklasarak, HEVC kaydi sirasinda,
   oda taramasindan donuste ve kayitli projeyi yukledikten sonra tekrarla.
   Kayitta da on/arka sirasi korunmali. Arka plana al, geri don, takibi gecici kaybet:
   eski derinlik yuzu sabit bir maske gibi goruntude kalmamali.
4. Koordinat panelindeki anlik LiDAR durumunu izle. Gorunen yuzde tum oda taramasinin
   tamamlanma orani degil gecerli anlik ornek oranidir. Cihaz isindiginda veya
   hesaplama geciktiginde kalite/hiz azalabilir; kritik termalde ARKit yedegi
   kullanilir. Instruments ile 10 dakikalik kayitta CPU/GPU, bellek ve kare zamanini
   olc; yeni yolun kuyruk biriktirmedigini ve hedef 30 fps'i dogrula.
5. Eski hatali duvar kaplamasini silip yeniden yerlestir. Duvarin onundeki dolaba
   dokunmak tum duvari one cekmemeli; yeni panel duvar duzlemine yakin kalmali.

Otomatik geometri testleri (Mac/Swift):

```sh
swiftc CineAR/LiveDepthGeometry.swift Tools/test_live_depth_geometry.swift -o /tmp/cinear-depth-tests
/tmp/cinear-depth-tests
```

Testler duz/egri yuzey, derinlik kopuklugu, eksik kose, guven degeri, gecersiz
olcum, bellek ornek butcesi ve eski kare reddini kapsar; Codemagic'e de eklenmistir.

## Baslangic kabul esikleri

0.17.10 ek regresyonlari (ozellikle iPhone 15 Pro Max):

- Tarama calismaya baslar baslamaz, hicbir yuzey henuz bulunmamis olsa dahi
  `Taramayi Bitir` etkin olmali ve dokununca tarama ekrani sonlandirilmalidir.
  Kaydedilebilir geometri yoksa onceki kayit korunarak acik hata gosterilmelidir.
- Yalnizca tek duvari veya zeminin bir bolumunu tara. Kapali oda/kose baglantisi
  olmadan bitirilebilmeli ve bulunan tek yuzey `room.json` icinde korunmalidir.
- Birinci duvardan ikinci duvara donerken RoomPlan gecici olarak duvar sayisini
  azaltirsa bitirme dugmesi yeniden kilitlenmemeli. `yaklas`, `uzaklas`, `yavasla`
  ve `isigi ac` onerileri gorunebilir ancak daha once taranan kismi gecersiz kilmamali.
- Tarama yesilken bitir. Son isleme gecerli zemin/duvari veya canli duvar
  uzunlugunun %10'undan fazlasini kaybederse `Onaylanan Canli Taramayi Kullan`
  sunulmali; aksi durumda islenmis sonuc kullanilabilmeli.
  Kullan/iptal yollarini, art arda taramalari, gercek RoomPlan hatasini ve isleme
  sirasinda kapatmayi dene; onceki oda kullanici kabul etmeden degismemeli.
- Hatali eski kaplamayi sil, yeni taramada bos duvara tek dokunusla yeniden koy.
  0.7, 1.5 ve 3 metreye uzaklas, saga/sola yuru: panelin kose ve kapi kesimleri
  fiziksel duvarla hizada kalmali. Saat/telefonun arka yuzu duvara 3 mm toleransla
  oturmali. Olcum kamera mesafesine bagli buyuyen bir bosluk gostermemeli.
- Duvar onundeki kettle/dolap kenarina dokun: karisik veya guvensiz olcumde
  yerlestirme reddedilmeli, arka duvarin derinligiyle hayali bir on yuz uretilmemeli.
  Iki farkli yuzeye hizlica cevirirken tek dokunus iki nesne olusturmamali.
- Arka plana al/geri don, kaydet/yukle ve tekrar tara; anchor kurtarmasi eski
  yerlestirme pozuna sicrama yapmamali. Takip kaymasini ve ortme kaynakli gorunurluk
  degisimini ayri kaydet. Gercek cihaz dogrulamasi olmadan kayma tamamen giderildi
  kabul edilmemeli.

```sh
swiftc CineAR/SpatialValidation.swift Tools/test_spatial_validation.swift -o /tmp/cinear-spatial-tests
/tmp/cinear-spatial-tests
```

- Tripod konum kaymasi: 10 dakikada 2 cm'den az
- Elde relocalization hatasi: 5 cm'den az
- Manuel dekor anchor'i ile dokunulan gercek yuzey hizasi: referans noktalarda 2 cm'den az
- Modelin gercek alt siniri ile zemin arasindaki dikey bosluk: 5 mm'den az
- Duvar modelinin gercek arka siniri ile duvar arasindaki bosluk: 1 cm'den az
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
