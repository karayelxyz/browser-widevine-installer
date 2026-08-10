<#
.SYNOPSIS
Installs the latest Widevine Content Decryption Module (CDM) for a Chromium-based browser (Windows x64).

.DESCRIPTION
Interactive installer: asks which browser to target, validates its User Data folder, downloads the
newest release from this repository and installs it into <User Data>\WidevineCdm\<version>.
Run this script in an interactive PowerShell window.

Source: https://github.com/karayelxyz/browser-widevine-installer
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ([Console]::IsInputRedirected) {
    Write-Host "[ERROR] Run this script in an interactive PowerShell window." -ForegroundColor Red
    exit 1
}

$repo = 'karayelxyz/browser-widevine-installer'

function Write-Banner {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "      Widevine CDM Installer (win-x64)" -ForegroundColor White
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Menu {
    Write-Host " Select the browser to install Widevine for:" -ForegroundColor White
    Write-Host "   [1] Helium" -ForegroundColor Gray
    Write-Host "   [2] Ungoogled Chromium / Chromium" -ForegroundColor Gray
    Write-Host "   [3] Custom path..." -ForegroundColor Gray
    Write-Host "   [0] Exit" -ForegroundColor DarkGray
    Write-Host ""
}

function Resolve-Target {
    param([string]$Selection)

    switch ($Selection) {
        '1' {
            return @{
                Name = 'Helium'
                Path = (Join-Path $env:LOCALAPPDATA 'imput\Helium\User Data')
            }
        }
        '2' {
            return @{
                Name = 'Ungoogled Chromium / Chromium'
                Path = (Join-Path $env:LOCALAPPDATA 'Chromium\User Data')
            }
        }
        '3' {
            $custom = Read-Host ' Enter the full path to your browser User Data folder'
            if ([string]::IsNullOrWhiteSpace($custom)) {
                Write-Host " [ERROR] No path entered." -ForegroundColor Red
                return $null
            }
            return @{ Name = 'Custom'; Path = $custom.Trim() }
        }
    }

    return $null
}

# --- Select the target browser ---
Write-Banner

$target = $null
do {
    Show-Menu
    $choice = Read-Host ' Select an option'
    if ($choice -eq '0') {
        Write-Host " [ABORT] Nothing was changed." -ForegroundColor Yellow
        return
    }
    $target = Resolve-Target $choice
    if (-not $target) {
        Write-Host " [ERROR] Invalid option: '$choice'. Try again." -ForegroundColor Red
        Write-Host ""
    }
} while (-not $target)

$UserDataPath = $target.Path
$browserName = $target.Name

# --- Validate the target folder ---
if (-not (Test-Path $UserDataPath)) {
    Write-Host ""
    Write-Host " [WARNING] The User Data folder does not exist:" -ForegroundColor Yellow
    Write-Host "   $UserDataPath" -ForegroundColor DarkGray
    $ans = Read-Host " Continue anyway? [y/N]"
    if ($ans -notin @('y', 'Y', 'yes', 'YES')) {
        Write-Host " [ABORT] Nothing was changed." -ForegroundColor Yellow
        return
    }
}

$widevineBase = Join-Path $UserDataPath 'WidevineCdm'
$tempWork = Join-Path $env:TEMP 'WidevineInstaller'
$zipPath = Join-Path $tempWork 'widevine.zip'
$extractPath = Join-Path $tempWork 'extracted'

Write-Banner
Write-Host "  Browser: $browserName" -ForegroundColor White
Write-Host "  Target:  $widevineBase" -ForegroundColor DarkGray
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
    $dll = Join-Path $finalDest '_platform_specific\win_x64\widevinecdm.dll'

    if (Test-Path $dll) {
        Write-Host " [4/5] Version $($manifest.version) is already installed." -ForegroundColor Green
    } else {
        if (Test-Path $finalDest) {
            Write-Host " [4/5] Replacing version: $($manifest.version)" -ForegroundColor Gray
            Remove-Item $finalDest -Recurse -Force
        } else {
            Write-Host " [4/5] Installing version: $($manifest.version)" -ForegroundColor Gray
        }
        New-Item -ItemType Directory -Path $finalDest -Force | Out-Null
        Copy-Item -Path "$($manifestFile.DirectoryName)\*" -Destination $finalDest -Recurse -Force
    }

    # 5. Remove older versions (keep only the latest)
    Get-ChildItem -Path $widevineBase -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne $manifest.version } |
        ForEach-Object {
            try {
                Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop
                Write-Host " [5/5] Removed old version: $($_.Name)" -ForegroundColor Gray
            } catch {
                Write-Host " [WARNING] Could not remove old version $($_.Name) (in use?): $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

    if (-not (Test-Path $dll)) { throw "widevinecdm.dll not found: $dll" }

    Write-Host ""
    Write-Host "----------------------------------------------" -ForegroundColor Gray
    Write-Host " [SUCCESS] Widevine installed!" -ForegroundColor Green
    Write-Host "  Version: $($manifest.version)" -ForegroundColor White
    Write-Host "  Path:    $finalDest" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host " [REMINDER] Fully close and restart $browserName, then check" -ForegroundColor Yellow
    Write-Host "   chrome://components to verify the 'Widevine Content Decryption Module' version." -ForegroundColor Yellow

} catch {
    Write-Host ""
    Write-Host " [ERROR] $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if (Test-Path $tempWork) { Remove-Item $tempWork -Recurse -Force }
}

Write-Host ""
Write-Host " Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
