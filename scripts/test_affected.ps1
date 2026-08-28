[CmdletBinding()]
param(
    [string[]]$Path = @(),
    [string[]]$Include = @(),
    [string]$BaseRef,
    [int]$Concurrency = [Math]::Min(4, [Environment]::ProcessorCount),
    [ValidateRange(1, 600)]
    [int]$TimeoutSeconds = 120,
    [switch]$Analyze,
    [switch]$ListOnly,
    [switch]$NoTestAssets
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $repoRoot
try {
    if ($Concurrency -lt 1) {
        throw 'Concurrency must be at least 1.'
    }

    function Normalize-RepoPath([string]$Value) {
        return $Value.Trim().Replace('\', '/').TrimStart('./')
    }

    $changedFiles = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($item in $Path) {
        foreach ($part in ($item -split ',')) {
            if (-not [string]::IsNullOrWhiteSpace($part)) {
                [void]$changedFiles.Add((Normalize-RepoPath $part))
            }
        }
    }

    if ($changedFiles.Count -eq 0) {
        $gitArguments = @('diff', '--name-only', '--diff-filter=ACMR')
        if (-not [string]::IsNullOrWhiteSpace($BaseRef)) {
            $gitArguments += "$BaseRef...HEAD"
        }
        foreach ($item in (& git @gitArguments)) {
            if (-not [string]::IsNullOrWhiteSpace($item)) {
                [void]$changedFiles.Add((Normalize-RepoPath $item))
            }
        }
        foreach ($item in (& git diff --cached --name-only --diff-filter=ACMR)) {
            if (-not [string]::IsNullOrWhiteSpace($item)) {
                [void]$changedFiles.Add((Normalize-RepoPath $item))
            }
        }
        foreach ($item in (& git ls-files --others --exclude-standard)) {
            if (-not [string]::IsNullOrWhiteSpace($item)) {
                [void]$changedFiles.Add((Normalize-RepoPath $item))
            }
        }
    }

    if ($changedFiles.Count -eq 0 -and $Include.Count -eq 0) {
        Write-Host 'No changed files or explicitly included tests were found.'
        exit 0
    }

    $allTests = @(
        Get-ChildItem -Path 'test' -Recurse -File -Filter '*_test.dart' |
            ForEach-Object { Normalize-RepoPath ([IO.Path]::GetRelativePath($repoRoot, $_.FullName)) }
    )
    $selectedTests = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($item in $Include) {
        foreach ($part in ($item -split ',')) {
            if ([string]::IsNullOrWhiteSpace($part)) {
                continue
            }
            $testPath = Normalize-RepoPath $part
            if (-not (Test-Path -LiteralPath $testPath -PathType Leaf)) {
                throw "Included test does not exist: $testPath"
            }
            [void]$selectedTests.Add($testPath)
        }
    }

    $testContents = @{}
    foreach ($testFile in $allTests) {
        $testContents[$testFile] = Get-Content -LiteralPath $testFile -Raw -Encoding UTF8
    }

    foreach ($changedFile in $changedFiles) {
        if ($changedFile -like 'test/*_test.dart' -and (Test-Path -LiteralPath $changedFile)) {
            [void]$selectedTests.Add($changedFile)
            continue
        }
        if (-not $changedFile.StartsWith('lib/', [System.StringComparison]::OrdinalIgnoreCase) -or
            -not $changedFile.EndsWith('.dart', [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        $libRelativePath = $changedFile.Substring(4)
        $packageImport = "package:nai_launcher/$libRelativePath"
        $mirroredTest = "test/$($libRelativePath.Substring(0, $libRelativePath.Length - 5))_test.dart"
        if (Test-Path -LiteralPath $mirroredTest -PathType Leaf) {
            [void]$selectedTests.Add($mirroredTest)
        }

        $sourceBaseName = [IO.Path]::GetFileNameWithoutExtension($changedFile)
        foreach ($testFile in $allTests) {
            if ($testContents[$testFile].Contains($packageImport, [System.StringComparison]::Ordinal) -or
                [IO.Path]::GetFileNameWithoutExtension($testFile) -eq "${sourceBaseName}_test") {
                [void]$selectedTests.Add($testFile)
            }
        }
    }

    $orderedTests = @($selectedTests | Sort-Object)
    Write-Host "Changed inputs: $($changedFiles.Count)"
    Write-Host "Selected test files: $($orderedTests.Count)"
    foreach ($testFile in $orderedTests) {
        Write-Host "  $testFile"
    }

    if ($ListOnly) {
        exit 0
    }

    if ($Analyze) {
        & flutter analyze
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }

    if ($orderedTests.Count -eq 0) {
        Write-Host 'No directly affected tests were found. Run flutter analyze or add tests with -Include.'
        exit 0
    }

    $baseRunnerArguments = @(
        '-TimeoutSeconds'
        $TimeoutSeconds
        '-Concurrency'
        $Concurrency
    )
    if ($NoTestAssets) {
        $baseRunnerArguments += '-NoTestAssets'
    }

    # Windows command lines are limited. Large platform changes can select
    # hundreds of tests, so keep each watchdog invocation comfortably bounded.
    $maxBatchArgumentLength = 6000
    $testBatches = [System.Collections.Generic.List[object]]::new()
    $currentBatch = [System.Collections.Generic.List[string]]::new()
    $currentLength = ($baseRunnerArguments -join ' ').Length
    foreach ($testFile in $orderedTests) {
        $nextLength = $currentLength + $testFile.Length + 3
        if ($currentBatch.Count -gt 0 -and $nextLength -gt $maxBatchArgumentLength) {
            $testBatches.Add($currentBatch.ToArray())
            $currentBatch = [System.Collections.Generic.List[string]]::new()
            $currentLength = ($baseRunnerArguments -join ' ').Length
        }
        $currentBatch.Add($testFile)
        $currentLength += $testFile.Length + 3
    }
    if ($currentBatch.Count -gt 0) {
        $testBatches.Add($currentBatch.ToArray())
    }

    for ($index = 0; $index -lt $testBatches.Count; $index++) {
        $batch = @($testBatches[$index])
        Write-Host "Running affected test batch $($index + 1)/$($testBatches.Count) ($($batch.Count) files)..."
        $runnerArguments = @(
            '-NoProfile'
            '-ExecutionPolicy'
            'Bypass'
            '-File'
            (Join-Path $PSScriptRoot 'run_flutter_tests.ps1')
            '-TimeoutSeconds'
            $TimeoutSeconds
            '-Concurrency'
            $Concurrency
        )
        if ($NoTestAssets) {
            $runnerArguments += '-NoTestAssets'
        }
        $runnerArguments += '-Path'
        # Native pwsh -File invocation does not preserve a PowerShell array
        # parameter across the process boundary. The runner already accepts
        # comma-separated paths, so pass the batch as one argument.
        $runnerArguments += ($batch -join ',')
        & pwsh @runnerArguments
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }
    exit 0
}
finally {
    Pop-Location
}
