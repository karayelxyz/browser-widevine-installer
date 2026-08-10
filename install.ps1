<#
.SYNOPSIS
Installs the latest Widevine Content Decryption Module (CDM) for a Chromium-based browser (Windows x64).

This script always downloads the newest release from the browser-widevine-installer repository
and installs it into the target browser's User Data\WidevineCdm\<version> folder.
The source code is fully open; feel free to inspect it and run it manually if you prefer.

.DESCRIPTION
Source: https://github.com/karayelxyz/browser-widevine-installer/releases/latest
Layout: User Data\WidevineCdm\<version>\manifest.json + _platform_specific\win_x64\widevinecdm.dll

.PARAMETER UserDataPath
Path to the target browser's User Data folder (e.g. C:\Users\<user>\AppData\Local\imput\Helium\User Data)

.PARAMETER NoPause
Skip the "press any key" prompt at the end (for automation / CI).

.PARAMETER CleanOld
Delete older Widevine version folders under WidevineCdm.
#>

param(
    [string]$UserDataPath = '',
    [switch]$NoPause,
    [switch]$CleanOld
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo = 'karayelxyz/browser-widevine-installer'

# --- Resolve target User Data folder ---
if (-not $UserDataPath -and $env:WIDEVINE_USERDATA) {
    $UserDataPath = $env:WIDEVINE_USERDATA
}
if (-not $UserDataPath) {
    Write-Host "[ERROR] No target specified. Provide -UserDataPath or set the WIDEVINE_USERDATA environment variable." -ForegroundColor Red
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
Write-Host "  Target: $widevineBase" -ForegroundColor DarkGray
Write-Host ""

if (Test-Path $tempWork) { Remove-Item $tempWork -Recurse -Force }
New-Item -ItemType Directory -Path $extractPath -Force | Out-Null

try {
    # 1. Fetch the latest release (always the most current one)
    Write-Host " [1/5] Looking up the latest Widevine release..." -ForegroundColor Gray
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -like 'widevine-win-x64-*.zip' } | Select-Object -First 1
    if (-not $asset) { throw 'widevine-win-x64-*.zip asset not found!' }
    $version = $release.tag_name -replace '^widevine-', ''
    Write-Host " [OK] Latest version: $version" -ForegroundColor Green

    # 2. Download
    Write-Host " [2/5] Downloading..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath
    Write-Host " [OK] $([math]::Round((Get-Item $zipPath).Length / 1MB, 1)) MB downloaded" -ForegroundColor Green

    # 3. Extract the package
    Write-Host " [3/5] Extracting package..." -ForegroundColor Gray
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    # 4. Verify and install
    $manifestFile = Get-ChildItem -Path $extractPath -Filter 'manifest.json' -Recurse | Select-Object -First 1
    if (-not $manifestFile) { throw 'manifest.json not found!' }
    $manifest = Get-Content $manifestFile.FullName -Raw | ConvertFrom-Json
    if ($manifest.name -notlike '*Widevine*') { throw "Invalid package: $($manifest.name)" }

    $finalDest = Join-Path $widevineBase $manifest.version
    if (Test-Path $finalDest) {
        Write-Host " [4/5] Removing existing version: $($manifest.version)" -ForegroundColor Gray
        Remove-Item $finalDest -Recurse -Force
    }
    New-Item -ItemType Directory -Path $finalDest -Force | Out-Null
    Copy-Item -Path "$($manifestFile.DirectoryName)\*" -Destination $finalDest -Recurse -Force

    # 5. Clean up older versions
    if ($CleanOld) {
        Get-ChildItem -Path $widevineBase -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne $manifest.version } |
            ForEach-Object { Remove-Item $_.FullName -Recurse -Force }
    }

    $dll = Join-Path $finalDest '_platform_specific\win_x64\widevinecdm.dll'
    if (-not (Test-Path $dll)) { throw "widevinecdm.dll not found: $dll" }

    Write-Host ""
    Write-Host "----------------------------------------------" -ForegroundColor Gray
    Write-Host " [SUCCESS] Widevine installed!" -ForegroundColor Green
    Write-Host "  Version: $($manifest.version)" -ForegroundColor White
    Write-Host "  Path:    $finalDest" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Restart the browser and check chrome://components to verify the" -ForegroundColor DarkGray
    Write-Host "  'Widevine Content Decryption Module' version." -ForegroundColor DarkGray

} catch {
    Write-Host ""
    Write-Host " [ERROR] $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if (Test-Path $tempWork) { Remove-Item $tempWork -Recurse -Force }
}

if (-not $NoPause -and -not [Console]::IsInputRedirected) {
    Write-Host ""
    Write-Host " Press any key to exit..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}
