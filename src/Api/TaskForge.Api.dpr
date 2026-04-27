program TaskForge.Api;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  System.SyncObjs,
  System.Classes,
  FireDAC.Comp.Client,
  FireDAC.Phys.SQLite,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  Winapi.Windows,
  TaskForge.Core.Config in '..\Core\TaskForge.Core.Config.pas',
  TaskForge.Core.Logging in '..\Core\TaskForge.Core.Logging.pas',
  TaskForge.Core.Migrations in '..\Core\TaskForge.Core.Migrations.pas',
  TaskForge.Core.Domain.Tasks in '..\Core\TaskForge.Core.Domain.Tasks.pas',
  TaskForge.Core.Attributes in '..\Core\TaskForge.Core.Attributes.pas',
  TaskForge.Core.Result in '..\Core\TaskForge.Core.Result.pas',
  TaskForge.Core.Rtti in '..\Core\TaskForge.Core.Rtti.pas',
  TaskForge.Core.Json in '..\Core\TaskForge.Core.Json.pas',
  TaskForge.Core.Repository in '..\Core\TaskForge.Core.Repository.pas',
  TaskForge.Core.EventBus in '..\Core\TaskForge.Core.EventBus.pas',
  TaskForge.Core.Ipc.NamedPipe in '..\Core\TaskForge.Core.Ipc.NamedPipe.pas',
  TaskForge.Api.Router in 'TaskForge.Api.Router.pas',
  TaskForge.Api.ETag in 'TaskForge.Api.ETag.pas',
  TaskForge.Api.Sse in 'TaskForge.Api.Sse.pas',
  TaskForge.Api.Controllers.Events in 'TaskForge.Api.Controllers.Events.pas',
  TaskForge.Api.Controllers.Tasks in 'TaskForge.Api.Controllers.Tasks.pas',
  TaskForge.Api.Server in 'TaskForge.Api.Server.pas';

{$R migrations.res}

var
  ShutdownEvent: TEvent = nil;

function ApiCtrlHandler(CtrlType: DWORD): BOOL; stdcall;
begin
  if Assigned(ShutdownEvent) then
    ShutdownEvent.SetEvent;
  Result := True;
end;

procedure Main;
var
  Cfg: TConfig;
  Logger: TJsonLogger;
  Conn: TFDConnection;
  Repo: TRepository<TTask>;
  Router: TRouter;
  Tasks: TTasksController;
  Events: TEventsController;
  Server: TApiServer;
  IniPath, MigDir: string;
begin
  IniPath := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'config.ini');
  Cfg := TConfig.Load(IniPath);

  Logger := TJsonLogger.Create;
  Conn := TFDConnection.Create(nil);
  Router := TRouter.Create;

  try
    Conn.DriverName := 'SQLite';
    Conn.Params.Values['Database'] := Cfg.DbPath;
    Conn.Params.Values['JournalMode'] := 'WAL';
    Conn.Open;

    MigDir := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), '..\migrations');
    if TDirectory.Exists(MigDir) then
      TMigrationRunner.Create(Conn, MigDir).Run
    else
      TMigrationRunner.Create(Conn).Run;

    Repo := TRepository<TTask>.Create(Conn);
    Tasks := TTasksController.Create(Repo);
    Events := TEventsController.Create(Cfg.PipeName, Logger);
    try
      Router.RegisterController(Tasks);

      ShutdownEvent := TEvent.Create(nil, True, False, '');
      SetConsoleCtrlHandler(@ApiCtrlHandler, True);

      Server := TApiServer.Create(Cfg.ApiPort, Router, Events, Logger);
      try
        Server.Start;
        ShutdownEvent.WaitFor(INFINITE);
        Logger.Info('api stopping');
      finally
        Server.Stop;
        Server.Free;
        SetConsoleCtrlHandler(@ApiCtrlHandler, False);
        ShutdownEvent.Free;
        ShutdownEvent := nil;
      end;
    finally
      Events.Free;
      Tasks.Free;
      Repo.Free;
    end;
  finally
    Router.Free;
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
