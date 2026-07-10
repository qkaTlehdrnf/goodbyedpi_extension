# Registers the native messaging host for Chrome (current user).
# Usage:  powershell -ExecutionPolicy Bypass -File install-host.ps1 -ExtensionId <id>
# Get <id> from chrome://extensions (Developer mode) after loading the /extension folder.

param([string]$ExtensionId)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$bat  = Join-Path $here "dpi_host.bat"
$manifestPath = Join-Path $here "com.goodbyedpi.chrome.json"

if ([string]::IsNullOrWhiteSpace($ExtensionId)) {
  Write-Host "Extension ID is required." -ForegroundColor Yellow
  Write-Host "1) Open chrome://extensions and turn ON Developer mode"
  Write-Host "2) Click 'Load unpacked' and select this project's 'extension' folder"
  Write-Host "3) Copy the shown ID, then run again:"
  Write-Host "   powershell -ExecutionPolicy Bypass -File install-host.ps1 -ExtensionId <paste-id>" -ForegroundColor Cyan
  exit 1
}

if (-not (Test-Path $bat)) { Write-Error "dpi_host.bat not found: $bat"; exit 1 }

$manifest = [ordered]@{
  name            = "com.goodbyedpi.chrome"
  description     = "GoodbyeDPI for Chrome native host"
  path            = $bat
  type            = "stdio"
  allowed_origins = @("chrome-extension://$ExtensionId/")
}
($manifest | ConvertTo-Json) | Set-Content -Path $manifestPath -Encoding ASCII

$key = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.goodbyedpi.chrome"
New-Item -Path $key -Force | Out-Null
Set-Item -Path $key -Value $manifestPath

Write-Host "Install complete." -ForegroundColor Green
Write-Host "  manifest : $manifestPath"
Write-Host "  host bat : $bat"
Write-Host "  registry : $key"
Write-Host ""
Write-Host "Fully quit Chrome and reopen it, then the popup 'backend' dot turns green."
