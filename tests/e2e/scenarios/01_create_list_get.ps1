param([Parameter(Mandatory)][string]$Bin)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\lib\Assert.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '..\lib\Bin.psm1') -Force

$envDir = New-TestEnvDir
$db     = Join-Path $envDir 'tf.db'
$pipe   = "TaskForge.E2E.$(Get-Random)"
$port   = Get-FreePort
$worker = $null
$api    = $null

try {
    $worker = Start-Worker -Bin $Bin -DbPath $db -PipeName $pipe
    $api    = Start-Api    -Bin $Bin -DbPath $db -PipeName $pipe -Port $port
    $base   = "http://127.0.0.1:$port"

    $body = '{"title":"e2e-1","status":"open","due_at":"2026-12-31T00:00:00Z"}'
    $r = Invoke-WebRequest -Method Post -Uri "$base/tasks" -Body $body -ContentType 'application/json' -UseBasicParsing
    Assert-StatusCode 201 $r 'POST /tasks'

    $list = Invoke-WebRequest -Uri "$base/tasks" -UseBasicParsing
    Assert-StatusCode 200 $list 'GET /tasks'
    Assert-True ($list.Content -match 'e2e-1') 'list should include created task'

    $obj = $r.Content | ConvertFrom-Json
    $id  = $obj.id
    $get = Invoke-WebRequest -Uri "$base/tasks/$id" -UseBasicParsing
    Assert-StatusCode 200 $get 'GET /tasks/{id}'

    $del = Invoke-WebRequest -Method Delete -Uri "$base/tasks/$id" -UseBasicParsing
    Assert-StatusCode 204 $del 'DELETE'

    Write-Host 'PASS 01_create_list_get'
}
finally {
    Stop-Bin $api
    Stop-Bin $worker
    Remove-Item -Recurse -Force $envDir -ErrorAction SilentlyContinue
}
