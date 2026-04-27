unit TaskForge.Core.Domain.Tasks;

interface

uses
  TaskForge.Core.Attributes;

type
  TTaskStatus = (tsOpen, tsDone, tsCancelled);

  [Table('tasks')]
  TTask = record
    [PrimaryKey]
    [Column('id')]
    Id: Int64;

    [Column('title')]
    Title: string;

    [Column('status')]
    Status: string;

    [Column('due_at')]
    [JsonName('due_at')]
    DueAt: string;

    [Column('version')]
    [JsonIgnore]
    Version: Integer;

    [Column('created_at')]
    [JsonName('created_at')]
    CreatedAt: string;
  end;

  TTaskOverdue = record
    Id: Int64;
    Title: string;
    DueAt: string;
  end;

function StatusToString(S: TTaskStatus): string;
function StringToStatus(const S: string): TTaskStatus;

implementation

function StatusToString(S: TTaskStatus): string;
begin
  case S of
    tsOpen:      Result := 'open';
    tsDone:      Result := 'done';
    tsCancelled: Result := 'cancelled';
  else
    Result := 'open';
  end;
end;

function StringToStatus(const S: string): TTaskStatus;
begin
  if S = 'done' then Exit(tsDone);
  if S = 'cancelled' then Exit(tsCancelled);
  Result := tsOpen;
end;

end.
