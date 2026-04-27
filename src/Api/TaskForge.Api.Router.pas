unit TaskForge.Api.Router;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.RegularExpressions,
  System.Generics.Collections,
  TaskForge.Core.Attributes,
  TaskForge.Core.Result;

type
  TRouteParams = TDictionary<string, string>;

  TRouteContext = class
    Method: string;
    Path: string;
    Body: string;
    RequestHeaders: TStrings;
    Params: TRouteParams;
    StatusCode: Integer;
    ResponseBody: string;
    ResponseContentType: string;
    ResponseHeaders: TStrings;
    constructor Create;
    destructor Destroy; override;
  end;

  TRouteHandler = reference to procedure(Ctx: TRouteContext);

  TRouteEntry = record
    Method: string;
    Pattern: TRegEx;
    ParamNames: TArray<string>;
    Handler: TRouteHandler;
    RawPath: string;
  end;

  TRouter = class
  strict private
    FRoutes: TList<TRouteEntry>;
    function PatternFor(const Path: string; out ParamNames: TArray<string>): TRegEx;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const Method, Path: string; const Handler: TRouteHandler);
    procedure RegisterController(Controller: TObject);
    function Dispatch(Ctx: TRouteContext): Boolean;
  end;

implementation

{ TRouteContext }

constructor TRouteContext.Create;
var
  ReqHeaders: TStringList;
begin
  inherited;
  Params := TRouteParams.Create;
  ReqHeaders := TStringList.Create;
  ReqHeaders.NameValueSeparator := ':'; // match Indy's RawHeaders format
  RequestHeaders := ReqHeaders;
  ResponseHeaders := TStringList.Create;
  StatusCode := 200;
  ResponseContentType := 'application/json; charset=utf-8';
end;

destructor TRouteContext.Destroy;
begin
  Params.Free;
  RequestHeaders.Free;
  ResponseHeaders.Free;
  inherited;
end;

{ TRouter }

constructor TRouter.Create;
begin
  inherited;
  FRoutes := TList<TRouteEntry>.Create;
end;

destructor TRouter.Destroy;
begin
  FRoutes.Free;
  inherited;
end;

function TRouter.PatternFor(const Path: string; out ParamNames: TArray<string>): TRegEx;
var
  Names: TList<string>;
  Re: string;
  i: Integer;
  C: Char;
  InParam: Boolean;
  ParamBuf: string;
begin
  Names := TList<string>.Create;
  try
    Re := '^';
    InParam := False;
    ParamBuf := '';
    i := 1;
    while i <= Length(Path) do
    begin
      C := Path[i];
      if InParam then
      begin
        if C = '}' then
        begin
          Names.Add(ParamBuf);
          Re := Re + '([^/]+)';
          ParamBuf := '';
          InParam := False;
        end
        else
          ParamBuf := ParamBuf + C;
      end
      else
      begin
        if C = '{' then
          InParam := True
        else if CharInSet(C, ['.', '\', '+', '*', '?', '(', ')', '[', ']', '^', '$', '|']) then
          Re := Re + '\' + C
        else
          Re := Re + C;
      end;
      Inc(i);
    end;
    Re := Re + '$';
    Result := TRegEx.Create(Re);
    ParamNames := Names.ToArray;
  finally
    Names.Free;
  end;
end;

procedure TRouter.Add(const Method, Path: string; const Handler: TRouteHandler);
var
  E: TRouteEntry;
begin
  E.Method := UpperCase(Method);
  E.RawPath := Path;
  E.Pattern := PatternFor(Path, E.ParamNames);
  E.Handler := Handler;
  FRoutes.Add(E);
end;

procedure TRouter.RegisterController(Controller: TObject);
var
  Ctx: TRttiContext;
  T: TRttiType;
  M: TRttiMethod;
  A: TCustomAttribute;
  RouteAttr: RouteAttribute;
  Inst: TObject;
  CapturedMethod: TRttiMethod;
  H: TRouteHandler;
begin
  Ctx := TRttiContext.Create;
  T := Ctx.GetType(Controller.ClassType);
  Inst := Controller;
  for M in T.GetMethods do
  begin
    for A in M.GetAttributes do
      if A is RouteAttribute then
      begin
        RouteAttr := RouteAttribute(A);
        CapturedMethod := M;
        H :=
          procedure(RC: TRouteContext)
          begin
            CapturedMethod.Invoke(Inst, [TValue.From<TRouteContext>(RC)]);
          end;
        Add(RouteAttr.Method, RouteAttr.Path, H);
      end;
  end;
end;

function TRouter.Dispatch(Ctx: TRouteContext): Boolean;
var
  E: TRouteEntry;
  M: TMatch;
  i: Integer;
begin
  for E in FRoutes do
  begin
    if not SameText(E.Method, Ctx.Method) then Continue;
    M := E.Pattern.Match(Ctx.Path);
    if not M.Success then Continue;
    for i := 0 to High(E.ParamNames) do
      if i + 1 < M.Groups.Count then
        Ctx.Params.AddOrSetValue(E.ParamNames[i], M.Groups[i + 1].Value);
    E.Handler(Ctx);
    Exit(True);
  end;
  Result := False;
end;

end.
