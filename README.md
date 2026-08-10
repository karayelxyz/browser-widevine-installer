# browser-widevine-installer

Downloads the Widevine Content Decryption Module (CDM) — **directly from Google** — and installs it for the **Helium** and **Ungoogled Chromium** browsers.

## Why is this needed?

Some browsers (e.g. Helium, Ungoogled Chromium) do **not** ship Widevine. As a result, DRM-protected videos on Netflix, Prime Video, Disney+, etc. will not play. This project fetches the module from Google's official distribution channel (the same component updater Chrome/Edge use) and installs it into the browser.

## How it works

```
[1] Monthly automated workflow (GitHub Actions)
    |
    |-- Downloads the Widevine CRX from Google (only ~22 MB, NO third-party repo)
    |-- If the version is unchanged --> STOPS (no new release)
    '-- If the version is newer   --> publishes a release: widevine-win-x64-<version>.zip
                                          |
[2] install.ps1 (user side) -- always fetches the LATEST release
    |
    '-- Installs into the browser's User Data\WidevineCdm\<version>\ folder
```

The only dependency is **Google** — there is no third-party repository that could be deleted or break.

## Correct directory layout (important!)

The WidevineCdm folder requires a **child folder named after the exact version** (identical to the `version` value in manifest.json). Dropping the files directly into the parent folder **does not work**:

```
X WRONG (does not work)               V CORRECT (versioned child folder)
WidevineCdm/                          WidevineCdm/
  |-- manifest.json                     '-- 4.10.3050.0
  '-- _platform_specific                    |-- manifest.json
      '-- win_x64                          '-- _platform_specific
          |-- widevinecdm.dll                  '-- win_x64
          '-- widevinecdm.dll.sig                  |-- widevinecdm.dll
                                                   '-- widevinecdm.dll.sig
```

The release zips from this project already use the correct layout; the installer handles everything automatically.

## Installation

### Helium

```powershell
irm https://raw.githubusercontent.com/karayelxyz/browser-widevine-installer/main/install-helium.ps1 | iex
```

### Ungoogled Chromium / Chromium

```powershell
irm https://raw.githubusercontent.com/karayelxyz/browser-widevine-installer/main/install-ungoogled-chromium.ps1 | iex
```

> Chrome, Edge and Brave **already** include Widevine — no action needed for those.

### Manual installation (security transparency)

If you have security concerns about `irm | iex`, download and **inspect** the script first, then run it manually:

```powershell
# 1) Download and open the script (read the code!)
Invoke-WebRequest https://raw.githubusercontent.com/karayelxyz/browser-widevine-installer/main/install.ps1 -OutFile install.ps1
notepad install.ps1

# 2) Run it with your browser's User Data path
.\install.ps1 -UserDataPath "$env:LOCALAPPDATA\imput\Helium\User Data"

# 3) Optional: also clean up older version folders
.\install.ps1 -UserDataPath "$env:LOCALAPPDATA\imput\Helium\User Data" -CleanOld
```

All scripts in this repository are open source; every run downloads the **most recent** Widevine.

## Verification

1. Fully close and restart the browser.
2. Type `chrome://components` in the address bar.
3. If the **Widevine Content Decryption Module** version is not `0.0.0.0`, the install succeeded.
4. Test: https://demo.castlabs.com — try playing a video tagged **DRM**.

## install.ps1 parameters

| Parameter | Description |
|---|---|
| `-UserDataPath` | Path to the target browser's User Data folder |
| `-CleanOld` | Deletes older Widevine version folders |
| `-NoPause` | Skips the "press any key" prompt (for CI) |

The `WIDEVINE_USERDATA` environment variable works the same as `-UserDataPath`.
