[CmdletBinding()]
param(
    [string[]]$Path = @(),
    [ValidateRange(1, 600)]
    [int]$TimeoutSeconds = 600,
    [ValidateRange(1, 32)]
    [int]$Concurrency = [Math]::Min(4, [Environment]::ProcessorCount),
    [switch]$NoTestAssets
)

$ErrorActionPreference = 'Stop'
$env:PUB_HOSTED_URL = 'https://pub.dev'
$env:FLUTTER_STORAGE_BASE_URL = $null

# $IsWindows only exists in PowerShell 6+, so Windows PowerShell 5.1 reads it as
# $null and would take the non-Windows branch; 5.1 itself only ships on Windows.
$script:onWindows = $PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows

function Stop-ProcessTree {
    param([System.Diagnostics.Process]$Target)

    if ($null -eq $Target -or $Target.HasExited) {
        return
    }

    try {
        if ($script:onWindows) {
            & taskkill.exe /PID $Target.Id /T /F | Out-Null
        }
        else {
            # Kill(bool) needs .NET Core 3.0+, which only PowerShell 6+ runs on.
            $Target.Kill($true)
        }
        $Target.WaitForExit(5000) | Out-Null
    }
    catch {
        # Never let cleanup mask the timeout or exit code the caller cares about.
        Write-Warning "Failed to terminate process tree $($Target.Id): $_"
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$flutterCommand = Get-Command flutter -ErrorAction Stop
$testPaths = @(
    foreach ($item in $Path) {
        foreach ($part in ($item -split ',')) {
            if (-not [string]::IsNullOrWhiteSpace($part)) {
                $part.Trim()
            }
        }
    }
)
$flutterArguments = @(
    'test'
    '--reporter=compact'
    "--concurrency=$Concurrency"
)
if ($NoTestAssets) {
    $flutterArguments += '--no-test-assets'
}
$flutterArguments += $testPaths

Push-Location $repoRoot
try {
    $process = Start-Process `
        -FilePath $flutterCommand.Source `
        -ArgumentList $flutterArguments `
        -NoNewWindow `
        -PassThru

    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-ProcessTree -Target $process
        throw "Flutter tests exceeded the hard limit of $TimeoutSeconds seconds; the entire process tree was terminated."
    }

    if ($process.ExitCode -ne 0) {
        exit $process.ExitCode
    }
}
finally {
    Stop-ProcessTree -Target $process
    Pop-Location
}
