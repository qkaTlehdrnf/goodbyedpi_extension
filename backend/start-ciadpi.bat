@echo off
rem Manual launcher for the ByeDPI proxy (use when native-host auto-start is off).
rem Leave this window open while browsing; close it to stop the proxy.
setlocal
set PORT=1080
if not exist "%~dp0ciadpi.exe" (
  echo ciadpi.exe not found. Run download-ciadpi.ps1 first.
  pause
  exit /b 1
)
echo ByeDPI proxy on 127.0.0.1:%PORT%  (press Ctrl+C to stop)
"%~dp0ciadpi.exe" -i 127.0.0.1 -p %PORT% -s 1 -d 3+s --mod-http=h,d --auto=torst -r 1+s
