unit Tests.Unit.ThreadPool;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.SyncObjs,
  TaskForge.Worker.ThreadPool;

type
  [TestFixture]
  TThreadPoolTests = class
  public
    [Test] procedure Submit_RunsAllJobs;
    [Test] procedure Shutdown_RefusesFurtherSubmit;
    [Test] procedure Shutdown_DrainsInBoundedTime;
  end;

implementation

uses
  System.Classes,
  System.DateUtils;

procedure TThreadPoolTests.Submit_RunsAllJobs;
var
  Pool: TThreadPool;
  Counter: Integer;
  i: Integer;
  Done: TEvent;
const
  N = 1000;
begin
  Pool := TThreadPool.Create(4, 2048);
  Counter := 0;
  Done := TEvent.Create(nil, True, False, '');
  try
    for i := 1 to N do
      Pool.Submit(
        procedure
        begin
          if TInterlocked.Increment(Counter) = N then
            Done.SetEvent;
        end);
    Assert.IsTrue(Done.WaitFor(10000) = wrSignaled, 'all jobs should complete');
    Assert.AreEqual(N, Counter);
  finally
    Done.Free;
    Pool.Free;
  end;
end;

procedure TThreadPoolTests.Shutdown_RefusesFurtherSubmit;
var
  Pool: TThreadPool;
begin
  Pool := TThreadPool.Create(2, 16);
  try
    Pool.Shutdown;
    Assert.IsFalse(Pool.Submit(procedure begin end));
  finally
    Pool.Free;
  end;
end;

procedure TThreadPoolTests.Shutdown_DrainsInBoundedTime;
var
  Pool: TThreadPool;
  Started: TDateTime;
  ElapsedMs: Int64;
begin
  Pool := TThreadPool.Create(2, 32);
  try
    Pool.Submit(procedure begin Sleep(100) end);
    Started := Now;
    Pool.Shutdown(5000);
    ElapsedMs := MilliSecondsBetween(Now, Started);
    Assert.IsTrue(ElapsedMs < 4000, Format('shutdown took %d ms', [ElapsedMs]));
  finally
    Pool.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TThreadPoolTests);

end.
