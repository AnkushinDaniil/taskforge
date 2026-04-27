unit Tests.Integration.HttpServer;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.Classes,
  System.JSON,
  FireDAC.Comp.Client,
  TaskForge.Core.Repository,
  TaskForge.Core.Domain.Tasks,
  TaskForge.Api.Router,
  TaskForge.Api.Controllers.Tasks,
  Tests.Support.Db,
  Tests.Support.Http,
  Tests.Support.Ports;

type
  [TestFixture]
  THttpServerTests = class
  strict private
    FConn: TFDConnection;
    FRepo: TRepository<TTask>;
    FRouter: TRouter;
    FCtrl: TTasksController;
    FFix: THttpFixture;
    FBaseUrl: string;
    function PostJson(const Path, Body: string; out RespBody: string): Integer;
    function GetUrl(const Path: string; out RespBody: string): Integer;
  public
    [Setup] procedure SetUp;
    [TearDown] procedure TearDown;
    [Test] procedure Post_Returns201;
    [Test] procedure Get_ReturnsList;
    [Test] procedure GetUnknown_Returns404;
  end;

implementation

procedure THttpServerTests.SetUp;
var
  Port: Word;
begin
  FConn := TDbFixture.NewMemoryConn;
  FRepo := TRepository<TTask>.Create(FConn);
  FRouter := TRouter.Create;
  FCtrl := TTasksController.Create(FRepo);
  FRouter.RegisterController(FCtrl);
  Port := TPortAllocator.NextFree;
  FFix := THttpFixture.Create(FRouter, Port);
  FBaseUrl := FFix.BaseUrl;
  FFix.Start;
end;

procedure THttpServerTests.TearDown;
begin
  FFix.Free;
  FCtrl.Free;
  FRouter.Free;
  FRepo.Free;
  FConn.Free;
end;

function THttpServerTests.PostJson(const Path, Body: string; out RespBody: string): Integer;
var
  Http: THTTPClient;
  Stream: TStringStream;
  Resp: IHTTPResponse;
begin
  Http := THTTPClient.Create;
  Stream := TStringStream.Create(Body, TEncoding.UTF8);
  try
    Http.ContentType := 'application/json';
    Resp := Http.Post(FBaseUrl + Path, Stream);
    Result := Resp.StatusCode;
    RespBody := Resp.ContentAsString(TEncoding.UTF8);
  finally
    Stream.Free;
    Http.Free;
  end;
end;

function THttpServerTests.GetUrl(const Path: string; out RespBody: string): Integer;
var
  Http: THTTPClient;
  Resp: IHTTPResponse;
begin
  Http := THTTPClient.Create;
  try
    Resp := Http.Get(FBaseUrl + Path);
    Result := Resp.StatusCode;
    RespBody := Resp.ContentAsString(TEncoding.UTF8);
  finally
    Http.Free;
  end;
end;

procedure THttpServerTests.Post_Returns201;
var
  Body: string;
  Code: Integer;
begin
  Code := PostJson('/tasks', '{"title":"hi","status":"open","due_at":"2026-12-31T00:00:00Z"}', Body);
  Assert.AreEqual(201, Code);
end;

procedure THttpServerTests.Get_ReturnsList;
var
  Body: string;
  Code: Integer;
begin
  Code := GetUrl('/tasks', Body);
  Assert.AreEqual(200, Code);
end;

procedure THttpServerTests.GetUnknown_Returns404;
var
  Body: string;
  Code: Integer;
begin
  Code := GetUrl('/tasks/9999999', Body);
  Assert.AreEqual(404, Code);
end;

initialization
  TDUnitX.RegisterTestFixture(THttpServerTests);

end.
