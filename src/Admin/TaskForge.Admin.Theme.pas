unit TaskForge.Admin.Theme;

interface

uses
  System.SysUtils,
  System.Win.Registry,
  Vcl.Themes,
  Winapi.Windows;

procedure ApplyDark;
procedure ApplyLight;
procedure RestoreSavedTheme;
procedure ToggleTheme;

implementation

const
  REG_PATH = 'Software\TaskForge';
  REG_VAL  = 'Theme';
  DARK_NAME  = 'Windows10 Dark';
  LIGHT_NAME = 'Windows';

procedure SaveTheme(const Name: string);
var
  R: TRegistry;
begin
  R := TRegistry.Create(KEY_WRITE);
  try
    R.RootKey := HKEY_CURRENT_USER;
    if R.OpenKey(REG_PATH, True) then
    begin
      R.WriteString(REG_VAL, Name);
      R.CloseKey;
    end;
  finally
    R.Free;
  end;
end;

function LoadTheme: string;
var
  R: TRegistry;
begin
  Result := LIGHT_NAME;
  R := TRegistry.Create(KEY_READ);
  try
    R.RootKey := HKEY_CURRENT_USER;
    if R.OpenKey(REG_PATH, False) then
    begin
      if R.ValueExists(REG_VAL) then
        Result := R.ReadString(REG_VAL);
      R.CloseKey;
    end;
  finally
    R.Free;
  end;
end;

procedure ApplyDark;
begin
  if TStyleManager.TrySetStyle(DARK_NAME) then
    SaveTheme(DARK_NAME);
end;

procedure ApplyLight;
begin
  if TStyleManager.TrySetStyle(LIGHT_NAME) then
    SaveTheme(LIGHT_NAME);
end;

procedure RestoreSavedTheme;
var
  Saved: string;
begin
  Saved := LoadTheme;
  if Saved <> '' then
    TStyleManager.TrySetStyle(Saved);
end;

procedure ToggleTheme;
begin
  if TStyleManager.ActiveStyle.Name = DARK_NAME then
    ApplyLight
  else
    ApplyDark;
end;

end.
