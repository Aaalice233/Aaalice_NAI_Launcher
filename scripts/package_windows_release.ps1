param(
  [string]$Version,
  [switch]$SkipFlutterBuild,
  [string]$DistDir = "dist"
)

$ErrorActionPreference = 'Stop'

function Get-PubspecVersion {
  $match = Select-String -Path "pubspec.yaml" -Pattern '^version:\s*(.+)$'
  if (-not $match) {
    throw "pubspec.yaml does not contain a version field."
  }
  return $match.Matches[0].Groups[1].Value.Trim()
}

function Get-ToolPath {
  param(
    [string]$Name,
    [string[]]$FallbackPaths = @()
  )

  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  foreach ($path in $FallbackPaths) {
    if (Test-Path -LiteralPath $path) {
      return $path
    }
  }

  throw "$Name was not found. Install NSIS or add it to PATH."
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $root

if ([string]::IsNullOrWhiteSpace($Version)) {
  $Version = Get-PubspecVersion
}

$distPath = Join-Path $root $DistDir
$buildPath = Join-Path $root "build/windows/x64/runner/Release"
$exePath = Join-Path $buildPath "nai_launcher.exe"
$nsisScript = Join-Path $root "installer/windows/nai_launcher.nsi"
$portablePath = Join-Path $distPath "NAI_Launcher_Windows_${Version}_Portable.zip"
$installerPath = Join-Path $distPath "NAI_Launcher_Windows_${Version}_Setup.exe"

if (-not $SkipFlutterBuild) {
  & (Join-Path $PSScriptRoot "verify_nuget.ps1")
  flutter pub get
  flutter gen-l10n
  dart run build_runner build --delete-conflicting-outputs
  flutter build windows --release
}

if (-not (Test-Path -LiteralPath $exePath)) {
  throw "Windows release executable was not found: $exePath"
}

New-Item -ItemType Directory -Force -Path $distPath | Out-Null

if (Test-Path -LiteralPath $portablePath) {
  Remove-Item -LiteralPath $portablePath -Force
}

Compress-Archive `
  -Path (Join-Path $buildPath "*") `
  -DestinationPath $portablePath `
  -Force

$makensis = Get-ToolPath `
  -Name "makensis.exe" `
  -FallbackPaths @(
    "${env:ProgramFiles(x86)}/NSIS/makensis.exe",
    "${env:ProgramFiles}/NSIS/makensis.exe"
  )

& $makensis `
  "/DVERSION=$Version" `
  "/DSOURCE_DIR=$buildPath" `
  "/DOUT_FILE=$installerPath" `
  $nsisScript

if (-not (Test-Path -LiteralPath $installerPath)) {
  throw "NSIS did not produce installer: $installerPath"
}

Write-Host "Created Windows installer: $installerPath"
Write-Host "Created Windows portable package: $portablePath"
