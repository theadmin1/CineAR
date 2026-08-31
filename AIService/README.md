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
yazilan `http://192.168...:8765` adresini CineAR icindeki `AI Derinlik` ayarina girin.
iPhone ve PC ayni yerel agda olmalidir.

Hotspot veya Wi-Fi degistiginde IP adresi de degisir. `run_server.ps1`, varsayilan ag
gecidi bulunan etkin Wi-Fi/Ethernet baglantisini secer; VMware/VirtualBox gibi sanal
adaptorlere ait adresleri iPhone adresi olarak gostermez. Betigi yeniden baslatin ve
ekranda yazan yeni adresi uygulamadaki `AI Derinlik` alanina girin.

PC'de saglik adresi calisip iPhone baglanamiyorsa iPhone Safari'de konsolda yazan
adresin sonuna `/health` ekleyerek acin. Safari de acamiyorsa Wi-Fi istemci yalitimi
ve Windows Guvenlik Duvari kontrol edilmelidir. Safari aciyor fakat CineAR acamiyorsa
iPhone Ayarlarinda CineAR icin `Yerel Ag` izni etkinlestirilmelidir.

Bu bilgisayardaki RTX 3050 Laptop GPU 4 GB icin varsayilan modeller bilerek
`Depth-Anything-V2-Small` ve `sam2.1-hiera-tiny` secilmistir. Daha buyuk modeller
gecikmeyi ve bellek tasmasi riskini ciddi bicimde artirir.

27 Agustos 2026 yerel dogrulamasinda RTX 3050 ilk isitma istegini 1847 ms,
ikinci istegi 682 ms'de tamamladi; SAM 2 dokuz maske uretti ve yapay LiDAR
boslugunun %100'u metreye kalibre edilmis Depth Anything sonucu ile doldu.
iPhone istemcisi 1500 ms'yi asan sonucu eski hareketli insan geometrisi
uretmemek icin reddeder ve ARKit occlusion'a geri doner.

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
