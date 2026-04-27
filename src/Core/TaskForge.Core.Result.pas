unit TaskForge.Core.Result;

interface

uses
  System.SysUtils;

type
  EResultUnwrap = class(Exception);

  Result<T> = record
  strict private
    type
      TState = (rsOk, rsErr);
    var
      FState: TState;
      FValue: T;
      FError: string;
      FCode: Integer;
  public
    class function Ok(const V: T): Result<T>; static;
    class function Err(const Msg: string; Code: Integer = 0): Result<T>; static;

    function IsOk: Boolean; inline;
    function IsErr: Boolean; inline;
    function Unwrap: T;
    function UnwrapOr(const Default: T): T;
    function ErrorMessage: string; inline;
    function ErrorCode: Integer; inline;

    class operator Implicit(const V: T): Result<T>;
  end;

implementation

class function Result<T>.Ok(const V: T): Result<T>;
begin
  Result.FState := rsOk;
  Result.FValue := V;
  Result.FError := '';
  Result.FCode := 0;
end;

class function Result<T>.Err(const Msg: string; Code: Integer): Result<T>;
begin
  Result.FState := rsErr;
  Result.FValue := Default(T);
  Result.FError := Msg;
  Result.FCode := Code;
end;

function Result<T>.IsOk: Boolean;
begin
  Result := FState = rsOk;
end;

function Result<T>.IsErr: Boolean;
begin
  Result := FState = rsErr;
end;

function Result<T>.Unwrap: T;
begin
  if FState <> rsOk then
    raise EResultUnwrap.Create('Cannot unwrap Err: ' + FError);
  Result := FValue;
end;

function Result<T>.UnwrapOr(const Default: T): T;
begin
  if FState = rsOk then
    Result := FValue
  else
    Result := Default;
end;

function Result<T>.ErrorMessage: string;
begin
  Result := FError;
end;

function Result<T>.ErrorCode: Integer;
begin
  Result := FCode;
end;

class operator Result<T>.Implicit(const V: T): Result<T>;
begin
  Result := Result<T>.Ok(V);
end;

end.
