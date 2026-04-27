unit TaskForge.Core.Attributes;

interface

uses
  System.Rtti;

type
  // Persistence
  TableAttribute = class(TCustomAttribute)
  strict private
    FName: string;
  public
    constructor Create(const AName: string);
    property Name: string read FName;
  end;

  ColumnAttribute = class(TCustomAttribute)
  strict private
    FName: string;
  public
    constructor Create(const AName: string);
    property Name: string read FName;
  end;

  PrimaryKeyAttribute = class(TCustomAttribute)
  end;

  // JSON
  JsonNameAttribute = class(TCustomAttribute)
  strict private
    FName: string;
  public
    constructor Create(const AName: string);
    property Name: string read FName;
  end;

  JsonIgnoreAttribute = class(TCustomAttribute)
  end;

  // Routing
  RouteAttribute = class(TCustomAttribute)
  strict private
    FMethod: string;
    FPath: string;
  public
    constructor Create(const AMethod, APath: string);
    property Method: string read FMethod;
    property Path: string read FPath;
  end;

implementation

constructor TableAttribute.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

constructor ColumnAttribute.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

constructor JsonNameAttribute.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

constructor RouteAttribute.Create(const AMethod, APath: string);
begin
  inherited Create;
  FMethod := AMethod;
  FPath := APath;
end;

end.
