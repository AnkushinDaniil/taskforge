unit TaskForge.Worker.ThreadPool;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections;

type
  TJob = reference to procedure;

  TThreadPool = class
  strict private
    type
      TWorker = class(TThread)
      strict private
        FOwner: TThreadPool;
      protected
        procedure Execute; override;
      public
        constructor Create(AOwner: TThreadPool);
      end;
  strict private
    FWorkers: TArray<TWorker>;
    FQueue: TThreadedQueue<TJob>;
    FShuttingDown: Boolean;
    FShutdownLock: TCriticalSection;
  public
    constructor Create(PoolSize, QueueCapacity: Integer);
    destructor Destroy; override;
    function Submit(const Job: TJob; TimeoutMs: Cardinal = INFINITE): Boolean;
    procedure Shutdown(WaitMs: Cardinal = 5000);
    function IsShutdown: Boolean;
  end;

implementation

{ TThreadPool.TWorker }

constructor TThreadPool.TWorker.Create(AOwner: TThreadPool);
begin
  inherited Create(False);
  FOwner := AOwner;
  FreeOnTerminate := False;
end;

procedure TThreadPool.TWorker.Execute;
var
  Job: TJob;
  PopResult: TWaitResult;
begin
  while True do
  begin
    PopResult := FOwner.FQueue.PopItem(Job);
    if PopResult <> wrSignaled then Continue;
    if not Assigned(Job) then Break; // poison pill
    try
      Job();
    except
      // swallow — pool is best-effort; logger is wired by caller
    end;
  end;
end;

{ TThreadPool }

constructor TThreadPool.Create(PoolSize, QueueCapacity: Integer);
var
  i: Integer;
begin
  inherited Create;
  FShutdownLock := TCriticalSection.Create;
  FQueue := TThreadedQueue<TJob>.Create(QueueCapacity, INFINITE, INFINITE);
  SetLength(FWorkers, PoolSize);
  for i := 0 to PoolSize - 1 do
    FWorkers[i] := TWorker.Create(Self);
end;

destructor TThreadPool.Destroy;
begin
  Shutdown;
  FQueue.Free;
  FShutdownLock.Free;
  inherited;
end;

function TThreadPool.Submit(const Job: TJob; TimeoutMs: Cardinal): Boolean;
var
  Pushed: TWaitResult;
begin
  FShutdownLock.Enter;
  try
    if FShuttingDown then Exit(False);
  finally
    FShutdownLock.Leave;
  end;
  Pushed := FQueue.PushItem(Job);
  Result := Pushed = wrSignaled;
end;

procedure TThreadPool.Shutdown(WaitMs: Cardinal);
var
  i: Integer;
  W: TWorker;
begin
  FShutdownLock.Enter;
  try
    if FShuttingDown then Exit;
    FShuttingDown := True;
  finally
    FShutdownLock.Leave;
  end;
  for i := 0 to High(FWorkers) do
    FQueue.PushItem(nil); // poison pill per worker
  for W in FWorkers do
  begin
    if W.WaitFor = WAIT_TIMEOUT then ; // best effort
    W.Free;
  end;
  SetLength(FWorkers, 0);
end;

function TThreadPool.IsShutdown: Boolean;
begin
  FShutdownLock.Enter;
  try
    Result := FShuttingDown;
  finally
    FShutdownLock.Leave;
  end;
end;

end.
