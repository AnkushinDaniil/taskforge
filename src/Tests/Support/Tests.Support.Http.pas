unit Tests.Support.Http;

interface

uses
  System.SysUtils,
  System.Classes,
  IdHTTPServer,
  IdContext,
  IdCustomHTTPServer,
  TaskForge.Core.Logging,
  TaskForge.Api.Router;

type
  THttpFixture = class
  strict private
    FServer: TIdHTTPServer;
    FRouter: TRouter;
    FPort: Word;
    procedure HandleCommand(AContext: TIdContext;
                            ARequestInfo: TIdHTTPRequestInfo;
                            AResponseInfo: TIdHTTPResponseInfo);
  public
    constructor Create(ARouter: TRouter; APort: Word);
    destructor Destroy; override;
    function BaseUrl: string;
    procedure Start;
    procedure Stop;
  end;

implementation

uses
  IdGlobal;

constructor THttpFixture.Create(ARouter: TRouter; APort: Word);
begin
  inherited Create;
  FRouter := ARouter;
  FPort := APort;
  FServer := TIdHTTPServer.Create(nil);
  FServer.DefaultPort := APort;
  FServer.OnCommandGet := HandleCommand;
  FServer.OnCommandOther := HandleCommand;
end;

destructor THttpFixture.Destroy;
begin
  Stop;
  FServer.Free;
  inherited;
end;

function THttpFixture.BaseUrl: string;
begin
  Result := Format('http://127.0.0.1:%d', [FPort]);
end;

procedure THttpFixture.Start;
begin
  FServer.Active := True;
end;

procedure THttpFixture.Stop;
begin
  if FServer.Active then FServer.Active := False;
end;

procedure THttpFixture.HandleCommand(AContext: TIdContext;
                                    ARequestInfo: TIdHTTPRequestInfo;
                                    AResponseInfo: TIdHTTPResponseInfo);
var
  RC: TRouteContext;
  i: Integer;
begin
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
    if not FRouter.Dispatch(RC) then
    begin
      AResponseInfo.ResponseNo := 404;
      AResponseInfo.ContentText := '{"error":"not found"}';
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
