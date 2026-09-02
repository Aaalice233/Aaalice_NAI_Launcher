param(
    [Parameter(Mandatory = $true)]
    [int]$OwnerProcessId,
    [Parameter(Mandatory = $true)]
    [int64]$OwnerProcessStartedAtUnixMs,
    [Parameter(Mandatory = $true)]
    [string]$DeviceId,
    [Parameter(Mandatory = $true)]
    [string]$AdbCommand
)

$ErrorActionPreference = 'Stop'

while ($true) {
    try {
        $owner = Get-Process -Id $OwnerProcessId -ErrorAction Stop
        $actualStartUnixMs = [DateTimeOffset]::new(
            $owner.StartTime.ToUniversalTime()
        ).ToUnixTimeMilliseconds()
        if ([Math]::Abs($actualStartUnixMs - $OwnerProcessStartedAtUnixMs) -ge 1000) {
            break
        }
    }
    catch {
        break
    }

    Start-Sleep -Milliseconds 500
}

if (-not (Test-Path -LiteralPath $AdbCommand -PathType Leaf)) {
    exit 0
}

$connectedDevices = @(& $AdbCommand devices) |
    Select-Object -Skip 1 |
    ForEach-Object {
        $columns = $_ -split '\s+'
        if ($columns.Count -ge 2 -and $columns[1] -eq 'device') {
            $columns[0]
        }
    }
if ($connectedDevices -contains $DeviceId) {
    & $AdbCommand -s $DeviceId emu kill | Out-Null
}
