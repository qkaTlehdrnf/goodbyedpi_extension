# Removes the GoodbyeDPI backend (native host + files + registry).
$ErrorActionPreference = "SilentlyContinue"

& taskkill /IM ciadpi.exe /F *> $null

$key = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.goodbyedpi.chrome"
if (Test-Path $key) { Remove-Item $key -Force; Write-Host "Removed registry entry." }

$dest = Join-Path $env:LOCALAPPDATA "GoodbyeDPIChrome"
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force; Write-Host "Removed $dest" }

Write-Host "Uninstalled." -ForegroundColor Green
