unit TaskForge.Core.Migrations;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.IOUtils,
  System.DateUtils,
  Winapi.Windows,
  FireDAC.Comp.Client,
  FireDAC.Comp.Script,
  FireDAC.Stan.Param;

type
  TMigration = record
    Version: Integer;
    Name: string;
    SQL: string;
  end;

  TMigrationRunner = class
  strict private
    FConn: TFDConnection;
    FFromDir: string; // optional override; empty -> use embedded resources
    function LoadFromResources: TArray<TMigration>;
    function LoadFromDirectory(const Dir: string): TArray<TMigration>;
    procedure EnsureSchemaTable;
    function CurrentVersion: Integer;
    procedure ApplyOne(const M: TMigration);
  public
    constructor Create(AConn: TFDConnection; const AFromDir: string = '');
    procedure Run;
  end;

implementation

constructor TMigrationRunner.Create(AConn: TFDConnection; const AFromDir: string);
begin
  inherited Create;
  FConn := AConn;
  FFromDir := AFromDir;
end;

function TMigrationRunner.LoadFromResources: TArray<TMigration>;
var
  i: Integer;
  ResName: string;
  Stream: TResourceStream;
  SS: TStringStream;
  Mig: TMigration;
  Lst: TList<TMigration>;
begin
  Lst := TList<TMigration>.Create;
  try
    for i := 1 to 999 do
    begin
      ResName := Format('MIGRATION_%4.4d', [i]);
      if FindResource(HInstance, PChar(ResName), RT_RCDATA) = 0 then
        Break;
      Stream := TResourceStream.Create(HInstance, ResName, RT_RCDATA);
      try
        SS := TStringStream.Create('', TEncoding.UTF8);
        try
          SS.LoadFromStream(Stream);
          Mig.Version := i;
          Mig.Name := ResName;
          Mig.SQL := SS.DataString;
          Lst.Add(Mig);
        finally
          SS.Free;
        end;
      finally
        Stream.Free;
      end;
    end;
    Result := Lst.ToArray;
  finally
    Lst.Free;
  end;
end;

function TMigrationRunner.LoadFromDirectory(const Dir: string): TArray<TMigration>;
var
  Files: TArray<string>;
  Lst: TList<TMigration>;
  F, Base, NumStr: string;
  Mig: TMigration;
  P: Integer;
begin
  Lst := TList<TMigration>.Create;
  try
    Files := TDirectory.GetFiles(Dir, '*.sql');
    TArray.Sort<string>(Files);
    for F in Files do
    begin
      Base := TPath.GetFileNameWithoutExtension(F);
      P := Pos('_', Base);
      if P < 2 then Continue;
      NumStr := Copy(Base, 1, P - 1);
      if not TryStrToInt(NumStr, Mig.Version) then Continue;
      Mig.Name := Base;
      Mig.SQL := TFile.ReadAllText(F, TEncoding.UTF8);
      Lst.Add(Mig);
    end;
    Result := Lst.ToArray;
  finally
    Lst.Free;
  end;
end;

procedure TMigrationRunner.EnsureSchemaTable;
begin
  FConn.ExecSQL(
    'CREATE TABLE IF NOT EXISTS schema_version (' +
    '  version    INTEGER PRIMARY KEY,' +
    '  applied_at TEXT    NOT NULL' +
    ')'
  );
end;

function TMigrationRunner.CurrentVersion: Integer;
var
  Q: TFDQuery;
begin
  Result := 0;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConn;
    Q.SQL.Text := 'SELECT COALESCE(MAX(version), 0) AS v FROM schema_version';
    Q.Open;
    if not Q.Eof then
      Result := Q.FieldByName('v').AsInteger;
  finally
    Q.Free;
  end;
end;

procedure TMigrationRunner.ApplyOne(const M: TMigration);
var
  Script: TFDScript;
  Q: TFDQuery;
  IsoNow: string;
begin
  FConn.StartTransaction;
  try
    Script := TFDScript.Create(nil);
    try
      Script.Connection := FConn;
      Script.SQLScripts.Add;
      Script.SQLScripts[0].SQL.Text := M.SQL;
      Script.ValidateAll;
      Script.ExecuteAll;
    finally
      Script.Free;
    end;

    IsoNow := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', TTimeZone.Local.ToUniversalTime(Now));

    Q := TFDQuery.Create(nil);
    try
      Q.Connection := FConn;
      Q.SQL.Text := 'INSERT INTO schema_version (version, applied_at) VALUES (:v, :a)';
      Q.ParamByName('v').AsInteger := M.Version;
      Q.ParamByName('a').AsString := IsoNow;
      Q.ExecSQL;
    finally
      Q.Free;
    end;

    FConn.Commit;
  except
    FConn.Rollback;
    raise;
  end;
end;

procedure TMigrationRunner.Run;
var
  All: TArray<TMigration>;
  M: TMigration;
  Cur: Integer;
begin
  EnsureSchemaTable;
  if FFromDir <> '' then
    All := LoadFromDirectory(FFromDir)
  else
    All := LoadFromResources;
  Cur := CurrentVersion;
  for M in All do
    if M.Version > Cur then
      ApplyOne(M);
end;

end.
