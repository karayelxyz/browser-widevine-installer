# browser-widevine-installer

Widevine Content Decryption Module (CDM) — **doğrudan Google'dan** indirilip **Helium** ve **Ungoogled Chromium** tarayıcılarına kurulur.

## Neden buna ihtiyaç var?

Bazı tarayıcılar (Helium, Ungoogled Chromium gibi) Widevine'ı paket içinde **göndermez**. Bu yüzden Netflix, Prime Video, Disney+ gibi DRM korumalı videolar oynatılmaz. Bu proje modülü doğrudan Google'ın resmi dağıtım kanalından (Chrome/Edge'in de kullandığı component updater) çekip tarayıcıya kurar.

## Nasıl çalışıyor?

```
[1] Aylık otomatik workflow (GitHub Actions)
    │
    ├── Widevine CRX'i Google'dan indirir (sadece ~10 MB, üçüncü taraf repo YOK)
    ├── Sürüm değişmemişse → DURUR (yeni release yok)
    └── Sürüm güncelse  → release yayınlar: widevine-win-x64-<sürüm>.zip
                            │
[2] install.ps1 (kullanıcı tarafı) ── hep EN SON release'i çeker
    │
    └── Tarayıcının User Data\WidevineCdm\<sürüm>\ klasörüne kurar
```

Bağımlılık zinciri yalnızca **Google** — silinebilecek/bozulabilecek hiçbir üçüncü taraf repo yok.

## Doğru dizin yapısı (önemli!)

WidevineCdm klasörü, sürüm numarasına göre **bir alt klasör** gerektirir (manifest.json'daki `version` değeriyle birebir aynı). Yalnızca dosyaları üst klasöre atmak **çalışmaz**:

```
✗ YANLIŞ (çalışmaz)                  ✓ DOĞRU (versiyonlu alt klasör)
WidevineCdm/                        WidevineCdm/
  ├── manifest.json                   └── 4.10.2934.0
  └── _platform_specific                  ├── manifest.json
      └── win_x64                          └── _platform_specific
          ├── widevinecdm.dll                  └── win_x64
          └── widevinecdm.dll.sig                  ├── widevinecdm.dll
                                                   └── widevinecdm.dll.sig
```

Bu projenin release zip'leri zaten doğru düzenle üretilir; script kurulumu otomatik halleder.

## Kurulum

### Helium

```powershell
irm https://raw.githubusercontent.com/karayelxyz/browser-widevine-installer/main/install-helium.ps1 | iex
```

### Ungoogled Chromium / Chromium

```powershell
irm https://raw.githubusercontent.com/karayelxyz/browser-widevine-installer/main/install-ungoogled-chromium.ps1 | iex
```

> Chrome, Edge ve Brave **zaten** Widevine içerir — onlara gerek yok.

### Elle kurulum (güvenlik şeffaflığı)

Güvenlik endişesi duyuyorsanız `irm | iex` kullanmayın. Önce script'i indirip **inceleyin**, sonra çalıştırın:

```powershell
# 1) Script'i indir ve aç (kodu okuyun!)
Invoke-WebRequest https://raw.githubusercontent.com/karayelxyz/browser-widevine-installer/main/install.ps1 -OutFile install.ps1
notepad install.ps1

# 2) İstediğiniz tarayıcının User Data yolunu vererek çalıştırın
.\install.ps1 -UserDataPath "$env:LOCALAPPDATA\imput\Helium\User Data"

# 3) Opsiyonel: eski sürüm klasörlerini de temizlesin
.\install.ps1 -UserDataPath "$env:LOCALAPPDATA\imput\Helium\User Data" -CleanOld
```

Tüm script'ler bu repoda açık kaynaktır; her çalıştırmada **en güncel** Widevine indirilir.

## Doğrulama

1. Tarayıcıyı tamamen kapatıp yeniden başlatın.
2. Adres çubuğuna `chrome://components` yazın.
3. **Widevine Content Decryption Module** sürümü `0.0.0.0` değilse kurulum başarılı.
4. Test: https://demo.castlabs.com → **DRM** etiketli videoları oynatmayı deneyin.

## Yapılandırma parametreleri (install.ps1)

| Parametre | Açıklama |
|---|---|
| `-UserDataPath` | Hedef tarayıcının User Data klasörü |
| `-CleanOld` | Eski Widevine sürüm klasörlerini siler |
| `-NoPause` | Bitişte tuş beklemeyi atlar (CI için) |

Ortam değişkeni `WIDEVINE_USERDATA` da `-UserDataPath` ile aynı görevi görür.
