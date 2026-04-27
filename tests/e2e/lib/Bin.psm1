function Get-FreePort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $listener.Stop()
    return $port
}

function New-TestEnvDir {
    $dir = Join-Path $env:TEMP "taskforge-e2e-$(Get-Random)"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    return $dir
}

function Start-Worker {
    param(
        [string]$Bin,
        [string]$DbPath,
        [string]$PipeName,
        [int]$ScanIntervalSec = 2
    )
    $exe = Join-Path $Bin 'TaskForge.Worker.exe'
    $env:TASKFORGE_DB_PATH = $DbPath
    $env:TASKFORGE_PIPE_NAME = $PipeName
    $env:TASKFORGE_SCAN_INTERVAL_SEC = "$ScanIntervalSec"
    $logFile = "$DbPath.worker.log"
    $proc = Start-Process -FilePath $exe -PassThru -NoNewWindow `
        -RedirectStandardOutput $logFile -RedirectStandardError "$logFile.err"
    Start-Sleep -Milliseconds 300
    return @{ Process = $proc; Log = $logFile }
}

function Start-Api {
    param(
        [string]$Bin,
        [string]$DbPath,
        [string]$PipeName,
        [int]$Port
    )
    $exe = Join-Path $Bin 'TaskForge.Api.exe'
    $env:TASKFORGE_DB_PATH = $DbPath
    $env:TASKFORGE_PIPE_NAME = $PipeName
    $env:TASKFORGE_API_PORT = "$Port"
    $logFile = "$DbPath.api.log"
    $proc = Start-Process -FilePath $exe -PassThru -NoNewWindow `
        -RedirectStandardOutput $logFile -RedirectStandardError "$logFile.err"
    # wait for the port
    $deadline = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $deadline) {
        try {
            $r = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/tasks" -UseBasicParsing -TimeoutSec 2
            if ($r.StatusCode -eq 200) { break }
        } catch {}
        Start-Sleep -Milliseconds 200
    }
    return @{ Process = $proc; Log = $logFile; Port = $Port }
}

function Stop-Bin {
    param($Handle)
    if ($Handle -and $Handle.Process -and -not $Handle.Process.HasExited) {
        try { $Handle.Process.Kill() } catch {}
        try { $Handle.Process.WaitForExit(2000) } catch {}
    }
}

Export-ModuleMember -Function Get-FreePort, New-TestEnvDir, Start-Worker, Start-Api, Stop-Bin
