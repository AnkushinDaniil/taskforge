unit TaskForge.Core.Logging;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.JSON,
  System.DateUtils;

type
  TLogLevel = (llDebug, llInfo, llWarn, llError);

  TLogContext = TArray<TPair<string, string>>;

  TJsonLogger = class
  strict private
    FLock: TLightweightMREW;
    procedure Emit(Level: TLogLevel; const Msg: string; const Ctx: TLogContext);
    class function LevelName(L: TLogLevel): string; static;
    class function NowIso: string; static;
  public
    procedure Debug(const Msg: string); overload;
    procedure Debug(const Msg: string; const Ctx: TLogContext); overload;
    procedure Info(const Msg: string); overload;
    procedure Info(const Msg: string; const Ctx: TLogContext); overload;
    procedure Warn(const Msg: string); overload;
    procedure Warn(const Msg: string; const Ctx: TLogContext); overload;
    procedure Error(const Msg: string); overload;
    procedure Error(const Msg: string; const Ctx: TLogContext); overload;
  end;

function Ctx(const K, V: string): TPair<string, string>; overload;
function Ctx(const K: string; V: Integer): TPair<string, string>; overload;
function Ctx(const K: string; V: Int64): TPair<string, string>; overload;

implementation

function Ctx(const K, V: string): TPair<string, string>;
begin
  Result := TPair<string, string>.Create(K, V);
end;

function Ctx(const K: string; V: Integer): TPair<string, string>;
begin
  Result := TPair<string, string>.Create(K, IntToStr(V));
end;

function Ctx(const K: string; V: Int64): TPair<string, string>;
begin
  Result := TPair<string, string>.Create(K, IntToStr(V));
end;

class function TJsonLogger.LevelName(L: TLogLevel): string;
begin
  case L of
    llDebug: Result := 'debug';
    llInfo:  Result := 'info';
    llWarn:  Result := 'warn';
    llError: Result := 'error';
  else
    Result := 'info';
  end;
end;

class function TJsonLogger.NowIso: string;
begin
  Result := DateToISO8601(TTimeZone.Local.ToUniversalTime(Now), True);
end;

procedure TJsonLogger.Emit(Level: TLogLevel; const Msg: string; const Ctx: TLogContext);
var
  Obj: TJSONObject;
  CtxObj: TJSONObject;
  P: TPair<string, string>;
  Line: string;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('ts', NowIso);
    Obj.AddPair('level', LevelName(Level));
    Obj.AddPair('msg', Msg);
    if Length(Ctx) > 0 then
    begin
      CtxObj := TJSONObject.Create;
      for P in Ctx do
        CtxObj.AddPair(P.Key, P.Value);
      Obj.AddPair('ctx', CtxObj);
    end;
    Line := Obj.ToJSON;
  finally
    Obj.Free;
  end;
  FLock.BeginWrite;
  try
    Writeln(Line);
    Flush(Output);
  finally
    FLock.EndWrite;
  end;
end;

procedure TJsonLogger.Debug(const Msg: string);
begin
  Emit(llDebug, Msg, []);
end;

procedure TJsonLogger.Debug(const Msg: string; const Ctx: TLogContext);
begin
  Emit(llDebug, Msg, Ctx);
end;

procedure TJsonLogger.Info(const Msg: string);
begin
  Emit(llInfo, Msg, []);
end;

procedure TJsonLogger.Info(const Msg: string; const Ctx: TLogContext);
begin
  Emit(llInfo, Msg, Ctx);
end;

procedure TJsonLogger.Warn(const Msg: string);
begin
  Emit(llWarn, Msg, []);
end;

procedure TJsonLogger.Warn(const Msg: string; const Ctx: TLogContext);
begin
  Emit(llWarn, Msg, Ctx);
end;

procedure TJsonLogger.Error(const Msg: string);
begin
  Emit(llError, Msg, []);
end;

procedure TJsonLogger.Error(const Msg: string; const Ctx: TLogContext);
begin
  Emit(llError, Msg, Ctx);
end;

end.
