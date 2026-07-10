# GoodbyeDPI for Chrome - native messaging host (pure PowerShell, no dependencies).
# Chrome launches this per message via dpi_host.bat. It starts/stops a detached
# ciadpi.exe (ByeDPI) SOCKS5 proxy. Protocol: 4-byte LE length + UTF-8 JSON.

$ErrorActionPreference = "Stop"
$Base      = Split-Path -Parent $PSCommandPath
$StateFile = Join-Path $Base "ciadpi.pid"
$LogFile   = Join-Path $Base "host.log"

function Log($m) { try { Add-Content -Path $LogFile -Value ("{0} {1}" -f (Get-Date -Format o), $m) } catch {} }

$In  = [Console]::OpenStandardInput()
$Out = [Console]::OpenStandardOutput()

function Read-Message {
  $lenBytes = New-Object byte[] 4
  $got = 0
  while ($got -lt 4) {
    $r = $In.Read($lenBytes, $got, 4 - $got)
    if ($r -le 0) { return $null }
    $got += $r
  }
  $len = [BitConverter]::ToInt32($lenBytes, 0)
  if ($len -le 0) { return $null }
  $buf = New-Object byte[] $len
  $got = 0
  while ($got -lt $len) {
    $r = $In.Read($buf, $got, $len - $got)
    if ($r -le 0) { break }
    $got += $r
  }
  return ([System.Text.Encoding]::UTF8.GetString($buf, 0, $got) | ConvertFrom-Json)
}

function Send-Message($obj) {
  $json  = $obj | ConvertTo-Json -Compress
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  $Out.Write([BitConverter]::GetBytes([int]$bytes.Length), 0, 4)
  $Out.Write($bytes, 0, $bytes.Length)
  $Out.Flush()
}

function Find-Exe {
  foreach ($p in @($env:CIADPI_EXE, (Join-Path $Base "ciadpi.exe"), (Join-Path $Base "..\backend\ciadpi.exe"))) {
    if ($p -and (Test-Path $p)) { return (Resolve-Path $p).Path }
  }
  return $null
}

function Read-State  { if (Test-Path $StateFile) { try { return Get-Content $StateFile -Raw | ConvertFrom-Json } catch { return $null } } return $null }
function Write-State($ProcId, $Port) { @{ pid = $ProcId; port = $Port } | ConvertTo-Json -Compress | Set-Content -Path $StateFile -Encoding ASCII }
function Clear-State { if (Test-Path $StateFile) { Remove-Item $StateFile -Force -ErrorAction SilentlyContinue } }
function Test-Alive($ProcId) { if (-not $ProcId) { return $false } return [bool](Get-Process -Id $ProcId -ErrorAction SilentlyContinue) }
function Kill-Proc($ProcId) { if ($ProcId) { & taskkill /PID $ProcId /T /F *> $null } }

function Start-Ciadpi($UserArgs, $Port) {
  $exe = Find-Exe
  if (-not $exe) { return @{ ok = $false; error = "ciadpi.exe not found next to host" } }
  $st = Read-State
  if ($st -and (Test-Alive $st.pid)) { Kill-Proc $st.pid; Start-Sleep -Milliseconds 300 }

  $argList = @("-i", "127.0.0.1", "-p", "$([int]$Port)")
  if ($UserArgs) { $argList += ($UserArgs -split '\s+' | Where-Object { $_ -ne "" }) }

  $p = Start-Process -FilePath $exe -ArgumentList $argList -WindowStyle Hidden -PassThru -WorkingDirectory (Split-Path $exe)
  Start-Sleep -Milliseconds 400
  if ($p.HasExited) { return @{ ok = $false; error = ("ciadpi exited immediately (rc={0}). Check args." -f $p.ExitCode) } }
  Write-State $p.Id ([int]$Port)
  Log ("started pid {0}: {1} {2}" -f $p.Id, $exe, ($argList -join ' '))
  return @{ ok = $true; running = $true; pid = $p.Id; exe = $exe }
}

function Stop-Ciadpi {
  $st = Read-State
  if ($st -and $st.pid) { Kill-Proc $st.pid }
  Clear-State
  Log "stopped"
  return @{ ok = $true; running = $false }
}

function Get-CiadpiStatus {
  $st = Read-State
  if ($st -and (Test-Alive $st.pid)) { return @{ ok = $true; running = $true; pid = $st.pid; port = $st.port } }
  return @{ ok = $true; running = $false }
}

function Invoke-Command2($msg) {
  switch ($msg.cmd) {
    "start"  { return Start-Ciadpi $msg.args $msg.port }
    "stop"   { return Stop-Ciadpi }
    "status" { return Get-CiadpiStatus }
    "ping"   { return @{ ok = $true; version = "1.0.0"; exe = (Find-Exe) } }
    default  { return @{ ok = $false; error = ("unknown cmd: {0}" -f $msg.cmd) } }
  }
}

try {
  $msg = Read-Message
  if ($null -ne $msg) { Send-Message (Invoke-Command2 $msg) }
} catch {
  Log ("ERROR " + $_.Exception.Message)
  try { Send-Message @{ ok = $false; error = $_.Exception.Message } } catch {}
}
