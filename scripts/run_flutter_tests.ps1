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
        if ($IsWindows) {
            & taskkill.exe /PID $process.Id /T /F | Out-Host
        }
        else {
            $process.Kill($true)
            $process.WaitForExit()
        }
        throw "Flutter tests exceeded the hard limit of $TimeoutSeconds seconds; the entire process tree was terminated."
    }

    if ($process.ExitCode -ne 0) {
        exit $process.ExitCode
    }
}
finally {
    if ($null -ne $process -and -not $process.HasExited) {
        if ($IsWindows) {
            & taskkill.exe /PID $process.Id /T /F | Out-Null
        }
        else {
            $process.Kill($true)
        }
    }
    Pop-Location
}
