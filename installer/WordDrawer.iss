; 词隙 Word Drawer — per-user installer (no admin prompt).
; Build:  "C:\Users\<you>\AppData\Local\Programs\Inno Setup 6\ISCC.exe" installer\WordDrawer.iss
; Output: build\dist\WordDrawer-Setup-<version>.exe

#define AppName "词隙"
#define AppNameEn "Word Drawer"
; The version comes from version.txt via ISCC /DAppVersion=<ver>, so the exe and
; the installer can never drift apart.
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define AppExe "WordDrawer.App.exe"
#define AppPublisher "WordDrawer"

[Setup]
AppId={{A3F1C7E2-9B44-4D17-8E6A-2C5B7D91F034}
AppName={#AppName} {#AppNameEn}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={code:GetDefaultDir}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; let the user pick where it goes
DisableDirPage=no
; a fixed D: location wins over any earlier install path
UsePreviousAppDir=no
AllowUNCPath=no
AllowRootDirectory=no
DisableWelcomePage=no
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\build\dist
OutputBaseFilename=WordDrawer-Setup-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#AppName} {#AppNameEn}
UninstallDisplayIcon={app}\{#AppExe}
SetupIconFile=..\src\WordDrawer.App\Assets\worddrawer.ico
CloseApplications=yes
AllowNoIcons=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "桌面快捷方式"; GroupDescription: "附加选项:"; Flags: unchecked
Name: "startup"; Description: "开机自动启动"; GroupDescription: "附加选项:"; Flags: unchecked

[Files]
Source: "..\build\publish\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\WordDrawer.App\piper\*"; DestDir: "{localappdata}\WordDrawer\piper"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion isreadme skipifsourcedoesntexist

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\卸载 {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; \
    ValueName: "WordDrawer"; ValueData: """{app}\{#AppExe}"""; Flags: uninsdeletevalue; Tasks: startup

[Run]
Filename: "{app}\{#AppExe}"; Description: "立即运行 {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
Type: filesandordirs; Name: "{localappdata}\WordDrawer\piper"

[Messages]
english.WelcomeLabel2=This will install [name/ver] on your computer.%n%n学习记录保存在 %LOCALAPPDATA%\WordDrawer，卸载时不会被删除。

[Code]
{ Prefer D:\词隙 on machines that have a D: drive (this machine), otherwise fall
  back to a normal per-user location so the installer runs anywhere. }
function GetDefaultDir(Param: string): string;
begin
  if DirExists('D:') then
    Result := 'D:\词隙'
  else
    Result := ExpandConstant('{localappdata}\Programs\词隙');
end;
