unit TaskForge.Api.Controllers.Events;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  IdContext,
  IdCustomHTTPServer,
  TaskForge.Core.Logging,
  TaskForge.Core.Ipc.NamedPipe,
  TaskForge.Api.Sse;

type
  TEventsController = class
  strict private
    FPipeName: string;
    FLogger: TJsonLogger;
  public
    constructor Create(const APipeName: string; ALogger: TJsonLogger);
    procedure Handle(AContext: TIdContext;
                     ARequestInfo: TIdHTTPRequestInfo;
                     AResponseInfo: TIdHTTPResponseInfo);
  end;

implementation

uses
  IdGlobal;

constructor TEventsController.Create(const APipeName: string; ALogger: TJsonLogger);
begin
  inherited Create;
  FPipeName := APipeName;
  FLogger := ALogger;
end;

procedure TEventsController.Handle(AContext: TIdContext;
                                   ARequestInfo: TIdHTTPRequestInfo;
                                   AResponseInfo: TIdHTTPResponseInfo);
var
  Sse: TSseStream;
  Client: TPipeClient;
  Line: string;
begin
  AResponseInfo.ResponseNo := 200;
  AResponseInfo.ContentType := 'text/event-stream';
  AResponseInfo.CharSet := 'utf-8';
  AResponseInfo.CustomHeaders.Values['Cache-Control'] := 'no-cache';
  AResponseInfo.CustomHeaders.Values['Connection']    := 'keep-alive';
  AResponseInfo.WriteHeader;

  Sse := TSseStream.Create(AContext);
  Client := TPipeClient.Create(FPipeName);
  try
    if not Client.Connect(2000) then
    begin
      Sse.SendComment('worker pipe unavailable');
      Exit;
    end;
    Sse.SendComment('connected');
    while not Sse.IsClosed do
    begin
      if Client.ReadLine(Line) then
        Sse.SendEvent('task.overdue', Line)
      else
        Break;
    end;
  finally
    Client.Free;
    Sse.Free;
  end;
end;

end.
