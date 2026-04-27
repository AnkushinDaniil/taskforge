unit TaskForge.Core.Rtti;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  TaskForge.Core.Attributes;

type
  TFieldMap = record
    Field: TRttiField;
    ColumnName: string;
    JsonName: string;
    JsonIgnored: Boolean;
    IsPrimaryKey: Boolean;
  end;

  TRecordMap = record
    TableName: string;
    Fields: TArray<TFieldMap>;
    PrimaryKeyIndex: Integer; // -1 if none
  end;

  TRttiHelper = class
  strict private
    class var FCtx: TRttiContext;
    class var FCache: TDictionary<PTypeInfo, TRecordMap>;
  public
    class constructor CreateCls;
    class destructor DestroyCls;
    class function MapOf<T>: TRecordMap; static;
  end;

implementation

class constructor TRttiHelper.CreateCls;
begin
  FCtx := TRttiContext.Create;
  FCache := TDictionary<PTypeInfo, TRecordMap>.Create;
end;

class destructor TRttiHelper.DestroyCls;
begin
  FCache.Free;
  FCtx.Free;
end;

class function TRttiHelper.MapOf<T>: TRecordMap;
var
  TI: PTypeInfo;
  RT: TRttiType;
  F: TRttiField;
  A: TCustomAttribute;
  FM: TFieldMap;
  Idx: Integer;
begin
  TI := TypeInfo(T);
  if FCache.TryGetValue(TI, Result) then Exit;

  RT := FCtx.GetType(TI);
  Result.TableName := '';
  SetLength(Result.Fields, 0);
  Result.PrimaryKeyIndex := -1;

  for A in RT.GetAttributes do
    if A is TableAttribute then
      Result.TableName := TableAttribute(A).Name;

  Idx := 0;
  for F in RT.GetFields do
  begin
    FM := Default(TFieldMap);
    FM.Field := F;
    FM.ColumnName := F.Name;
    FM.JsonName := F.Name;
    for A in F.GetAttributes do
    begin
      if A is ColumnAttribute then FM.ColumnName := ColumnAttribute(A).Name;
      if A is JsonNameAttribute then FM.JsonName := JsonNameAttribute(A).Name;
      if A is JsonIgnoreAttribute then FM.JsonIgnored := True;
      if A is PrimaryKeyAttribute then
      begin
        FM.IsPrimaryKey := True;
        Result.PrimaryKeyIndex := Idx;
      end;
    end;
    SetLength(Result.Fields, Length(Result.Fields) + 1);
    Result.Fields[High(Result.Fields)] := FM;
    Inc(Idx);
  end;

  FCache.Add(TI, Result);
end;

end.
