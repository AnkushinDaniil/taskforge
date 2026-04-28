unit TaskForge.Worker.Pipe;

interface

uses
  System.SysUtils,
  System.JSON,
  System.SyncObjs,
  System.Classes,
  System.Generics.Collections,
  TaskForge.Core.EventBus,
  TaskForge.Core.Logging,
  TaskForge.Core.Ipc.NamedPipe,
  TaskForge.Core.Domain.Tasks;

type
  TPipeBridge = class
  strict private
    FServer: TPipeServer;
    FBus: TEventBus;
    FLogger: TJsonLogger;
    FQueue: TThreadedQueue<string>;
    FWriter: TThread;
    FStopping: Boolean;
    procedure HandleOverdue(const E: TTaskOverdue);
    procedure WriterLoop;
  public
    constructor Create(const PipeName: string; ABus: TEventBus; ALogger: TJsonLogger);
    destructor Destroy; override;
    procedure Stop;
  end;

implementation

uses
  System.DateUtils;

constructor TPipeBridge.Create(const PipeName: string; ABus: TEventBus; ALogger: TJsonLogger);
begin
  inherited Create;
  FServer := TPipeServer.Create(PipeName);
  FBus := ABus;
  FLogger := ALogger;
  FQueue := TThreadedQueue<string>.Create(1024, INFINITE, INFINITE);
  FBus.Subscribe<TTaskOverdue>(
    procedure(E: TTaskOverdue)
    begin
      Self.HandleOverdue(E);
    end);
  FWriter := TThread.CreateAnonymousThread(WriterLoop);
  FWriter.FreeOnTerminate := False;
  FWriter.Start;
end;

destructor TPipeBridge.Destroy;
begin
  Stop;
  FWriter.Free;
  FQueue.Free;
  FServer.Free;
  inherited;
end;

procedure TPipeBridge.HandleOverdue(const E: TTaskOverdue);
var
  Obj: TJSONObject;
  Line: string;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('event', 'task.overdue');
    Obj.AddPair('id', TJSONNumber.Create(E.Id));
    Obj.AddPair('title', E.Title);
    Obj.AddPair('due_at', E.DueAt);
    Line := Obj.ToJSON;
  finally
    Obj.Free;
  end;
  if FQueue.PushItem(Line) <> wrSignaled then
    FLogger.Warn('pipe queue full, dropping event', [Ctx('id', E.Id)]);
end;

procedure TPipeBridge.WriterLoop;
var
  Line: string;
  R: TWaitResult;
begin
  while not FStopping do
  begin
    R := FQueue.PopItem(Line);
    if R <> wrSignaled then Continue;
    if FStopping then Break;
    try
      FServer.WriteLine(Line);
    except
      on E: Exception do
        FLogger.Warn('pipe write failed', [Ctx('err', E.Message)]);
    end;
  end;
end;

procedure TPipeBridge.Stop;
begin
  if FStopping then Exit;
  FStopping := True;
  FQueue.PushItem(''); // wake writer
  FServer.Close;
  FWriter.WaitFor;
end;

end.
