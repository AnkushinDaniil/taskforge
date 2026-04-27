unit TaskForge.Api.Server;

interface

uses
  System.SysUtils,
  System.Classes,
  IdHTTPServer,
  IdCustomHTTPServer,
  IdContext,
  IdGlobal,
  TaskForge.Core.Logging,
  TaskForge.Api.Router,
  TaskForge.Api.Controllers.Events;

type
  TApiServer = class
  strict private
    FHttp: TIdHTTPServer;
    FRouter: TRouter;
    FEvents: TEventsController;
    FLogger: TJsonLogger;
    procedure HandleCommand(AContext: TIdContext;
                            ARequestInfo: TIdHTTPRequestInfo;
                            AResponseInfo: TIdHTTPResponseInfo);
  public
    constructor Create(Port: Integer; ARouter: TRouter; AEvents: TEventsController; ALogger: TJsonLogger);
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
  end;

implementation

constructor TApiServer.Create(Port: Integer; ARouter: TRouter; AEvents: TEventsController; ALogger: TJsonLogger);
begin
  inherited Create;
  FRouter := ARouter;
  FEvents := AEvents;
  FLogger := ALogger;
  FHttp := TIdHTTPServer.Create(nil);
  FHttp.DefaultPort := Port;
  FHttp.OnCommandGet := HandleCommand;
  FHttp.OnCommandOther := HandleCommand;
end;

destructor TApiServer.Destroy;
begin
  FHttp.Free;
  inherited;
end;

procedure TApiServer.Start;
begin
  FHttp.Active := True;
  FLogger.Info('api listening', [Ctx('port', FHttp.DefaultPort)]);
end;

procedure TApiServer.Stop;
begin
  if FHttp.Active then FHttp.Active := False;
end;

procedure TApiServer.HandleCommand(AContext: TIdContext;
                                   ARequestInfo: TIdHTTPRequestInfo;
                                   AResponseInfo: TIdHTTPResponseInfo);
var
  RC: TRouteContext;
  i: Integer;
begin
  if (UpperCase(ARequestInfo.Command) = 'GET') and (ARequestInfo.Document = '/events') then
  begin
    FEvents.Handle(AContext, ARequestInfo, AResponseInfo);
    Exit;
  end;

  RC := TRouteContext.Create;
  try
    RC.Method := UpperCase(ARequestInfo.Command);
    RC.Path := ARequestInfo.Document;
    if ARequestInfo.PostStream <> nil then
      RC.Body := ReadStringFromStream(ARequestInfo.PostStream, -1, IndyTextEncoding_UTF8)
    else
      RC.Body := '';
    for i := 0 to ARequestInfo.RawHeaders.Count - 1 do
      RC.RequestHeaders.Add(ARequestInfo.RawHeaders[i]);

    // Forward query string params (status, limit) into Params
    if ARequestInfo.Params.Count > 0 then
      for i := 0 to ARequestInfo.Params.Count - 1 do
        RC.Params.AddOrSetValue(ARequestInfo.Params.Names[i], ARequestInfo.Params.ValueFromIndex[i]);

    if not FRouter.Dispatch(RC) then
    begin
      AResponseInfo.ResponseNo := 404;
      AResponseInfo.ContentType := 'application/json; charset=utf-8';
      AResponseInfo.ContentText := '{"error":"route not found"}';
      Exit;
    end;

    AResponseInfo.ResponseNo := RC.StatusCode;
    AResponseInfo.ContentType := RC.ResponseContentType;
    AResponseInfo.ContentText := RC.ResponseBody;
    for i := 0 to RC.ResponseHeaders.Count - 1 do
      AResponseInfo.CustomHeaders.Add(RC.ResponseHeaders[i]);
  finally
    RC.Free;
  end;
end;

end.
