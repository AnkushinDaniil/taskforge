unit Tests.Integration.Sse;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TSseTests = class
  public
    [Test]
    [Ignore('Driving an open SSE stream requires a chunked-reader client; covered by E2E scenario 03_overdue_sse_stream.ps1')]
    procedure StreamRoundTrip;
  end;

implementation

procedure TSseTests.StreamRoundTrip;
begin
  // Intentionally a placeholder. The SSE handler's contract is exercised
  // out-of-process by the PowerShell E2E suite, which can keep a chunked
  // HTTP connection open while a TTaskOverdue event flows worker -> pipe
  // -> API -> SSE -> client. Doing the same in-process would require a
  // chunked HTTP client that we don't currently have wired in tests.
end;

initialization
  TDUnitX.RegisterTestFixture(TSseTests);

end.
