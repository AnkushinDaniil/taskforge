unit TaskForge.Api.ETag;

interface

uses
  System.SysUtils;

function ComputeETag(Id: Int64; Version: Integer): string;
function MatchesETag(const IfNoneMatch, ETag: string): Boolean;

implementation

function ComputeETag(Id: Int64; Version: Integer): string;
begin
  Result := Format('W/"%d-%d"', [Id, Version]);
end;

function MatchesETag(const IfNoneMatch, ETag: string): Boolean;
begin
  Result := Trim(IfNoneMatch) = ETag;
end;

end.
