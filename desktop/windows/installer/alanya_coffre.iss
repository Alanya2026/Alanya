; Installateur Windows de l'application de bureau (Inno Setup 6).
; Construit par GitHub Actions (.github/workflows/coffre-bureau.yml) :
;   iscc /DAppVersion=1.0.0 windows\installer\alanya_coffre.iss   (depuis desktop/)
; Entrée : build\windows\x64\runner\Release (flutter build windows --release,
; avec les DLL Visual C++ copiées à côté de l'exécutable).
; Sortie : dist\AlanyaCoffre-Setup-<version>.exe
;
; Installé pour l'utilisateur seul (pas de droits administrateur demandés),
; dans %LOCALAPPDATA%\Programs\Alanya Coffre-fort. L'installateur n'est pas
; signé : Windows affiche « Windows a protégé votre ordinateur » (la page de
; téléchargement explique « Informations complémentaires › Exécuter quand
; même »). Conception : backend docs/conception/coffre-bureau.html, section 09.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#define AppName "Alanya Coffre-fort"
#define AppExe "alanya_coffre.exe"
#define Source "..\..\build\windows\x64\runner\Release"

[Setup]
; Ne jamais changer cet identifiant : Windows reconnaît par lui les mises à
; jour (installer par-dessus) et la désinstallation.
AppId={{6F3B2A1E-8C4D-4E7A-9B1F-2D5C8E0A7B34}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Alanya
AppPublisherURL=https://www.alanya237.com/coffre
AppSupportURL=https://www.alanya237.com/coffre
AppUpdatesURL=https://www.alanya237.com/coffre
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\dist
OutputBaseFilename=AlanyaCoffre-Setup-{#AppVersion}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; L'application ouverte est fermée avant d'être remplacée.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#Source}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
