unit Tests.Unit.Json;

interface

uses
  DUnitX.TestFramework,
  System.JSON,
  TaskForge.Core.Json,
  TaskForge.Core.Domain.Tasks;

type
  [TestFixture]
  TJsonTests = class
  public
    [Test] procedure RoundTrip_PreservesJsonName;
    [Test] procedure JsonIgnore_FieldOmitted;
    [Test] procedure FromJson_DefaultsForMissing;
  end;

implementation

uses
  System.SysUtils;

procedure TJsonTests.RoundTrip_PreservesJsonName;
var
  T, T2: TTask;
  S: string;
begin
  T := Default(TTask);
  T.Id := 1;
  T.Title := 'milk';
  T.Status := 'open';
  T.DueAt := '2026-04-26T12:00:00Z';
  T.CreatedAt := '2026-04-25T10:00:00Z';
  S := TJsonMapper.SerializeRecord<TTask>(T);
  Assert.IsTrue(Pos('"due_at"', S) > 0, 'due_at expected: ' + S);
  Assert.IsTrue(Pos('"created_at"', S) > 0);
  T2 := TJsonMapper.DeserializeRecord<TTask>(S);
  Assert.AreEqual(T.Title, T2.Title);
  Assert.AreEqual(T.DueAt, T2.DueAt);
end;

procedure TJsonTests.JsonIgnore_FieldOmitted;
var
  T: TTask;
  S: string;
begin
  T := Default(TTask);
  T.Id := 1;
  T.Version := 9;
  S := TJsonMapper.SerializeRecord<TTask>(T);
  Assert.IsTrue(Pos('"version"', S) = 0, 'version must be omitted: ' + S);
end;

procedure TJsonTests.FromJson_DefaultsForMissing;
var
  T: TTask;
begin
  T := TJsonMapper.DeserializeRecord<TTask>('{"title":"x"}');
  Assert.AreEqual('x', T.Title);
  Assert.AreEqual(Int64(0), T.Id);
end;

initialization
  TDUnitX.RegisterTestFixture(TJsonTests);

end.
