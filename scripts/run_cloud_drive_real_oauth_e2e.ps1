param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('googleDrive', 'oneDrive')]
    [string]$Provider,

    [Parameter(Mandatory = $true)]
    [ValidateSet('windows', 'macos', 'android')]
    [string]$Platform,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedTestAccount,

    [string]$DeviceId,
    [string]$CleanupNamespace,
    [switch]$ConfirmDedicatedTestAccount,
    [switch]$ConfirmCleanup,
    [switch]$PlanOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-BoundedProcess {
    param(
        [Parameter(Mandatory = $true)] [string]$FilePath,
        [Parameter(Mandatory = $true)] [string[]]$ArgumentList,
        [Parameter(Mandatory = $true)] [int]$TimeoutSeconds,
        [Parameter(Mandatory = $true)] [string]$Label
    )

    $command = Get-Command $FilePath -ErrorAction Stop
    $boundedProcess = Start-Process `
        -FilePath $command.Source `
        -ArgumentList $ArgumentList `
        -NoNewWindow `
        -PassThru
    if (-not $boundedProcess.WaitForExit($TimeoutSeconds * 1000)) {
        if ($IsWindows) {
            & taskkill.exe /PID $boundedProcess.Id /T /F | Out-Host
        } else {
            $boundedProcess.Kill($true)
            $boundedProcess.WaitForExit()
        }
        throw "$Label exceeded its $TimeoutSeconds-second limit and was terminated."
    }
    if ($boundedProcess.ExitCode -ne 0) {
        throw "$Label failed with exit code $($boundedProcess.ExitCode)."
    }
}

$root = Split-Path -Parent $PSScriptRoot
$testFile = 'integration_test/cloud_drive_real_oauth_backup_test.dart'
$tempRoot = Join-Path $root 'tool/.tmp/cloud-drive-real-oauth-e2e'
$providerId = if ($Provider -eq 'googleDrive') { 'google_drive' } else { 'onedrive' }
$cleanupOnly = -not [string]::IsNullOrWhiteSpace($CleanupNamespace)
$normalizedAccount = $ExpectedTestAccount.Trim().ToLowerInvariant()
if ([string]::IsNullOrWhiteSpace($normalizedAccount)) {
    throw 'ExpectedTestAccount must identify the dedicated OAuth test account.'
}
$expectedAccountHash = [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($normalizedAccount))
).ToLowerInvariant()

if ($Platform -eq 'windows' -and -not $IsWindows) {
    throw 'Windows E2E must run on a Windows host.'
}
if ($Platform -eq 'macos' -and -not $IsMacOS) {
    throw 'macOS E2E must run on a macOS host.'
}
if ($Platform -eq 'android' -and [string]::IsNullOrWhiteSpace($DeviceId)) {
    throw 'Android E2E requires an explicit -DeviceId.'
}
if ([string]::IsNullOrWhiteSpace($DeviceId)) {
    $DeviceId = $Platform
}

if ($cleanupOnly) {
    $expectedPrefix = "aaalice-e2e-$providerId-"
    if (-not $CleanupNamespace.StartsWith($expectedPrefix, [StringComparison]::Ordinal) -or
        $CleanupNamespace -notmatch '^aaalice-e2e-[A-Za-z0-9._-]+$' -or
        $CleanupNamespace.Length -gt 128) {
        throw "CleanupNamespace must be an isolated $expectedPrefix* namespace."
    }
    $namespace = $CleanupNamespace
    $recoveryStatePath = Join-Path $tempRoot "run-$namespace.json"
    if (-not (Test-Path -LiteralPath $recoveryStatePath -PathType Leaf)) {
        throw "Cleanup requires the original recovery state file: $recoveryStatePath"
    }
    $recoveryState = Get-Content -LiteralPath $recoveryStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($recoveryState.namespace -ne $namespace -or
        $recoveryState.provider -ne $Provider -or
        $recoveryState.platform -ne $Platform) {
        throw 'Cleanup provider/platform/namespace do not match the recorded failed run.'
    }
} else {
    $timestamp = [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')
    $entropy = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(6)).ToLowerInvariant()
    $namespace = "aaalice-e2e-$providerId-$timestamp-$entropy"
}

$requiredKeys = switch ("$providerId/$Platform") {
    'google_drive/windows' { @('GOOGLE_DRIVE_WINDOWS_CLIENT_ID', 'GOOGLE_DRIVE_WINDOWS_REDIRECT_URI') }
    'google_drive/macos' { @('GOOGLE_DRIVE_MACOS_CLIENT_ID', 'GOOGLE_DRIVE_MACOS_REDIRECT_URI') }
    'google_drive/android' { @('GOOGLE_DRIVE_ANDROID_CLIENT_ID') }
    'onedrive/windows' { @('ONEDRIVE_WINDOWS_CLIENT_ID', 'ONEDRIVE_WINDOWS_REDIRECT_URI') }
    'onedrive/macos' { @('ONEDRIVE_MACOS_CLIENT_ID', 'ONEDRIVE_MACOS_REDIRECT_URI') }
    'onedrive/android' { @('ONEDRIVE_ANDROID_CLIENT_ID', 'ONEDRIVE_ANDROID_REDIRECT_URI') }
    default { throw 'Unsupported provider/platform pair.' }
}
$optionalKeys = if ($providerId -eq 'onedrive') { @('ONEDRIVE_TENANT_ID') } else { @() }
$missing = @($requiredKeys | Where-Object { [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_)) })
if ($missing.Count -gt 0) {
    throw "Missing OAuth environment variables: $($missing -join ', ')"
}

if (-not $PlanOnly) {
    if (-not $ConfirmDedicatedTestAccount) {
        throw 'Use a dedicated Google/Microsoft test account, then pass -ConfirmDedicatedTestAccount.'
    }
    if (-not $ConfirmCleanup) {
        throw 'Confirm deletion of the isolated namespace and OAuth disconnect/revocation with -ConfirmCleanup.'
    }
}

$defines = @(
    '--dart-define=RUN_REAL_CLOUD_DRIVE_E2E=true',
    "--dart-define=REAL_CLOUD_DRIVE_E2E_PROVIDER=$providerId",
    "--dart-define=REAL_CLOUD_DRIVE_E2E_NAMESPACE=$namespace",
    "--dart-define=REAL_CLOUD_DRIVE_E2E_EXPECTED_ACCOUNT_SHA256=$expectedAccountHash",
    '--dart-define=REAL_CLOUD_DRIVE_E2E_CONFIRM_CLEANUP=true',
    "--dart-define=REAL_CLOUD_DRIVE_E2E_CLEANUP_ONLY=$($cleanupOnly.ToString().ToLowerInvariant())"
)
foreach ($key in @($requiredKeys) + @($optionalKeys)) {
    $value = [Environment]::GetEnvironmentVariable($key)
    if (-not [string]::IsNullOrWhiteSpace($value)) {
        $defines += "--dart-define=$key=$value"
    }
}

Write-Host "Provider : $Provider"
Write-Host "Platform : $Platform"
Write-Host "Device   : $DeviceId"
Write-Host "Namespace: $namespace"
Write-Host 'OAuth credentials are read from environment variables; tokens and account identity are never printed.'
if ($PlanOnly) {
    Write-Host 'Plan only: required environment-variable presence was checked; no OAuth, cloud write, or cleanup was executed.'
    exit 0
}

$androidRunning = $false
$androidPackageWasAbsent = $false

New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$lockRoot = Join-Path ([IO.Path]::GetTempPath()) 'aaalice-nai-launcher-cloud-drive-e2e'
New-Item -ItemType Directory -Path $lockRoot -Force | Out-Null
$lockPath = Join-Path $lockRoot 'active.lock'
$statePath = Join-Path $tempRoot "run-$namespace.json"
$stateTempPath = "$statePath.tmp"
$lockStream = $null
$lockAcquired = $false
$locationPushed = $false
$process = $null
$flutterStarted = $false
try {
    try {
        $lockStream = [IO.File]::Open(
            $lockPath,
            [IO.FileMode]::OpenOrCreate,
            [IO.FileAccess]::ReadWrite,
            [IO.FileShare]::None
        )
        $lockStream.SetLength(0)
        $lockPayload = [Text.Encoding]::UTF8.GetBytes("pid=$PID`nnamespace=$namespace`n")
        $lockStream.Write($lockPayload, 0, $lockPayload.Length)
        $lockStream.Flush($true)
        $lockAcquired = $true
    } catch {
        throw "Another real OAuth E2E run is active. Inspect $lockPath before retrying."
    }

    if ($Platform -eq 'android') {
        $deviceState = & adb -s $DeviceId get-state 2>$null
        if ($LASTEXITCODE -ne 0 -or ($deviceState | Out-String).Trim() -ne 'device') {
            throw "Android device $DeviceId is not ready."
        }
        $isEmulator = (& adb -s $DeviceId shell getprop ro.kernel.qemu 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $isEmulator -ne '1') {
            throw 'Android real OAuth E2E requires a dedicated emulator.'
        }
        $installedPath = (& adb -s $DeviceId shell pm path com.aaalice.nai_launcher 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to inspect installed packages on Android device $DeviceId."
        }
        if (-not [string]::IsNullOrWhiteSpace($installedPath)) {
            throw 'The production package is already installed. Use a clean dedicated emulator so app data and secure storage cannot be reused.'
        }
        $androidPackageWasAbsent = $true
        $adbOutput = & adb -s $DeviceId shell pidof com.aaalice.nai_launcher 2>$null
        $pidExitCode = $LASTEXITCODE
        if ($pidExitCode -eq 0) {
            $androidRunning = -not [string]::IsNullOrWhiteSpace(($adbOutput | Out-String))
        } elseif ($pidExitCode -ne 1) {
            throw "Unable to inspect the Launcher process on Android device $DeviceId."
        }
    }
    $running = switch ($Platform) {
        'windows' { @(Get-Process -Name 'nai_launcher' -ErrorAction SilentlyContinue).Count -gt 0 }
        'macos' {
            @(Get-Process -Name 'nai_launcher', 'Aaalice NAI Launcher' -ErrorAction SilentlyContinue).Count -gt 0
        }
        'android' { $androidRunning }
    }
    if ($running) {
        throw 'Aaalice NAI Launcher is already running on the target. Stop the existing runner before starting the isolated E2E app.'
    }

    $state = [ordered]@{
        provider = $Provider
        platform = $Platform
        deviceId = $DeviceId
        namespace = $namespace
        cleanupOnly = $cleanupOnly
        startedAt = [DateTime]::UtcNow.ToString('o')
    }
    $state | ConvertTo-Json | Set-Content -LiteralPath $stateTempPath -Encoding UTF8
    Move-Item -LiteralPath $stateTempPath -Destination $statePath -Force

    Push-Location $root
    $locationPushed = $true
    Invoke-BoundedProcess `
        -FilePath 'pwsh' `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', 'scripts/verify_flutter_sources.ps1') `
        -TimeoutSeconds 60 `
        -Label 'Flutter source verification'
    Invoke-BoundedProcess `
        -FilePath 'flutter' `
        -ArgumentList @('pub', 'get', '--enforce-lockfile') `
        -TimeoutSeconds 300 `
        -Label 'flutter pub get'
    Invoke-BoundedProcess `
        -FilePath 'pwsh' `
        -ArgumentList @(
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            'scripts/verify_cloud_drive_oauth_config.ps1',
            '-Platform',
            $Platform,
            '-Provider',
            $providerId,
            '-RequireConfigured'
        ) `
        -TimeoutSeconds 60 `
        -Label 'OAuth configuration validation'

    Write-Host 'Complete account selection, password, MFA, and consent only in the provider system browser.'
    $flutterArgs = @(
        'test',
        $testFile,
        '-d',
        $DeviceId,
        '--no-pub',
        '--timeout=10m'
    ) + $defines
    $flutterCommand = Get-Command flutter -ErrorAction Stop
    $process = Start-Process `
        -FilePath $flutterCommand.Source `
        -ArgumentList $flutterArgs `
        -NoNewWindow `
        -PassThru
    $flutterStarted = $true
    if (-not $process.WaitForExit(15 * 60 * 1000)) {
        if ($IsWindows) {
            & taskkill.exe /PID $process.Id /T /F | Out-Host
        } else {
            $process.Kill($true)
            $process.WaitForExit()
        }
        throw 'Real OAuth E2E exceeded the 15-minute process limit; the Flutter process tree was terminated.'
    }
    if ($process.ExitCode -ne 0) {
        throw "Real OAuth cloud-drive E2E failed with exit code $($process.ExitCode). The isolated namespace is recorded in $statePath."
    }
    if ($Platform -eq 'android' -and $androidPackageWasAbsent -and $flutterStarted) {
        & adb -s $DeviceId uninstall com.aaalice.nai_launcher | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw 'The E2E flow passed, but the isolated Android test installation could not be removed.'
        }
        $androidPackageWasAbsent = $false
    }

    Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue
    Write-Host 'Real OAuth backup, encrypted upload, new-device recovery, second backup, pull, and cleanup passed.'
} finally {
    if ($null -ne $process -and -not $process.HasExited) {
        if ($IsWindows) {
            & taskkill.exe /PID $process.Id /T /F | Out-Null
        } else {
            $process.Kill($true)
        }
    }
    if ($locationPushed) { Pop-Location }
    if ($Platform -eq 'android' -and $androidPackageWasAbsent -and $flutterStarted) {
        $uninstallOutput = & adb -s $DeviceId uninstall com.aaalice.nai_launcher 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error -ErrorAction Continue "CRITICAL: Android E2E cleanup could not remove com.aaalice.nai_launcher from $DeviceId. Run 'adb -s $DeviceId uninstall com.aaalice.nai_launcher' manually before reuse. Output: $($uninstallOutput | Out-String)"
        } else {
            $androidPackageWasAbsent = $false
        }
    }
    Remove-Item -LiteralPath $stateTempPath -Force -ErrorAction SilentlyContinue
    if ($null -ne $lockStream) { $lockStream.Dispose() }
    if ($lockAcquired) {
        Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
    }
}
