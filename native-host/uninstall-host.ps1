# Removes the native messaging host registration (current user).
# Usage: powershell -ExecutionPolicy Bypass -File uninstall-host.ps1

$key = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\com.goodbyedpi.chrome"
if (Test-Path $key) {
  Remove-Item -Path $key -Force
  Write-Host "Removed registry entry: $key" -ForegroundColor Green
} else {
  Write-Host "No registration found."
}
Write-Host "If ciadpi is still running: taskkill /IM ciadpi.exe /F"
