# Helium tarayicisi icin en guncel Widevine CDM'i indirir ve kurar.
# Kaynak kod: https://github.com/karayelxyz/browser-widevine-installer/blob/main/install.ps1
$env:WIDEVINE_USERDATA = Join-Path $env:LOCALAPPDATA 'imput\Helium\User Data'
Invoke-RestMethod 'https://raw.githubusercontent.com/karayelxyz/browser-widevine-installer/main/install.ps1' | Invoke-Expression
