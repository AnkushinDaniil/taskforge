param([Parameter(Mandatory)][string]$Bin)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\Assert.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\lib\Bin.psm1') -Force

$envDir = New-TestEnvDir
$db     = Join-Path $envDir 'tf.db'
$pipe   = "TaskForge.E2E.$(Get-Random)"
$port   = Get-FreePort

try {
    $worker = Start-Worker -Bin $Bin -DbPath $db -PipeName $pipe
    $api    = Start-Api    -Bin $Bin -DbPath $db -PipeName $pipe -Port $port
    $base   = "http://127.0.0.1:$port"

    $r = Invoke-WebRequest -Method Post -Uri "$base/tasks" `
        -Body '{"title":"etag-test","status":"open"}' `
        -ContentType 'application/json' -UseBasicParsing
    Assert-StatusCode 201 $r
    $id = ($r.Content | ConvertFrom-Json).id

    $get1 = Invoke-WebRequest -Uri "$base/tasks/$id" -UseBasicParsing
    Assert-StatusCode 200 $get1
    $etag = $get1.Headers['ETag']
    Assert-True ($etag -ne $null -and $etag -ne '') 'ETag header missing'

    $304 = $null
    try {
        $304 = Invoke-WebRequest -Uri "$base/tasks/$id" `
            -Headers @{ 'If-None-Match' = $etag } -UseBasicParsing
    } catch {
        $304 = $_.Exception.Response
    }
    $code = if ($304 -is [Microsoft.PowerShell.Commands.WebResponseObject]) {
              $304.StatusCode
            } else {
              [int]$304.StatusCode
            }
    Assert-Equal 304 $code 'second GET with If-None-Match should be 304'

    Write-Host 'PASS 04_etag_304'
}
finally {
    Stop-Bin $api
    Stop-Bin $worker
    Remove-Item -Recurse -Force $envDir -ErrorAction SilentlyContinue
}
