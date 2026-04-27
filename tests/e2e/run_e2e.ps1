[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Bin
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$scenarioDir = Join-Path $root 'scenarios'
$scenarios = Get-ChildItem -Path $scenarioDir -Filter '*.ps1' | Sort-Object Name

$results = @()
$failures = 0

foreach ($s in $scenarios) {
    Write-Host "RUN  $($s.Name)" -ForegroundColor Cyan
    try {
        & $s.FullName -Bin $Bin
        $results += [PSCustomObject]@{ Scenario = $s.Name; Result = 'PASS' }
    }
    catch {
        $failures++
        Write-Host "FAIL $($s.Name): $($_.Exception.Message)" -ForegroundColor Red
        $results += [PSCustomObject]@{ Scenario = $s.Name; Result = 'FAIL'; Error = $_.Exception.Message }
    }
}

Write-Host ''
$results | Format-Table -AutoSize

if ($failures -gt 0) {
    Write-Host "$failures scenario(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host 'All scenarios passed.' -ForegroundColor Green
exit 0
