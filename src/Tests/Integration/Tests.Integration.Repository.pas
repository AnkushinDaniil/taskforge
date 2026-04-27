unit Tests.Integration.Repository;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  FireDAC.Comp.Client,
  TaskForge.Core.Repository,
  TaskForge.Core.Domain.Tasks,
  TaskForge.Core.Result,
  Tests.Support.Db;

type
  [TestFixture]
  TRepositoryTests = class
  strict private
    FConn: TFDConnection;
    FRepo: TRepository<TTask>;
  public
    [Setup] procedure SetUp;
    [TearDown] procedure TearDown;
    [Test] procedure InsertGet;
    [Test] procedure UpdateBumpsVersion;
    [Test] procedure StaleVersion_ReturnsFalse;
    [Test] procedure SqlInjection_DoesNotExecute;
    [Test] procedure DeleteRemoves;
  end;

implementation

procedure TRepositoryTests.SetUp;
begin
  FConn := TDbFixture.NewMemoryConn;
  FRepo := TRepository<TTask>.Create(FConn);
end;

procedure TRepositoryTests.TearDown;
begin
  FRepo.Free;
  FConn.Free;
end;

function MakeTask(const Title: string): TTask;
begin
  Result := Default(TTask);
  Result.Title := Title;
  Result.Status := 'open';
  Result.DueAt := '2026-12-31T00:00:00Z';
  Result.CreatedAt := '2026-04-01T00:00:00Z';
end;

procedure TRepositoryTests.InsertGet;
var
  Ins: Result<Int64>;
  Got: Result<TTask>;
begin
  Ins := FRepo.Insert(MakeTask('hello'));
  Assert.IsTrue(Ins.IsOk);
  Got := FRepo.GetById(Ins.Unwrap);
  Assert.IsTrue(Got.IsOk);
  Assert.AreEqual('hello', Got.Unwrap.Title);
end;

procedure TRepositoryTests.UpdateBumpsVersion;
var
  Ins: Result<Int64>;
  Got: Result<TTask>;
  T: TTask;
  Up: Result<Boolean>;
begin
  Ins := FRepo.Insert(MakeTask('v1'));
  Got := FRepo.GetById(Ins.Unwrap);
  T := Got.Unwrap;
  T.Title := 'v2';
  Up := FRepo.Update(T, T.Version);
  Assert.IsTrue(Up.IsOk and Up.Unwrap);
  Got := FRepo.GetById(Ins.Unwrap);
  Assert.AreEqual('v2', Got.Unwrap.Title);
  Assert.AreEqual(2, Got.Unwrap.Version);
end;

procedure TRepositoryTests.StaleVersion_ReturnsFalse;
var
  Ins: Result<Int64>;
  Got: Result<TTask>;
  T: TTask;
  Up: Result<Boolean>;
begin
  Ins := FRepo.Insert(MakeTask('v1'));
  Got := FRepo.GetById(Ins.Unwrap);
  T := Got.Unwrap;
  T.Title := 'will fail';
  Up := FRepo.Update(T, T.Version + 5); // wrong version
  Assert.IsTrue(Up.IsOk);
  Assert.IsFalse(Up.Unwrap);
end;

procedure TRepositoryTests.SqlInjection_DoesNotExecute;
var
  Ins: Result<Int64>;
  Got: Result<TTask>;
  Evil: TTask;
begin
  Evil := MakeTask('x''); DROP TABLE tasks;--');
  Ins := FRepo.Insert(Evil);
  Assert.IsTrue(Ins.IsOk);
  Got := FRepo.GetById(Ins.Unwrap);
  Assert.IsTrue(Got.IsOk);
  Assert.AreEqual(Evil.Title, Got.Unwrap.Title);
end;

procedure TRepositoryTests.DeleteRemoves;
var
  Ins: Result<Int64>;
  Del: Result<Boolean>;
  Got: Result<TTask>;
begin
  Ins := FRepo.Insert(MakeTask('to-delete'));
  Del := FRepo.Delete(Ins.Unwrap);
  Assert.IsTrue(Del.IsOk and Del.Unwrap);
  Got := FRepo.GetById(Ins.Unwrap);
  Assert.IsTrue(Got.IsErr);
end;

initialization
  TDUnitX.RegisterTestFixture(TRepositoryTests);

end.
