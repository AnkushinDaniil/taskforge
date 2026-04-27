unit Tests.Unit.Result;

interface

uses
  DUnitX.TestFramework,
  TaskForge.Core.Result;

type
  [TestFixture]
  TResultTests = class
  public
    [Test] procedure Ok_HasValue;
    [Test] procedure Err_HasMessage;
    [Test] procedure Unwrap_RaisesOnErr;
    [Test] procedure UnwrapOr_ReturnsDefaultOnErr;
    [Test] procedure ImplicitFromValue;
  end;

implementation

uses
  System.SysUtils;

procedure TResultTests.Ok_HasValue;
var
  R: Result<Integer>;
begin
  R := Result<Integer>.Ok(42);
  Assert.IsTrue(R.IsOk);
  Assert.AreEqual(42, R.Unwrap);
end;

procedure TResultTests.Err_HasMessage;
var
  R: Result<Integer>;
begin
  R := Result<Integer>.Err('boom', 7);
  Assert.IsFalse(R.IsOk);
  Assert.IsTrue(R.IsErr);
  Assert.AreEqual('boom', R.ErrorMessage);
  Assert.AreEqual(7, R.ErrorCode);
end;

procedure TResultTests.Unwrap_RaisesOnErr;
var
  R: Result<Integer>;
begin
  R := Result<Integer>.Err('nope');
  Assert.WillRaise(procedure begin R.Unwrap end, EResultUnwrap);
end;

procedure TResultTests.UnwrapOr_ReturnsDefaultOnErr;
var
  R: Result<Integer>;
begin
  R := Result<Integer>.Err('e');
  Assert.AreEqual(99, R.UnwrapOr(99));
  R := Result<Integer>.Ok(1);
  Assert.AreEqual(1, R.UnwrapOr(99));
end;

procedure TResultTests.ImplicitFromValue;
var
  R: Result<string>;
begin
  R := 'hello';
  Assert.IsTrue(R.IsOk);
  Assert.AreEqual('hello', R.Unwrap);
end;

initialization
  TDUnitX.RegisterTestFixture(TResultTests);

end.
