@echo off
setlocal EnableDelayedExpansion

if not defined BDS (
    if exist "%PROGRAMFILES(X86)%\Embarcadero\Studio\23.0\bin\rsvars.bat" (
        call "%PROGRAMFILES(X86)%\Embarcadero\Studio\23.0\bin\rsvars.bat"
    ) else if exist "%PROGRAMFILES(X86)%\Embarcadero\Studio\22.0\bin\rsvars.bat" (
        call "%PROGRAMFILES(X86)%\Embarcadero\Studio\22.0\bin\rsvars.bat"
    ) else (
        echo ERROR: rsvars.bat not found. Set BDS env var to your RAD Studio installation.
        exit /b 1
    )
)

set ROOT=%~dp0
set OUT=%ROOT%bin
if not exist "%OUT%" mkdir "%OUT%"
if not exist "%OUT%\dcu" mkdir "%OUT%\dcu"

set SRC=%ROOT%src

REM Build resources (brcc32 -> res) for binaries that embed migrations.
REM brcc32 is RAD Studio's Borland Resource Compiler (put on PATH by
REM rsvars.bat). It uses Borland-style options (-fo<file>) and does not
REM require the Windows SDK rc.exe — which is what fails on a clean
REM install with the cryptic "RC1106: invalid option: -ologo".
where /q brcc32.exe || (
    echo ERROR: brcc32.exe not found on PATH. Make sure rsvars.bat ran successfully.
    exit /b 1
)
pushd "%SRC%\Worker"
brcc32 -fomigrations.res migrations.rc || ( popd & exit /b 1 )
popd
pushd "%SRC%\Api"
brcc32 -fomigrations.res migrations.rc || ( popd & exit /b 1 )
popd

set COMMON=-Q -B ^
  -NSSystem;System.Win;Vcl;Winapi;Data;Data.Win;FireDAC;IdGlobal ^
  -E"%OUT%" ^
  -N"%OUT%\dcu" ^
  -U"%SRC%\Core"

echo === Building TaskForge.Worker.exe ===
dcc64 %COMMON% -U"%SRC%\Worker" "%SRC%\Worker\TaskForge.Worker.dpr" || goto :err

echo === Building TaskForge.Api.exe ===
dcc64 %COMMON% -U"%SRC%\Api" "%SRC%\Api\TaskForge.Api.dpr" || goto :err

echo === Building TaskForge.Admin.exe ===
dcc64 %COMMON% -U"%SRC%\Admin" "%SRC%\Admin\TaskForge.Admin.dpr" || goto :err

echo === Building TaskForge.Tests.exe ===
dcc64 %COMMON% -U"%SRC%\Api;%SRC%\Worker;%SRC%\Tests;%SRC%\Tests\Support;%SRC%\Tests\Unit;%SRC%\Tests\Integration" ^
  "%SRC%\Tests\TaskForge.Tests.dpr" || goto :err

echo BUILD OK
exit /b 0

:err
echo BUILD FAILED
exit /b 1
