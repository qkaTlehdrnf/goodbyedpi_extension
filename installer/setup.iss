; Inno Setup script for the "GoodbyeDPI for Chrome" companion backend.
; Compile on Windows with Inno Setup (https://jrsoftware.org/isinfo.php)
; -> produces installer\Output\GoodbyeDPI-for-Chrome-Setup.exe
;
#define MyAppName "GoodbyeDPI for Chrome"
#define MyAppVersion "1.0.0"
#define MyStoreId "aiclkdmpdfgaeaibbpeeaaolkmfkmiog"

[Setup]
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher="GoodbyeDPI for Chrome"
DefaultDirName={localappdata}\GoodbyeDPIChrome
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputBaseFilename=GoodbyeDPI-for-Chrome-Setup
UninstallDisplayName={#MyAppName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Files]
Source: "files\ciadpi.exe";        DestDir: "{app}"; Flags: ignoreversion
Source: "files\dpi_host.ps1";      DestDir: "{app}"; Flags: ignoreversion
Source: "files\dpi_host.bat";      DestDir: "{app}"; Flags: ignoreversion
Source: "files\LICENSE-ByeDPI.txt"; DestDir: "{app}"; Flags: ignoreversion

[Registry]
Root: HKCU; Subkey: "Software\Google\Chrome\NativeMessagingHosts\com.goodbyedpi.chrome"; \
  ValueType: string; ValueName: ""; ValueData: "{app}\com.goodbyedpi.chrome.json"; \
  Flags: uninsdeletekey

[Code]
procedure WriteManifest();
var
  M: TStringList;
  P: String;
begin
  P := ExpandConstant('{app}\dpi_host.bat');
  StringChangeEx(P, '\', '\\', True);   { JSON-escape backslashes }
  M := TStringList.Create;
  M.Add('{');
  M.Add('  "name": "com.goodbyedpi.chrome",');
  M.Add('  "description": "GoodbyeDPI for Chrome native host",');
  M.Add('  "path": "' + P + '",');
  M.Add('  "type": "stdio",');
  M.Add('  "allowed_origins": [ "chrome-extension://{#MyStoreId}/" ]');
  M.Add('}');
  M.SaveToFile(ExpandConstant('{app}\com.goodbyedpi.chrome.json'));
  M.Free;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    WriteManifest();
end;

[UninstallRun]
Filename: "taskkill"; Parameters: "/IM ciadpi.exe /F"; Flags: runhidden; RunOnceId: "killproxy"

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
