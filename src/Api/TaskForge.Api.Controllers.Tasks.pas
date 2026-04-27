unit TaskForge.Api.Controllers.Tasks;

{$RTTI EXPLICIT METHODS([vcPrivate, vcProtected, vcPublic, vcPublished]) PROPERTIES([vcPrivate, vcProtected, vcPublic, vcPublished])}

interface

uses
  System.SysUtils,
  System.JSON,
  System.Classes,
  FireDAC.Comp.Client,
  TaskForge.Core.Attributes,
  TaskForge.Core.Result,
  TaskForge.Core.Repository,
  TaskForge.Core.Domain.Tasks,
  TaskForge.Core.Json,
  TaskForge.Api.Router,
  TaskForge.Api.ETag;

type
  TTasksController = class
  strict private
    FRepo: TRepository<TTask>;
    procedure WriteJson(Ctx: TRouteContext; Status: Integer; const J: TJSONValue); overload;
    procedure WriteJsonString(Ctx: TRouteContext; Status: Integer; const S: string);
  public
    constructor Create(ARepo: TRepository<TTask>);

    [Route('GET', '/tasks')]
    procedure List(Ctx: TRouteContext);

    [Route('GET', '/tasks/{id}')]
    procedure GetOne(Ctx: TRouteContext);

    [Route('POST', '/tasks')]
    procedure Post(Ctx: TRouteContext);

    [Route('PATCH', '/tasks/{id}')]
    procedure Patch(Ctx: TRouteContext);

    [Route('DELETE', '/tasks/{id}')]
    procedure DeleteOne(Ctx: TRouteContext);
  end;

implementation

constructor TTasksController.Create(ARepo: TRepository<TTask>);
begin
  inherited Create;
  FRepo := ARepo;
end;

procedure TTasksController.WriteJson(Ctx: TRouteContext; Status: Integer; const J: TJSONValue);
begin
  Ctx.StatusCode := Status;
  Ctx.ResponseBody := J.ToJSON;
  Ctx.ResponseContentType := 'application/json; charset=utf-8';
end;

procedure TTasksController.WriteJsonString(Ctx: TRouteContext; Status: Integer; const S: string);
begin
  Ctx.StatusCode := Status;
  Ctx.ResponseBody := S;
  Ctx.ResponseContentType := 'application/json; charset=utf-8';
end;

procedure TTasksController.List(Ctx: TRouteContext);
var
  Filter: TQueryFilter;
  R: Result<TArray<TTask>>;
  Arr: TJSONArray;
  T: TTask;
  Q: string;
  Limit: Integer;
  StatusVal: string;
begin
  Filter.Status := '';
  Filter.Limit := 0;

  // very small query string parsing
  Q := Ctx.Path;
  if Pos('?', Q) > 0 then ; // path is already without query — left as a hook

  StatusVal := Ctx.Params.GetValueOrDefault('status', '');
  if StatusVal <> '' then Filter.Status := StatusVal;
  if TryStrToInt(Ctx.Params.GetValueOrDefault('limit', ''), Limit) then
    Filter.Limit := Limit;

  R := FRepo.List(Filter);
  if R.IsErr then
  begin
    WriteJsonString(Ctx, 500, '{"error":"' + R.ErrorMessage + '"}');
    Exit;
  end;
  Arr := TJSONArray.Create;
  try
    for T in R.Unwrap do
      Arr.AddElement(TJsonMapper.ToJson<TTask>(T));
    WriteJson(Ctx, 200, Arr);
  finally
    Arr.Free;
  end;
end;

procedure TTasksController.GetOne(Ctx: TRouteContext);
var
  Id: Int64;
  R: Result<TTask>;
  J: TJSONObject;
  ETag, IfNoneMatch: string;
begin
  if not TryStrToInt64(Ctx.Params.GetValueOrDefault('id', ''), Id) then
  begin
    WriteJsonString(Ctx, 400, '{"error":"invalid id"}');
    Exit;
  end;
  R := FRepo.GetById(Id);
  if R.IsErr then
  begin
    WriteJsonString(Ctx, 404, '{"error":"not found"}');
    Exit;
  end;
  ETag := ComputeETag(R.Unwrap.Id, R.Unwrap.Version);
  IfNoneMatch := Ctx.RequestHeaders.Values['If-None-Match'];
  Ctx.ResponseHeaders.Values['ETag'] := ETag;
  if (IfNoneMatch <> '') and MatchesETag(IfNoneMatch, ETag) then
  begin
    Ctx.StatusCode := 304;
    Ctx.ResponseBody := '';
    Exit;
  end;
  J := TJsonMapper.ToJson<TTask>(R.Unwrap);
  try
    WriteJson(Ctx, 200, J);
  finally
    J.Free;
  end;
end;

procedure TTasksController.Post(Ctx: TRouteContext);
var
  T: TTask;
  Ins: Result<Int64>;
  J: TJSONObject;
  Created: Result<TTask>;
  JOut: TJSONObject;
begin
  try
    T := TJsonMapper.DeserializeRecord<TTask>(Ctx.Body);
  except
    on E: Exception do
    begin
      WriteJsonString(Ctx, 400, '{"error":"invalid json"}');
      Exit;
    end;
  end;
  if T.Status = '' then T.Status := 'open';
  if T.CreatedAt = '' then
    T.CreatedAt := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', TTimeZone.Local.ToUniversalTime(Now));
  T.Version := 1;
  Ins := FRepo.Insert(T);
  if Ins.IsErr then
  begin
    WriteJsonString(Ctx, 500, '{"error":"' + Ins.ErrorMessage + '"}');
    Exit;
  end;
  Created := FRepo.GetById(Ins.Unwrap);
  if Created.IsOk then
  begin
    JOut := TJsonMapper.ToJson<TTask>(Created.Unwrap);
    try
      Ctx.ResponseHeaders.Values['Location'] := '/tasks/' + IntToStr(Ins.Unwrap);
      WriteJson(Ctx, 201, JOut);
    finally
      JOut.Free;
    end;
  end
  else
    WriteJsonString(Ctx, 201, Format('{"id":%d}', [Ins.Unwrap]));
end;

procedure TTasksController.Patch(Ctx: TRouteContext);
var
  Id: Int64;
  Existing: Result<TTask>;
  T: TTask;
  Body: TJSONValue;
  Obj: TJSONObject;
  ExpectedVersion: Integer;
  Up: Result<Boolean>;
  JOut: TJSONObject;
  IfMatch: string;
  ETag: string;
  After: Result<TTask>;
begin
  if not TryStrToInt64(Ctx.Params.GetValueOrDefault('id', ''), Id) then
  begin
    WriteJsonString(Ctx, 400, '{"error":"invalid id"}');
    Exit;
  end;
  Existing := FRepo.GetById(Id);
  if Existing.IsErr then
  begin
    WriteJsonString(Ctx, 404, '{"error":"not found"}');
    Exit;
  end;
  T := Existing.Unwrap;
  ExpectedVersion := T.Version;

  IfMatch := Ctx.RequestHeaders.Values['If-Match'];
  if IfMatch <> '' then
  begin
    ETag := ComputeETag(T.Id, T.Version);
    if Trim(IfMatch) <> ETag then
    begin
      WriteJsonString(Ctx, 409, '{"error":"version mismatch"}');
      Exit;
    end;
  end;

  Body := TJSONObject.ParseJSONValue(Ctx.Body);
  if not (Body is TJSONObject) then
  begin
    if Body <> nil then Body.Free;
    WriteJsonString(Ctx, 400, '{"error":"invalid json"}');
    Exit;
  end;
  try
    Obj := TJSONObject(Body);
    if Obj.GetValue('title') <> nil then T.Title := Obj.GetValue('title').Value;
    if Obj.GetValue('status') <> nil then T.Status := Obj.GetValue('status').Value;
    if Obj.GetValue('due_at') <> nil then T.DueAt := Obj.GetValue('due_at').Value;
  finally
    Body.Free;
  end;

  Up := FRepo.Update(T, ExpectedVersion);
  if Up.IsErr then
  begin
    WriteJsonString(Ctx, 500, '{"error":"' + Up.ErrorMessage + '"}');
    Exit;
  end;
  if not Up.Unwrap then
  begin
    WriteJsonString(Ctx, 409, '{"error":"version conflict"}');
    Exit;
  end;
  After := FRepo.GetById(Id);
  if After.IsOk then
  begin
    JOut := TJsonMapper.ToJson<TTask>(After.Unwrap);
    try
      WriteJson(Ctx, 200, JOut);
    finally
      JOut.Free;
    end;
  end
  else
    WriteJsonString(Ctx, 200, '{}');
end;

procedure TTasksController.DeleteOne(Ctx: TRouteContext);
var
  Id: Int64;
  R: Result<Boolean>;
begin
  if not TryStrToInt64(Ctx.Params.GetValueOrDefault('id', ''), Id) then
  begin
    WriteJsonString(Ctx, 400, '{"error":"invalid id"}');
    Exit;
  end;
  R := FRepo.Delete(Id);
  if R.IsErr then
  begin
    WriteJsonString(Ctx, 500, '{"error":"' + R.ErrorMessage + '"}');
    Exit;
  end;
  if R.Unwrap then
  begin
    Ctx.StatusCode := 204;
    Ctx.ResponseBody := '';
  end
  else
    WriteJsonString(Ctx, 404, '{"error":"not found"}');
end;

end.
