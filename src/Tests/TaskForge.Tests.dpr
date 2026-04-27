program TaskForge.Tests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  TaskForge.Core.Attributes in '..\Core\TaskForge.Core.Attributes.pas',
  TaskForge.Core.Result in '..\Core\TaskForge.Core.Result.pas',
  TaskForge.Core.EventBus in '..\Core\TaskForge.Core.EventBus.pas',
  TaskForge.Core.Logging in '..\Core\TaskForge.Core.Logging.pas',
  TaskForge.Core.Config in '..\Core\TaskForge.Core.Config.pas',
  TaskForge.Core.Domain.Tasks in '..\Core\TaskForge.Core.Domain.Tasks.pas',
  TaskForge.Core.Rtti in '..\Core\TaskForge.Core.Rtti.pas',
  TaskForge.Core.Json in '..\Core\TaskForge.Core.Json.pas',
  TaskForge.Core.Repository in '..\Core\TaskForge.Core.Repository.pas',
  TaskForge.Core.Migrations in '..\Core\TaskForge.Core.Migrations.pas',
  TaskForge.Core.Ipc.NamedPipe in '..\Core\TaskForge.Core.Ipc.NamedPipe.pas',
  TaskForge.Worker.ThreadPool in '..\Worker\TaskForge.Worker.ThreadPool.pas',
  TaskForge.Api.Router in '..\Api\TaskForge.Api.Router.pas',
  TaskForge.Api.ETag in '..\Api\TaskForge.Api.ETag.pas',
  TaskForge.Api.Controllers.Tasks in '..\Api\TaskForge.Api.Controllers.Tasks.pas',
  Tests.Support.Db in 'Support\Tests.Support.Db.pas',
  Tests.Support.Http in 'Support\Tests.Support.Http.pas',
  Tests.Support.Ports in 'Support\Tests.Support.Ports.pas',
  Tests.Unit.Result in 'Unit\Tests.Unit.Result.pas',
  Tests.Unit.Json in 'Unit\Tests.Unit.Json.pas',
  Tests.Unit.ThreadPool in 'Unit\Tests.Unit.ThreadPool.pas',
  Tests.Unit.Attributes in 'Unit\Tests.Unit.Attributes.pas',
  Tests.Unit.Config in 'Unit\Tests.Unit.Config.pas',
  Tests.Unit.Router in 'Unit\Tests.Unit.Router.pas',
  Tests.Integration.Migrations in 'Integration\Tests.Integration.Migrations.pas',
  Tests.Integration.Repository in 'Integration\Tests.Integration.Repository.pas',
  Tests.Integration.HttpServer in 'Integration\Tests.Integration.HttpServer.pas',
  Tests.Integration.Sse in 'Integration\Tests.Integration.Sse.pas',
  Tests.Integration.Pipe in 'Integration\Tests.Integration.Pipe.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
begin
  try
    TDUnitX.CheckCommandLine;
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Logger := TDUnitXConsoleLogger.Create(False);
    Runner.AddLogger(Logger);
    Runner.FailsOnNoAsserts := False;
    Results := Runner.Execute;
    if not Results.AllPassed then
      ExitCode := 1
    else
      ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 2;
    end;
  end;
end.
