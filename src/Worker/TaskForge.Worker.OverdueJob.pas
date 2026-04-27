unit TaskForge.Worker.OverdueJob;

interface

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  FireDAC.Comp.Client,
  TaskForge.Core.EventBus,
  TaskForge.Core.Logging,
  TaskForge.Core.Domain.Tasks;

type
  TOverdueJob = class
  strict private
    FConn: TFDConnection;
    FBus: IEventBus;
    FLogger: TJsonLogger;
  public
    constructor Create(AConn: TFDConnection; ABus: IEventBus; ALogger: TJsonLogger);
    procedure Scan;
  end;

implementation

constructor TOverdueJob.Create(AConn: TFDConnection; ABus: IEventBus; ALogger: TJsonLogger);
begin
  inherited Create;
  FConn := AConn;
  FBus := ABus;
  FLogger := ALogger;
end;

procedure TOverdueJob.Scan;
var
  Q: TFDQuery;
  Now: string;
  Evt: TTaskOverdue;
  Count: Integer;
begin
  Now := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', TTimeZone.Local.ToUniversalTime(System.SysUtils.Now));
  Count := 0;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConn;
    Q.SQL.Text := 'SELECT id, title, due_at FROM tasks WHERE status = :st AND due_at IS NOT NULL AND due_at < :now';
    Q.ParamByName('st').AsString := 'open';
    Q.ParamByName('now').AsString := Now;
    Q.Open;
    while not Q.Eof do
    begin
      Evt.Id := Q.FieldByName('id').AsLargeInt;
      Evt.Title := Q.FieldByName('title').AsString;
      Evt.DueAt := Q.FieldByName('due_at').AsString;
      FBus.Publish<TTaskOverdue>(Evt);
      Inc(Count);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  if Count > 0 then
    FLogger.Info('overdue scan complete', [Ctx('count', Count)]);
end;

end.
