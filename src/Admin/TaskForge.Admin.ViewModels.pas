unit TaskForge.Admin.ViewModels;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  TTaskVM = class
  private
    FId: Int64;
    FTitle: string;
    FStatus: string;
    FDueAt: string;
    FVersion: Integer;
    FIsDirty: Boolean;
  public
    property Id: Int64 read FId write FId;
    property Title: string read FTitle write FTitle;
    property Status: string read FStatus write FStatus;
    property DueAt: string read FDueAt write FDueAt;
    property Version: Integer read FVersion write FVersion;
    property IsDirty: Boolean read FIsDirty write FIsDirty;
  end;

  TTaskList = TObjectList<TTaskVM>;

implementation

end.
