; Inno Setup script for Lesefluss's Windows installer.
;
; Produces a normal double-clickable Setup.exe with no certificate or
; App Installer trust dance - the tradeoff (vs. the .msix path in this
; same folder) is that it's unsigned, so Windows SmartScreen shows a
; one-time "Windows protected your PC" warning on first run, which the
; user clicks through via "More info" -> "Run anyway". That's judged an
; easier ask for non-technical users than PowerShell/certificate steps.
;
; Build with: packaging/windows/build_installer.ps1 (runs `flutter build
; windows --release` first, then invokes ISCC.exe against this script).
; Requires Inno Setup 6 (https://jrsoftware.org/isinfo.php / winget install
; JRSoftware.InnoSetup) - not bundled, install once per build machine.

#define AppName "Lesefluss"
#define AppVersion "1.0.0"
#define AppPublisher "Lesefluss"
#define AppExeName "immersive_reader.exe"
#define SourceDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{9E9C3E2B-6C7B-4B0E-9C0E-2B2E7C6A3D11}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
; Per-user install (under %LOCALAPPDATA%\Programs, same convention as VS
; Code/Discord) rather than Program Files - this means install/uninstall
; never needs an admin prompt at all, one less thing for a non-technical
; user to click through.
PrivilegesRequired=lowest
DefaultDirName={userpf}\{#AppName}
DefaultGroupName={#AppName}
UninstallDisplayIcon={app}\{#AppExeName}
OutputDir=dist
OutputBaseFilename=LesefflussSetup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=app_icon.ico
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; The [Files] section above only covers what Setup itself puts down: it
; doesn't know about files the running app creates afterward. The app
; pins all of its own on-disk state - shared_preferences (theme, font,
; reading level, scroll position, bookmarks) and sqflite (word progress,
; cached documents, the decompressed offline dictionary) - to one stable
; per-user folder (see main.dart's getApplicationSupportDirectory() call),
; so cleaning it up here is enough regardless of how the app was launched.
Type: filesandordirs; Name: "{userappdata}\com.example\{#AppName}"
Type: dirifempty; Name: "{userappdata}\com.example"
; Defensive: recursively wipe the install directory too, in case a future
; change ever reintroduces a cwd-relative path here.
Type: filesandordirs; Name: "{app}"
