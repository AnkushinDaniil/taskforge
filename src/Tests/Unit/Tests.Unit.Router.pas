unit Tests.Unit.Router;

interface

uses
  DUnitX.TestFramework,
  TaskForge.Api.Router;

type
  [TestFixture]
  TRouterTests = class
  public
    [Test] procedure ExactPath_Matches;
    [Test] procedure ParamPath_ExtractsId;
    [Test] procedure UnknownPath_Returns404Sentinel;
  end;

implementation

procedure TRouterTests.ExactPath_Matches;
var
  R: TRouter;
  Ctx: TRouteContext;
  Hit: Boolean;
begin
  Hit := False;
  R := TRouter.Create;
  Ctx := TRouteContext.Create;
  try
    R.Add('GET', '/tasks',
      procedure(C: TRouteContext) begin Hit := True; C.StatusCode := 200; end);
    Ctx.Method := 'GET'; Ctx.Path := '/tasks';
    Assert.IsTrue(R.Dispatch(Ctx));
    Assert.IsTrue(Hit);
  finally
    Ctx.Free;
    R.Free;
  end;
end;

procedure TRouterTests.ParamPath_ExtractsId;
var
  R: TRouter;
  Ctx: TRouteContext;
  Captured: string;
begin
  Captured := '';
  R := TRouter.Create;
  Ctx := TRouteContext.Create;
  try
    R.Add('GET', '/tasks/{id}',
      procedure(C: TRouteContext) begin Captured := C.Params['id'] end);
    Ctx.Method := 'GET'; Ctx.Path := '/tasks/42';
    Assert.IsTrue(R.Dispatch(Ctx));
    Assert.AreEqual('42', Captured);
  finally
    Ctx.Free;
    R.Free;
  end;
end;

procedure TRouterTests.UnknownPath_Returns404Sentinel;
var
  R: TRouter;
  Ctx: TRouteContext;
begin
  R := TRouter.Create;
  Ctx := TRouteContext.Create;
  try
    Ctx.Method := 'GET'; Ctx.Path := '/missing';
    Assert.IsFalse(R.Dispatch(Ctx));
  finally
    Ctx.Free;
    R.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRouterTests);

end.
