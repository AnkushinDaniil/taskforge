unit TaskForge.Core.Json;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.JSON,
  TaskForge.Core.Rtti;

type
  EJsonMap = class(Exception);

  TJsonMapper = class
  public
    class function ToJson<T>(const Rec: T): TJSONObject;
    class function FromJson<T>(const Obj: TJSONObject): T;
    class function SerializeRecord<T>(const Rec: T): string;
    class function DeserializeRecord<T>(const S: string): T;
  end;

implementation

class function TJsonMapper.ToJson<T>(const Rec: T): TJSONObject;
var
  Map: TRecordMap;
  FM: TFieldMap;
  V: TValue;
  RecValue: TValue;
  Kind: TTypeKind;
begin
  Map := TRttiHelper.MapOf<T>;
  Result := TJSONObject.Create;
  RecValue := TValue.From<T>(Rec);
  for FM in Map.Fields do
  begin
    if FM.JsonIgnored then Continue;
    V := FM.Field.GetValue(RecValue.GetReferenceToRawData);
    Kind := FM.Field.FieldType.TypeKind;
    case Kind of
      tkInteger, tkInt64:
        Result.AddPair(FM.JsonName, TJSONNumber.Create(V.AsInt64));
      tkFloat:
        Result.AddPair(FM.JsonName, TJSONNumber.Create(V.AsExtended));
      tkUString, tkString, tkLString, tkWString:
        Result.AddPair(FM.JsonName, V.AsString);
      tkEnumeration:
        if FM.Field.FieldType.Handle = TypeInfo(Boolean) then
          Result.AddPair(FM.JsonName, TJSONBool.Create(V.AsBoolean))
        else
          Result.AddPair(FM.JsonName, GetEnumName(FM.Field.FieldType.Handle, V.AsOrdinal));
    else
      Result.AddPair(FM.JsonName, V.ToString);
    end;
  end;
end;

class function TJsonMapper.FromJson<T>(const Obj: TJSONObject): T;
var
  Map: TRecordMap;
  FM: TFieldMap;
  RecValue: TValue;
  Pair: TJSONPair;
  Kind: TTypeKind;
  AsInt: Int64;
  AsFloat: Double;
  AsBool: Boolean;
  Ord: Integer;
begin
  Result := Default(T);
  Map := TRttiHelper.MapOf<T>;
  RecValue := TValue.From<T>(Result);
  for FM in Map.Fields do
  begin
    if FM.JsonIgnored then Continue;
    Pair := Obj.Get(FM.JsonName);
    if Pair = nil then Continue;
    Kind := FM.Field.FieldType.TypeKind;
    case Kind of
      tkInteger, tkInt64:
        if Pair.JsonValue.TryGetValue<Int64>(AsInt) then
          FM.Field.SetValue(RecValue.GetReferenceToRawData, TValue.From<Int64>(AsInt));
      tkFloat:
        if Pair.JsonValue.TryGetValue<Double>(AsFloat) then
          FM.Field.SetValue(RecValue.GetReferenceToRawData, TValue.From<Double>(AsFloat));
      tkUString, tkString, tkLString, tkWString:
        FM.Field.SetValue(RecValue.GetReferenceToRawData, TValue.From<string>(Pair.JsonValue.Value));
      tkEnumeration:
        if FM.Field.FieldType.Handle = TypeInfo(Boolean) then
        begin
          if Pair.JsonValue.TryGetValue<Boolean>(AsBool) then
            FM.Field.SetValue(RecValue.GetReferenceToRawData, TValue.From<Boolean>(AsBool));
        end
        else
        begin
          Ord := GetEnumValue(FM.Field.FieldType.Handle, Pair.JsonValue.Value);
          if Ord >= 0 then
            FM.Field.SetValue(RecValue.GetReferenceToRawData, TValue.FromOrdinal(FM.Field.FieldType.Handle, Ord));
        end;
    end;
  end;
  Result := RecValue.AsType<T>;
end;

class function TJsonMapper.SerializeRecord<T>(const Rec: T): string;
var
  J: TJSONObject;
begin
  J := ToJson<T>(Rec);
  try
    Result := J.ToJSON;
  finally
    J.Free;
  end;
end;

class function TJsonMapper.DeserializeRecord<T>(const S: string): T;
var
  V: TJSONValue;
begin
  V := TJSONObject.ParseJSONValue(S);
  if not (V is TJSONObject) then
  begin
    V.Free;
    raise EJsonMap.Create('Expected JSON object');
  end;
  try
    Result := FromJson<T>(TJSONObject(V));
  finally
    V.Free;
  end;
end;

end.
