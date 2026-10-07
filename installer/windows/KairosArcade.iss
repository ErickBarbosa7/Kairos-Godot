; Instalador de Kairos Arcade para Windows (Inno Setup 6).
;
; Compilar (en Windows, con Inno Setup instalado):
;   iscc installer\windows\KairosArcade.iss
; Requiere antes la build exportada en builds\KairosArcade.exe (ver tools/build.sh).
;
; Instalación sin ventanas (para dejar varias máquinas iguales):
;   KairosArcade-Setup.exe /VERYSILENT /API=https://api.tu-dominio.com
;
; NOTA: este script no se pudo compilar ni probar en el entorno donde se escribió
; (sin Windows ni Inno Setup). Pruébalo en una máquina de prueba antes de usarlo.

#define AppName "Kairos Arcade"
#define AppVersion "0.1.0"
#define AppExe "KairosArcade.exe"

[Setup]
AppId={{7D3C1B52-9E1A-4C0B-8F5D-2A6B7C9E4D10}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Kairos
DefaultDirName={autopf}\Kairos Arcade
DisableProgramGroupPage=yes
OutputDir=..\..\builds\installer
OutputBaseFilename=KairosArcade-Setup
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
UninstallDisplayName={#AppName}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "nosleep"; Description: "Evitar que el equipo se suspenda y que la pantalla se apague (recomendado para una cabina)"
Name: "desktopicon"; Description: "Crear un acceso directo en el escritorio"; Flags: unchecked

[Files]
Source: "..\..\builds\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "run-kairos.cmd"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; Arranque automático al iniciar sesión cualquier usuario del equipo.
Name: "{commonstartup}\{#AppName}"; Filename: "{app}\run-kairos.cmd"; WorkingDir: "{app}"; IconFilename: "{app}\{#AppExe}"; Flags: runminimized
Name: "{commondesktop}\{#AppName}"; Filename: "{app}\run-kairos.cmd"; WorkingDir: "{app}"; IconFilename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "powercfg.exe"; Parameters: "/change standby-timeout-ac 0"; Flags: runhidden; Tasks: nosleep
Filename: "powercfg.exe"; Parameters: "/change monitor-timeout-ac 0"; Flags: runhidden; Tasks: nosleep
Filename: "powercfg.exe"; Parameters: "/change hibernate-timeout-ac 0"; Flags: runhidden; Tasks: nosleep
Filename: "{app}\run-kairos.cmd"; Description: "Abrir {#AppName} ahora"; Flags: postinstall nowait skipifsilent

[Code]
var
  ApiPage: TInputQueryWizardPage;

procedure InitializeWizard;
begin
  ApiPage := CreateInputQueryPage(wpSelectTasks,
    'Servidor de Kairos',
    'Dirección de la API',
    'Escribe la dirección del servidor que te dio Kairos. La máquina la usará para vincularse con tu negocio.');
  ApiPage.Add('Dirección (https://...):', False);
  ApiPage.Values[0] := ExpandConstant('{param:API|https://api.kairos.example}');
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  Url: String;
begin
  Result := True;
  if CurPageID = ApiPage.ID then
  begin
    Url := Trim(ApiPage.Values[0]);
    if (Pos('http://', Url) <> 1) and (Pos('https://', Url) <> 1) then
    begin
      MsgBox('La dirección debe empezar con https:// (o http:// solo para pruebas).', mbError, MB_OK);
      Result := False;
    end;
  end;
end;

{ Godot lee override.cfg junto al ejecutable y reemplaza el ajuste kairos/api_url. }
procedure CurStepChanged(CurStep: TSetupStep);
var
  Url: String;
begin
  if CurStep = ssPostInstall then
  begin
    Url := Trim(ApiPage.Values[0]);
    SaveStringToFile(ExpandConstant('{app}\override.cfg'),
      '[kairos]' + #13#10 + #13#10 + 'api_url="' + Url + '"' + #13#10, False);
  end;
end;
