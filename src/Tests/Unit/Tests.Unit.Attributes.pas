unit Tests.Unit.Attributes;

interface

uses
  DUnitX.TestFramework,
  TaskForge.Core.Rtti,
  TaskForge.Core.Domain.Tasks;

type
  [TestFixture]
  TAttributeTests = class
  public
    [Test] procedure TableName_Resolves;
    [Test] procedure Column_OverridesFieldName;
    [Test] procedure PrimaryKey_IsSetForId;
  end;

implementation

procedure TAttributeTests.TableName_Resolves;
var
  Map: TRecordMap;
begin
  Map := TRttiHelper.MapOf<TTask>;
  Assert.AreEqual('tasks', Map.TableName);
end;

procedure TAttributeTests.Column_OverridesFieldName;
var
  Map: TRecordMap;
  Found: Boolean;
  i: Integer;
begin
  Map := TRttiHelper.MapOf<TTask>;
  Found := False;
  for i := 0 to High(Map.Fields) do
    if Map.Fields[i].ColumnName = 'due_at' then Found := True;
  Assert.IsTrue(Found, 'expected column due_at');
end;

procedure TAttributeTests.PrimaryKey_IsSetForId;
var
  Map: TRecordMap;
begin
  Map := TRttiHelper.MapOf<TTask>;
  Assert.IsTrue(Map.PrimaryKeyIndex >= 0);
  Assert.AreEqual('id', Map.Fields[Map.PrimaryKeyIndex].ColumnName);
end;

initialization
  TDUnitX.RegisterTestFixture(TAttributeTests);

end.
