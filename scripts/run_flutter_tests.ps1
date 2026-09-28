#requires -Version 7.0
[CmdletBinding()]
param(
    [string[]]$Path = @(),
    [ValidateRange(1, 600)]
    [int]$TimeoutSeconds = 600,
    [ValidateRange(1, 32)]
    [int]$Concurrency = [Math]::Min(4, [Environment]::ProcessorCount),
    [switch]$NoTestAssets,
    [ValidateRange(1, 64)]
    [int]$TotalShards = 1,
    [ValidateRange(0, 63)]
    [int]$ShardIndex = 0,
    [switch]$NoPub,
    [string]$ReportPath,
    [switch]$ListOnly
)

$ErrorActionPreference = 'Stop'
if ($ShardIndex -ge $TotalShards) {
    throw 'ShardIndex must be less than TotalShards.'
}
$env:PUB_HOSTED_URL = 'https://pub.dev'
$env:FLUTTER_STORAGE_BASE_URL = $null

$script:onWindows = $IsWindows

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
$testPaths = @(
    foreach ($item in $Path) {
        foreach ($part in ($item -split ',')) {
            if (-not [string]::IsNullOrWhiteSpace($part)) {
                $part.Trim()
            }
        }
    }
)
if ($TotalShards -gt 1 -or $ListOnly) {
    # Native test sharding loads every suite before slicing its test cases.
    # Partition files first so each suite is compiled on only one CI runner.
    $discovered = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $roots = if ($testPaths.Count -eq 0) { @('test') } else { $testPaths }
    foreach ($root in $roots) {
        $rootPath = if ([IO.Path]::IsPathRooted($root)) { $root } else { Join-Path $repoRoot $root }
        $resolved = Get-Item -LiteralPath $rootPath -ErrorAction Stop
        $files = if ($resolved.PSIsContainer) {
            Get-ChildItem -LiteralPath $resolved.FullName -Recurse -File -Filter '*_test.dart'
        } else {
            @($resolved)
        }
        foreach ($file in $files) {
            $relative = [IO.Path]::GetRelativePath($repoRoot, $file.FullName).Replace('\', '/')
            [void]$discovered.Add($relative)
        }
    }
    [string[]]$ordered = @($discovered)
    [Array]::Sort($ordered, [StringComparer]::Ordinal)
    $testPaths = @(for ($index = $ShardIndex; $index -lt $ordered.Count; $index += $TotalShards) {
        $ordered[$index]
    })
    if ($testPaths.Count -eq 0) { throw 'No test files were selected for this shard.' }
}
if ($ListOnly) {
    $testPaths
    exit 0
}
$flutterCommand = Get-Command flutter -ErrorAction Stop
$flutterArguments = @(
    'test'
    '--reporter=compact'
    "--concurrency=$Concurrency"
)
if ($NoPub) {
    $flutterArguments += '--no-pub'
}
$reportFile = $null
if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $reportFile = if ([IO.Path]::IsPathRooted($ReportPath)) {
        $ReportPath
    } else {
        Join-Path $repoRoot $ReportPath
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $reportFile) | Out-Null
}
if ($NoTestAssets) {
    $flutterArguments += '--no-test-assets'
}

# Flutter's Windows launcher is a batch file. Keep each invocation below the
# command-line limit while sharing one watchdog budget across the whole shard.
$batches = [System.Collections.Generic.List[object]]::new()
$batch = [System.Collections.Generic.List[string]]::new()
$argumentLength = 0
foreach ($testPath in $testPaths) {
    if ($batch.Count -gt 0 -and $argumentLength + $testPath.Length + 3 -gt 6000) {
        $batches.Add($batch.ToArray())
        $batch.Clear()
        $argumentLength = 0
    }
    $batch.Add(('"{0}"' -f $testPath))
    $argumentLength += $testPath.Length + 3
}
if ($batch.Count -gt 0 -or $batches.Count -eq 0) { $batches.Add($batch.ToArray()) }

Push-Location $repoRoot
$process = $null
$watch = [Diagnostics.Stopwatch]::StartNew()
$exitCode = 0
try {
    for ($index = 0; $index -lt $batches.Count; $index++) {
        $remaining = ($TimeoutSeconds * 1000) - $watch.ElapsedMilliseconds
        if ($remaining -le 0) { throw "Flutter tests exceeded the hard limit of $TimeoutSeconds seconds." }
        $arguments = @($flutterArguments) + @($batches[$index])
        if ($reportFile) {
            $batchReport = if ($batches.Count -eq 1) { $reportFile } else { "$reportFile.batch-$index.json" }
            $arguments += ('"--file-reporter=json:{0}"' -f $batchReport)
        }
        Write-Host "Running test batch $($index + 1)/$($batches.Count) (shard $ShardIndex/$TotalShards)..."
        $process = Start-Process `
            -FilePath $flutterCommand.Source `
            -ArgumentList $arguments `
            -NoNewWindow `
            -PassThru
        if (-not $process.WaitForExit([int]$remaining)) {
            Stop-ProcessTree -Target $process
            throw "Flutter tests exceeded the hard limit of $TimeoutSeconds seconds; the entire process tree was terminated."
        }
        if ($process.ExitCode -ne 0) { $exitCode = $process.ExitCode }
    }
    exit $exitCode
}
finally {
    Stop-ProcessTree -Target $process
    Pop-Location
}
