# CineAR Codemagic ve TestFlight kurulumu

Bu depo, `cinear-testflight` is akisi ile Release `.xcarchive` ve imzali `.ipa`
uretir; basarili IPA'yi App Store Connect'e yukler ve `CineAR Internal Testers`
grubuna TestFlight dagitimi ister. Is akisi manuel baslatilir; depoya her kod
gonderildiginde kendiliginden yayin yapmaz.

## Apple tarafinda bir kez yapilacaklar

Bu adimlari Apple Developer Program uyesi olan hesap sahibi veya gerekli
yetkilere sahip ekip uyesi yapmalidir.

1. Apple Developer > Certificates, Identifiers & Profiles > Identifiers
   bolumunde Explicit App ID olusturun. Bundle ID tam olarak
   `com.cinear.virtualproduction` olmalidir.
2. App Store Connect > Apps > `+` > New App ile CineAR kaydi olusturun ve ayni
   Bundle ID'yi secin. SKU serbesttir; ornegin `CINEAR-IOS-001`.
3. App Store Connect > Users and Access > Integrations > App Store Connect API
   bolumunde `App Manager` yetkili ayri bir API key olusturun. `.p8` dosyasini
   hemen indirin; Apple bu dosyanin yalnizca bir kez indirilmesine izin verir.
   Issuer ID ve Key ID degerlerini not edin.
4. CineAR uygulamasinda TestFlight > Internal Testing altinda adi tam olarak
   `CineAR Internal Testers` olan bir grup olusturun ve test edecek App Store
   Connect kullanicilarini ekleyin.
5. App Store Connect > CineAR > General > App Information altindaki sayisal
   Apple ID'yi not edin. Bu deger Bundle ID degildir.

## Dagitim sertifikasi icin ozel anahtar

Codemagic'in Apple Distribution sertifikasini bulabilmesi veya olusturabilmesi
icin sifresiz 2048-bit RSA private key gerekir. Mevcut dagitim sertifikasinin
private key'i yoksa yeni bir tane olusturun:

```sh
ssh-keygen -t rsa -b 2048 -m PEM -f ios_distribution_private_key -q -N ""
```

`ios_distribution_private_key.pub` kullanilmaz. `ios_distribution_private_key`
dosyasinin `BEGIN RSA PRIVATE KEY` ile `END RSA PRIVATE KEY` dahil tum icerigi
Codemagic'e eklenecektir. Bu anahtari Git'e veya mesajlasma uygulamasina
yuklemeyin.

## Codemagic UI degisken gruplari

Codemagic'te Git deposunu ekledikten sonra App settings > Environment variables
altinda su iki grubu olusturun.

### `appstore_credentials`

Asagidaki dort degiskenin her birinde `Secret` secili olmalidir:

| Degisken | Deger |
| --- | --- |
| `APP_STORE_CONNECT_ISSUER_ID` | Apple API Issuer ID |
| `APP_STORE_CONNECT_KEY_IDENTIFIER` | Apple API Key ID |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Indirilen `.p8` dosyasinin eksiksiz icerigi |
| `CERTIFICATE_PRIVATE_KEY` | `ios_distribution_private_key` dosyasinin eksiksiz icerigi |

### `cinear_config`

| Degisken | Deger |
| --- | --- |
| `APP_STORE_APPLE_ID` | App Store Connect'teki CineAR uygulamasinin sayisal Apple ID'si |

Apple ID gizli bir anahtar degildir; `Secret` secilmesi gerekmez. Grup ve
degisken adlari buyuk/kucuk harf dahil burada yazildigi gibi olmalidir.

## Ilk derleme

1. `codemagic.yaml` dosyasinin deponun kokunde oldugunu kontrol edin.
2. Codemagic uygulama sayfasinda **Check for configuration file** ile YAML'i
   yeniden taratin.
3. **Start new build** secin, gonderilen dali ve `CineAR - TestFlight` is
   akisini secerek derlemeyi baslatin.
4. Is akisi sirasiyla yapilandirmayi kontrol eder, App Store profili ve dagitim
   sertifikasini Apple'dan getirir/olusturur, App Store Connect'teki en yuksek
   build numarasini bir artirir, Release archive ve IPA olusturur ve TestFlight'a
   yukler.
5. Apple'in build islemesi tamamlaninca App Store Connect > CineAR > TestFlight
   ekranindan durumu kontrol edin. Ilk build'de ihracat uygunlugu veya beta test
   bilgileri icin Apple ek alanlar isterse bunlari App Store Connect'te doldurun.

YAML'deki `submit_to_app_store: false` nedeniyle bu akisin App Store production
incelemesine uygulama gondermesi mumkun degildir.

## Sik rastlanan hatalar

- `Bundle ID mismatch`: Xcode projesi ve YAML ayni
  `com.cinear.virtualproduction` kimligini kullanmiyor.
- `Missing Codemagic environment variable`: UI grubunun adi, degisken adi veya
  dal erisimi yanlis.
- Certificate/profile hatasi: API key rolunun `App Manager` oldugunu, Apple
  Developer uyeliginin aktif oldugunu ve `CERTIFICATE_PRIVATE_KEY` degerinin
  PEM baslik/sonlariyla eksiksiz yapistirildigini kontrol edin.
- App bulunamadi/build numarasi alinamadi: `APP_STORE_APPLE_ID` alanina sayisal
  App Store Connect Apple ID yerine Bundle ID yazilmis olabilir.
- Beta group bulunamadi: Internal Testing grup adi tam olarak
  `CineAR Internal Testers` olmalidir.

## Resmi kaynaklar

- [Codemagic: Native iOS apps](https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/)
- [Codemagic: Automatic iOS code signing](https://docs.codemagic.io/yaml-code-signing/alternative-code-signing-methods/)
- [Codemagic: App Store Connect publishing](https://docs.codemagic.io/yaml-publishing/app-store-connect/)
- [Codemagic CLI: build-ipa](https://github.com/codemagic-ci-cd/cli-tools/blob/master/docs/xcode-project/build-ipa.md)
- [Codemagic CLI: latest build number](https://github.com/codemagic-ci-cd/cli-tools/blob/master/docs/app-store-connect/get-latest-build-number.md)
