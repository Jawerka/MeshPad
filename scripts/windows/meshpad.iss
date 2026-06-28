; MeshPad Windows installer (Inno Setup 6). PLAN §11.9.2
; CI/local: scripts/package-windows-installer.ps1

#ifndef MyAppVersion
  #define MyAppVersion "0.2.0"
#endif
#ifndef ReleaseDir
  #define ReleaseDir "..\..\apps\meshpad\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif

#define MyAppName "MeshPad"
#define MyAppExeName "meshpad.exe"
#define MyAppPublisher "MeshPad"
#define MyAppUrl "https://github.com/Jawerka/MeshPad"

[Setup]
AppId={{8F4E2A1B-6C3D-4E5F-9A2B-1D0C8E7F6A5B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppUrl}
AppSupportURL={#MyAppUrl}
AppUpdatesURL={#MyAppUrl}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=meshpad-{#MyAppVersion}-windows-x64-setup
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
CloseApplications=force

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
