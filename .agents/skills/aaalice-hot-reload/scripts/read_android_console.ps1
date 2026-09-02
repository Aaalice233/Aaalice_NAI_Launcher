param(
    [string]$DeviceId,
    [string]$PackageName = 'com.aaalice.nai_launcher',
    [string]$Pattern,
    [ValidateRange(1, 10000)]
    [int]$Last = 200,
    [ValidateRange(0, 100)]
    [int]$Context = 2,
    [ValidateSet('Auto', 'Terminal', 'Device')]
    [string]$Source = 'Auto',
    [switch]$Follow,
    [switch]$KeepAnsi
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir '../../../..')

function Read-OrcaHotReloadTerminal {
    $orcaCommand = Get-Command orca -ErrorAction SilentlyContinue
    if (-not $orcaCommand) {
        return $null
    }

    try {
        $terminalHandle = $null
        $sessionPath = Join-Path $repoRoot 'tool/.tmp/android_hot_reload_session.json'
        if (Test-Path -LiteralPath $sessionPath -PathType Leaf) {
            $metadata = Get-Content -LiteralPath $sessionPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $terminalHandle = [string]$metadata.terminalHandle
        }

        $listText = (& $orcaCommand.Source terminal list --worktree active --json 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($listText)) {
            return $null
        }
        $listResult = $listText | ConvertFrom-Json
        $terminals = @($listResult.result.terminals) |
            Where-Object { $_.connected } |
            Sort-Object `
                @{ Expression = { if ($terminalHandle -and $_.handle -eq $terminalHandle) { 0 } else { 1 } } },
                @{ Expression = 'lastOutputAt'; Descending = $true }
        $captureLineCount = [Math]::Min(10000, [Math]::Max(1000, $Last * 5))

        foreach ($terminal in $terminals) {
            $handleMatches = $terminalHandle -and $terminal.handle -eq $terminalHandle
            $titleMatches = $terminal.title -like '*安卓热重载*'
            if (-not $handleMatches -and -not $titleMatches -and $terminal.title -match '(?i)(Pi|Codex|Claude|Gemini|Grok|OMP)$') {
                continue
            }

            $readText = (& $orcaCommand.Source terminal read `
                --terminal $terminal.handle `
                --limit $captureLineCount `
                --json 2>$null | Out-String).Trim()
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($readText)) {
                if ($titleMatches) {
                    throw "Could not read Orca terminal '$($terminal.title)'."
                }
                continue
            }
            $readResult = $readText | ConvertFrom-Json
            if ($readResult.result.terminal.status -ne 'running') {
                continue
            }

            $lines = @($readResult.result.terminal.tail)
            $hasAndroidMarker = ($lines -join "`n") -match 'Starting Flutter in Android debug mode|Launching lib[\\/]main\.dart on .*Android|I/flutter\s+\(\s*\d+\)|EGL_emulation'
            if ($handleMatches -or $titleMatches -or $hasAndroidMarker) {
                return [pscustomobject]@{
                    Handle = [string]$terminal.handle
                    Lines = $lines
                }
            }
        }
        return $null
    }
    catch {
        if ($Source -eq 'Terminal') {
            throw
        }
        return $null
    }
}

function Resolve-AdbCommand {
    $command = Get-Command adb -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $sdkRoots = @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME)
    $localProperties = Join-Path $repoRoot 'android/local.properties'
    if (Test-Path -LiteralPath $localProperties -PathType Leaf) {
        $sdkLine = Get-Content -LiteralPath $localProperties -Encoding UTF8 |
            Where-Object { $_ -like 'sdk.dir=*' } |
            Select-Object -First 1
        if ($sdkLine) {
            $sdkRoot = $sdkLine.Substring('sdk.dir='.Length)
            $sdkRoots += $sdkRoot.Replace('\\', '\').Replace('\:', ':')
        }
    }

    $adbRelativePath = if ($IsWindows) {
        'platform-tools/adb.exe'
    }
    else {
        'platform-tools/adb'
    }
    foreach ($sdkRoot in $sdkRoots) {
        if ([string]::IsNullOrWhiteSpace($sdkRoot)) {
            continue
        }
        $candidate = Join-Path $sdkRoot $adbRelativePath
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    throw 'adb command not found. Add Android platform-tools to PATH or configure ANDROID_SDK_ROOT/android/local.properties.'
}

function Get-ConnectedDevices {
    param([Parameter(Mandatory = $true)][string]$AdbCommand)

    $output = @(& $AdbCommand devices)
    if ($LASTEXITCODE -ne 0) {
        throw 'adb devices failed.'
    }

    return @(
        $output |
            Select-Object -Skip 1 |
            ForEach-Object {
                $columns = $_ -split '\s+'
                if ($columns.Count -ge 2 -and $columns[1] -eq 'device') {
                    $columns[0]
                }
            } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Resolve-DeviceId {
    param(
        [Parameter(Mandatory = $true)][string]$AdbCommand,
        [string]$RequestedDeviceId
    )

    $devices = @(Get-ConnectedDevices -AdbCommand $AdbCommand)
    if (-not [string]::IsNullOrWhiteSpace($RequestedDeviceId)) {
        if ($devices -notcontains $RequestedDeviceId) {
            throw "Connected Android device not found: $RequestedDeviceId. Available: $($devices -join ', ')"
        }
        return $RequestedDeviceId
    }

    $sessionPath = Join-Path $repoRoot 'tool/.tmp/android_hot_reload_session.json'
    if (Test-Path -LiteralPath $sessionPath -PathType Leaf) {
        try {
            $session = Get-Content -LiteralPath $sessionPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($devices -contains [string]$session.deviceId) {
                return [string]$session.deviceId
            }
        }
        catch {
            # A malformed or stale session marker must not hide connected devices.
        }
    }

    if ($devices.Count -eq 1) {
        return $devices[0]
    }
    if ($devices.Count -eq 0) {
        throw 'No connected Android device found.'
    }

    throw "Multiple Android devices are connected. Specify -DeviceId. Available: $($devices -join ', ')"
}

function Remove-AnsiEscapeSequences {
    param([string[]]$Lines)

    if ($KeepAnsi) {
        return $Lines
    }

    $escape = [char]27
    return @($Lines | ForEach-Object { $_ -replace "$escape\[[0-?]*[ -/]*[@-~]", '' })
}

function Select-MatchingLines {
    param(
        [string[]]$Lines,
        [string]$RegexPattern,
        [int]$ContextLines
    )

    if ([string]::IsNullOrWhiteSpace($RegexPattern)) {
        return $Lines
    }

    $selectedIndexes = [System.Collections.Generic.SortedSet[int]]::new()
    for ($index = 0; $index -lt $Lines.Count; $index++) {
        if ($Lines[$index] -notmatch $RegexPattern) {
            continue
        }

        $start = [Math]::Max(0, $index - $ContextLines)
        $end = [Math]::Min($Lines.Count - 1, $index + $ContextLines)
        for ($contextIndex = $start; $contextIndex -le $end; $contextIndex++) {
            [void]$selectedIndexes.Add($contextIndex)
        }
    }

    return @($selectedIndexes | ForEach-Object { $Lines[$_] })
}

if ($Follow -and $Source -eq 'Terminal') {
    throw '-Follow reads the live device log. Use -Source Device or omit -Source.'
}

if (-not $Follow -and $Source -ne 'Device') {
    $orcaTerminal = Read-OrcaHotReloadTerminal
    if ($orcaTerminal) {
        $lines = @(Remove-AnsiEscapeSequences -Lines $orcaTerminal.Lines)
        $lines = @(Select-MatchingLines `
            -Lines $lines `
            -RegexPattern $Pattern `
            -ContextLines $Context)
        $lines | Select-Object -Last $Last
        return
    }
    if ($Source -eq 'Terminal') {
        throw "Running Orca terminal '安卓热重载' not found in the active worktree."
    }
}

$adbCommand = Resolve-AdbCommand
$resolvedDeviceId = Resolve-DeviceId `
    -AdbCommand $adbCommand `
    -RequestedDeviceId $DeviceId
$processIdText = (& $adbCommand -s $resolvedDeviceId shell pidof -s $PackageName | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($processIdText)) {
    throw "Android app is not running on $resolvedDeviceId`: $PackageName"
}
if ($processIdText -notmatch '^\d+$') {
    throw "Unexpected process id for $PackageName on $resolvedDeviceId`: $processIdText"
}

$logcatArguments = @(
    '-s',
    $resolvedDeviceId,
    'logcat',
    "--pid=$processIdText",
    '-v',
    'time'
)

if ($Follow) {
    Write-Host "Following $PackageName (PID $processIdText) on $resolvedDeviceId. Press Ctrl+C to stop." -ForegroundColor Cyan
    & $adbCommand @logcatArguments
    exit $LASTEXITCODE
}

$captureLineCount = [Math]::Min(50000, [Math]::Max(1000, $Last * 5))
$lines = @(& $adbCommand @logcatArguments -d -t $captureLineCount)
if ($LASTEXITCODE -ne 0) {
    throw 'adb logcat failed.'
}

$lines = @(Remove-AnsiEscapeSequences -Lines $lines)
$lines = @(Select-MatchingLines `
    -Lines $lines `
    -RegexPattern $Pattern `
    -ContextLines $Context)
$lines | Select-Object -Last $Last
