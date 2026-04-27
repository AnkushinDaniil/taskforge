unit TaskForge.Core.Repository;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  TaskForge.Core.Attributes,
  TaskForge.Core.Rtti,
  TaskForge.Core.Result;

type
  TQueryFilter = record
    Status: string;     // empty = no filter
    Limit: Integer;     // 0 = no limit
  end;

  TRepository<T: record> = class
  strict private
    FConn: TFDConnection;
    function ColumnList(const Map: TRecordMap; ExcludePk: Boolean): string;
    function ParamList(const Map: TRecordMap; ExcludePk: Boolean): string;
    function SetClause(const Map: TRecordMap): string;
    procedure BindRecord(const Q: TFDQuery; const Map: TRecordMap; const Rec: T; ExcludePk: Boolean);
    function ReadRecord(const Q: TFDQuery; const Map: TRecordMap): T;
  public
    constructor Create(AConn: TFDConnection);
    function GetById(Id: Int64): Result<T>;
    function List(const Filter: TQueryFilter): Result<TArray<T>>;
    function Insert(const Rec: T): Result<Int64>;
    function Update(const Rec: T; ExpectedVersion: Integer): Result<Boolean>;
    function Delete(Id: Int64): Result<Boolean>;
  end;

implementation

constructor TRepository<T>.Create(AConn: TFDConnection);
begin
  inherited Create;
  FConn := AConn;
end;

function TRepository<T>.ColumnList(const Map: TRecordMap; ExcludePk: Boolean): string;
var
  i: Integer;
  FM: TFieldMap;
  First: Boolean;
begin
  Result := '';
  First := True;
  for i := 0 to High(Map.Fields) do
  begin
    FM := Map.Fields[i];
    if ExcludePk and FM.IsPrimaryKey then Continue;
    if not First then Result := Result + ', ';
    Result := Result + FM.ColumnName;
    First := False;
  end;
end;

function TRepository<T>.ParamList(const Map: TRecordMap; ExcludePk: Boolean): string;
var
  i: Integer;
  FM: TFieldMap;
  First: Boolean;
begin
  Result := '';
  First := True;
  for i := 0 to High(Map.Fields) do
  begin
    FM := Map.Fields[i];
    if ExcludePk and FM.IsPrimaryKey then Continue;
    if not First then Result := Result + ', ';
    Result := Result + ':' + FM.ColumnName;
    First := False;
  end;
end;

function TRepository<T>.SetClause(const Map: TRecordMap): string;
var
  i: Integer;
  FM: TFieldMap;
  First: Boolean;
begin
  Result := '';
  First := True;
  for i := 0 to High(Map.Fields) do
  begin
    FM := Map.Fields[i];
    if FM.IsPrimaryKey then Continue;
    if SameText(FM.ColumnName, 'version') then Continue; // bumped explicitly
    if not First then Result := Result + ', ';
    Result := Result + FM.ColumnName + ' = :' + FM.ColumnName;
    First := False;
  end;
  if Result <> '' then Result := Result + ', ';
  Result := Result + 'version = version + 1';
end;

procedure TRepository<T>.BindRecord(const Q: TFDQuery; const Map: TRecordMap; const Rec: T; ExcludePk: Boolean);
var
  i: Integer;
  FM: TFieldMap;
  V: TValue;
  RecValue: TValue;
  SkipVersion: Boolean;
begin
  // Updates use `version = version + 1` in the SET clause, so :version is
  // not a parameter. Inserts include version as a regular column.
  SkipVersion := not ExcludePk;
  RecValue := TValue.From<T>(Rec);
  for i := 0 to High(Map.Fields) do
  begin
    FM := Map.Fields[i];
    if ExcludePk and FM.IsPrimaryKey then Continue;
    if SkipVersion and SameText(FM.ColumnName, 'version') then Continue;
    V := FM.Field.GetValue(RecValue.GetReferenceToRawData);
    Q.ParamByName(FM.ColumnName).Value := V.AsVariant;
  end;
end;

function TRepository<T>.ReadRecord(const Q: TFDQuery; const Map: TRecordMap): T;
var
  i: Integer;
  FM: TFieldMap;
  RecValue: TValue;
  Field: TField;
  V: TValue;
begin
  Result := Default(T);
  RecValue := TValue.From<T>(Result);
  for i := 0 to High(Map.Fields) do
  begin
    FM := Map.Fields[i];
    Field := Q.FindField(FM.ColumnName);
    if (Field = nil) or Field.IsNull then Continue;
    case FM.Field.FieldType.TypeKind of
      tkInteger, tkInt64:
        V := TValue.From<Int64>(Field.AsLargeInt);
      tkFloat:
        V := TValue.From<Double>(Field.AsFloat);
    else
      V := TValue.From<string>(Field.AsString);
    end;
    FM.Field.SetValue(RecValue.GetReferenceToRawData, V);
  end;
  Result := RecValue.AsType<T>;
end;

function TRepository<T>.GetById(Id: Int64): Result<T>;
var
  Map: TRecordMap;
  Q: TFDQuery;
  Pk: TFieldMap;
begin
  Map := TRttiHelper.MapOf<T>;
  if Map.PrimaryKeyIndex < 0 then
    Exit(Result<T>.Err('No primary key on record'));
  Pk := Map.Fields[Map.PrimaryKeyIndex];
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConn;
    Q.SQL.Text := 'SELECT ' + ColumnList(Map, False) + ' FROM ' + Map.TableName +
                  ' WHERE ' + Pk.ColumnName + ' = :id';
    Q.ParamByName('id').AsLargeInt := Id;
    Q.Open;
    if Q.Eof then
      Exit(Result<T>.Err('Not found', 404));
    Exit(Result<T>.Ok(ReadRecord(Q, Map)));
  finally
    Q.Free;
  end;
end;

function TRepository<T>.List(const Filter: TQueryFilter): Result<TArray<T>>;
var
  Map: TRecordMap;
  Q: TFDQuery;
  Rows: TList<T>;
  SQL: string;
begin
  Map := TRttiHelper.MapOf<T>;
  Rows := TList<T>.Create;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConn;
    SQL := 'SELECT ' + ColumnList(Map, False) + ' FROM ' + Map.TableName;
    if Filter.Status <> '' then
      SQL := SQL + ' WHERE status = :status';
    SQL := SQL + ' ORDER BY id DESC';
    if Filter.Limit > 0 then
      SQL := SQL + ' LIMIT :lim';
    Q.SQL.Text := SQL;
    if Filter.Status <> '' then
      Q.ParamByName('status').AsString := Filter.Status;
    if Filter.Limit > 0 then
      Q.ParamByName('lim').AsInteger := Filter.Limit;
    Q.Open;
    while not Q.Eof do
    begin
      Rows.Add(ReadRecord(Q, Map));
      Q.Next;
    end;
    Exit(Result<TArray<T>>.Ok(Rows.ToArray));
  finally
    Rows.Free;
    Q.Free;
  end;
end;

function TRepository<T>.Insert(const Rec: T): Result<Int64>;
var
  Map: TRecordMap;
  Q: TFDQuery;
  NewId: Int64;
begin
  Map := TRttiHelper.MapOf<T>;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConn;
    Q.SQL.Text := 'INSERT INTO ' + Map.TableName + ' (' + ColumnList(Map, True) + ') VALUES (' + ParamList(Map, True) + ')';
    BindRecord(Q, Map, Rec, True);
    Q.ExecSQL;
    NewId := FConn.GetLastAutoGenValue('');
    Exit(Result<Int64>.Ok(NewId));
  finally
    Q.Free;
  end;
end;

function TRepository<T>.Update(const Rec: T; ExpectedVersion: Integer): Result<Boolean>;
var
  Map: TRecordMap;
  Q: TFDQuery;
  Pk: TFieldMap;
  PkVal: TValue;
  RecValue: TValue;
begin
  Map := TRttiHelper.MapOf<T>;
  if Map.PrimaryKeyIndex < 0 then
    Exit(Result<Boolean>.Err('No primary key'));
  Pk := Map.Fields[Map.PrimaryKeyIndex];
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConn;
    Q.SQL.Text := 'UPDATE ' + Map.TableName + ' SET ' + SetClause(Map) +
                  ' WHERE ' + Pk.ColumnName + ' = :' + Pk.ColumnName +
                  ' AND version = :_expected_version';
    BindRecord(Q, Map, Rec, False);
    RecValue := TValue.From<T>(Rec);
    PkVal := Pk.Field.GetValue(RecValue.GetReferenceToRawData);
    Q.ParamByName(Pk.ColumnName).AsLargeInt := PkVal.AsInt64;
    Q.ParamByName('_expected_version').AsInteger := ExpectedVersion;
    Q.ExecSQL;
    Exit(Result<Boolean>.Ok(Q.RowsAffected > 0));
  finally
    Q.Free;
  end;
end;

function TRepository<T>.Delete(Id: Int64): Result<Boolean>;
var
  Map: TRecordMap;
  Q: TFDQuery;
  Pk: TFieldMap;
begin
  Map := TRttiHelper.MapOf<T>;
  if Map.PrimaryKeyIndex < 0 then
    Exit(Result<Boolean>.Err('No primary key'));
  Pk := Map.Fields[Map.PrimaryKeyIndex];
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConn;
    Q.SQL.Text := 'DELETE FROM ' + Map.TableName + ' WHERE ' + Pk.ColumnName + ' = :id';
    Q.ParamByName('id').AsLargeInt := Id;
    Q.ExecSQL;
    Exit(Result<Boolean>.Ok(Q.RowsAffected > 0));
  finally
    Q.Free;
  end;
end;

end.
