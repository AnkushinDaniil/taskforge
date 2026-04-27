unit TaskForge.Admin.Main;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.Menus,
  Winapi.Windows,
  Winapi.Messages,
  TaskForge.Admin.ViewModels,
  TaskForge.Admin.HttpClient,
  TaskForge.Admin.Theme;

type
  TFormMain = class(TForm)
    PanelTop: TPanel;
    EditFilter: TEdit;
    ButtonRefresh: TButton;
    ButtonTheme: TButton;
    ListViewTasks: TListView;
    PanelDetail: TPanel;
    LabelTitle: TLabel;
    EditTitle: TEdit;
    LabelStatus: TLabel;
    ComboStatus: TComboBox;
    LabelDueAt: TLabel;
    EditDueAt: TEdit;
    ButtonSave: TButton;
    ButtonNew: TButton;
    ButtonDelete: TButton;
    DebounceTimer: TTimer;
    StatusBar1: TStatusBar;
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
    procedure ButtonRefreshClick(Sender: TObject);
    procedure ButtonThemeClick(Sender: TObject);
    procedure ButtonSaveClick(Sender: TObject);
    procedure ButtonNewClick(Sender: TObject);
    procedure ButtonDeleteClick(Sender: TObject);
    procedure EditFilterChange(Sender: TObject);
    procedure DebounceTimerTimer(Sender: TObject);
    procedure ListViewTasksData(Sender: TObject; Item: TListItem);
    procedure ListViewTasksSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
  private
    FAll: TTaskList;
    FView: TList<TTaskVM>;
    FApi: TApiClient;
    FSelected: TTaskVM;
    procedure RefreshList;
    procedure ApplyFilter;
    procedure UpdateDetailPanel;
    procedure SetStatus(const S: string);
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

procedure TFormMain.FormCreate(Sender: TObject);
begin
  FAll := TTaskList.Create(True);
  FView := TList<TTaskVM>.Create;
  FApi := TApiClient.Create('http://localhost:8080');
  ComboStatus.Items.CommaText := 'open,done,cancelled';
  RestoreSavedTheme;
  ListViewTasks.OwnerData := True;
  ListViewTasks.ViewStyle := vsReport;
  ListViewTasks.Columns.Clear;
  with ListViewTasks.Columns.Add do begin Caption := 'ID'; Width := 60; end;
  with ListViewTasks.Columns.Add do begin Caption := 'Title'; Width := 220; end;
  with ListViewTasks.Columns.Add do begin Caption := 'Status'; Width := 90; end;
  with ListViewTasks.Columns.Add do begin Caption := 'Due At'; Width := 180; end;
  RefreshList;
end;

procedure TFormMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  FApi.CancelAll;
  CanClose := True;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  FApi.Free;
  FView.Free;
  FAll.Free;
end;

procedure TFormMain.SetStatus(const S: string);
begin
  StatusBar1.SimpleText := S;
end;

procedure TFormMain.RefreshList;
begin
  SetStatus('Loading...');
  FApi.ListAsync(
    procedure(Items: TArray<TTaskVM>)
    var
      VM: TTaskVM;
    begin
      FAll.Clear;
      for VM in Items do
        FAll.Add(VM);
      ApplyFilter;
      SetStatus(Format('%d tasks loaded', [FAll.Count]));
    end,
    procedure(Err: string)
    begin
      SetStatus('Error: ' + Err);
    end);
end;

procedure TFormMain.ApplyFilter;
var
  Q: string;
  VM: TTaskVM;
begin
  Q := LowerCase(Trim(EditFilter.Text));
  FView.Clear;
  for VM in FAll do
    if (Q = '') or (Pos(Q, LowerCase(VM.Title)) > 0) then
      FView.Add(VM);
  ListViewTasks.Items.Count := FView.Count;
  ListViewTasks.Invalidate;
end;

procedure TFormMain.ButtonRefreshClick(Sender: TObject);
begin
  RefreshList;
end;

procedure TFormMain.ButtonThemeClick(Sender: TObject);
begin
  ToggleTheme;
end;

procedure TFormMain.ButtonNewClick(Sender: TObject);
begin
  FSelected := nil;
  EditTitle.Text := '';
  ComboStatus.ItemIndex := 0;
  EditDueAt.Text := '';
  EditTitle.SetFocus;
end;

procedure TFormMain.ButtonSaveClick(Sender: TObject);
var
  Body: string;
  Res: THttpResult;
  IfMatch: string;
begin
  Body := Format(
    '{"title":"%s","status":"%s","due_at":"%s"}',
    [EditTitle.Text, ComboStatus.Text, EditDueAt.Text]);
  if FSelected = nil then
    Res := FApi.Post('/tasks', Body)
  else
  begin
    IfMatch := Format('W/"%d-%d"', [FSelected.Id, FSelected.Version]);
    Res := FApi.Patch('/tasks/' + IntToStr(FSelected.Id), Body, IfMatch);
  end;
  if Res.StatusCode in [200, 201] then
  begin
    SetStatus('Saved');
    RefreshList;
  end
  else
    SetStatus(Format('Save failed: HTTP %d', [Res.StatusCode]));
end;

procedure TFormMain.ButtonDeleteClick(Sender: TObject);
var
  Res: THttpResult;
begin
  if FSelected = nil then Exit;
  Res := FApi.Delete('/tasks/' + IntToStr(FSelected.Id));
  if Res.StatusCode = 204 then
  begin
    SetStatus('Deleted');
    RefreshList;
  end
  else
    SetStatus(Format('Delete failed: HTTP %d', [Res.StatusCode]));
end;

procedure TFormMain.EditFilterChange(Sender: TObject);
begin
  DebounceTimer.Enabled := False;
  DebounceTimer.Enabled := True;
end;

procedure TFormMain.DebounceTimerTimer(Sender: TObject);
begin
  DebounceTimer.Enabled := False;
  ApplyFilter;
end;

procedure TFormMain.ListViewTasksData(Sender: TObject; Item: TListItem);
var
  VM: TTaskVM;
begin
  if (Item.Index < 0) or (Item.Index >= FView.Count) then Exit;
  VM := FView[Item.Index];
  Item.Caption := IntToStr(VM.Id);
  Item.SubItems.Add(VM.Title);
  Item.SubItems.Add(VM.Status);
  Item.SubItems.Add(VM.DueAt);
end;

procedure TFormMain.ListViewTasksSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if not Selected or (Item = nil) then Exit;
  if (Item.Index < 0) or (Item.Index >= FView.Count) then Exit;
  FSelected := FView[Item.Index];
  UpdateDetailPanel;
end;

procedure TFormMain.UpdateDetailPanel;
begin
  if FSelected = nil then Exit;
  EditTitle.Text := FSelected.Title;
  ComboStatus.ItemIndex := ComboStatus.Items.IndexOf(FSelected.Status);
  EditDueAt.Text := FSelected.DueAt;
end;

end.
