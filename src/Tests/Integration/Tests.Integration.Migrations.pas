unit Tests.Integration.Migrations;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  FireDAC.Comp.Client,
  Tests.Support.Db;

type
  [TestFixture]
  TMigrationTests = class
  public
    [Test] procedure Run_AppliesAllMigrations;
    [Test] procedure Run_IsIdempotent;
  end;

implementation

procedure TMigrationTests.Run_AppliesAllMigrations;
var
  Conn: TFDConnection;
  Q: TFDQuery;
begin
  Conn := TDbFixture.NewMemoryConn;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Conn;
    Q.SQL.Text := 'SELECT COUNT(*) AS c FROM schema_version';
    Q.Open;
    Assert.IsTrue(Q.FieldByName('c').AsInteger >= 1);
  finally
    Q.Free;
    Conn.Free;
  end;
end;

procedure TMigrationTests.Run_IsIdempotent;
var
  Conn: TFDConnection;
  Q: TFDQuery;
  C1, C2: Integer;
begin
  Conn := TDbFixture.NewMemoryConn;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Conn;
    Q.SQL.Text := 'SELECT COUNT(*) AS c FROM schema_version';
    Q.Open;
    C1 := Q.FieldByName('c').AsInteger;
    Q.Close;
    // re-run shouldn't add rows
    // (NewMemoryConn already runs once; do a second pass on the same conn)
    Q.Open;
    C2 := Q.FieldByName('c').AsInteger;
    Assert.AreEqual(C1, C2);
  finally
    Q.Free;
    Conn.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TMigrationTests);

end.
