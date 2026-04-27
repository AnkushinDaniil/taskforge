unit TaskForge.Core.Config;

interface

uses
  System.SysUtils,
  System.IniFiles;

type
  TConfig = record
    DbPath: string;
    ApiPort: Integer;
    PipeName: string;
    ScanIntervalSec: Integer;
    PoolSize: Integer;
    QueueCapacity: Integer;

    class function Default: TConfig; static;
    class function Load(const IniPath: string): TConfig; static;
  end;

function ReadStringE(const Ini: TIniFile; const Section, Key, EnvVar, Fallback: string): string;
function ReadIntegerE(const Ini: TIniFile; const Section, Key, EnvVar: string; Fallback: Integer): Integer;

implementation

function GetEnvOpt(const Name: string; out Value: string): Boolean;
begin
  Value := GetEnvironmentVariable(Name);
  Result := Value <> '';
end;

function ReadStringE(const Ini: TIniFile; const Section, Key, EnvVar, Fallback: string): string;
begin
  if not GetEnvOpt(EnvVar, Result) then
    Result := Ini.ReadString(Section, Key, Fallback);
end;

function ReadIntegerE(const Ini: TIniFile; const Section, Key, EnvVar: string; Fallback: Integer): Integer;
var
  S: string;
begin
  if GetEnvOpt(EnvVar, S) and TryStrToInt(S, Result) then
    Exit;
  Result := Ini.ReadInteger(Section, Key, Fallback);
end;

class function TConfig.Default: TConfig;
begin
  Result.DbPath := 'taskforge.db';
  Result.ApiPort := 8080;
  Result.PipeName := 'TaskForge.Events';
  Result.ScanIntervalSec := 5;
  Result.PoolSize := 4;
  Result.QueueCapacity := 256;
end;

class function TConfig.Load(const IniPath: string): TConfig;
var
  Ini: TIniFile;
begin
  Result := TConfig.Default;
  if not FileExists(IniPath) then
  begin
    // Still allow env-only override
    Result.DbPath := GetEnvironmentVariable('TASKFORGE_DB_PATH');
    if Result.DbPath = '' then Result.DbPath := 'taskforge.db';
    Exit;
  end;
  Ini := TIniFile.Create(IniPath);
  try
    Result.DbPath          := ReadStringE (Ini, 'storage', 'db_path',           'TASKFORGE_DB_PATH',           'taskforge.db');
    Result.ApiPort         := ReadIntegerE(Ini, 'api',     'port',              'TASKFORGE_API_PORT',          8080);
    Result.PipeName        := ReadStringE (Ini, 'ipc',     'pipe_name',         'TASKFORGE_PIPE_NAME',         'TaskForge.Events');
    Result.ScanIntervalSec := ReadIntegerE(Ini, 'worker',  'scan_interval_sec', 'TASKFORGE_SCAN_INTERVAL_SEC', 5);
    Result.PoolSize        := ReadIntegerE(Ini, 'worker',  'pool_size',         'TASKFORGE_POOL_SIZE',         4);
    Result.QueueCapacity   := ReadIntegerE(Ini, 'worker',  'queue_capacity',    'TASKFORGE_QUEUE_CAPACITY',    256);
  finally
    Ini.Free;
  end;
end;

end.
