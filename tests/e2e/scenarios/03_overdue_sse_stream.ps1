param([Parameter(Mandatory)][string]$Bin)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\Assert.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\lib\Bin.psm1') -Force

$envDir = New-TestEnvDir
$db     = Join-Path $envDir 'tf.db'
$pipe   = "TaskForge.E2E.$(Get-Random)"
$port   = Get-FreePort

try {
    $worker = Start-Worker -Bin $Bin -DbPath $db -PipeName $pipe -ScanIntervalSec 1
    $api    = Start-Api    -Bin $Bin -DbPath $db -PipeName $pipe -Port $port
    $base   = "http://127.0.0.1:$port"

    $past = (Get-Date).AddHours(-1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $body = '{"title":"overdue-1","status":"open","due_at":"' + $past + '"}'
    $r = Invoke-WebRequest -Method Post -Uri "$base/tasks" -Body $body -ContentType 'application/json' -UseBasicParsing
    Assert-StatusCode 201 $r

    $client = [System.Net.Http.HttpClient]::new()
    $client.Timeout = [TimeSpan]::FromSeconds(10)
    $stream = $client.GetStreamAsync("$base/events").GetAwaiter().GetResult()
    $reader = [System.IO.StreamReader]::new($stream)

    $deadline = (Get-Date).AddSeconds(5)
    $hit = $false
    while ((Get-Date) -lt $deadline -and -not $hit) {
        $line = $reader.ReadLine()
        if ($null -eq $line) { Start-Sleep -Milliseconds 50; continue }
        if ($line -match 'task.overdue') { $hit = $true }
    }
    $reader.Dispose()
    $client.Dispose()

    Assert-True $hit 'Expected an SSE task.overdue event within 5s'
    Write-Host 'PASS 03_overdue_sse_stream'
}
finally {
    Stop-Bin $api
    Stop-Bin $worker
    Remove-Item -Recurse -Force $envDir -ErrorAction SilentlyContinue
}
