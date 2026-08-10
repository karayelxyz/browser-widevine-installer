# Browser Widevine Installer

Installs the Widevine Content Decryption Module for **Helium** and **Ungoogled Chromium** — downloaded directly from Google's component updater, no third-party repositories.

## Installation

Run the following command in **PowerShell**:

```powershell
irm https://karayelxyz.github.io/browser-widevine-installer/install.ps1 | iex
```

The script asks which browser to install for (Helium / Ungoogled Chromium / custom path), validates the User Data folder, installs the latest Widevine, and reminds you to restart the browser.

## Verification

1. Restart the browser.
2. Open `chrome://components` — **Widevine Content Decryption Module** must not be `0.0.0.0`.
3. Test playback: https://demo.castlabs.com (pick a **DRM** video).

## Updating

Run the install command again — it always fetches the latest release and skips the download if the version is already installed.

## Troubleshooting

- **"Update error" in `chrome://components`:** normal and harmless. Google only serves Widevine updates to real Chrome/Edge builds; the installed module still works. Use the installer script to update instead.
- **Version shows `0.0.0.0`:** the CDM wasn't detected. Re-run the installer and restart the browser.

## License

MIT — see [LICENSE](LICENSE). Not affiliated with or endorsed by Google.
