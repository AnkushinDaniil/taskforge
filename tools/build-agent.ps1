# TaskForge build agent — runs in the user's interactive Windows session.
#
# Watches origin/main for new commits. When one lands:
#   1. git pull --ff-only
#   2. Activate the running Delphi IDE window
#   3. Send Ctrl+Shift+F9 (Build All Projects, requires TaskForge.groupproj loaded)
#   4. Poll bin\ until all four EXEs are newer than the build start, or timeout
#   5. Write bin\.build-status.json
#
# Pre-requisites:
#   - Delphi IDE running with C:\dev\taskforge\TaskForge.groupproj loaded
#   - This script registered as a scheduled task by tools\install-agent.ps1
#   - Git in PATH

[CmdletBinding()]
param(
    [string]$RepoPath = 'C:\dev\taskforge',
    [int]$PollIntervalSec = 5,
    [int]$BuildTimeoutSec = 300
)

$ErrorActionPreference = 'Continue'
Set-StrictMode -Version Latest

# ---- Win32 + UIA helpers ----------------------------------------------------

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

if (-not ('Native.Win' -as [type])) {
    Add-Type -Namespace Native -Name Win -MemberDefinition @'
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(System.IntPtr hWnd);
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
        [System.Runtime.InteropServices.DllImport("user32.dll")]
        public static extern bool IsIconic(System.IntPtr hWnd);
'@
}

function Find-DelphiWindow {
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $cond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ClassNameProperty, 'TAppBuilder')
    return $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
}

function Activate-Window {
    param([System.Windows.Automation.AutomationElement]$Window)
    $hwnd = [System.IntPtr]$Window.Current.NativeWindowHandle
    if ([Native.Win]::IsIconic($hwnd)) {
        [Native.Win]::ShowWindow($hwnd, 9) | Out-Null   # SW_RESTORE
    }
    [Native.Win]::SetForegroundWindow($hwnd) | Out-Null
    Start-Sleep -Milliseconds 600
}

function Trigger-Build {
    # Delphi's main menu is a custom VCL TMainMenu that does not expose
    # menu items through UI Automation (UIA reports only the Win32 system
    # menu). Drive it via keystrokes against the foreground IDE window.
    #
    #   Alt+P     opens Project menu
    #   B         highlights first B-item ("Build <active project>")
    #   B         cycles to second B-item ("Build All Projects")
    #   Enter     invokes Build All Projects
    $win = Find-DelphiWindow
    if (-not $win) {
        throw 'Delphi IDE window (TAppBuilder) not found — open it with TaskForge.groupproj first.'
    }
    Activate-Window -Window $win

    [System.Windows.Forms.SendKeys]::SendWait('%P')
    Start-Sleep -Milliseconds 350
    [System.Windows.Forms.SendKeys]::SendWait('B')
    Start-Sleep -Milliseconds 100
    [System.Windows.Forms.SendKeys]::SendWait('B')
    Start-Sleep -Milliseconds 100
    [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
    Write-Output "[$(Get-Date -Format o)] Build All Projects sent via Alt+P,B,B,Enter"
}

# ---- Build status -----------------------------------------------------------

$BinaryProjects = [ordered]@{
    'TaskForge.Worker' = 'src\Worker'
    'TaskForge.Api'    = 'src\Api'
    'TaskForge.Admin'  = 'src\Admin'
    'TaskForge.Tests'  = 'src\Tests'
}
$BinaryNames = @($BinaryProjects.Keys)

function Find-LatestExe {
    # The IDE may emit the .exe to bin\, to the project source dir, or under
    # src\Foo\Win64\Release\. Return the newest match across those.
    param([string]$Name, [string]$ProjectDir)
    $candidates = @(
        (Join-Path (Join-Path $RepoPath 'bin')           "$Name.exe"),
        (Join-Path (Join-Path $RepoPath $ProjectDir)     "$Name.exe"),
        (Join-Path (Join-Path $RepoPath $ProjectDir)     "Win64\Release\$Name.exe"),
        (Join-Path (Join-Path $RepoPath $ProjectDir)     "Win64\Debug\$Name.exe")
    )
    $best = $null
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            $f = Get-Item $c
            if (-not $best -or $f.LastWriteTimeUtc -gt $best.LastWriteTimeUtc) {
                $best = $f
            }
        }
    }
    return $best
}

function Get-BinaryStatus {
    $h = [ordered]@{}
    foreach ($n in $BinaryNames) {
        $f = Find-LatestExe -Name $n -ProjectDir $BinaryProjects[$n]
        if ($f) {
            $h[$n] = @{
                path  = $f.FullName
                size  = $f.Length
                mtime = $f.LastWriteTimeUtc.ToString('o')
            }
        } else {
            $h[$n] = $null
        }
    }
    return $h
}

function Copy-BinariesToBin {
    # After a successful build, mirror everything to bin\ so tests / SSH
    # callers have a single canonical location.
    $bin = Join-Path $RepoPath 'bin'
    if (-not (Test-Path $bin)) { New-Item -ItemType Directory -Path $bin -Force | Out-Null }
    foreach ($n in $BinaryNames) {
        $src = Find-LatestExe -Name $n -ProjectDir $BinaryProjects[$n]
        if (-not $src) { continue }
        $dst = Join-Path $bin "$n.exe"
        if ($src.FullName -ne $dst) {
            Copy-Item -Path $src.FullName -Destination $dst -Force
        }
    }
}

function Wait-AllBinariesFresh {
    param([DateTime]$Started, [int]$TimeoutSec)
    $startedUtc = $Started.ToUniversalTime()
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        $status = Get-BinaryStatus
        $allFresh = $true
        foreach ($n in $BinaryNames) {
            $info = $status[$n]
            if (-not $info) { $allFresh = $false; break }
            $mtime = [datetime]::Parse($info.mtime).ToUniversalTime()
            if ($mtime -lt $startedUtc) { $allFresh = $false; break }
        }
        if ($allFresh) {
            return @{ outcome = 'success'; binaries = $status }
        }
    }
    # Timed out — report which binaries did update vs not
    $status = Get-BinaryStatus
    $stale = @()
    foreach ($n in $BinaryNames) {
        $info = $status[$n]
        if (-not $info) { $stale += $n; continue }
        $mtime = [datetime]::Parse($info.mtime).ToUniversalTime()
        if ($mtime -lt $startedUtc) { $stale += $n }
    }
    return @{ outcome = 'timeout'; binaries = $status; stale = $stale }
}

function Write-BuildStatus {
    param([string]$Sha, [DateTime]$Started, [DateTime]$Completed, $Result)
    $bin = Join-Path $RepoPath 'bin'
    if (-not (Test-Path $bin)) { New-Item -ItemType Directory -Path $bin -Force | Out-Null }
    $obj = [ordered]@{
        sha          = $Sha
        started      = $Started.ToUniversalTime().ToString('o')
        completed    = $Completed.ToUniversalTime().ToString('o')
        duration_sec = [int]($Completed - $Started).TotalSeconds
        outcome      = $Result.outcome
        binaries     = $Result.binaries
    }
    if ($Result.ContainsKey('stale')) { $obj.stale = $Result.stale }
    if ($Result.ContainsKey('error')) { $obj.error = $Result.error }
    $json = $obj | ConvertTo-Json -Depth 6
    $path = Join-Path $bin '.build-status.json'
    Set-Content -Path $path -Value $json -Encoding UTF8
    Write-Output "[$(Get-Date -Format o)] Status -> $path : $($Result.outcome)"
}

# ---- Main loop --------------------------------------------------------------

function Main {
    if (-not (Test-Path $RepoPath)) {
        throw "Repo path not found: $RepoPath"
    }
    Push-Location $RepoPath
    try {
        $lastSha = (git rev-parse HEAD 2>$null).Trim()
        Write-Output "[$(Get-Date -Format o)] Agent started in $RepoPath at $lastSha"

        while ($true) {
            try {
                git fetch origin main 2>$null | Out-Null
                $remote = (git rev-parse origin/main 2>$null).Trim()
                if ($remote -and ($remote -ne $lastSha)) {
                    Write-Output "[$(Get-Date -Format o)] New commit upstream: $remote"
                    # Advance lastSha immediately so a Trigger-Build failure
                    # doesn't put us in a hot loop on the same commit.
                    $lastSha = $remote
                    git pull --ff-only 2>&1 | Out-Null

                    $started = Get-Date
                    try {
                        Trigger-Build
                        $result = Wait-AllBinariesFresh -Started $started -TimeoutSec $BuildTimeoutSec
                        if ($result.outcome -eq 'success') {
                            Copy-BinariesToBin
                            $result.binaries = Get-BinaryStatus
                        }
                    } catch {
                        $result = @{ outcome = 'error'; error = $_.ToString(); binaries = (Get-BinaryStatus) }
                        Write-Output "[$(Get-Date -Format o)] Trigger-Build threw: $_"
                    }
                    $completed = Get-Date
                    Write-BuildStatus -Sha $remote -Started $started -Completed $completed -Result $result
                }
            } catch {
                Write-Output "[$(Get-Date -Format o)] Loop error: $_"
            }
            Start-Sleep -Seconds $PollIntervalSec
        }
    } finally {
        Pop-Location
    }
}

Main
