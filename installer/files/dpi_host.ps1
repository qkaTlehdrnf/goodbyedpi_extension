# GoodbyeDPI for Chrome - native messaging host (pure PowerShell, no dependencies).
# Chrome launches this per message via dpi_host.bat. It starts/stops a detached
# ciadpi.exe (ByeDPI) SOCKS5 proxy. Protocol: 4-byte LE length + UTF-8 JSON.
#
# Keep in step with dpi_host.py (the macOS/Linux host): same commands, same
# reply fields. installer/files/dpi_host.ps1 must be an identical copy; the
# release workflow copies this file over it before building the installer.

$ErrorActionPreference = "Stop"
# Bump on every host change; shown in the extension's error panel.
$HostVersion = "1.1.0"
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
  $json  = $obj | ConvertTo-Json -Compress -Depth 5
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

# True only if the PID is alive AND is a ciadpi. The PID file survives reboots
# and Windows reuses PIDs quickly, so a bare "process exists" check could report
# a dead proxy as running and make stop/start kill an unrelated program.
function Test-Ours($ProcId) {
  if (-not $ProcId) { return $false }
  $p = Get-Process -Id $ProcId -ErrorAction SilentlyContinue
  return [bool]($p -and $p.ProcessName -like "ciadpi*")
}
function Kill-Proc($ProcId) {
  if (Test-Ours $ProcId) { Stop-Process -Id $ProcId -Force -ErrorAction SilentlyContinue }
}

# True if 127.0.0.1:<port> is free for ciadpi to listen on.
function Test-PortFree($Port) {
  $l = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Parse("127.0.0.1"), [int]$Port)
  try { $l.Start(); return $true } catch { return $false } finally { try { $l.Stop() } catch {} }
}

# A free port near <preferred> (so it stays recognisable), else any.
function Get-FreePort($Preferred) {
  $hi = [Math]::Min([int]$Preferred + 50, 65535)
  for ($p = [int]$Preferred + 1; $p -lt $hi; $p++) { if (Test-PortFree $p) { return $p } }
  $l = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Parse("127.0.0.1"), 0)
  $l.Start(); $p = $l.LocalEndpoint.Port; $l.Stop(); return $p
}

# Processes listening on <port>, as objects with Id and ProcessName. Empty if
# Get-NetTCPConnection is unavailable (very old Windows).
function Get-PortListeners($Port) {
  try {
    $conns = Get-NetTCPConnection -LocalPort ([int]$Port) -State Listen -ErrorAction Stop
  } catch { return @() }
  $ids = $conns | Select-Object -ExpandProperty OwningProcess -Unique
  return @($ids | ForEach-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue } | Where-Object { $_ })
}

# Kill any ciadpi.exe from OUR install path that we no longer track, e.g. left
# over after the PID file was lost. Other copies are handled by Free-Port.
function Remove-Orphans($Exe) {
  Get-Process -Name "ciadpi" -ErrorAction SilentlyContinue | Where-Object {
    try { $_.Path -eq $Exe } catch { $false }
  } | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
}

# Make sure the proxy port is free. A ciadpi holding it (any path) is a
# leftover proxy of ours, so it is killed; anything else is left alone and named.
# Returns $null when free, else an error string.
function Free-Port($Port) {
  foreach ($p in (Get-PortListeners $Port)) {
    if ($p.ProcessName -like "ciadpi*") {
      Log ("killing foreign ciadpi on port {0} pid {1}" -f $Port, $p.Id)
      Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    }
  }
  for ($i = 0; $i -lt 10; $i++) {
    if (Test-PortFree $Port) { return $null }
    Start-Sleep -Milliseconds 200
  }
  $holders = (Get-PortListeners $Port | ForEach-Object { "{0} (pid {1})" -f $_.ProcessName, $_.Id }) -join ", "
  if (-not $holders) { $holders = "another program" }
  return ("port {0} is already in use by {1}. Quit that program, or change the port in the extension options." -f [int]$Port, $holders)
}

# Run ciadpi again in the foreground, only after it exited at startup, to
# capture why (bad argument, port in use, ...). Bounded so it can never hang.
function Get-StartupError($Exe, $ArgList) {
  try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Exe
    $psi.Arguments = ($ArgList | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardOutput = $true
    $psi.WorkingDirectory = (Split-Path $Exe)
    $p = [System.Diagnostics.Process]::Start($psi)
    $errTask = $p.StandardError.ReadToEndAsync()
    $outTask = $p.StandardOutput.ReadToEndAsync()
    if (-not $p.WaitForExit(1500)) { try { $p.Kill() } catch {}; return "" }
    $text = ($errTask.Result + $outTask.Result).Trim()
    if ($text.Length -gt 500) { $text = $text.Substring($text.Length - 500) }
    return $text
  } catch { return "" }
}

# Split user arguments like a shell: whitespace separates, "double quotes" group.
function Split-Args($s) {
  if (-not $s) { return @() }
  return @([regex]::Matches($s, '"([^"]*)"|(\S+)') | ForEach-Object {
    if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value }
  })
}

# Launch ciadpi on <Port>. With <Flexible> (sent by extensions that read the
# "port" field of the reply), fall back to a free port instead of failing when
# something else holds <Port>; older extensions keep the strict behaviour.
function Start-Ciadpi($UserArgs, $Port, $Flexible) {
  $exe = Find-Exe
  if (-not $exe) { return @{ ok = $false; error = "ciadpi.exe not found next to host" } }
  if (-not $Port) { $Port = 1080 }
  $st = Read-State
  if ($st -and (Test-Ours $st.pid)) { Kill-Proc $st.pid; Start-Sleep -Milliseconds 300 }
  Remove-Orphans $exe
  $busy = Free-Port $Port
  if ($busy -and $Flexible) {
    $alt = Get-FreePort $Port
    Log ("port busy, falling back to {0} -- {1}" -f $alt, $busy)
    $Port = $alt
  } elseif ($busy) {
    Log ("start blocked: " + $busy)
    return @{ ok = $false; error = $busy }
  }

  $argList = @("-i", "127.0.0.1", "-p", "$([int]$Port)")
  $argList += @(Split-Args $UserArgs)   # @() so no args adds nothing, not $null
  $quoted = $argList | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }

  $p = Start-Process -FilePath $exe -ArgumentList $quoted -WindowStyle Hidden -PassThru -WorkingDirectory (Split-Path $exe)
  Start-Sleep -Milliseconds 400
  if ($p.HasExited) {
    $rc = $p.ExitCode
    $stderr = Get-StartupError $exe $argList
    Log ("start failed rc {0}: {1} -- {2}" -f $rc, ($argList -join ' '), $stderr)
    $msg = "ciadpi exited immediately (rc={0})" -f $rc
    if ($stderr) { $msg += ": " + $stderr } else { $msg += ". Check args." }
    return @{ ok = $false; error = $msg; rc = $rc; stderr = $stderr }
  }
  Write-State $p.Id ([int]$Port)
  Log ("started pid {0}: {1} {2}" -f $p.Id, $exe, ($argList -join ' '))
  return @{ ok = $true; running = $true; pid = $p.Id; exe = $exe; port = [int]$Port }
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
  if ($st -and (Test-Ours $st.pid)) {
    # Also require the port to be taken: a ciadpi that is alive but not
    # listening is of no use to Chrome.
    if (-not $st.port -or -not (Test-PortFree $st.port)) {
      return @{ ok = $true; running = $true; pid = $st.pid; port = $st.port }
    }
  }
  if ($st) { Clear-State }  # stale: process gone, reused PID, or not listening
  return @{ ok = $true; running = $false }
}

function Invoke-Command2($msg) {
  switch ($msg.cmd) {
    "start"  { return Start-Ciadpi $msg.args $msg.port ([bool]$msg.flexiblePort) }
    "stop"   { return Stop-Ciadpi }
    "status" { return Get-CiadpiStatus }
    "ping"   { return @{ ok = $true; version = $HostVersion; exe = (Find-Exe) } }
    default  { return @{ ok = $false; error = ("unknown cmd: {0}" -f $msg.cmd) } }
  }
}

try {
  $msg = Read-Message
  if ($null -ne $msg) {
    $reply = Invoke-Command2 $msg
    $reply.hostVersion = $HostVersion
    Send-Message $reply
  }
} catch {
  Log ("ERROR " + $_.Exception.Message)
  try { Send-Message @{ ok = $false; error = $_.Exception.Message; hostVersion = $HostVersion } } catch {}
}
