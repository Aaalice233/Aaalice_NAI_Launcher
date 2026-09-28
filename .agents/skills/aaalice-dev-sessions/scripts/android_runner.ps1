param(
    [string]$DeviceId,
    [string]$EmulatorId,
    [switch]$RunPubGet,
    [switch]$RunBuildRunner,
    [switch]$SkipPubGet,
    [switch]$SkipBuildRunner,
    [switch]$StopEmulatorOnExit,
    [switch]$ListDevices
)

$ErrorActionPreference = 'Stop'
$env:PUB_HOSTED_URL = 'https://pub.dev'
$env:FLUTTER_STORAGE_BASE_URL = $null

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir '../../../..')
Set-Location -LiteralPath $repoRoot
. (Join-Path $scriptDir 'generated_sources.ps1')

$sessionDirectory = Join-Path $repoRoot 'tool/.tmp'
$sessionPath = Join-Path $sessionDirectory 'android_hot_reload_session.json'
if ($Host.Name -eq 'ConsoleHost') {
    $Host.UI.RawUI.WindowTitle = '安卓热重载'
}
if (-not $ListDevices -and (Test-Path -LiteralPath $sessionPath -PathType Leaf)) {
    try {
        $existingSession = Get-Content -LiteralPath $sessionPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $existingProcess = Get-Process -Id ([int]$existingSession.processId) -ErrorAction Stop
        $processStartUnixMs = [DateTimeOffset]::new(
            $existingProcess.StartTime.ToUniversalTime()
        ).ToUnixTimeMilliseconds()
        $sameProcess = $existingProcess.ProcessName -eq 'pwsh' -and
            [Math]::Abs($processStartUnixMs - [int64]$existingSession.processStartedAtUnixMs) -lt 1000
        $sameTarget = [string]::IsNullOrWhiteSpace($DeviceId) -or
            [string]$existingSession.deviceId -eq $DeviceId
        if ($sameProcess -and $sameTarget -and [string]$existingSession.repoRoot -eq [string]$repoRoot) {
            Write-Host "Reusing Android hot-reload session $($existingSession.processId) on $($existingSession.deviceId)." -ForegroundColor Green
            return
        }
    }
    catch {
        # A stale marker is removed below; the new session remains explicit.
    }
    Remove-Item -LiteralPath $sessionPath -Force -ErrorAction SilentlyContinue
}

function Get-OAuthConfigValue {
    param([Parameter(Mandatory = $true)][string]$Name)

    foreach ($target in @('Process', 'User', 'Machine')) {
        $value = [Environment]::GetEnvironmentVariable($Name, $target)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }
    return $null
}

function Get-OptionalOAuthDartDefines {
    $names = @(
        'GOOGLE_DRIVE_ANDROID_CLIENT_ID',
        'ONEDRIVE_ANDROID_CLIENT_ID',
        'ONEDRIVE_ANDROID_REDIRECT_URI',
        'ONEDRIVE_TENANT_ID'
    )
    $defines = @()
    foreach ($name in $names) {
        $value = Get-OAuthConfigValue -Name $name
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $defines += "--dart-define=$name=$value"
        }
    }
    return $defines
}

function Resolve-ToolCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentVariable,
        [Parameter(Mandatory = $true)]
        [string]$CommandName
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

function Resolve-AndroidSdkTool {
    param(
        [Parameter(Mandatory = $true)][string]$CommandName,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
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
            $sdkRoot = $sdkRoot.Replace('\\', '\').Replace('\:', ':')
            $sdkRoots += $sdkRoot
        }
    }

    foreach ($sdkRoot in $sdkRoots) {
        if ([string]::IsNullOrWhiteSpace($sdkRoot)) {
            continue
        }
        $candidate = Join-Path $sdkRoot $RelativePath
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    return $null
}

function Get-AndroidDevices {
    $json = (& $flutterCommand devices --machine | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw 'flutter devices failed.'
    }
    if ([string]::IsNullOrWhiteSpace($json)) {
        return @()
    }

    $devices = @($json | ConvertFrom-Json)
    return @(
        $devices | Where-Object {
            $_.targetPlatform -like 'android-*' -and $_.isSupported -ne $false
        }
    )
}

function Get-AndroidEmulators {
    $emulatorExecutable = if ($IsWindows) { 'emulator/emulator.exe' } else { 'emulator/emulator' }
    $emulatorCommand = Resolve-AndroidSdkTool `
        -CommandName 'emulator' `
        -RelativePath $emulatorExecutable
    if (-not $emulatorCommand) {
        return @()
    }

    $ids = @(& $emulatorCommand -list-avds) |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($LASTEXITCODE -ne 0) {
        return @()
    }

    return @(
        $ids | ForEach-Object {
            [pscustomobject]@{
                id = $_
                name = $_
            }
        }
    )
}

function Write-DeviceList {
    param([object[]]$Devices)

    if ($Devices.Count -eq 0) {
        Write-Host 'Connected Android devices: none' -ForegroundColor Yellow
        return
    }

    Write-Host 'Connected Android devices:' -ForegroundColor Cyan
    foreach ($device in $Devices) {
        $kind = if ($device.emulator) { 'emulator' } else { 'device' }
        Write-Host "  $($device.id)  $($device.name)  [$kind, $($device.targetPlatform)]"
    }
}

function Write-EmulatorList {
    param([object[]]$Emulators)

    if ($Emulators.Count -eq 0) {
        Write-Host 'Available Android emulators: none' -ForegroundColor Yellow
        return
    }

    Write-Host 'Available Android emulators:' -ForegroundColor Cyan
    foreach ($emulator in $Emulators) {
        Write-Host "  $($emulator.id)  $($emulator.name)"
    }
}

function Start-EmulatorLifetimeMonitor {
    param(
        [Parameter(Mandatory = $true)][string]$DeviceId,
        [Parameter(Mandatory = $true)][string]$AdbCommand
    )

    $monitorScript = Join-Path $scriptDir 'stop_owned_android_emulator.ps1'
    if (-not (Test-Path -LiteralPath $monitorScript -PathType Leaf)) {
        throw "Android emulator lifetime monitor not found: $monitorScript"
    }

    $pwshCommand = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwshCommand) {
        throw 'pwsh command not found. Cannot bind the emulator lifecycle to this session.'
    }

    $owner = Get-Process -Id $PID
    $ownerStartedAtUnixMs = [DateTimeOffset]::new(
        $owner.StartTime.ToUniversalTime()
    ).ToUnixTimeMilliseconds()
    $arguments = @(
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        "`"$monitorScript`"",
        '-OwnerProcessId',
        [string]$PID,
        '-OwnerProcessStartedAtUnixMs',
        [string]$ownerStartedAtUnixMs,
        '-DeviceId',
        $DeviceId,
        '-AdbCommand',
        "`"$AdbCommand`""
    )
    $startParameters = @{
        FilePath = $pwshCommand.Source
        ArgumentList = $arguments
        WorkingDirectory = $repoRoot
        PassThru = $true
    }
    if ($IsWindows) {
        $startParameters.WindowStyle = 'Hidden'
    }

    return Start-Process @startParameters
}

function Enable-AvdHardwareKeyboard {
    param([Parameter(Mandatory = $true)][string]$Id)

    $avdHome = if ([string]::IsNullOrWhiteSpace($env:ANDROID_AVD_HOME)) {
        Join-Path $HOME '.android/avd'
    }
    else {
        $env:ANDROID_AVD_HOME
    }
    $avdPointerPath = Join-Path $avdHome "$Id.ini"
    $configPath = Join-Path $avdHome "$Id.avd/config.ini"
    if (Test-Path -LiteralPath $avdPointerPath -PathType Leaf) {
        $pathEntry = Get-Content -LiteralPath $avdPointerPath -Encoding UTF8 |
            Where-Object { $_ -match '^path=(.+)$' } |
            Select-Object -First 1
        if ($pathEntry -match '^path=(.+)$') {
            $configPath = Join-Path $Matches[1] 'config.ini'
        }
    }
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        throw "Android emulator configuration not found: $configPath"
    }

    $lines = @(Get-Content -LiteralPath $configPath -Encoding UTF8)
    $keyboardEntries = @($lines | Where-Object { $_ -match '^hw\.keyboard\s*=' })
    if ($keyboardEntries.Count -ne 1) {
        throw "Expected one hw.keyboard entry in Android emulator configuration: $configPath"
    }
    if ($keyboardEntries[0] -match '^hw\.keyboard\s*=\s*yes\s*$') {
        return
    }

    $updatedLines = @(
        $lines | ForEach-Object {
            if ($_ -match '^hw\.keyboard\s*=') { 'hw.keyboard = yes' } else { $_ }
        }
    )
    Set-Content -LiteralPath $configPath -Value $updatedLines -Encoding UTF8
    Write-Host "Enabled host keyboard input for Android emulator '$Id'." -ForegroundColor Cyan
}

function Start-AndroidEmulator {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [string[]]$ExistingDeviceIds = @()
    )

    $emulatorExecutable = if ($IsWindows) { 'emulator/emulator.exe' } else { 'emulator/emulator' }
    $emulatorCommand = Resolve-AndroidSdkTool `
        -CommandName 'emulator' `
        -RelativePath $emulatorExecutable
    if (-not $emulatorCommand) {
        throw 'Android emulator command not found.'
    }

    Write-Host "Launching Android emulator '$Id' with a clean runtime state..." -ForegroundColor Cyan
    $emulatorProcess = Start-Process `
        -FilePath $emulatorCommand `
        -ArgumentList @(
            '-avd', $Id,
            '-no-snapshot',
            '-gpu', 'host',
            '-no-skin'
        ) `
        -WorkingDirectory $repoRoot `
        -PassThru

    $deadline = (Get-Date).AddMinutes(3)
    do {
        Start-Sleep -Seconds 2
        if ($emulatorProcess.HasExited) {
            throw "Android emulator '$Id' exited during startup with code $($emulatorProcess.ExitCode)."
        }
        $devices = @(Get-AndroidDevices)
        $newDevices = @(
            $devices | Where-Object { $ExistingDeviceIds -notcontains $_.id }
        )
        if ($newDevices.Count -gt 0) {
            return $newDevices
        }
    } while ((Get-Date) -lt $deadline)

    throw "Android emulator '$Id' did not register within 3 minutes."
}

function Wait-AndroidDeviceBoot {
    param(
        [Parameter(Mandatory = $true)][string]$DeviceId,
        [Parameter(Mandatory = $true)][string]$AdbCommand
    )

    Write-Host "Waiting for Android to finish booting on '$DeviceId'..." -ForegroundColor Cyan
    $deadline = (Get-Date).AddMinutes(3)
    do {
        $state = (& $AdbCommand -s $DeviceId get-state 2>$null | Out-String).Trim()
        $bootCompleted = if ($state -eq 'device') {
            (& $AdbCommand -s $DeviceId shell getprop sys.boot_completed 2>$null | Out-String).Trim()
        }
        else {
            ''
        }
        if ($state -eq 'device' -and $bootCompleted -eq '1') {
            return
        }
        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $deadline)

    throw "Android target '$DeviceId' did not finish booting within 3 minutes."
}

$flutterCommand = Resolve-ToolCommand -EnvironmentVariable 'FLUTTER_CMD' -CommandName 'flutter'
$dartCommand = Resolve-ToolCommand -EnvironmentVariable 'DART_CMD' -CommandName 'dart'
$flutterSdkRoot = Split-Path -Parent (Split-Path -Parent $flutterCommand)
$flutterGradleRoot = Join-Path $flutterSdkRoot 'packages/flutter_tools/gradle'
$obsoleteGradleSources = @(
    'resolve_dependencies.gradle',
    'settings.gradle.legacy_versions',
    'src/main/groovy/app_plugin_loader.groovy',
    'src/main/groovy/flutter.groovy',
    'src/main/groovy/native_plugin_loader.groovy',
    'src/main/kotlin/dependency_version_checker.gradle.kts',
    'src/main/kotlin/flutter.gradle.kts'
) | ForEach-Object { Join-Path $flutterGradleRoot $_ } |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
if ($obsoleteGradleSources.Count -gt 0) {
    throw "Flutter SDK contains obsolete Gradle sources left by an incomplete upgrade: $($obsoleteGradleSources -join ', ')"
}

$adbExecutable = if ($IsWindows) { 'platform-tools/adb.exe' } else { 'platform-tools/adb' }
$adbCommand = Resolve-AndroidSdkTool `
    -CommandName 'adb' `
    -RelativePath $adbExecutable
if (-not $adbCommand) {
    throw 'adb command not found. Add Android SDK platform-tools to PATH.'
}

$androidDevices = @(Get-AndroidDevices)
$androidEmulators = @(Get-AndroidEmulators)
$ownsSelectedEmulator = $false

if ($ListDevices) {
    Write-DeviceList -Devices $androidDevices
    Write-Host ''
    Write-EmulatorList -Emulators $androidEmulators
    return
}

$shouldRunPubGet = $RunPubGet -and -not $SkipPubGet
$shouldRunBuildRunner = $RunBuildRunner -and -not $SkipBuildRunner
if ($shouldRunPubGet) {
    Write-Host 'Resolving Flutter dependencies...' -ForegroundColor Cyan
    & $flutterCommand pub get --enforce-lockfile
    if ($LASTEXITCODE -ne 0) {
        throw 'flutter pub get failed.'
    }
}

if ($shouldRunBuildRunner) {
    Write-Host 'Running build_runner...' -ForegroundColor Cyan
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
}

$runSourceLock = Enter-DevelopmentSourceLock -ProjectRoot $repoRoot -Mode Run
Assert-GeneratedSourcesReady -ProjectRoot $repoRoot

if (-not [string]::IsNullOrWhiteSpace($EmulatorId)) {
    $emulator = $androidEmulators | Where-Object { $_.id -eq $EmulatorId } | Select-Object -First 1
    if (-not $emulator) {
        Write-EmulatorList -Emulators $androidEmulators
        throw "Android emulator not found: $EmulatorId"
    }

    $runningEmulator = $androidDevices |
        Where-Object { $_.emulator } |
        Where-Object {
            $avdName = (& $adbCommand -s $_.id emu avd name 2>$null | Select-Object -First 1)
            $LASTEXITCODE -eq 0 -and $avdName.Trim() -eq $EmulatorId
        } |
        Select-Object -First 1
    if ($runningEmulator) {
        Write-Host "Reusing cached Android emulator '$EmulatorId' ($($runningEmulator.id))." -ForegroundColor Green
        $androidDevices = @($runningEmulator)
    }
    else {
        Enable-AvdHardwareKeyboard -Id $EmulatorId
        $existingDeviceIds = @($androidDevices | ForEach-Object { $_.id })
        $androidDevices = @(
            Start-AndroidEmulator -Id $EmulatorId -ExistingDeviceIds $existingDeviceIds
        )
        $ownsSelectedEmulator = $true
    }
}
elseif ($androidDevices.Count -eq 0) {
    if ($androidEmulators.Count -eq 1) {
        $androidDevices = @(Start-AndroidEmulator -Id $androidEmulators[0].id)
        $ownsSelectedEmulator = $true
    }
    elseif ($androidEmulators.Count -gt 1) {
        Write-EmulatorList -Emulators $androidEmulators
        throw 'No Android device is connected. Choose an emulator with -EmulatorId.'
    }
}

if (-not [string]::IsNullOrWhiteSpace($DeviceId)) {
    $selectedDevice = $androidDevices |
        Where-Object { $_.id -eq $DeviceId } |
        Select-Object -First 1
    if (-not $selectedDevice) {
        Write-DeviceList -Devices $androidDevices
        throw "Connected Android device not found: $DeviceId"
    }
}
else {
    if ($androidDevices.Count -eq 0) {
        throw 'No Android device or emulator is available. Start one, or pass -EmulatorId.'
    }
    if ($androidDevices.Count -gt 1) {
        Write-DeviceList -Devices $androidDevices
        throw 'Multiple Android targets are available. Choose one with -DeviceId.'
    }
    $selectedDevice = $androidDevices[0]
}

Wait-AndroidDeviceBoot -DeviceId $selectedDevice.id -AdbCommand $adbCommand
if (-not [string]::IsNullOrWhiteSpace($EmulatorId)) {
    $googlePlayServicesPackage = (& $adbCommand -s $selectedDevice.id shell pm path com.google.android.gms 2>$null | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($googlePlayServicesPackage)) {
        throw "Android emulator '$EmulatorId' does not include Google Play Services. Recreate it from system-images;android-35;google_apis_playstore;x86_64 before testing Google Drive OAuth."
    }

    # Reused emulators keep their warm system/Gradle caches, but never restore a stale
    # launcher screen as this session's result.
    & $adbCommand -s $selectedDevice.id shell am force-stop com.aaalice.nai_launcher | Out-Null
    & $adbCommand -s $selectedDevice.id shell input keyevent HOME | Out-Null
}

Write-Host "[1/2] Android target: $($selectedDevice.name) ($($selectedDevice.id))" -ForegroundColor Cyan
Write-Host '[2/2] Starting Flutter in Android debug mode...' -ForegroundColor Cyan
Write-Host 'Hot reload: r    Hot restart: R    Quit: q' -ForegroundColor DarkGray

$emulatorMonitor = $null
if ($ownsSelectedEmulator -and $StopEmulatorOnExit) {
    try {
        $emulatorMonitor = Start-EmulatorLifetimeMonitor `
            -DeviceId $selectedDevice.id `
            -AdbCommand $adbCommand
    }
    catch {
        & $adbCommand -s $selectedDevice.id emu kill | Out-Null
        throw
    }
    Write-Host 'Closing this session will also close its emulator.' -ForegroundColor DarkGray
}
elseif ($ownsSelectedEmulator) {
    Write-Host 'The emulator will remain running as the cached target for the next development session.' -ForegroundColor DarkGray
}

New-Item -ItemType Directory -Path $sessionDirectory -Force | Out-Null
$currentProcess = Get-Process -Id $PID
@{
    target = 'Android'
    state = 'running'
    processId = $PID
    processStartedAtUnixMs = [DateTimeOffset]::new(
        $currentProcess.StartTime.ToUniversalTime()
    ).ToUnixTimeMilliseconds()
    deviceId = [string]$selectedDevice.id
    deviceName = [string]$selectedDevice.name
    packageName = 'com.aaalice.nai_launcher'
    repoRoot = [string]$repoRoot
    controller = 'codex'
    launchedEmulator = $ownsSelectedEmulator
    stopsEmulatorOnExit = $ownsSelectedEmulator -and $StopEmulatorOnExit
    emulatorMonitorProcessId = if ($emulatorMonitor) { $emulatorMonitor.Id } else { $null }
    startedAt = (Get-Date).ToUniversalTime().ToString('o')
} | ConvertTo-Json | Set-Content -LiteralPath $sessionPath -Encoding UTF8

try {
    $flutterArguments = @(
        '--print-dtd',
        'run',
        '--debug',
        '-d',
        $selectedDevice.id,
        '--dart-define=ENABLE_FLUTTER_DRIVER=true'
    ) + @(Get-OptionalOAuthDartDefines)
    & $flutterCommand @flutterArguments
    if ($LASTEXITCODE -ne 0) {
        throw "flutter run failed for Android target '$($selectedDevice.id)'."
    }
}
finally {
    $runSourceLock.Dispose()
    if (Test-Path -LiteralPath $sessionPath -PathType Leaf) {
        $session = Get-Content -LiteralPath $sessionPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ([int]$session.processId -eq $PID) {
            Remove-Item -LiteralPath $sessionPath -Force
        }
    }
}
