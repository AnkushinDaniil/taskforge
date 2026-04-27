program TaskForge.Worker;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.SyncObjs,
  FireDAC.Comp.Client,
  FireDAC.Phys.SQLite,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  TaskForge.Core.Config in '..\Core\TaskForge.Core.Config.pas',
  TaskForge.Core.EventBus in '..\Core\TaskForge.Core.EventBus.pas',
  TaskForge.Core.Logging in '..\Core\TaskForge.Core.Logging.pas',
  TaskForge.Core.Migrations in '..\Core\TaskForge.Core.Migrations.pas',
  TaskForge.Core.Domain.Tasks in '..\Core\TaskForge.Core.Domain.Tasks.pas',
  TaskForge.Core.Attributes in '..\Core\TaskForge.Core.Attributes.pas',
  TaskForge.Core.Result in '..\Core\TaskForge.Core.Result.pas',
  TaskForge.Core.Rtti in '..\Core\TaskForge.Core.Rtti.pas',
  TaskForge.Core.Json in '..\Core\TaskForge.Core.Json.pas',
  TaskForge.Core.Repository in '..\Core\TaskForge.Core.Repository.pas',
  TaskForge.Core.Ipc.NamedPipe in '..\Core\TaskForge.Core.Ipc.NamedPipe.pas',
  TaskForge.Worker.Signals in 'TaskForge.Worker.Signals.pas',
  TaskForge.Worker.ThreadPool in 'TaskForge.Worker.ThreadPool.pas',
  TaskForge.Worker.OverdueJob in 'TaskForge.Worker.OverdueJob.pas',
  TaskForge.Worker.Pipe in 'TaskForge.Worker.Pipe.pas';

{$R migrations.res}

procedure Main;
var
  Cfg: TConfig;
  Logger: TJsonLogger;
  Conn: TFDConnection;
  Bus: IEventBus;
  Bridge: TPipeBridge;
  Pool: TThreadPool;
  Job: TOverdueJob;
  WaitMs: Cardinal;
  IniPath: string;
  MigDir: string;
begin
  IniPath := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'config.ini');
  Cfg := TConfig.Load(IniPath);

  Logger := TJsonLogger.Create;
  Conn := TFDConnection.Create(nil);
  Bus := TEventBus.Create;

  try
    Conn.DriverName := 'SQLite';
    Conn.Params.Values['Database'] := Cfg.DbPath;
    Conn.Params.Values['LockingMode'] := 'Normal';
    Conn.Params.Values['Synchronous'] := 'Normal';
    Conn.Params.Values['JournalMode'] := 'WAL';
    Conn.Open;
    Logger.Info('worker starting', [Ctx('db', Cfg.DbPath), Ctx('pipe', Cfg.PipeName)]);

    MigDir := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), '..\migrations');
    if TDirectory.Exists(MigDir) then
      TMigrationRunner.Create(Conn, MigDir).Run
    else
      TMigrationRunner.Create(Conn).Run;

    InstallShutdownHandler;

    Bridge := TPipeBridge.Create(Cfg.PipeName, Bus, Logger);
    Pool := TThreadPool.Create(Cfg.PoolSize, Cfg.QueueCapacity);
    Job := TOverdueJob.Create(Conn, Bus, Logger);

    try
      WaitMs := Cardinal(Cfg.ScanIntervalSec) * 1000;
      while ShutdownEvent.WaitFor(WaitMs) = wrTimeout do
      begin
        Pool.Submit(
          procedure
          begin
            Job.Scan;
          end);
      end;

      Logger.Info('shutting down');
    finally
      Pool.Shutdown(5000);
      Bridge.Stop;
      Job.Free;
      Pool.Free;
      Bridge.Free;
      UninstallShutdownHandler;
    end;
  finally
    Conn.Free;
    Logger.Free;
  end;
end;

begin
  try
    Main;
    ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, '{"level":"error","msg":"', E.Message, '"}');
      ExitCode := 1;
    end;
  end;
end.
