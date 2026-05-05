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
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

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
