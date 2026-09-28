param(
  [string]$Version,
  [switch]$SkipFlutterBuild,
  [ValidateSet("Debug", "Release")]
  [string]$BuildMode = "Release",
  [switch]$PortableOnly,
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

function Assert-WindowsFlutterRuntime {
  param([string]$BundlePath)

  foreach ($required in @(
      'nai_launcher.exe',
      'flutter_windows.dll',
      'data/icudtl.dat'
    )) {
    $path = Join-Path $BundlePath $required
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      throw "Windows Flutter runtime file was not found: $path"
    }
    if ((Get-Item -LiteralPath $path).Length -le 0) {
      throw "Windows Flutter runtime file is empty: $path"
    }
  }

  $flutterAssetsPath = Join-Path $BundlePath 'data/flutter_assets'
  $flutterAssets = @(
    if (Test-Path -LiteralPath $flutterAssetsPath -PathType Container) {
      Get-ChildItem -LiteralPath $flutterAssetsPath -File -Recurse |
        Where-Object { $_.Length -gt 0 }
    }
  )
  if ($flutterAssets.Count -eq 0) {
    throw "Windows Flutter assets directory does not contain any non-empty files: $flutterAssetsPath"
  }
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $root

if ([string]::IsNullOrWhiteSpace($Version)) {
  $Version = Get-PubspecVersion
}

$distPath = Join-Path $root $DistDir
$buildPath = Join-Path $root "build/windows/x64/runner/$BuildMode"
$nsisScript = Join-Path $root "installer/windows/nai_launcher.nsi"
$portablePath = Join-Path $distPath "NAI_Launcher_Windows_${Version}_Portable.zip"
$installerPath = Join-Path $distPath "NAI_Launcher_Windows_${Version}_Setup.exe"

if (-not $SkipFlutterBuild) {
  & (Join-Path $PSScriptRoot "verify_nuget.ps1")
  & (Join-Path $PSScriptRoot "verify_flutter_sources.ps1")
  flutter pub get --enforce-lockfile
  flutter gen-l10n
  dart run build_runner build --delete-conflicting-outputs
  $flutterBuildMode = $BuildMode.ToLowerInvariant()
  flutter build windows --$flutterBuildMode
}

Assert-WindowsFlutterRuntime -BundlePath $buildPath

# 便携版更新使用该清单区分应用文件与用户放在程序目录中的个人文件。
$filesManifestPath = Join-Path $buildPath "app_files_manifest.json"
if (Test-Path -LiteralPath $filesManifestPath) {
  Remove-Item -LiteralPath $filesManifestPath -Force
}
$managedFiles = Get-ChildItem -LiteralPath $buildPath -File -Recurse |
  ForEach-Object {
    $_.FullName.Substring($buildPath.Length).TrimStart([char[]]@('\', '/'))
  } |
  Sort-Object
[ordered]@{
  schemaVersion = 1
  version = $Version
  files = @($managedFiles)
} |
  ConvertTo-Json -Depth 4 |
  Set-Content -LiteralPath $filesManifestPath -Encoding UTF8

New-Item -ItemType Directory -Force -Path $distPath | Out-Null

if (Test-Path -LiteralPath $portablePath) {
  Remove-Item -LiteralPath $portablePath -Force
}

Compress-Archive `
  -Path (Join-Path $buildPath "*") `
  -DestinationPath $portablePath `
  -Force

Write-Host "Created Windows portable package: $portablePath"

if ($PortableOnly) {
  return
}

$makensis = Get-ToolPath `
  -Name "makensis.exe" `
  -FallbackPaths @(
    "${env:ProgramFiles(x86)}/NSIS/makensis.exe",
    "${env:ProgramFiles}/NSIS/makensis.exe"
  )

& $makensis `
  "/INPUTCHARSET" `
  "UTF8" `
  "/DVERSION=$Version" `
  "/DSOURCE_DIR=$buildPath" `
  "/DOUT_FILE=$installerPath" `
  $nsisScript

if (-not (Test-Path -LiteralPath $installerPath)) {
  throw "NSIS did not produce installer: $installerPath"
}

Write-Host "Created Windows installer: $installerPath"
