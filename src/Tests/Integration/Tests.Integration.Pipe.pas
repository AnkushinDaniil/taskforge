unit Tests.Integration.Pipe;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  TaskForge.Core.Ipc.NamedPipe;

type
  [TestFixture]
  TPipeTests = class
  public
    [Test] procedure WriteThenRead_PreservesOrder;
  end;

implementation

procedure TPipeTests.WriteThenRead_PreservesOrder;
var
  Server: TPipeServer;
  Client: TPipeClient;
  ServerThread: TThread;
  Got: TStringList;
  Line: string;
  i: Integer;
  Connected: TEvent;
const
  N = 100;
  PIPE_NAME = 'TaskForge.Test.Pipe';
begin
  Server := TPipeServer.Create(PIPE_NAME);
  Client := TPipeClient.Create(PIPE_NAME);
  Got := TStringList.Create;
  Connected := TEvent.Create(nil, True, False, '');
  try
    ServerThread := TThread.CreateAnonymousThread(
      procedure
      var
        i: Integer;
      begin
        Connected.WaitFor(2000);
        for i := 1 to N do
          Server.WriteLine('msg-' + IntToStr(i));
      end);
    ServerThread.FreeOnTerminate := False;
    ServerThread.Start;

    // give server time to set up
    Sleep(50);
    Assert.IsTrue(Client.Connect(2000), 'pipe client should connect');
    Connected.SetEvent;

    for i := 1 to N do
    begin
      if not Client.ReadLine(Line) then Break;
      Got.Add(Line);
    end;

    ServerThread.WaitFor;
    ServerThread.Free;

    Assert.AreEqual(N, Got.Count);
    Assert.AreEqual('msg-1', Got[0]);
    Assert.AreEqual('msg-' + IntToStr(N), Got[N-1]);
  finally
    Connected.Free;
    Got.Free;
    Client.Free;
    Server.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPipeTests);

end.
