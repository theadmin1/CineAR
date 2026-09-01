# CineAR PC AI Derinlik Servisi

Bu servis iPhone'un kamera karesini ve ARKit LiDAR derinligini ayni Wi-Fi uzerinden
alir. Depth Anything V2 Small ile yogun derinlik uretir, SAM 2.1 Tiny maskelerini
nesne siniri olarak kullanir ve sonucu LiDAR metreleriyle kalibre ederek telefona
geri yollar. RealityKit dunya takibi ve anchor'lar telefonda kalir.

## Windows kurulumu

PowerShell'de depo kokunden:

```powershell
powershell -ExecutionPolicy Bypass -File .\AIService\setup_windows.ps1
powershell -ExecutionPolicy Bypass -File .\AIService\run_server.ps1
```

Ilk kurulum ve ilk servis acilisi PyTorch ile model agirliklarini indirir. Windows
Guvenlik Duvari sorarsa Python icin yalnizca `Ozel aglar` erisimini acin. Konsolda
yazilan `http://192.168...:8765` adresi Bonjour ile yerel aga yayinlanir; CineAR
`AI Derinlik` ekrani acildiginda PC'yi bulur, `/health` ile dogrular ve adresi kendi
gunceller. iPhone ve PC ayni yerel agda olmalidir.

Hotspot veya Wi-Fi degistiginde IP adresi de degisir. `run_server.ps1`, varsayilan ag
gecidi bulunan etkin Wi-Fi/Ethernet baglantisini secer; VMware/VirtualBox gibi sanal
adaptorlere ait adresleri iPhone adresi olarak gostermez. Sunucu acikken ag degisirse
varsayilan rota 5 saniyede bir kontrol edilir, Bonjour yeni IP ile yeniden yayinlanir
ve CineAR yeni adresi otomatik alir. Bonjour engellenirse terminaldeki adres elle
girilebilir ve kayitli son adres yedek kalir.

Eski `.venv` kurulumunda `zeroconf` yoksa `run_server.ps1` yalniz bu kucuk
bagimliligi ilk acilista kurar; CUDA, PyTorch ve model dosyalari yeniden indirilmez.

PC'de saglik adresi calisip iPhone baglanamiyorsa iPhone Safari'de konsolda yazan
adresin sonuna `/health` ekleyerek acin. Safari de acamiyorsa Wi-Fi istemci yalitimi
ve Windows Guvenlik Duvari kontrol edilmelidir. Safari aciyor fakat CineAR acamiyorsa
iPhone Ayarlarinda CineAR icin `Yerel Ag` izni etkinlestirilmelidir.

Basarili otomatik yayinda terminalde su satir da gorunur:

```text
CineAR Bonjour: advertising http://192.168.x.x:8765
```

Bu bilgisayardaki RTX 3050 Laptop GPU 4 GB icin varsayilan modeller bilerek
`Depth-Anything-V2-Small` ve `sam2.1-hiera-tiny` secilmistir. Daha buyuk modeller
gecikmeyi ve bellek tasmasi riskini ciddi bicimde artirir.

Varsayilan dengeli profil SAM 2 otomatik maske izgara yogunlugunu `6`, giris kenarini
`448 px` kullanir; iPhone kamera karesi `512 px / JPEG %62` olarak gonderilir. LiDAR
metreleri tam cozunurlukte kalir. Kalite denemesi icin sunucuyu baslatmadan once
`CINEAR_SAM_POINTS=8` ve `CINEAR_SAM_MAX_SIDE=512` ayarlanabilir, ancak RTX 3050'de
gecikme ve VRAM kullanimi belirgin bicimde artar.

1 Eylul 2026'da gonderilen gercek oda karesinde dengeli `6/448` profil ilk
istegi 1315 ms, isinmis istekleri 320 ve 298 ms'de tamamladi; her karede 6
gecerli nesne maskesi uretti.

iPhone istemcisi yerlesim modundayken uzak mesh'i durdurur. Toplam gecikmesi
1200 ms'yi asan veya guncel kameradan 18 cm/12 derece uzaklasmis sonuc ekrana
cizilmez; uygulama o karelerde cihazdaki LiDAR occlusion'ina geri doner.

27 Agustos 2026 yerel dogrulamasinda RTX 3050 ilk isitma istegini 1847 ms,
ikinci istegi 682 ms'de tamamladi; SAM 2 dokuz maske uretti ve yapay LiDAR
boslugunun %100'u metreye kalibre edilmis Depth Anything sonucu ile doldu.
Bu, onceki yuksek kaliteli `8/512` profilinin karsilastirma sonucudur.

Saglik kontrolu:

```powershell
Invoke-RestMethod http://127.0.0.1:8765/health
```

## Lisans

- Meta SAM 2 kodu ve agirliklari: Apache-2.0
- Depth Anything V2 Small: Apache-2.0
- Depth Anything V2 Base/Large/Giant: CC-BY-NC-4.0; ticari CineAR paketinde kullanilmaz

Model agirliklari Git deposuna veya iOS uygulamasina eklenmez; kurulum sirasinda
resmi Hugging Face depolarindan PC onbellegine indirilir.
