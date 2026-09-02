[CmdletBinding()]
param(
    [ValidateRange(60, 600)]
    [int]$TimeoutSeconds = 600,
    [string]$Output = 'tool/.tmp/cloud-sync-benchmark/report.json'
)

$ErrorActionPreference = 'Stop'
$env:PUB_HOSTED_URL = 'https://pub.dev'
$env:FLUTTER_STORAGE_BASE_URL = $null
$script:onWindows = $PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows

function Stop-ProcessTree {
    param([System.Diagnostics.Process]$Target)

    if ($null -eq $Target -or $Target.HasExited) { return }
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
        Write-Warning "Failed to terminate process tree $($Target.Id): $_"
    }
}

function Get-ProcessTreeWorkingSet {
    param([System.Diagnostics.Process]$Root)

    if (-not $script:onWindows) {
        $Root.Refresh()
        return [int64]$Root.WorkingSet64
    }
    $pending = [System.Collections.Generic.Queue[int]]::new()
    $seen = [System.Collections.Generic.HashSet[int]]::new()
    $pending.Enqueue($Root.Id)
    [int64]$total = 0
    while ($pending.Count -gt 0) {
        $id = $pending.Dequeue()
        if (-not $seen.Add($id)) { continue }
        $childIds = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$id" -ErrorAction SilentlyContinue | ForEach-Object { [int]$_.ProcessId })
        foreach ($childId in $childIds) { $pending.Enqueue($childId) }
        $item = Get-Process -Id $id -ErrorAction SilentlyContinue
        if ($null -ne $item) { $total += [int64]$item.WorkingSet64 }
    }
    return $total
}

function Wait-BoundedProcess {
    param(
        [System.Diagnostics.Process]$Target,
        [System.Diagnostics.Stopwatch]$TotalWatch,
        [int]$TotalTimeoutSeconds
    )

    $remainingMilliseconds = ($TotalTimeoutSeconds * 1000) - $TotalWatch.ElapsedMilliseconds
    if ($remainingMilliseconds -le 0 -or -not $Target.WaitForExit($remainingMilliseconds)) {
        Stop-ProcessTree -Target $Target
        throw "Cloud-sync benchmark exceeded $TotalTimeoutSeconds seconds; the process tree was terminated."
    }
    if ($Target.ExitCode -ne 0) {
        throw "Cloud-sync benchmark child process failed with exit code $($Target.ExitCode)."
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$reportPath = if ([System.IO.Path]::IsPathRooted($Output)) { $Output } else { Join-Path $repoRoot $Output }
$reportDirectory = Split-Path -Parent $reportPath
$syntheticReportPath = "$reportPath.synthetic.json"
$benchmarkExe = Join-Path $reportDirectory 'cloud_sync_production_benchmark.exe'
$readyPath = Join-Path $reportDirectory 'production.ready'
$goPath = Join-Path $reportDirectory 'production.go'
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
Remove-Item -LiteralPath $reportPath, $syntheticReportPath, $benchmarkExe, $readyPath, $goPath -Force -ErrorAction SilentlyContinue

$flutterCommand = Get-Command flutter -ErrorAction Stop
$dartCommand = Get-Command dart -ErrorAction Stop
$totalWatch = [System.Diagnostics.Stopwatch]::StartNew()
$process = $null
$providerContractPeak = 0L

Push-Location $repoRoot
try {
    $testArguments = @(
        'test'
        'test/core/cloud_sync/cloud_sync_benchmark_test.dart'
        'test/core/cloud_sync/backend/github_cloud_sync_backend_test.dart'
        'test/core/cloud_sync/backend/google_drive_cloud_sync_backend_test.dart'
        'test/core/cloud_sync/backend/onedrive_cloud_sync_backend_test.dart'
        'test/core/cloud_sync/backend/webdav_cloud_sync_backend_test.dart'
        'test/core/cloud_sync/backend/backend_http_loopback_test.dart'
        'test/core/cloud_sync/bounded_transfer_scheduler_test.dart'
        'test/core/cloud_sync/snapshot_transfer_test.dart'
        "--dart-define=CLOUD_SYNC_BENCHMARK_OUTPUT=$syntheticReportPath"
    )
    $process = Start-Process -FilePath $flutterCommand.Source -ArgumentList $testArguments -NoNewWindow -PassThru
    while (-not $process.HasExited) {
        $providerContractPeak = [Math]::Max($providerContractPeak, (Get-ProcessTreeWorkingSet -Root $process))
        if ($totalWatch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            Stop-ProcessTree -Target $process
            throw "Cloud-sync benchmark exceeded $TimeoutSeconds seconds; the process tree was terminated."
        }
        Start-Sleep -Milliseconds 50
    }
    if ($process.ExitCode -ne 0) { throw "Provider contract tests failed with exit code $($process.ExitCode)." }
    $process = $null

    $compileArguments = @(
        'compile', 'exe',
        'tool/cloud_sync/cloud_sync_production_benchmark.dart',
        '-o', $benchmarkExe
    )
    $process = Start-Process -FilePath $dartCommand.Source -ArgumentList $compileArguments -NoNewWindow -PassThru
    Wait-BoundedProcess -Target $process -TotalWatch $totalWatch -TotalTimeoutSeconds $TimeoutSeconds
    $process = $null

    $runArguments = @(
        '--output', $reportPath,
        '--ready', $readyPath,
        '--go', $goPath
    )
    $process = Start-Process -FilePath $benchmarkExe -ArgumentList $runArguments -NoNewWindow -PassThru
    while (-not (Test-Path -LiteralPath $readyPath)) {
        if ($process.HasExited) { throw "Production benchmark exited before its memory baseline was established." }
        if ($totalWatch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            Stop-ProcessTree -Target $process
            throw "Cloud-sync benchmark exceeded $TimeoutSeconds seconds; the process tree was terminated."
        }
        Start-Sleep -Milliseconds 10
    }
    $process.Refresh()
    $baselineWorkingSet = [int64]$process.WorkingSet64
    $peakWorkingSet = $baselineWorkingSet
    New-Item -ItemType File -Force -Path $goPath | Out-Null
    while (-not $process.HasExited) {
        $process.Refresh()
        $peakWorkingSet = [Math]::Max($peakWorkingSet, [int64]$process.WorkingSet64)
        if ($totalWatch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            Stop-ProcessTree -Target $process
            throw "Cloud-sync benchmark exceeded $TimeoutSeconds seconds; the process tree was terminated."
        }
        Start-Sleep -Milliseconds 10
    }
    if ($process.ExitCode -ne 0) { throw "Production benchmark failed with exit code $($process.ExitCode)." }
    $process = $null

    $production = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $contract = Get-Content -LiteralPath $syntheticReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $providers = @($contract.providerProtocolSmoke | ForEach-Object { $_.provider })
    foreach ($requiredProvider in @('github', 'googleDrive', 'oneDrive', 'webDav')) {
        if ($requiredProvider -notin $providers) {
            throw "Cloud-sync benchmark is missing protocol evidence for $requiredProvider."
        }
    }
    $expectedBudgets = @{ android = 16MB; desktop = 32MB }
    foreach ($profile in $expectedBudgets.Keys) {
        $budget = @($contract.schedulerBudgets | Where-Object { $_.profile -eq $profile })
        if ($budget.Count -ne 1 -or
            [int64]$budget[0].budgetBytes -ne [int64]$expectedBudgets[$profile] -or
            [int64]$budget[0].peakReservedBytes -gt [int64]$budget[0].budgetBytes) {
            throw "Cloud-sync benchmark did not prove the $profile production scheduler limits."
        }
    }

    $oneGiB = 1GB
    if (-not $production.defaultOneGiBExecuted -or
        [int64]$production.logicalBytes -ne $oneGiB -or
        [int64]$production.sourceOpens -ne 1 -or
        [int64]$production.uploadHashPasses -ne [int64]$production.payloadCount -or
        [int64]$production.downloadHashPasses -ne [int64]$production.payloadCount -or
        [int64]$production.uploadedObjectBytes -lt $oneGiB -or
        [int64]$production.downloadedObjectBytes -lt $oneGiB -or
        [int64]$production.appliedBytes -ne $oneGiB) {
        throw 'Production benchmark did not prove the default 1 GiB single-read/single-hash round trip.'
    }

    $memoryDelta = $peakWorkingSet - $baselineWorkingSet
    if ($memoryDelta -lt 0 -or $memoryDelta -gt 512MB) {
        throw "Production process peak delta $memoryDelta bytes exceeded the 512 MiB regression gate."
    }
    $production | Add-Member -NotePropertyName osProcessMemory -NotePropertyValue ([ordered]@{
        measurementSource = 'System.Diagnostics.Process.WorkingSet64'
        samplingIntervalMs = 10
        baselineWorkingSetBytes = $baselineWorkingSet
        peakWorkingSetBytes = $peakWorkingSet
        peakWorkingSetDeltaBytes = $memoryDelta
        regressionGateBytes = 512MB
    })
    $production | Add-Member -NotePropertyName providerContractSuite -NotePropertyValue ([ordered]@{
        status = 'passed'
        transport = 'production provider classes with fake Dio adapters; BackendHttp has a separate real loopback socket test'
        providers = @('github', 'googleDrive', 'oneDrive', 'webDav')
        coveredBehaviors = @('pagination', 'duplicate detection', 'conditional writes', 'immutable objects', 'GitHub commit/ref publication', 'WebDAV manual-only', 'retry and cancellation')
        tests = @(
            'github_cloud_sync_backend_test.dart',
            'google_drive_cloud_sync_backend_test.dart',
            'onedrive_cloud_sync_backend_test.dart',
            'webdav_cloud_sync_backend_test.dart',
            'backend_http_loopback_test.dart'
        )
        suitePeakWorkingSetBytes = $providerContractPeak
        note = 'OS-sampled peak of the complete Flutter contract suite, including test-runner overhead; it is not a per-provider memory measurement or public-network evidence.'
    })
    $production | Add-Member -NotePropertyName syntheticScenarios -NotePropertyValue $contract.results
    $production | Add-Member -NotePropertyName schedulerBudgets -NotePropertyValue $contract.schedulerBudgets
    $production | Add-Member -NotePropertyName providerProtocolSmoke -NotePropertyValue $contract.providerProtocolSmoke
    $production | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reportPath -Encoding UTF8
}
finally {
    Stop-ProcessTree -Target $process
    Remove-Item -LiteralPath $benchmarkExe, $readyPath, $goPath -Force -ErrorAction SilentlyContinue
    Pop-Location
}
