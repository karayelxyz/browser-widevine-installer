# Downloads and installs the latest Widevine CDM for the Helium browser.
# Source code: https://github.com/karayelxyz/browser-widevine-installer/blob/main/install.ps1
$env:WIDEVINE_USERDATA = Join-Path $env:LOCALAPPDATA 'imput\Helium\User Data'
Invoke-RestMethod 'https://raw.githubusercontent.com/karayelxyz/browser-widevine-installer/main/install.ps1' | Invoke-Expression
