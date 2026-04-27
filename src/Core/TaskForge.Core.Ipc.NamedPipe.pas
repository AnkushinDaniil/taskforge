unit TaskForge.Core.Ipc.NamedPipe;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  Winapi.Windows;

type
  TPipeServer = class
  strict private
    FName: string;
    FHandle: THandle;
    FConnected: Boolean;
    FLock: TCriticalSection;
    function FullName: string;
    procedure EnsureHandle;
    function TryConnectClient: Boolean;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
    procedure WriteLine(const S: string);
    procedure Close;
  end;

  TPipeClient = class
  strict private
    FName: string;
    FHandle: THandle;
    FBuffer: TBytes;
    function FullName: string;
    function ReadByteCount(out B: Byte): Boolean;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
    function Connect(TimeoutMs: Cardinal): Boolean;
    function ReadLine(out S: string): Boolean;
    procedure Close;
  end;

implementation

const
  PIPE_BUFFER_SIZE = 64 * 1024;

{ TPipeServer }

constructor TPipeServer.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FHandle := INVALID_HANDLE_VALUE;
  FConnected := False;
  FLock := TCriticalSection.Create;
end;

destructor TPipeServer.Destroy;
begin
  Close;
  FLock.Free;
  inherited;
end;

function TPipeServer.FullName: string;
begin
  Result := '\\.\pipe\' + FName;
end;

procedure TPipeServer.EnsureHandle;
begin
  if FHandle <> INVALID_HANDLE_VALUE then Exit;
  FHandle := CreateNamedPipe(
    PChar(FullName),
    PIPE_ACCESS_OUTBOUND,
    PIPE_TYPE_MESSAGE or PIPE_WAIT,
    1, // single instance — single consumer model
    PIPE_BUFFER_SIZE, PIPE_BUFFER_SIZE,
    0, nil);
  if FHandle = INVALID_HANDLE_VALUE then
    RaiseLastOSError;
end;

function TPipeServer.TryConnectClient: Boolean;
begin
  EnsureHandle;
  if ConnectNamedPipe(FHandle, nil) then
    Result := True
  else
    Result := GetLastError = ERROR_PIPE_CONNECTED;
  FConnected := Result;
end;

procedure TPipeServer.WriteLine(const S: string);
var
  Bytes: TBytes;
  Written: DWORD;
  Ok: Boolean;
begin
  FLock.Enter;
  try
    if not FConnected then
      if not TryConnectClient then
        Exit;
    Bytes := TEncoding.UTF8.GetBytes(S + #10);
    Ok := WriteFile(FHandle, Bytes[0], Length(Bytes), Written, nil);
    if not Ok then
    begin
      FConnected := False;
      DisconnectNamedPipe(FHandle);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TPipeServer.Close;
begin
  FLock.Enter;
  try
    if FHandle <> INVALID_HANDLE_VALUE then
    begin
      if FConnected then DisconnectNamedPipe(FHandle);
      CloseHandle(FHandle);
      FHandle := INVALID_HANDLE_VALUE;
      FConnected := False;
    end;
  finally
    FLock.Leave;
  end;
end;

{ TPipeClient }

constructor TPipeClient.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FHandle := INVALID_HANDLE_VALUE;
  SetLength(FBuffer, 0);
end;

destructor TPipeClient.Destroy;
begin
  Close;
  inherited;
end;

function TPipeClient.FullName: string;
begin
  Result := '\\.\pipe\' + FName;
end;

function TPipeClient.Connect(TimeoutMs: Cardinal): Boolean;
var
  Deadline: UInt64;
begin
  Deadline := GetTickCount64 + TimeoutMs;
  while True do
  begin
    FHandle := CreateFile(PChar(FullName), GENERIC_READ, 0, nil, OPEN_EXISTING, 0, 0);
    if FHandle <> INVALID_HANDLE_VALUE then Exit(True);
    if GetTickCount64 >= Deadline then Exit(False);
    if not WaitNamedPipe(PChar(FullName), 100) then
      Sleep(50);
  end;
end;

function TPipeClient.ReadByteCount(out B: Byte): Boolean;
var
  Got: DWORD;
begin
  Result := ReadFile(FHandle, B, 1, Got, nil) and (Got = 1);
end;

function TPipeClient.ReadLine(out S: string): Boolean;
var
  B: Byte;
  Buf: TBytes;
begin
  SetLength(Buf, 0);
  while ReadByteCount(B) do
  begin
    if B = 10 then
    begin
      S := TEncoding.UTF8.GetString(Buf);
      Exit(True);
    end;
    SetLength(Buf, Length(Buf) + 1);
    Buf[High(Buf)] := B;
  end;
  if Length(Buf) > 0 then
  begin
    S := TEncoding.UTF8.GetString(Buf);
    Exit(True);
  end;
  Result := False;
end;

procedure TPipeClient.Close;
begin
  if FHandle <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FHandle);
    FHandle := INVALID_HANDLE_VALUE;
  end;
end;

end.
