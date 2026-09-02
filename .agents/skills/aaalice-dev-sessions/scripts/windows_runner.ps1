param(
    [switch]$RunPubGet,
    [switch]$RunBuildRunner,
    [switch]$SkipBuildRunner
)

$ErrorActionPreference = 'Stop'
$env:PUB_HOSTED_URL = 'https://pub.dev'
$env:FLUTTER_STORAGE_BASE_URL = $null

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir '../../../..')
Set-Location -LiteralPath $repoRoot
. (Join-Path $scriptDir 'generated_sources.ps1')

$sessionDirectory = Join-Path $repoRoot 'tool/.tmp'
$sessionPath = Join-Path $sessionDirectory 'windows_hot_reload_session.json'

if ($Host.Name -eq 'ConsoleHost') {
    $Host.UI.RawUI.WindowTitle = 'PC热重载'
}

function Resolve-ToolCommand {
    param(
        [Parameter(Mandatory = $true)][string]$EnvironmentVariable,
        [Parameter(Mandatory = $true)][string]$CommandName
    )

    $override = [Environment]::GetEnvironmentVariable($EnvironmentVariable)
    if (-not [string]::IsNullOrWhiteSpace($override)) {
        $resolvedOverride = $override.Trim('"')
        if (-not (Test-Path -LiteralPath $resolvedOverride -PathType Leaf)) {
            throw "$EnvironmentVariable points to a missing executable: $resolvedOverride"
        }
        return $resolvedOverride
    }

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "$CommandName command not found. Add it to PATH or set $EnvironmentVariable."
    }

    return $command.Source
}

function Test-ExistingSession {
    if (-not (Test-Path -LiteralPath $sessionPath -PathType Leaf)) {
        return $false
    }

    try {
        $session = Get-Content -LiteralPath $sessionPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $process = Get-Process -Id ([int]$session.processId) -ErrorAction Stop
        $processStartUnixMs = [DateTimeOffset]::new(
            $process.StartTime.ToUniversalTime()
        ).ToUnixTimeMilliseconds()
        return $process.ProcessName -eq 'pwsh' -and
            [Math]::Abs($processStartUnixMs - [int64]$session.processStartedAtUnixMs) -lt 1000 -and
            [string]$session.repoRoot -eq [string]$repoRoot
    }
    catch {
        Remove-Item -LiteralPath $sessionPath -Force -ErrorAction SilentlyContinue
        return $false
    }
}

function Write-SessionMarker {
    param([Parameter(Mandatory = $true)][string]$State)

    New-Item -ItemType Directory -Path $sessionDirectory -Force | Out-Null
    $currentProcess = Get-Process -Id $PID
    @{
        target = 'Windows'
        state = $State
        processId = $PID
        processStartedAtUnixMs = [DateTimeOffset]::new(
            $currentProcess.StartTime.ToUniversalTime()
        ).ToUnixTimeMilliseconds()
        repoRoot = [string]$repoRoot
        controller = 'codex'
        startedAt = (Get-Date).ToUniversalTime().ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath $sessionPath -Encoding UTF8
}

if (Test-ExistingSession) {
    $session = Get-Content -LiteralPath $sessionPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "Reusing Windows hot-reload session $($session.processId)." -ForegroundColor Green
    return
}

$dartCommand = Resolve-ToolCommand -EnvironmentVariable 'DART_CMD' -CommandName 'dart'
$flutterCommand = Resolve-ToolCommand -EnvironmentVariable 'FLUTTER_CMD' -CommandName 'flutter'
$shouldRunBuildRunner = $RunBuildRunner -and -not $SkipBuildRunner
$stepCount = 2 + [int]$RunPubGet.IsPresent + [int]$shouldRunBuildRunner
$step = 1
$runSourceLock = $null

Write-SessionMarker -State 'starting'
try {
    Write-Host "[$step/$stepCount] Checking Windows build prerequisites..." -ForegroundColor Cyan
    & (Join-Path $repoRoot 'scripts/verify_nuget.ps1')
    if ($LASTEXITCODE -ne 0) {
        throw 'Windows build prerequisite verification failed.'
    }
    $step++

    if ($RunPubGet) {
        Write-Host ''
        Write-Host "[$step/$stepCount] Resolving Flutter dependencies..." -ForegroundColor Cyan
        & $flutterCommand pub get --enforce-lockfile
        if ($LASTEXITCODE -ne 0) {
            throw 'flutter pub get failed.'
        }
        $step++
    }

    if ($shouldRunBuildRunner) {
        Write-Host ''
        Write-Host "[$step/$stepCount] Running build_runner..." -ForegroundColor Cyan
        $generationLock = Enter-DevelopmentSourceLock -ProjectRoot $repoRoot -Mode Generate
        try {
            & $dartCommand run build_runner build --delete-conflicting-outputs
            if ($LASTEXITCODE -ne 0) {
                throw 'build_runner failed.'
            }
        }
        finally {
            $generationLock.Dispose()
        }
        $step++
    }

    $runSourceLock = Enter-DevelopmentSourceLock -ProjectRoot $repoRoot -Mode Run
    Assert-GeneratedSourcesReady -ProjectRoot $repoRoot

    Write-Host ''
    Write-Host "[$step/$stepCount] Starting Flutter in Windows debug mode..." -ForegroundColor Cyan
    Write-Host 'Hot reload: r    Hot restart: R    Quit: q' -ForegroundColor DarkGray
    Write-SessionMarker -State 'running'
    & $flutterCommand run `
        -d windows `
        --dart-define=ENABLE_FLUTTER_DRIVER=true
    if ($LASTEXITCODE -ne 0) {
        throw 'flutter run failed for Windows.'
    }
}
finally {
    if ($runSourceLock) {
        $runSourceLock.Dispose()
    }
    if (Test-Path -LiteralPath $sessionPath -PathType Leaf) {
        try {
            $session = Get-Content -LiteralPath $sessionPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ([int]$session.processId -eq $PID) {
                Remove-Item -LiteralPath $sessionPath -Force
            }
        }
        catch {
            Remove-Item -LiteralPath $sessionPath -Force -ErrorAction SilentlyContinue
        }
    }
}
