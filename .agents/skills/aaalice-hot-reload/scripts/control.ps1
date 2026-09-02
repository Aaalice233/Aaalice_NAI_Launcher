param(
    [ValidateSet('Status', 'Reload', 'Restart', 'Logs')]
    [string]$Action = 'Status',
    [ValidateSet('All', 'Windows', 'Android')]
    [string]$Target = 'All',
    [ValidateRange(1, 10000)]
    [int]$Last = 120,
    [ValidateRange(0, 100)]
    [int]$Context = 2,
    [string]$Pattern,
    [ValidateRange(0, 10000)]
    [int]$WaitMilliseconds = 1500,
    [switch]$SkipLogs
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir '../../../..')
$targets = if ($Target -eq 'All') { @('Windows', 'Android') } else { @($Target) }

function Get-SessionStatus {
    param([Parameter(Mandatory = $true)][string]$SessionTarget)

    $fileName = if ($SessionTarget -eq 'Windows') {
        'windows_hot_reload_session.json'
    }
    else {
        'android_hot_reload_session.json'
    }
    $sessionPath = Join-Path $repoRoot "tool/.tmp/$fileName"
    if (-not (Test-Path -LiteralPath $sessionPath -PathType Leaf)) {
        return [pscustomobject]@{
            Target = $SessionTarget
            Ready = $false
            Summary = 'not started'
        }
    }

    try {
        $session = Get-Content -LiteralPath $sessionPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $process = Get-Process -Id ([int]$session.processId) -ErrorAction Stop
        $processStartUnixMs = [DateTimeOffset]::new(
            $process.StartTime.ToUniversalTime()
        ).ToUnixTimeMilliseconds()
        $sameProcess = $process.ProcessName -eq 'pwsh' -and
            [Math]::Abs($processStartUnixMs - [int64]$session.processStartedAtUnixMs) -lt 1000
        if (-not $sameProcess -or [string]$session.repoRoot -ne [string]$repoRoot) {
            throw 'stale session marker'
        }

        $details = if ($SessionTarget -eq 'Android') {
            "$($session.state) on $($session.deviceId), PID $($session.processId)"
        }
        else {
            "$($session.state), PID $($session.processId)"
        }
        return [pscustomobject]@{
            Target = $SessionTarget
            Ready = $session.state -eq 'running'
            Summary = $details
        }
    }
    catch {
        Remove-Item -LiteralPath $sessionPath -Force -ErrorAction SilentlyContinue
        return [pscustomobject]@{
            Target = $SessionTarget
            Ready = $false
            Summary = "not started (removed stale marker: $($_.Exception.Message))"
        }
    }
}

function Write-TargetLogs {
    param([Parameter(Mandatory = $true)][string]$LogTarget)

    Write-Host ''
    Write-Host "===== $LogTarget console =====" -ForegroundColor Cyan
    $arguments = @{
        Target = $LogTarget
        Last = $Last
        Context = $Context
    }
    if (-not [string]::IsNullOrWhiteSpace($Pattern)) {
        $arguments.Pattern = $Pattern
    }
    & (Join-Path $scriptDir 'read_console.ps1') @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$LogTarget console read failed."
    }
}

if ($Action -eq 'Status') {
    $statuses = @($targets | ForEach-Object { Get-SessionStatus -SessionTarget $_ })
    foreach ($status in $statuses) {
        $color = if ($status.Ready) { 'Green' } else { 'Yellow' }
        Write-Host ("{0,-8} {1}" -f $status.Target, $status.Summary) -ForegroundColor $color
    }
    if (@($statuses | Where-Object { -not $_.Ready }).Count -gt 0) {
        exit 1
    }
    return
}

$failures = [System.Collections.Generic.List[string]]::new()
if ($Action -in @('Reload', 'Restart')) {
    foreach ($currentTarget in $targets) {
        try {
            $triggerArguments = @{ Target = $currentTarget }
            if ($Action -eq 'Restart') {
                $triggerArguments.Restart = $true
            }
            & (Join-Path $scriptDir 'trigger.ps1') @triggerArguments
            if ($LASTEXITCODE -ne 0) {
                throw "$Action command failed."
            }
        }
        catch {
            $failures.Add("$currentTarget`: $($_.Exception.Message)")
        }
    }

    if (-not $SkipLogs) {
        if ($WaitMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $WaitMilliseconds
        }
        foreach ($currentTarget in $targets) {
            try {
                Write-TargetLogs -LogTarget $currentTarget
            }
            catch {
                $failures.Add("$currentTarget logs: $($_.Exception.Message)")
            }
        }
    }
}
else {
    foreach ($currentTarget in $targets) {
        try {
            Write-TargetLogs -LogTarget $currentTarget
        }
        catch {
            $failures.Add("$currentTarget logs: $($_.Exception.Message)")
        }
    }
}

if ($failures.Count -gt 0) {
    throw "Flutter development command completed with errors:`n- $($failures -join "`n- ")"
}
