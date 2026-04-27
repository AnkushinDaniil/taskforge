unit TaskForge.Worker.Signals;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  Winapi.Windows;

var
  ShutdownEvent: TEvent;

procedure InstallShutdownHandler;
procedure UninstallShutdownHandler;

implementation

function CtrlHandler(CtrlType: DWORD): BOOL; stdcall;
begin
  case CtrlType of
    CTRL_C_EVENT, CTRL_BREAK_EVENT, CTRL_CLOSE_EVENT, CTRL_SHUTDOWN_EVENT, CTRL_LOGOFF_EVENT:
      begin
        if Assigned(ShutdownEvent) then
          ShutdownEvent.SetEvent;
        Result := True;
      end;
  else
    Result := False;
  end;
end;

procedure InstallShutdownHandler;
begin
  if not Assigned(ShutdownEvent) then
    ShutdownEvent := TEvent.Create(nil, True, False, '');
  Winapi.Windows.SetConsoleCtrlHandler(@CtrlHandler, True);
end;

procedure UninstallShutdownHandler;
begin
  Winapi.Windows.SetConsoleCtrlHandler(@CtrlHandler, False);
  FreeAndNil(ShutdownEvent);
end;

end.
