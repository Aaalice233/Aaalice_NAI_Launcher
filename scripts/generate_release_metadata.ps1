param(
  [Parameter(Mandatory = $true)]
  [string]$AssetDirectory,

  [string]$OutputDirectory,

  [Parameter(Mandatory = $true)]
  [string]$Version,

  [Parameter(Mandatory = $true)]
  [string]$Tag,

  [Parameter(Mandatory = $true)]
  [string]$Repository
)

$ErrorActionPreference = 'Stop'

function Get-AssetInfo {
  param([System.IO.FileInfo]$File)

  $name = $File.Name
  if ($name -match '_Windows_.*_Setup\.exe$') {
    return [ordered]@{
      platform = 'windows'
      type = 'windows-installer'
      label = 'Windows 安装版'
      description = '推荐普通用户使用，支持应用内一键更新。'
    }
  }
  if ($name -match '_Windows_.*_Portable\.zip$') {
    return [ordered]@{
      platform = 'windows'
      type = 'windows-portable'
      label = 'Windows 便携版'
      description = '解压即用，支持应用内一键更新，适合放在自定义目录。'
    }
  }
  if ($name -match '_macOS_.*_Portable\.zip$') {
    return [ordered]@{
      platform = 'macos'
      type = 'macos-portable'
      label = 'macOS 便携版'
      description = '解压后打开应用，更新时需要手动替换。'
    }
  }
  if ($name -match '_Android_.+_(arm64-v8a|armeabi-v7a|x86_64)\.apk$') {
    $abi = $Matches[1].ToLowerInvariant()
    return [ordered]@{
      platform = 'android'
      type = 'android-apk'
      abi = $abi
      label = "Android APK ($abi)"
      description = '下载后由 Android 系统确认并安装更新。'
    }
  }
  if ($name -match '_Android_.*\.apk$') {
    return [ordered]@{
      platform = 'android'
      type = 'android-apk'
      abi = $null
      label = 'Android APK'
      description = '下载后由 Android 系统确认并安装更新。'
    }
  }
  return $null
}

function Get-PlatformSortOrder {
  param([string]$Platform)

  switch ($Platform) {
    'android' { return 0 }
    'macos' { return 1 }
    'windows' { return 2 }
    default { return 3 }
  }
}

function Get-AndroidAbiSortOrder {
  param([string]$Abi)

  switch ($Abi) {
    'arm64-v8a' { return 0 }
    'armeabi-v7a' { return 1 }
    'x86_64' { return 2 }
    default {
      if ([string]::IsNullOrEmpty($Abi)) {
        return 3
      }
      return 4
    }
  }
}

function Get-ChangelogSection {
  param([string]$Version)

  $changelogPath = Join-Path (Resolve-Path ".") "CHANGELOG.md"
  if (-not (Test-Path -LiteralPath $changelogPath)) {
    return "本次发布见 CHANGELOG.md。"
  }

  $lines = Get-Content -Path $changelogPath -Encoding UTF8
  $headerPattern = '^##\s+(\[)?v?' + [regex]::Escape($Version) + '(\])?(\s|$)'
  $start = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match $headerPattern) {
      $start = $i + 1
      break
    }
  }

  if ($start -lt 0) {
    return "本次发布见 CHANGELOG.md。"
  }

  $end = $lines.Count
  for ($i = $start; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^##\s+') {
      $end = $i
      break
    }
  }

  $section = $lines[$start..($end - 1)] -join [Environment]::NewLine
  if ([string]::IsNullOrWhiteSpace($section)) {
    return "本次发布见 CHANGELOG.md。"
  }
  return $section.Trim()
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $OutputDirectory = $AssetDirectory
}

$assetPath = Resolve-Path $AssetDirectory
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$outputPath = Resolve-Path $OutputDirectory

$candidateFiles = @(
  Get-ChildItem -Path $assetPath -File |
    Where-Object { $_.Extension -in @('.exe', '.zip', '.apk') }
)

if (-not $candidateFiles) {
  throw "No release assets were found in $assetPath"
}

# 旧版客户端（v4.3.1 及以前）会直接选用 manifest 中第一个 android-apk 资产，
# 因此 Android 资产必须显式保证 arm64-v8a 排在第一位，不依赖文件名字母序。
$resolvedEntries = @(
  foreach ($file in $candidateFiles) {
    $assetInfo = Get-AssetInfo -File $file
    if (-not $assetInfo) {
      throw "Unknown release asset type: $($file.Name)"
    }
    [pscustomobject]@{
      File = $file
      Info = $assetInfo
      PlatformOrder = Get-PlatformSortOrder -Platform $assetInfo.platform
      AbiOrder = if ($assetInfo.platform -eq 'android') {
        Get-AndroidAbiSortOrder -Abi $assetInfo.abi
      } else {
        0
      }
    }
  }
) | Sort-Object PlatformOrder, AbiOrder, @{ Expression = { $_.File.Name } }

$assets = @()
$checksumLines = @()
foreach ($entry in $resolvedEntries) {
  $file = $entry.File
  $assetInfo = $entry.Info

  $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  $downloadUrl = "https://github.com/$Repository/releases/download/$Tag/$([uri]::EscapeDataString($file.Name))"
  $checksumLines += "$hash  $($file.Name)"
  $assetRecord = [ordered]@{
    platform = $assetInfo.platform
    type = $assetInfo.type
  }
  if ($assetInfo.Contains('abi')) {
    $assetRecord['abi'] = $assetInfo.abi
  }
  $assetRecord['fileName'] = $file.Name
  $assetRecord['downloadUrl'] = $downloadUrl
  $assetRecord['sha256'] = $hash
  $assetRecord['size'] = $file.Length
  $assetRecord['label'] = $assetInfo.label
  $assetRecord['description'] = $assetInfo.description
  $assets += $assetRecord
}

$changelogSection = Get-ChangelogSection -Version ($Version -replace '\+.*$', '')
$manifest = [ordered]@{
  version = $Version
  tag = $Tag
  name = "NAI Launcher $Tag"
  publishedAt = (Get-Date).ToUniversalTime().ToString('o')
  releaseNotes = $changelogSection
  assets = $assets
}

$manifestPath = Join-Path $outputPath "release_manifest.json"
$checksumsPath = Join-Path $outputPath "checksums.txt"
$notesPath = Join-Path $outputPath "release_notes_${Tag}.md"

$manifest |
  ConvertTo-Json -Depth 6 |
  Set-Content -Path $manifestPath -Encoding UTF8
$checksumLines |
  Set-Content -Path $checksumsPath -Encoding UTF8

function Get-DownloadBadge {
  param([System.Collections.IDictionary]$Asset)

  $type = $Asset['type']
  $url = $Asset['downloadUrl']
  switch ($type) {
    'windows-installer' {
      return "[![Windows Setup x64](https://img.shields.io/badge/Setup-x64-0078D4?style=flat-square&logo=windows11&logoColor=white)]($url)"
    }
    'windows-portable' {
      return "[![Windows Portable x64](https://img.shields.io/badge/Portable-x64-56B4D3?style=flat-square&logo=windows11&logoColor=white)]($url)"
    }
    'macos-portable' {
      return "[![macOS Portable ZIP](https://img.shields.io/badge/Portable-ZIP-555555?style=flat-square&logo=apple&logoColor=white)]($url)"
    }
    'android-apk' {
      $abi = $Asset['abi']
      if (-not [string]::IsNullOrWhiteSpace($abi)) {
        $escapedAbi = $abi.Replace('-', '--').Replace('_', '__')
        return "[![Android APK ($abi)](https://img.shields.io/badge/APK-$escapedAbi-3DDC84?style=flat-square&logo=android&logoColor=white)]($url)"
      }
      return "[![Android APK](https://img.shields.io/badge/Android-APK-3DDC84?style=flat-square&logo=android&logoColor=white)]($url)"
    }
    default {
      throw "Cannot create download badge for asset type: $type"
    }
  }
}

$windowsBadges = @(
  $assets |
    Where-Object { $_['platform'] -eq 'windows' } |
    ForEach-Object { Get-DownloadBadge -Asset $_ }
)
$macosBadges = @(
  $assets |
    Where-Object { $_['platform'] -eq 'macos' } |
    ForEach-Object { Get-DownloadBadge -Asset $_ }
)
$androidAssets = @(
  $assets |
    Where-Object { $_['platform'] -eq 'android' }
)
$androidBadges = @(
  $androidAssets |
    ForEach-Object { Get-DownloadBadge -Asset $_ }
)
$hasSplitAndroidApks = @(
  $androidAssets |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_['abi']) }
).Count -gt 0
$downloadRows = @()
if ($windowsBadges.Count -gt 0) {
  $downloadRows += "| **Windows** | $($windowsBadges -join '<br>') |"
}
if ($macosBadges.Count -gt 0) {
  $downloadRows += "| **macOS** | $($macosBadges -join '<br>') |"
}
if ($androidBadges.Count -gt 0) {
  $androidCell = $androidBadges -join '<br>'
  if ($hasSplitAndroidApks) {
    $androidCell += '<br><sub>大多数手机与平板请选择 `arm64-v8a`（32 位旧设备选 `armeabi-v7a`，桌面模拟器选 `x86_64`）。</sub>'
  }
  $downloadRows += "| **Android** | $androidCell |"
}
$releaseLines = @(
  "# NAI Launcher $Tag",
  "",
  "## 📥 按系统下载",
  "",
  "点击对应按钮直接下载：",
  "",
  "| OS | Download |",
  "| --- | --- |"
)
$releaseLines += $downloadRows
$releaseLines += @(
  '',
  '> **应用内更新：** Windows 安装版用户无需手动下载。应用会自动选择 Setup x64，完成下载与 SHA256 校验后退出旧版本、静默安装并重新启动。Portable 版也支持应用内自动更新和失败回滚；Android 应用内更新会自动按设备架构下载对应 APK。',
  '',
  '> **安装提示：** Android 下载 APK 后由系统确认更新（大多数手机选 `arm64-v8a`）；macOS 当前需下载 ZIP 后手动替换应用。Windows Setup 为普通用户的推荐版本，Portable 适合放在自定义目录。',
  "",
  "## 📝 更新内容",
  "",
  $changelogSection,
  "",
  "## 🔐 文件校验",
  "",
  '本次 Release 附带 `checksums.txt` 和 `release_manifest.json`。应用内更新会同时校验文件大小与 SHA256，校验失败不会启动安装。'
)

$releaseNotes = $releaseLines -join [Environment]::NewLine

$releaseNotes | Set-Content -Path $notesPath -Encoding UTF8

Write-Host "Created release manifest: $manifestPath"
Write-Host "Created checksums: $checksumsPath"
Write-Host "Created release notes: $notesPath"
