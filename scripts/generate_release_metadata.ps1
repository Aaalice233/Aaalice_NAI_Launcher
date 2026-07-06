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
      description = '解压即用，不自动更新，适合放在自定义目录。'
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
  return $null
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

$releaseFiles = Get-ChildItem -Path $assetPath -File |
  Where-Object { $_.Extension -in @('.exe', '.zip') } |
  Sort-Object Name

if (-not $releaseFiles) {
  throw "No release assets were found in $assetPath"
}

$assets = @()
$checksumLines = @()
foreach ($file in $releaseFiles) {
  $assetInfo = Get-AssetInfo -File $file
  if (-not $assetInfo) {
    throw "Unknown release asset type: $($file.Name)"
  }

  $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  $downloadUrl = "https://github.com/$Repository/releases/download/$Tag/$([uri]::EscapeDataString($file.Name))"
  $checksumLines += "$hash  $($file.Name)"
  $assets += [ordered]@{
    platform = $assetInfo.platform
    type = $assetInfo.type
    fileName = $file.Name
    downloadUrl = $downloadUrl
    sha256 = $hash
    size = $file.Length
    label = $assetInfo.label
    description = $assetInfo.description
  }
}

$manifest = [ordered]@{
  version = $Version
  tag = $Tag
  publishedAt = (Get-Date).ToUniversalTime().ToString('o')
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

$markdownCodeTick = [char]96
$downloadRows = $assets | ForEach-Object {
  "| $markdownCodeTick$($_['fileName'])$markdownCodeTick | $($_['description']) |"
}
$changelogSection = Get-ChangelogSection -Version ($Version -replace '\+.*$', '')

$releaseLines = @(
  "# NAI Launcher $Tag",
  "",
  "## 📦 发布文件",
  "",
  "| 文件 | 说明 |",
  "| --- | --- |"
)
$releaseLines += $downloadRows
$releaseLines += @(
  "",
  "## 📝 更新内容",
  "",
  $changelogSection,
  "",
  "## 🔐 校验",
  "",
  '本次 Release 附带 `checksums.txt` 和 `release_manifest.json`。安装版应用内更新会在启动安装器前校验 SHA256。'
)

$releaseNotes = $releaseLines -join [Environment]::NewLine

$releaseNotes | Set-Content -Path $notesPath -Encoding UTF8

Write-Host "Created release manifest: $manifestPath"
Write-Host "Created checksums: $checksumsPath"
Write-Host "Created release notes: $notesPath"
