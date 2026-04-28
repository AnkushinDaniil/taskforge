unit TaskForge.Core.EventBus;

interface

uses
  System.SysUtils,
  System.Classes,
  System.TypInfo,
  System.Rtti,
  System.Generics.Collections;

type
  // NOTE: Delphi disallows generic methods on interfaces (E2535), so we
  // expose the bus as a concrete class and let callers hold a TEventBus
  // reference directly. Lifetime is the caller's responsibility.
  TEventBus = class
  strict private
    type
      TThunk = reference to procedure(const Value: TValue);
  strict private
    FSubs: TDictionary<PTypeInfo, TList<TThunk>>;
    function GetOrCreateBucket(TI: PTypeInfo): TList<TThunk>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Subscribe<T>(const Handler: TProc<T>);
    procedure Publish<T>(const Event: T);
  end;

implementation

constructor TEventBus.Create;
begin
  inherited;
  FSubs := TObjectDictionary<PTypeInfo, TList<TThunk>>.Create([doOwnsValues]);
end;

destructor TEventBus.Destroy;
begin
  FSubs.Free;
  inherited;
end;

function TEventBus.GetOrCreateBucket(TI: PTypeInfo): TList<TThunk>;
begin
  if not FSubs.TryGetValue(TI, Result) then
  begin
    Result := TList<TThunk>.Create;
    FSubs.Add(TI, Result);
  end;
end;

procedure TEventBus.Subscribe<T>(const Handler: TProc<T>);
var
  Thunk: TThunk;
  Bucket: TList<TThunk>;
begin
  Thunk :=
    procedure(const V: TValue)
    begin
      Handler(V.AsType<T>);
    end;
  System.TMonitor.Enter(Self);
  try
    Bucket := GetOrCreateBucket(TypeInfo(T));
    Bucket.Add(Thunk);
  finally
    System.TMonitor.Exit(Self);
  end;
end;

procedure TEventBus.Publish<T>(const Event: T);
var
  Bucket: TList<TThunk>;
  Snapshot: TArray<TThunk>;
  V: TValue;
  Th: TThunk;
begin
  System.TMonitor.Enter(Self);
  try
    if not FSubs.TryGetValue(TypeInfo(T), Bucket) then
      Exit;
    Snapshot := Bucket.ToArray;
  finally
    System.TMonitor.Exit(Self);
  end;
  V := TValue.From<T>(Event);
  for Th in Snapshot do
    Th(V);
end;

end.
