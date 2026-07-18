# GoodbyeDPI for Chrome - companion backend installer (no dependencies).
# Installs ciadpi.exe + the PowerShell native messaging host, then registers it
# so the Web Store extension can start/stop the proxy with one toggle.
#
# Usage (end user): double-click install.bat
# Usage (manual):   powershell -ExecutionPolicy Bypass -File install.ps1 [-ExtensionId <id>]

param([string]$ExtensionId)

# The published Chrome Web Store ID is the SAME for every user. Fill it in once
# after your first upload to the Developer Dashboard, then everyone can install.
$StoreExtensionId = "aiclkdmpdfgaeaibbpeeaaolkmfkmiog"

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($ExtensionId)) { $ExtensionId = $StoreExtensionId }
if ([string]::IsNullOrWhiteSpace($ExtensionId) -or $ExtensionId -eq "REPLACE_WITH_STORE_ID") {
  Write-Host "No extension ID configured." -ForegroundColor Yellow
  Write-Host "Edit `$StoreExtensionId in this file, or run: install.ps1 -ExtensionId <id>"
  exit 1
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $here "files"
$dest = Join-Path $env:LOCALAPPDATA "GoodbyeDPIChrome"

Write-Host "Installing to $dest ..."
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item (Join-Path $src "*") -Destination $dest -Recurse -Force

$bat = Join-Path $dest "dpi_host.bat"
$manifestPath = Join-Path $dest "com.goodbyedpi.chrome.json"
$manifest = [ordered]@{
  name            = "com.goodbyedpi.chrome"
  description     = "GoodbyeDPI for Chrome native host"
  path            = $bat
  type            = "stdio"
  allowed_origins = @("chrome-extension://$ExtensionId/")
}
# ASCII (no BOM) so Chrome parses the manifest cleanly.
($manifest | ConvertTo-Json) | Set-Content -Path $manifestPath -Encoding ASCII

$key = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.goodbyedpi.chrome"
New-Item -Path $key -Force | Out-Null
Set-Item -Path $key -Value $manifestPath

Write-Host "Done." -ForegroundColor Green
Write-Host "  files    : $dest"
Write-Host "  host     : $bat"
Write-Host "  registry : $key  ->  extension $ExtensionId"
Write-Host ""
Write-Host "Now fully quit Chrome, reopen it, and toggle the extension ON."
