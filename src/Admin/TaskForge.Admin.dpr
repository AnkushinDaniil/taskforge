program TaskForge.Admin;

uses
  Vcl.Forms,
  Vcl.Themes,
  Vcl.Styles,
  TaskForge.Admin.ViewModels in 'TaskForge.Admin.ViewModels.pas',
  TaskForge.Admin.Mvvm in 'TaskForge.Admin.Mvvm.pas',
  TaskForge.Admin.HttpClient in 'TaskForge.Admin.HttpClient.pas',
  TaskForge.Admin.Theme in 'TaskForge.Admin.Theme.pas',
  TaskForge.Admin.Main in 'TaskForge.Admin.Main.pas' {FormMain};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Windows');
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
