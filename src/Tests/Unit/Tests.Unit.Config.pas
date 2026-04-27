unit Tests.Unit.Config;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
  TaskForge.Core.Config;

type
  [TestFixture]
  TConfigTests = class
  public
    [Test] procedure Load_FromIni;
    [Test] procedure Load_EnvOverridesIni;
  end;

implementation

procedure WriteTempIni(const Path, Contents: string);
begin
  TFile.WriteAllText(Path, Contents);
end;

procedure TConfigTests.Load_FromIni;
var
  Path: string;
  Cfg: TConfig;
begin
  Path := TPath.Combine(TPath.GetTempPath, 'taskforge_test_' + IntToStr(GetTickCount) + '.ini');
  WriteTempIni(Path, '[api]'#10'port=9001'#10);
  try
    SetEnvironmentVariable('TASKFORGE_API_PORT', nil);
    Cfg := TConfig.Load(Path);
    Assert.AreEqual(9001, Cfg.ApiPort);
  finally
    TFile.Delete(Path);
  end;
end;

procedure TConfigTests.Load_EnvOverridesIni;
var
  Path: string;
  Cfg: TConfig;
begin
  Path := TPath.Combine(TPath.GetTempPath, 'taskforge_test_' + IntToStr(GetTickCount) + '.ini');
  WriteTempIni(Path, '[api]'#10'port=8080'#10);
  try
    SetEnvironmentVariable('TASKFORGE_API_PORT', PChar('9999'));
    try
      Cfg := TConfig.Load(Path);
      Assert.AreEqual(9999, Cfg.ApiPort);
    finally
      SetEnvironmentVariable('TASKFORGE_API_PORT', nil);
    end;
  finally
    TFile.Delete(Path);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TConfigTests);

end.
