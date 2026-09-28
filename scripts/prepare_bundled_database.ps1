[CmdletBinding()]
param(
  [string]$ManifestPath = 'assets/databases/manifest.json',
  [string]$DestinationPath = 'assets/databases/tag_catalog.db'
)

$ErrorActionPreference = 'Stop'

if ($env:GITHUB_ACTIONS -eq 'true') {
  # Checkout keeps the pointer, while generated-file checks still need the
  # normal LFS clean filter to recognize the verified replacement as unchanged.
  & git lfs install --local --skip-smudge
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to configure the local Git LFS pointer filter.'
  }
}

function Test-DatabaseFile {
  param(
    [Parameter(Mandatory)] [string]$Path,
    [Parameter(Mandatory)] [long]$ExpectedSize,
    [Parameter(Mandatory)] [string]$ExpectedSha256
  )

  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
    return $false
  }

  $item = Get-Item -LiteralPath $Path -Force
  if ($item.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint) -or
      $item.Length -ne $ExpectedSize) {
    return $false
  }

  $stream = [IO.File]::OpenRead($item.FullName)
  try {
    $headerBytes = [byte[]]::new(16)
    if ($stream.Read($headerBytes, 0, $headerBytes.Length) -ne 16) {
      return $false
    }
    if ([Text.Encoding]::ASCII.GetString($headerBytes) -ne "SQLite format 3`0") {
      return $false
    }
  } finally {
    $stream.Dispose()
  }

  $actualSha256 = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
  return $actualSha256.Equals($ExpectedSha256, [StringComparison]::OrdinalIgnoreCase)
}

$manifestFile = Get-Item -LiteralPath $ManifestPath
$manifest = Get-Content -LiteralPath $manifestFile.FullName -Raw -Encoding UTF8 |
  ConvertFrom-Json
$database = $manifest.databases.'tag_catalog.db'
if ($null -eq $database) {
  throw 'Database manifest does not contain tag_catalog.db.'
}

$expectedSize = [long]$database.size
$expectedSha256 = [string]$database.sha256
$dataVersion = [string]$database.dataVersion
$releaseTag = [string]$database.release.tag
$releaseUrl = [string]$database.release.url
$expectedUrl = "https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/download/$releaseTag/tag_catalog.db"

if ($expectedSize -lt 1024 -or $expectedSize -gt 160MB) {
  throw "Invalid tag catalog size in manifest: $expectedSize"
}
if ($expectedSha256 -notmatch '^[0-9a-f]{64}$') {
  throw 'Invalid tag catalog SHA-256 in manifest.'
}
if ($dataVersion -notmatch '^[0-9a-f]{12}$') {
  throw 'Invalid tag catalog data version in manifest.'
}
$releaseTagPattern =
  "^autocomplete-data-tag-catalog-$($dataVersion.Substring(0, 8))-v[1-9][0-9]*$"
if ($releaseTag -notmatch $releaseTagPattern -or
    $releaseUrl -cne $expectedUrl -or
    $database.release.prerelease -ne $true -or
    $database.release.makeLatest -ne $false) {
  throw 'Tag catalog release metadata is invalid or not source-locked.'
}

$destination = [IO.Path]::GetFullPath($DestinationPath)
if (Test-Path -LiteralPath $destination) {
  $destinationItem = Get-Item -LiteralPath $destination -Force
  if ($destinationItem.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) {
    throw "Refusing to replace a reparse point: $destination"
  }
}
if (Test-DatabaseFile `
    -Path $destination `
    -ExpectedSize $expectedSize `
    -ExpectedSha256 $expectedSha256) {
  Write-Host "Bundled database is already verified: $destination"
  exit 0
}

$destinationDirectory = Split-Path -Parent $destination
[IO.Directory]::CreateDirectory($destinationDirectory) | Out-Null
$temporaryPath = Join-Path `
  $destinationDirectory `
  ".tag_catalog.$PID.$([guid]::NewGuid().ToString('N')).download"

try {
  Write-Host "Downloading verified bundled database from $releaseUrl"
  Invoke-WebRequest `
    -Uri $releaseUrl `
    -OutFile $temporaryPath `
    -MaximumRetryCount 2 `
    -RetryIntervalSec 3

  if (!(Test-DatabaseFile `
      -Path $temporaryPath `
      -ExpectedSize $expectedSize `
      -ExpectedSha256 $expectedSha256)) {
    throw 'Downloaded tag catalog failed size, SQLite header, or SHA-256 validation.'
  }

  # The temporary file is in the destination directory so File.Move maps to
  # one same-volume rename/replace operation on every supported runner.
  [IO.File]::Move($temporaryPath, $destination, $true)
  Write-Host "Prepared verified bundled database: $destination"
} finally {
  Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
}
