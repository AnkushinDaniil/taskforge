function Assert-Equal {
    param([object]$Expected, [object]$Actual, [string]$Message = '')
    if ($Expected -ne $Actual) {
        throw "Assert-Equal failed: expected '$Expected', got '$Actual'. $Message"
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Message = '')
    if (-not $Condition) { throw "Assert-True failed. $Message" }
}

function Assert-StatusCode {
    param([int]$Expected, $Response, [string]$Message = '')
    if ($Response.StatusCode -ne $Expected) {
        throw "Expected HTTP $Expected, got $($Response.StatusCode). $Message"
    }
}

Export-ModuleMember -Function Assert-Equal, Assert-True, Assert-StatusCode
