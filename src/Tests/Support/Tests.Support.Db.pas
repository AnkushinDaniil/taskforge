unit Tests.Support.Db;

interface

uses
  System.SysUtils,
  System.IOUtils,
  FireDAC.Comp.Client,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteWrapper.Stat,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  TaskForge.Core.Migrations;

type
  TDbFixture = class
  public
    class function NewMemoryConn(const MigrationsDir: string = ''): TFDConnection;
    class function FindMigrationsDir: string;
  end;

implementation

class function TDbFixture.FindMigrationsDir: string;
var
  Cur, Candidate: string;
  i: Integer;
begin
  // The Tests.exe may land in bin\, src\Tests\, src\Tests\Win64\Release\
  // or similar depending on how it was built — walk up looking for the
  // repo-root migrations\ folder.
  Cur := TPath.GetDirectoryName(ParamStr(0));
  for i := 0 to 5 do
  begin
    Candidate := TPath.Combine(Cur, 'migrations');
    if TDirectory.Exists(Candidate) then Exit(Candidate);
    Cur := TPath.GetDirectoryName(Cur);
    if Cur = '' then Break;
  end;
  Result := '';
end;

class function TDbFixture.NewMemoryConn(const MigrationsDir: string): TFDConnection;
var
  Dir: string;
begin
  Result := TFDConnection.Create(nil);
  Result.DriverName := 'SQLite';
  Result.Params.Values['Database'] := ':memory:';
  Result.Params.Values['LockingMode'] := 'Normal';
  Result.Open;

  Dir := MigrationsDir;
  if Dir = '' then Dir := FindMigrationsDir;
  if (Dir <> '') and TDirectory.Exists(Dir) then
    TMigrationRunner.Create(Result, Dir).Run
  else
    TMigrationRunner.Create(Result).Run;
end;

end.
