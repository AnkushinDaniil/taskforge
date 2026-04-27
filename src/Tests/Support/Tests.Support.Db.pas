unit Tests.Support.Db;

interface

uses
  System.SysUtils,
  System.IOUtils,
  FireDAC.Comp.Client,
  FireDAC.Phys.SQLite,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  TaskForge.Core.Migrations;

type
  TDbFixture = class
  public
    class function NewMemoryConn(const MigrationsDir: string = ''): TFDConnection;
  end;

implementation

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
  if Dir = '' then
    Dir := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), '..\migrations');
  if TDirectory.Exists(Dir) then
    TMigrationRunner.Create(Result, Dir).Run
  else
    TMigrationRunner.Create(Result).Run;
end;

end.
