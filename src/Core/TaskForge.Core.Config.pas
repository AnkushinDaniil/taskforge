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
  if GetEnvOpt(EnvVar, Result) then Exit;
  if Assigned(Ini) then
    Result := Ini.ReadString(Section, Key, Fallback)
  else
    Result := Fallback;
end;

function ReadIntegerE(const Ini: TIniFile; const Section, Key, EnvVar: string; Fallback: Integer): Integer;
var
  S: string;
begin
  if GetEnvOpt(EnvVar, S) and TryStrToInt(S, Result) then Exit;
  if Assigned(Ini) then
    Result := Ini.ReadInteger(Section, Key, Fallback)
  else
    Result := Fallback;
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
  if FileExists(IniPath) then
    Ini := TIniFile.Create(IniPath)
  else
    Ini := nil;
  try
    Result.DbPath          := ReadStringE (Ini, 'storage', 'db_path',           'TASKFORGE_DB_PATH',           Result.DbPath);
    Result.ApiPort         := ReadIntegerE(Ini, 'api',     'port',              'TASKFORGE_API_PORT',          Result.ApiPort);
    Result.PipeName        := ReadStringE (Ini, 'ipc',     'pipe_name',         'TASKFORGE_PIPE_NAME',         Result.PipeName);
    Result.ScanIntervalSec := ReadIntegerE(Ini, 'worker',  'scan_interval_sec', 'TASKFORGE_SCAN_INTERVAL_SEC', Result.ScanIntervalSec);
    Result.PoolSize        := ReadIntegerE(Ini, 'worker',  'pool_size',         'TASKFORGE_POOL_SIZE',         Result.PoolSize);
    Result.QueueCapacity   := ReadIntegerE(Ini, 'worker',  'queue_capacity',    'TASKFORGE_QUEUE_CAPACITY',    Result.QueueCapacity);
  finally
    Ini.Free;
  end;
end;

end.
