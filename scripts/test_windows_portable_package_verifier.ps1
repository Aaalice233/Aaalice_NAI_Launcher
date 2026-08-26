$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$verifierPath = Join-Path $PSScriptRoot 'verify_windows_portable_package.ps1'
$testRoot = Join-Path $root "tool/.tmp/windows-portable-verifier-test-$PID-$([guid]::NewGuid().ToString('N'))"
$fixturePath = Join-Path $testRoot 'bundle'
$archivePath = Join-Path $testRoot 'bundle.zip'
$packagerRoot = Join-Path $testRoot 'packager'
$version = '9.8.7'

function Write-TestFile {
  param(
    [string]$RelativePath,
    [string]$Content = 'fixture'
  )

  $path = Join-Path $fixturePath $RelativePath
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
  Set-Content -LiteralPath $path -Value $Content -Encoding UTF8
}

function Write-FixtureManifest {
  $files = @(
    Get-ChildItem -LiteralPath $fixturePath -File -Recurse |
      Where-Object { $_.Name -ne 'app_files_manifest.json' } |
      ForEach-Object {
        [IO.Path]::GetRelativePath($fixturePath, $_.FullName).Replace('\', '/')
      } |
      Sort-Object
  )
  [ordered]@{
    schemaVersion = 1
    version = $version
    files = $files
  } |
    ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath (Join-Path $fixturePath 'app_files_manifest.json') -Encoding UTF8
}

function Reset-Fixture {
  if (Test-Path -LiteralPath $fixturePath) {
    Remove-Item -LiteralPath $fixturePath -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $fixturePath | Out-Null
  Write-TestFile 'nai_launcher.exe' 'executable'
  Write-TestFile 'flutter_windows.dll' 'flutter runtime'
  Write-TestFile 'data/icudtl.dat' 'icu data'
  Write-TestFile 'data/flutter_assets/AssetManifest.bin' 'asset manifest'
  Write-TestFile 'data/flutter_assets/kernel_blob.bin' 'kernel'
  Write-FixtureManifest
}

function New-FixtureArchive {
  if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
  }
  Compress-Archive `
    -Path (Join-Path $fixturePath '*') `
    -DestinationPath $archivePath `
    -CompressionLevel NoCompression
}

function Invoke-Verifier {
  param([ValidateSet('Directory', 'Archive')][string]$Target)

  if ($Target -eq 'Directory') {
    & $verifierPath -DirectoryPath $fixturePath -ExpectedVersion $version
    return
  }

  New-FixtureArchive
  & $verifierPath -ArchivePath $archivePath -ExpectedVersion $version
}

function Assert-Accepted {
  param([string]$Name)

  foreach ($target in @('Directory', 'Archive')) {
    try {
      Invoke-Verifier -Target $target | Out-Null
    } catch {
      throw "$Name should pass for $target input, but failed: $($_.Exception.Message)"
    }
  }
  Write-Host "PASS: $Name"
}

function Assert-Rejected {
  param(
    [string]$Name,
    [string]$ExpectedError
  )

  foreach ($target in @('Directory', 'Archive')) {
    $failure = $null
    try {
      Invoke-Verifier -Target $target | Out-Null
    } catch {
      $failure = $_.Exception.Message
    }
    if ($null -eq $failure) {
      throw "$Name should fail for $target input, but passed."
    }
    if (-not $failure.Contains($ExpectedError, [StringComparison]::OrdinalIgnoreCase)) {
      throw "$Name failed for $target input with an unexpected error: $failure"
    }
  }
  Write-Host "PASS: $Name"
}

function Assert-PackagerChecksRuntimeBeforeReplacingManifest {
  $packagerScripts = Join-Path $packagerRoot 'scripts'
  $packagerBundle = Join-Path $packagerRoot 'build/windows/x64/runner/Release'
  New-Item -ItemType Directory -Force -Path $packagerScripts | Out-Null
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $packagerBundle) | Out-Null
  Copy-Item `
    -LiteralPath (Join-Path $PSScriptRoot 'package_windows_release.ps1') `
    -Destination $packagerScripts
  Copy-Item -LiteralPath $fixturePath -Destination $packagerBundle -Recurse

  $manifestPath = Join-Path $packagerBundle 'app_files_manifest.json'
  $originalManifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
  $failure = $null
  try {
    & (Join-Path $packagerScripts 'package_windows_release.ps1') `
      -Version $version `
      -SkipFlutterBuild `
      -PortableOnly | Out-Null
  } catch {
    $failure = $_.Exception.Message
  } finally {
    Set-Location $root
  }

  if ($null -eq $failure) {
    throw 'Packager should reject a bundle with a missing runtime file.'
  }
  if (-not $failure.Contains(
      'Windows Flutter runtime file was not found:',
      [StringComparison]::OrdinalIgnoreCase
    )) {
    throw "Packager failed with an unexpected error: $failure"
  }
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw 'Packager deleted the old manifest before validating the runtime.'
  }
  $currentManifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
  if ($currentManifest -ne $originalManifest) {
    throw 'Packager replaced the old manifest before validating the runtime.'
  }
  Write-Host 'PASS: packager validates runtime before replacing manifest'
}

try {
  Reset-Fixture
  Assert-Accepted -Name 'complete package'

  Reset-Fixture
  Remove-Item -LiteralPath (Join-Path $fixturePath 'flutter_windows.dll') -Force
  Write-FixtureManifest
  Assert-Rejected `
    -Name 'missing runtime file removed from manifest' `
    -ExpectedError 'missing required Windows Flutter runtime file: flutter_windows.dll'
  Assert-PackagerChecksRuntimeBeforeReplacingManifest

  Reset-Fixture
  Remove-Item `
    -LiteralPath (Join-Path $fixturePath 'data/flutter_assets/kernel_blob.bin') `
    -Force
  Assert-Rejected `
    -Name 'stale manifest references missing file' `
    -ExpectedError 'manifest references a missing file: data/flutter_assets/kernel_blob.bin'

  Reset-Fixture
  Write-TestFile 'unregistered.txt' 'not in manifest'
  Assert-Rejected `
    -Name 'package contains unregistered file' `
    -ExpectedError 'files missing from the manifest: unregistered.txt'

  Write-Host 'Windows portable package verifier regression tests passed.'
} finally {
  if (Test-Path -LiteralPath $testRoot) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
  }
}
