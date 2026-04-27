unit TaskForge.Admin.Mvvm;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  TObservable<T> = class
  strict private
    FValue: T;
    FOnChanged: TProc<T>;
    procedure SetValue(const Val: T);
  public
    constructor Create(const Initial: T);
    property Value: T read FValue write SetValue;
    property OnChanged: TProc<T> read FOnChanged write FOnChanged;
  end;

implementation

constructor TObservable<T>.Create(const Initial: T);
begin
  inherited Create;
  FValue := Initial;
end;

procedure TObservable<T>.SetValue(const Val: T);
begin
  FValue := Val;
  if Assigned(FOnChanged) then FOnChanged(FValue);
end;

end.
