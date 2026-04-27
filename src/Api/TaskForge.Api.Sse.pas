unit TaskForge.Api.Sse;

interface

uses
  System.SysUtils,
  System.Classes,
  IdContext,
  IdGlobal;

type
  TSseStream = class
  strict private
    FContext: TIdContext;
  public
    constructor Create(AContext: TIdContext);
    procedure SendEvent(const EventName, Data: string);
    procedure SendComment(const C: string);
    procedure SendKeepalive;
    function IsClosed: Boolean;
  end;

implementation

constructor TSseStream.Create(AContext: TIdContext);
begin
  inherited Create;
  FContext := AContext;
end;

procedure TSseStream.SendEvent(const EventName, Data: string);
var
  Frame: string;
begin
  Frame := '';
  if EventName <> '' then
    Frame := Frame + 'event: ' + EventName + #10;
  Frame := Frame + 'data: ' + Data + #10#10;
  FContext.Connection.IOHandler.Write(Frame, IndyTextEncoding_UTF8);
end;

procedure TSseStream.SendComment(const C: string);
begin
  FContext.Connection.IOHandler.Write(': ' + C + #10#10, IndyTextEncoding_UTF8);
end;

procedure TSseStream.SendKeepalive;
begin
  SendComment('keepalive');
end;

function TSseStream.IsClosed: Boolean;
begin
  Result := (FContext = nil) or (FContext.Connection = nil) or
            (not FContext.Connection.Connected);
end;

end.
