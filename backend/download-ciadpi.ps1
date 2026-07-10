# Downloads the latest ByeDPI (ciadpi.exe) Windows x64 build into this folder.
# Usage: powershell -ExecutionPolicy Bypass -File download-ciadpi.ps1

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ua = @{ "User-Agent" = "goodbyedpi-chrome" }

Write-Host "Querying latest release..."
$rel = Invoke-RestMethod -Uri "https://api.github.com/repos/hufrea/byedpi/releases/latest" -Headers $ua

$asset = $rel.assets | Where-Object { $_.name -like "*x86_64-w64.zip" } | Select-Object -First 1
if (-not $asset) { $asset = $rel.assets | Where-Object { $_.name -like "*w64.zip" } | Select-Object -First 1 }
if (-not $asset) { Write-Error "No Windows build found."; exit 1 }

Write-Host ("Downloading: {0} ({1})" -f $asset.name, $rel.tag_name)
$zip = Join-Path $env:TEMP $asset.name
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -Headers $ua

$tmp = Join-Path $env:TEMP "byedpi_extract"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
Expand-Archive -Path $zip -DestinationPath $tmp -Force

$exe = Get-ChildItem -Path $tmp -Recurse -Filter "ciadpi.exe" | Select-Object -First 1
if (-not $exe) { Write-Error "ciadpi.exe not found inside the archive."; exit 1 }

Copy-Item $exe.FullName (Join-Path $here "ciadpi.exe") -Force
Remove-Item $zip -Force; Remove-Item $tmp -Recurse -Force

Write-Host ("Done  ->  {0}" -f (Join-Path $here "ciadpi.exe")) -ForegroundColor Green
