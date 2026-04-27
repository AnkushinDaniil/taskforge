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

    $created = Invoke-RestMethod -Method Post -Uri "$base/tasks" `
        -Body '{"title":"lock-test","status":"open"}' `
        -ContentType 'application/json'
    $id    = $created.id
    $etag1 = 'W/"' + $id + '-1"'

    $first = Invoke-WebRequest -Method Patch -Uri "$base/tasks/$id" `
        -Body '{"title":"v2"}' -ContentType 'application/json' `
        -Headers @{ 'If-Match' = $etag1 } -UseBasicParsing
    Assert-StatusCode 200 $first 'first PATCH should succeed'

    $stale = $null
    try {
        $stale = Invoke-WebRequest -Method Patch -Uri "$base/tasks/$id" `
            -Body '{"title":"v3"}' -ContentType 'application/json' `
            -Headers @{ 'If-Match' = $etag1 } -UseBasicParsing
    } catch {
        $stale = $_.Exception.Response
    }
    if ($stale -is [System.Net.Http.HttpResponseMessage]) {
        $code = [int]$stale.StatusCode
    } else {
        $code = if ($stale.StatusCode) { [int]$stale.StatusCode } else { 0 }
    }
    Assert-Equal 409 $code 'second PATCH with stale ETag should be 409'

    Write-Host 'PASS 02_optimistic_lock_409'
}
finally {
    Stop-Bin $api
    Stop-Bin $worker
    Remove-Item -Recurse -Force $envDir -ErrorAction SilentlyContinue
}
