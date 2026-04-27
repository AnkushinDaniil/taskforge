unit Tests.Support.Ports;

interface

uses
  System.SysUtils,
  Winapi.Windows,
  Winapi.Winsock2;

type
  TPortAllocator = class
  public
    class function NextFree: Word; static;
  end;

implementation

class function TPortAllocator.NextFree: Word;
var
  Sock: TSocket;
  Addr: TSockAddrIn;
  Sz: Integer;
  Data: TWSAData;
begin
  WSAStartup($0202, Data);
  Sock := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if Sock = INVALID_SOCKET then RaiseLastOSError;
  try
    FillChar(Addr, SizeOf(Addr), 0);
    Addr.sin_family := AF_INET;
    Addr.sin_port := 0;
    Addr.sin_addr.S_addr := htonl(INADDR_LOOPBACK);
    if bind(Sock, TSockAddr(Addr), SizeOf(Addr)) <> 0 then RaiseLastOSError;
    Sz := SizeOf(Addr);
    if getsockname(Sock, TSockAddr(Addr), Sz) <> 0 then RaiseLastOSError;
    Result := ntohs(Addr.sin_port);
  finally
    closesocket(Sock);
  end;
end;

end.
