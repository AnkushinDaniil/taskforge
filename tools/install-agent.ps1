# One-time setup: register the TaskForge build agent as a scheduled task that
# runs in the current user's interactive session at every logon.
#
# Run once on the Windows VM (regular PowerShell — does NOT need admin):
#
#     powershell -ExecutionPolicy Bypass -File C:\dev\taskforge\tools\install-agent.ps1
#
# After this:
#   1. Open Delphi 12 IDE
#   2. File -> Open Project -> C:\dev\taskforge\TaskForge.groupproj
#   3. Leave the IDE running. Do nothing else.
# Every subsequent `git push` from elsewhere triggers a build automatically and
# the result lands in C:\dev\taskforge\bin\.build-status.json.

[CmdletBinding()]
param(
    [string]$RepoPath = 'C:\dev\taskforge',
    [string]$TaskName = 'TaskForgeBuildAgent'
)

$agentPath = Join-Path $RepoPath 'tools\build-agent.ps1'
$logPath   = Join-Path $RepoPath 'bin\.build-agent.log'

if (-not (Test-Path $agentPath)) {
    Write-Error "build-agent.ps1 not found at $agentPath. Did you git pull?"
    exit 1
}

$binDir = Join-Path $RepoPath 'bin'
if (-not (Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
}

# Disable Windows' foreground-stealing lock so the agent can bring the
# Delphi IDE to the front before sending keystrokes. HKCU only — no
# admin needed. The Set-ItemProperty persists across sign-in; the
# SystemParametersInfo call applies it to the *current* session so a
# sign-out is not required.
Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' `
    -Name 'ForegroundLockTimeout' -Value 0 -Type DWord -Force

if (-not ('Native.SPI' -as [type])) {
    Add-Type -Namespace Native -Name SPI -MemberDefinition @'
        [System.Runtime.InteropServices.DllImport("user32.dll", SetLastError=true)]
        public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, System.IntPtr pvParam, uint fWinIni);
'@
}
# SPI_SETFOREGROUNDLOCKTIMEOUT = 0x2001
# SPIF_UPDATEINIFILE | SPIF_SENDCHANGE = 0x3
$ok = [Native.SPI]::SystemParametersInfo(0x2001, 0, [System.IntPtr]::Zero, 0x3)
Write-Host "  ForegroundLockTimeout = 0 (HKCU registry + live: $ok)"

# Build the launch arguments. We redirect output to a log file the agent
# itself can append to (PowerShell's transcript is too noisy here).
$argList = @(
    '-NoProfile'
    '-WindowStyle','Hidden'
    '-ExecutionPolicy','Bypass'
    '-Command',
    "& `"$agentPath`" -RepoPath `"$RepoPath`" *>> `"$logPath`""
) -join ' '

$action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argList -WorkingDirectory $RepoPath
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings  = New-ScheduledTaskSettingsSet `
                -StartWhenAvailable `
                -DontStopIfGoingOnBatteries `
                -AllowStartIfOnBatteries `
                -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
                -ExecutionTimeLimit ([TimeSpan]::Zero)
# Run elevated so the agent can send keystrokes to the elevated Delphi
# IDE window. Without this, Windows UIPI silently drops keystrokes
# travelling from a low-IL process to a high-IL window.
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest

Register-ScheduledTask `
    -TaskName  $TaskName `
    -Action    $action `
    -Trigger   $trigger `
    -Settings  $settings `
    -Principal $principal `
    -Description 'TaskForge: poll origin/main, drive Delphi IDE Build All, write bin\.build-status.json' `
    -Force | Out-Null

# Kick it off now too.
Start-ScheduledTask -TaskName $TaskName

Write-Host ''
Write-Host '==================================================================='
Write-Host '  TaskForge build agent installed.' -ForegroundColor Green
Write-Host '==================================================================='
Write-Host ''
Write-Host '  Next steps:'
Write-Host '    1. Open Delphi 12'
Write-Host "    2. File -> Open Project -> $RepoPath\TaskForge.groupproj"
Write-Host '    3. Leave the IDE open. Do nothing else.'
Write-Host ''
Write-Host '  Logs:    ' -NoNewline; Write-Host $logPath -ForegroundColor Yellow
Write-Host '  Status:  ' -NoNewline; Write-Host (Join-Path $RepoPath 'bin\.build-status.json') -ForegroundColor Yellow
Write-Host ''
Write-Host '  To uninstall:  Unregister-ScheduledTask -TaskName ' -NoNewline
Write-Host "$TaskName -Confirm:`$false" -ForegroundColor Yellow
Write-Host ''
