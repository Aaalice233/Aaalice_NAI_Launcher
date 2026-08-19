param(
  [string]$MakensisPath
)

$ErrorActionPreference = 'Stop'

function Get-MakensisPath {
  if (-not [string]::IsNullOrWhiteSpace($MakensisPath)) {
    if (-not (Test-Path -LiteralPath $MakensisPath)) {
      throw "makensis.exe was not found: $MakensisPath"
    }
    return (Resolve-Path -LiteralPath $MakensisPath).Path
  }

  $command = Get-Command 'makensis.exe' -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($command) {
    return $command.Source
  }

  foreach ($candidate in @(
      "${env:ProgramFiles(x86)}\NSIS\makensis.exe",
      "$env:ProgramFiles\NSIS\makensis.exe"
    )) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  throw 'makensis.exe was not found. Install NSIS or pass -MakensisPath.'
}

function Invoke-Makensis {
  param(
    [Parameter(Mandatory)]
    [string]$OutputPath,
    [Parameter(Mandatory)]
    [string]$InstallPath,
    [Parameter(Mandatory)]
    [string]$SourcePath,
    [Parameter(Mandatory)]
    [string]$UninstallKey,
    [string]$ProcessQueryAccess
  )

  $arguments = @(
    '/INPUTCHARSET',
    'UTF8',
    '/DVERSION=0.0.0-test',
    '/DAPP_NAME=Aaalice NAI Launcher Process Test',
    '/DAPP_EXE=nai_launcher_process_test.exe',
    '/DPUBLISHER=Aaalice Test',
    "/DUNINSTALL_KEY=$UninstallKey",
    "/DINSTALL_DIR=$InstallPath",
    "/DSOURCE_DIR=$SourcePath",
    "/DOUT_FILE=$OutputPath"
  )
  if (-not [string]::IsNullOrWhiteSpace($ProcessQueryAccess)) {
    $arguments += "/DPROCESS_QUERY_ACCESS=$ProcessQueryAccess"
  }
  $arguments += $script:NsisScript

  & $script:Makensis @arguments
  if ($LASTEXITCODE -ne 0) {
    throw "makensis.exe failed with exit code $LASTEXITCODE"
  }
  if (-not (Test-Path -LiteralPath $OutputPath)) {
    throw "NSIS did not produce the expected installer: $OutputPath"
  }
}

function Start-HiddenProcess {
  param(
    [Parameter(Mandatory)]
    [string]$Path
  )

  $process = Start-Process `
    -FilePath $Path `
    -ArgumentList @('-t', '127.0.0.1') `
    -WindowStyle Hidden `
    -PassThru
  [void]$script:StartedProcesses.Add($process)
  Start-Sleep -Milliseconds 300
  $process.Refresh()
  if ($process.HasExited) {
    throw "Test process exited unexpectedly: $Path"
  }
  return $process
}

function Invoke-SilentExecutable {
  param(
    [Parameter(Mandatory)]
    [string]$Path
  )

  $process = Start-Process `
    -FilePath $Path `
    -ArgumentList '/S' `
    -WindowStyle Hidden `
    -Wait `
    -PassThru
  return $process.ExitCode
}

function Assert-ProcessState {
  param(
    [Parameter(Mandatory)]
    [System.Diagnostics.Process]$Process,
    [Parameter(Mandatory)]
    [bool]$HasExited,
    [Parameter(Mandatory)]
    [string]$Message
  )

  $Process.Refresh()
  if ($Process.HasExited -ne $HasExited) {
    throw $Message
  }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$script:NsisScript = Join-Path $repoRoot 'installer\windows\nai_launcher.nsi'
$script:Makensis = Get-MakensisPath
$script:StartedProcesses = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()
$testId = [Guid]::NewGuid().ToString('N')
$tempRoot = Join-Path $env:TEMP "nai-launcher-installer-process-$testId"
$sourceDir = Join-Path $tempRoot 'source'
$installDir = Join-Path $tempRoot 'installed'
$otherDir = Join-Path $tempRoot 'other'
$outputDir = Join-Path $tempRoot 'output'
$appName = 'nai_launcher_process_test.exe'
$uninstallKey = "Software\Aaalice\InstallerProcessTest\$testId"

try {
  foreach ($directory in @($sourceDir, $installDir, $otherDir, $outputDir)) {
    [void](New-Item -ItemType Directory -Path $directory -Force)
  }

  $ping = Join-Path $env:SystemRoot 'System32\ping.exe'
  Copy-Item -LiteralPath $ping -Destination (Join-Path $sourceDir $appName)
  Copy-Item -LiteralPath $ping -Destination (Join-Path $installDir $appName)
  Copy-Item -LiteralPath $ping -Destination (Join-Path $otherDir $appName)
  Set-Content `
    -LiteralPath (Join-Path $sourceDir 'source-version.txt') `
    -Value 'new installer payload' `
    -Encoding UTF8

  $normalInstaller = Join-Path $outputDir 'normal-setup.exe'
  Invoke-Makensis `
    -OutputPath $normalInstaller `
    -InstallPath $installDir `
    -SourcePath $sourceDir `
    -UninstallKey $uninstallKey

  $targetProcess = Start-HiddenProcess -Path (Join-Path $installDir $appName)
  $otherProcess = Start-HiddenProcess -Path (Join-Path $otherDir $appName)

  $installExit = Invoke-SilentExecutable -Path $normalInstaller
  if ($installExit -ne 0) {
    throw "Normal silent installer exited with code $installExit"
  }
  Assert-ProcessState `
    -Process $targetProcess `
    -HasExited $true `
    -Message 'The installer did not stop the executable from its own install directory.'
  Assert-ProcessState `
    -Process $otherProcess `
    -HasExited $false `
    -Message 'The installer stopped a same-named executable from another directory.'
  if (-not (Test-Path -LiteralPath (Join-Path $installDir 'source-version.txt'))) {
    throw 'The normal installer did not copy its payload.'
  }

  $uninstaller = Join-Path $installDir 'Uninstall.exe'
  $uninstallExit = Invoke-SilentExecutable -Path $uninstaller
  if ($uninstallExit -ne 0) {
    throw "Silent uninstaller exited with code $uninstallExit"
  }
  Assert-ProcessState `
    -Process $otherProcess `
    -HasExited $false `
    -Message 'The uninstaller stopped a same-named executable from another directory.'

  [void](New-Item -ItemType Directory -Path $installDir -Force)
  Copy-Item -LiteralPath $ping -Destination (Join-Path $installDir $appName)
  Set-Content `
    -LiteralPath (Join-Path $installDir 'existing-version.txt') `
    -Value 'existing installation' `
    -Encoding UTF8

  $blockedInstaller = Join-Path $outputDir 'blocked-setup.exe'
  Invoke-Makensis `
    -OutputPath $blockedInstaller `
    -InstallPath $installDir `
    -SourcePath $sourceDir `
    -UninstallKey $uninstallKey `
    -ProcessQueryAccess '0x00000001'

  $unreadableTarget = Start-HiddenProcess -Path (Join-Path $installDir $appName)
  $blockedExit = Invoke-SilentExecutable -Path $blockedInstaller
  if ($blockedExit -ne 3) {
    throw "Fail-closed installer exited with code $blockedExit instead of 3."
  }
  Assert-ProcessState `
    -Process $unreadableTarget `
    -HasExited $false `
    -Message 'The fail-closed installer stopped a process whose path it could not inspect.'
  if (-not (Test-Path -LiteralPath (Join-Path $installDir 'existing-version.txt'))) {
    throw 'The fail-closed installer modified the existing installation.'
  }
  if (Test-Path -LiteralPath (Join-Path $installDir 'source-version.txt')) {
    throw 'The fail-closed installer copied files after process inspection failed.'
  }

  Write-Host 'Windows installer process isolation and fail-closed checks passed.'
} finally {
  foreach ($process in $script:StartedProcesses) {
    try {
      $process.Refresh()
      if (-not $process.HasExited) {
        Stop-Process -Id $process.Id -Force
      }
    } catch {
      Write-Warning "Failed to stop test process $($process.Id): $($_.Exception.Message)"
    }
  }

  $registryPath = "HKCU:\$uninstallKey"
  if (Test-Path -LiteralPath $registryPath) {
    Remove-Item -LiteralPath $registryPath -Recurse -Force
  }

  if (Test-Path -LiteralPath $tempRoot) {
    $resolvedTemp = [System.IO.Path]::GetFullPath($tempRoot)
    $resolvedBase = [System.IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
    if (-not $resolvedTemp.StartsWith(
        $resolvedBase,
        [System.StringComparison]::OrdinalIgnoreCase
      )) {
      throw "Refusing to remove a test directory outside TEMP: $resolvedTemp"
    }
    Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
  }
}
