<#
.SYNOPSIS
Widevine Content Decryption Module (CDM) kurucusu (Windows x64).

Bu script, browser-widevine-installer reposunun en guncel release'ini (hep latest)
indirir ve hedef tarayicinin User Data\WidevineCdm\<surum> klasorune kurar.
Kod tamamen acik kaynak; isterseniz indirip elle de calistirabilirsiniz.

.DESCRIPTION
Kaynak: https://github.com/karayelxyz/browser-widevine-installer/releases/latest
Yapi:   User Data\WidevineCdm\<surum>\manifest.json + _platform_specific\win_x64\widevinecdm.dll

.PARAMETER UserDataPath
Hedef tarayicinin User Data klasoru (ornek: C:\Users\murat\AppData\Local\imput\Helium\User Data)

.PARAMETER NoPause
Bitis'te tus beklemeyi atlar (otomasyon / CI icin).

.PARAMETER CleanOld
WidevineCdm altindaki eski surum klasorlerini siler.
#>

param(
    [string]$UserDataPath = '',
    [switch]$NoPause,
    [switch]$CleanOld
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo = 'karayelxyz/browser-widevine-installer'

# --- Hedef User Data klasorunu belirle ---
if (-not $UserDataPath -and $env:WIDEVINE_USERDATA) {
    $UserDataPath = $env:WIDEVINE_USERDATA
}
if (-not $UserDataPath) {
    Write-Host "[HATA] Hedef belirtilmedi. -UserDataPath parametresiyle veya WIDEVINE_USERDATA ortam degiskeniyle verin." -ForegroundColor Red
    return
}

$widevineBase = Join-Path $UserDataPath 'WidevineCdm'
$tempWork = Join-Path $env:TEMP 'WidevineInstaller'
$zipPath = Join-Path $tempWork 'widevine.zip'
$extractPath = Join-Path $tempWork 'extracted'

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "      Widevine CDM Installer (win-x64)" -ForegroundColor White
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Hedef: $widevineBase" -ForegroundColor DarkGray
Write-Host ""

if (Test-Path $tempWork) { Remove-Item $tempWork -Recurse -Force }
New-Item -ItemType Directory -Path $extractPath -Force | Out-Null

try {
    # 1. En guncel release'i bul (hep latest indirilir)
    Write-Host " [1/5] En guncel Widevine surumu araniyor..." -ForegroundColor Gray
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -like 'widevine-win-x64-*.zip' } | Select-Object -First 1
    if (-not $asset) { throw 'widevine-win-x64-*.zip asset bulunamadi!' }
    $version = $release.tag_name -replace '^widevine-', ''
    Write-Host " [OK] En guncel surum: $version" -ForegroundColor Green

    # 2. Indir
    Write-Host " [2/5] Indiriliyor..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath
    Write-Host " [OK] $([math]::Round((Get-Item $zipPath).Length / 1MB, 1)) MB indirildi" -ForegroundColor Green

    # 3. Paketi ac
    Write-Host " [3/5] Paket aciliyor..." -ForegroundColor Gray
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    # 4. Dogrula ve kur
    $manifestFile = Get-ChildItem -Path $extractPath -Filter 'manifest.json' -Recurse | Select-Object -First 1
    if (-not $manifestFile) { throw 'manifest.json bulunamadi!' }
    $manifest = Get-Content $manifestFile.FullName -Raw | ConvertFrom-Json
    if ($manifest.name -notlike '*Widevine*') { throw "Gecersiz paket: $($manifest.name)" }

    $finalDest = Join-Path $widevineBase $manifest.version
    if (Test-Path $finalDest) {
        Write-Host " [4/5] Mevcut surum temizleniyor: $($manifest.version)" -ForegroundColor Gray
        Remove-Item $finalDest -Recurse -Force
    }
    New-Item -ItemType Directory -Path $finalDest -Force | Out-Null
    Copy-Item -Path "$($manifestFile.DirectoryName)\*" -Destination $finalDest -Recurse -Force

    # 5. Eski surumleri temizle
    if ($CleanOld) {
        Get-ChildItem -Path $widevineBase -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne $manifest.version } |
            ForEach-Object { Remove-Item $_.FullName -Recurse -Force }
    }

    $dll = Join-Path $finalDest '_platform_specific\win_x64\widevinecdm.dll'
    if (-not (Test-Path $dll)) { throw "widevinecdm.dll bulunamadi: $dll" }

    Write-Host ""
    Write-Host "----------------------------------------------" -ForegroundColor Gray
    Write-Host " [BASARILI] Widevine kuruldu!" -ForegroundColor Green
    Write-Host "  Surum: $($manifest.version)" -ForegroundColor White
    Write-Host "  Yol:   $finalDest" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Tarayiciyi yeniden baslatin ve chrome://components adresinde" -ForegroundColor DarkGray
    Write-Host "  'Widevine Content Decryption Module' surumunu kontrol edin." -ForegroundColor DarkGray

} catch {
    Write-Host ""
    Write-Host " [HATA] $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if (Test-Path $tempWork) { Remove-Item $tempWork -Recurse -Force }
}

if (-not $NoPause -and -not [Console]::IsInputRedirected) {
    Write-Host ""
    Write-Host " Devam etmek icin bir tusa basin..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
