unit TaskForge.Admin.HttpClient;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.JSON,
  TaskForge.Admin.ViewModels;

type
  TCancellationToken = class
  strict private
    FEvent: TEvent;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Cancel;
    function IsCancelled: Boolean;
  end;

  THttpResult = record
    StatusCode: Integer;
    Body: string;
  end;

  TApiClient = class
  strict private
    FBaseUrl: string;
    FToken: TCancellationToken;
  public
    constructor Create(const ABaseUrl: string);
    destructor Destroy; override;
    procedure CancelAll;
    function Get(const Path: string): THttpResult;
    function Post(const Path, Body: string): THttpResult;
    function Patch(const Path, Body: string; const IfMatch: string = ''): THttpResult;
    function Delete(const Path: string): THttpResult;

    procedure ListAsync(OnComplete: TProc<TArray<TTaskVM>>; OnError: TProc<string>);
    function ParseList(const Body: string): TArray<TTaskVM>;
  end;

implementation

{ TCancellationToken }

constructor TCancellationToken.Create;
begin
  inherited;
  FEvent := TEvent.Create(nil, True, False, '');
end;

destructor TCancellationToken.Destroy;
begin
  FEvent.Free;
  inherited;
end;

procedure TCancellationToken.Cancel;
begin
  FEvent.SetEvent;
end;

function TCancellationToken.IsCancelled: Boolean;
begin
  Result := FEvent.WaitFor(0) = wrSignaled;
end;

{ TApiClient }

constructor TApiClient.Create(const ABaseUrl: string);
begin
  inherited Create;
  FBaseUrl := ABaseUrl;
  FToken := TCancellationToken.Create;
end;

destructor TApiClient.Destroy;
begin
  FToken.Free;
  inherited;
end;

procedure TApiClient.CancelAll;
begin
  FToken.Cancel;
end;

function TApiClient.Get(const Path: string): THttpResult;
var
  Http: THTTPClient;
  Resp: IHTTPResponse;
begin
  Http := THTTPClient.Create;
  try
    Resp := Http.Get(FBaseUrl + Path);
    Result.StatusCode := Resp.StatusCode;
    Result.Body := Resp.ContentAsString(TEncoding.UTF8);
  finally
    Http.Free;
  end;
end;

function TApiClient.Post(const Path, Body: string): THttpResult;
var
  Http: THTTPClient;
  Resp: IHTTPResponse;
  Stream: TStringStream;
begin
  Http := THTTPClient.Create;
  Stream := TStringStream.Create(Body, TEncoding.UTF8);
  try
    Http.ContentType := 'application/json; charset=utf-8';
    Resp := Http.Post(FBaseUrl + Path, Stream);
    Result.StatusCode := Resp.StatusCode;
    Result.Body := Resp.ContentAsString(TEncoding.UTF8);
  finally
    Stream.Free;
    Http.Free;
  end;
end;

function TApiClient.Patch(const Path, Body, IfMatch: string): THttpResult;
var
  Http: THTTPClient;
  Resp: IHTTPResponse;
  Stream: TStringStream;
  Headers: TNetHeaders;
begin
  Http := THTTPClient.Create;
  Stream := TStringStream.Create(Body, TEncoding.UTF8);
  try
    SetLength(Headers, 0);
    if IfMatch <> '' then
    begin
      SetLength(Headers, 1);
      Headers[0] := TNetHeader.Create('If-Match', IfMatch);
    end;
    Http.ContentType := 'application/json; charset=utf-8';
    Resp := Http.Patch(FBaseUrl + Path, Stream, nil, Headers);
    Result.StatusCode := Resp.StatusCode;
    Result.Body := Resp.ContentAsString(TEncoding.UTF8);
  finally
    Stream.Free;
    Http.Free;
  end;
end;

function TApiClient.Delete(const Path: string): THttpResult;
var
  Http: THTTPClient;
  Resp: IHTTPResponse;
begin
  Http := THTTPClient.Create;
  try
    Resp := Http.Delete(FBaseUrl + Path);
    Result.StatusCode := Resp.StatusCode;
    Result.Body := Resp.ContentAsString(TEncoding.UTF8);
  finally
    Http.Free;
  end;
end;

function TApiClient.ParseList(const Body: string): TArray<TTaskVM>;
var
  V: TJSONValue;
  Arr: TJSONArray;
  Item: TJSONValue;
  VM: TTaskVM;
  i: Integer;
begin
  V := TJSONObject.ParseJSONValue(Body);
  if not (V is TJSONArray) then
  begin
    if V <> nil then V.Free;
    Exit(nil);
  end;
  try
    Arr := TJSONArray(V);
    SetLength(Result, Arr.Count);
    for i := 0 to Arr.Count - 1 do
    begin
      Item := Arr.Items[i];
      VM := TTaskVM.Create;
      VM.Id := StrToInt64Def(Item.GetValue<string>('id', '0'), 0);
      VM.Title := Item.GetValue<string>('title', '');
      VM.Status := Item.GetValue<string>('status', '');
      VM.DueAt := Item.GetValue<string>('due_at', '');
      VM.Version := Item.GetValue<Integer>('version', 1);
      Result[i] := VM;
    end;
  finally
    V.Free;
  end;
end;

procedure TApiClient.ListAsync(OnComplete: TProc<TArray<TTaskVM>>; OnError: TProc<string>);
var
  Token: TCancellationToken;
begin
  Token := FToken;
  TThread.CreateAnonymousThread(
    procedure
    var
      Res: THttpResult;
      Items: TArray<TTaskVM>;
    begin
      try
        Res := Self.Get('/tasks');
        if Token.IsCancelled then Exit;
        if Res.StatusCode <> 200 then
        begin
          TThread.Queue(nil,
            procedure begin OnError(Format('HTTP %d', [Res.StatusCode])); end);
          Exit;
        end;
        Items := Self.ParseList(Res.Body);
        if Token.IsCancelled then Exit;
        TThread.Queue(nil,
          procedure begin OnComplete(Items); end);
      except
        on E: Exception do
        begin
          if Token.IsCancelled then Exit;
          TThread.Queue(nil,
            procedure begin OnError(E.Message); end);
        end;
      end;
    end).Start;
end;

end.
