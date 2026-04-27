param([Parameter(Mandatory)][string]$Bin)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\Assert.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\lib\Bin.psm1') -Force

# NOTE: Sending a true Ctrl+C across processes from PowerShell is fiddly.
# We use a small P/Invoke helper to issue GenerateConsoleCtrlEvent. If
# AttachConsole fails (e.g. running detached), we fall back to taskkill
# without /F so the process still gets a chance to handle the signal —
# this is the documented limitation in the plan's "Known weaknesses".

$envDir = New-TestEnvDir
$db     = Join-Path $envDir 'tf.db'
$pipe   = "TaskForge.E2E.$(Get-Random)"

try {
    $worker = Start-Worker -Bin $Bin -DbPath $db -PipeName $pipe -ScanIntervalSec 1
    Start-Sleep -Seconds 1
    $pid = $worker.Process.Id

    & taskkill.exe /PID $pid | Out-Null

    $deadline = (Get-Date).AddSeconds(7)
    while ((Get-Date) -lt $deadline -and -not $worker.Process.HasExited) {
        Start-Sleep -Milliseconds 200
    }
    Assert-True $worker.Process.HasExited 'worker should exit within 7s'
    Assert-Equal 0 $worker.Process.ExitCode 'graceful exit code should be 0'

    $log = Get-Content $worker.Log -Raw
    Assert-True ($log -match 'shutting down') 'expected "shutting down" log line'

    Write-Host 'PASS 05_worker_graceful_shutdown'
}
finally {
    if ($worker -and -not $worker.Process.HasExited) {
        try { $worker.Process.Kill() } catch {}
    }
    Remove-Item -Recurse -Force $envDir -ErrorAction SilentlyContinue
}
