[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('All', 'Windows', 'Android')]
    [string]$Target = 'All',
    [string]$DeviceId,
    [string]$EmulatorId = 'Aaalice_API35',
    [switch]$RunPubGet,
    [switch]$RunBuildRunner,
    [switch]$StopEmulatorOnExit
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir '../../../..')
$pwshCommand = (Get-Command pwsh -ErrorAction Stop).Source
$targets = if ($Target -eq 'All') { @('Windows', 'Android') } else { @($Target) }

if ($Target -eq 'All' -and ($RunPubGet -or $RunBuildRunner)) {
    throw 'Dependency resolution or code generation must finish in one target before the other development window starts. Start one target with the preparation switch, then start the other target without it.'
}
if (-not [string]::IsNullOrWhiteSpace($DeviceId) -and $Target -eq 'Windows') {
    throw '-DeviceId only applies to Android sessions.'
}

function Find-RunnerProcess {
    param([Parameter(Mandatory = $true)][string]$SessionTarget)

    $runnerName = if ($SessionTarget -eq 'Windows') {
        'windows_runner.ps1'
    }
    else {
        'android_runner.ps1'
    }
    $runnerPath = Join-Path $repoRoot ".agents/skills/aaalice-dev-sessions/scripts/$runnerName"

    return Get-CimInstance Win32_Process |
        Where-Object {
            $_.Name -eq 'pwsh.exe' -and
            -not [string]::IsNullOrWhiteSpace($_.CommandLine) -and
            $_.CommandLine.Contains([string]$runnerPath, [StringComparison]::OrdinalIgnoreCase)
        } |
        Sort-Object CreationDate -Descending |
        Select-Object -First 1
}

function Add-SwitchArgument {
    param(
        [Parameter(Mandatory = $true)][System.Collections.Generic.List[string]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Enabled
    )

    if ($Enabled) {
        $Arguments.Add($Name)
    }
}

foreach ($currentTarget in $targets) {
    $existing = Find-RunnerProcess -SessionTarget $currentTarget
    if ($existing) {
        Write-Output "$currentTarget development window is already running (PID $($existing.ProcessId))."
        continue
    }

    $runnerName = if ($currentTarget -eq 'Windows') {
        'windows_runner.ps1'
    }
    else {
        'android_runner.ps1'
    }
    $runnerPath = Join-Path $scriptDir $runnerName
    if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) {
        throw "Development runner not found: $runnerPath"
    }

    $arguments = [System.Collections.Generic.List[string]]::new()
    $arguments.Add('-NoProfile')
    $arguments.Add('-ExecutionPolicy')
    $arguments.Add('Bypass')
    $arguments.Add('-File')
    $arguments.Add(('"{0}"' -f $runnerPath))
    Add-SwitchArgument -Arguments $arguments -Name '-RunPubGet' -Enabled $RunPubGet.IsPresent
    Add-SwitchArgument -Arguments $arguments -Name '-RunBuildRunner' -Enabled $RunBuildRunner.IsPresent

    if ($currentTarget -eq 'Android') {
        if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
            $arguments.Add('-DeviceId')
            $arguments.Add(('"{0}"' -f $DeviceId))
        }
        elseif (-not [string]::IsNullOrWhiteSpace($EmulatorId)) {
            $arguments.Add('-EmulatorId')
            $arguments.Add(('"{0}"' -f $EmulatorId))
        }
        Add-SwitchArgument `
            -Arguments $arguments `
            -Name '-StopEmulatorOnExit' `
            -Enabled $StopEmulatorOnExit.IsPresent
    }

    if (-not $PSCmdlet.ShouldProcess("$currentTarget development window", 'Start PowerShell runner')) {
        continue
    }

    $process = Start-Process `
        -FilePath $pwshCommand `
        -ArgumentList $arguments `
        -WorkingDirectory $repoRoot `
        -WindowStyle Normal `
        -PassThru
    Write-Output "Started $currentTarget development window (PID $($process.Id))."
}
