param(
    [string]$DeviceId,
    [string]$Name = 'android-ui',
    [string[]]$Action = @(),
    [switch]$HotReload,
    [switch]$Foreground,
    [ValidateRange(0, 10000)]
    [int]$ReloadWaitMilliseconds = 1200,
    [ValidateRange(0, 5000)]
    [int]$ActionWaitMilliseconds = 250
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir '../../../..')
$sessionPath = Join-Path $repoRoot 'tool/.tmp/android_hot_reload_session.json'
$packageName = 'com.aaalice.nai_launcher'

if (Test-Path -LiteralPath $sessionPath -PathType Leaf) {
    $session = Get-Content -LiteralPath $sessionPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace($DeviceId)) {
        $DeviceId = [string]$session.deviceId
    }
    $packageName = [string]$session.packageName
}
if ([string]::IsNullOrWhiteSpace($DeviceId)) {
    throw 'No Android target was supplied and no active Android hot-reload session was found.'
}
if ($Name -notmatch '^[a-zA-Z0-9][a-zA-Z0-9._-]*$') {
    throw 'Name may contain only letters, numbers, dot, underscore, and hyphen.'
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
            $sdkRoots += $sdkLine.Substring('sdk.dir='.Length).Replace('\\', '\').Replace('\:', ':')
        }
    }

    foreach ($sdkRoot in $sdkRoots) {
        if ([string]::IsNullOrWhiteSpace($sdkRoot)) {
            continue
        }
        $candidate = Join-Path $sdkRoot 'platform-tools/adb.exe'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    throw 'adb command not found. Add Android SDK platform-tools to PATH.'
}

function Invoke-Adb {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    & $adbCommand -s $DeviceId @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "adb failed: $($Arguments -join ' ')"
    }
}

function Invoke-UiAction {
    param([Parameter(Mandatory = $true)][string]$Value)

    if ($Value -match '^wait:(\d+)$') {
        Start-Sleep -Milliseconds ([int]$Matches[1])
        return
    }
    if ($Value -match '^tap:(\d+),(\d+)$') {
        Invoke-Adb shell input tap $Matches[1] $Matches[2] | Out-Null
    }
    elseif ($Value -match '^key:([a-zA-Z0-9_]+)$') {
        Invoke-Adb shell input keyevent $Matches[1] | Out-Null
    }
    elseif ($Value -match '^text:(.*)$') {
        $text = $Matches[1].Replace(' ', '%s')
        Invoke-Adb shell input text $text | Out-Null
    }
    elseif ($Value -match '^swipe:(\d+),(\d+),(\d+),(\d+),(\d+)$') {
        Invoke-Adb shell input swipe $Matches[1] $Matches[2] $Matches[3] $Matches[4] $Matches[5] | Out-Null
    }
    else {
        throw "Unsupported Android UI action: $Value"
    }

    if ($ActionWaitMilliseconds -gt 0) {
        Start-Sleep -Milliseconds $ActionWaitMilliseconds
    }
}

$adbCommand = Resolve-AdbCommand
$startedAt = Get-Date
$state = (& $adbCommand -s $DeviceId get-state | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $state -ne 'device') {
    throw "Android target '$DeviceId' is not ready."
}

if ($HotReload) {
    $pwshCommand = (Get-Command pwsh -ErrorAction Stop).Source
    $reloadScript = Join-Path $repoRoot '.pi/skills/aaalice-hot-reload/scripts/control.ps1'
    & $pwshCommand -NoProfile -ExecutionPolicy Bypass -File $reloadScript `
        -Action Reload `
        -Target Android `
        -SkipLogs
    if ($LASTEXITCODE -ne 0) {
        throw 'Android hot reload failed.'
    }
    if ($ReloadWaitMilliseconds -gt 0) {
        Start-Sleep -Milliseconds $ReloadWaitMilliseconds
    }
}
if ($Foreground) {
    Invoke-Adb shell am start -n "$packageName/.MainActivity" | Out-Null
    Start-Sleep -Milliseconds 350
}

Invoke-Adb logcat -c | Out-Null
foreach ($item in $Action) {
    Invoke-UiAction -Value $item
}

$outputDirectory = Join-Path $repoRoot 'tool/.tmp/android-e2e'
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$screenshotPath = Join-Path $outputDirectory "$Name.png"
$windowPath = Join-Path $outputDirectory "$Name.xml"
$logPath = Join-Path $outputDirectory "$Name.log"
$activityPath = Join-Path $outputDirectory "$Name.activity.txt"
$deviceWindowPath = "/data/local/tmp/$Name.xml"

& $adbCommand -s $DeviceId exec-out screencap -p > $screenshotPath
if ($LASTEXITCODE -ne 0) {
    throw 'Android screenshot capture failed.'
}
Invoke-Adb shell uiautomator dump $deviceWindowPath | Out-Null
Invoke-Adb pull $deviceWindowPath $windowPath | Out-Null
Invoke-Adb shell rm -f $deviceWindowPath | Out-Null
$activity = Invoke-Adb shell dumpsys activity activities
$activity | Set-Content -LiteralPath $activityPath -Encoding UTF8
$logs = Invoke-Adb logcat -d -v time -t 2000 'flutter:I' 'flutter:E' 'AndroidRuntime:E' '*:S'
$logs | Set-Content -LiteralPath $logPath -Encoding UTF8

if (($activity | Out-String) -notmatch [regex]::Escape($packageName)) {
    throw "Android verification artifacts were captured, but '$packageName' is not in the activity stack."
}

$errorPattern = 'RenderFlex overflowed|EXCEPTION CAUGHT BY (?:WIDGETS|RENDERING) LIBRARY|FATAL EXCEPTION|AndroidRuntime: Process: com\.aaalice\.nai_launcher'
$errors = @($logs | Select-String -Pattern $errorPattern)
if ($errors.Count -gt 0) {
    throw "Android UI verification captured $($errors.Count) new Flutter/native error line(s). See $logPath"
}

$elapsed = [Math]::Round(((Get-Date) - $startedAt).TotalSeconds, 2)
Write-Output "Android UI verification completed in ${elapsed}s."
Write-Output "Screenshot: $screenshotPath"
Write-Output "Window tree: $windowPath"
Write-Output "Log: $logPath"
