[CmdletBinding(DefaultParameterSetName = 'Archive')]
param(
  [Parameter(Mandatory = $true, ParameterSetName = 'Archive')]
  [string]$ArchivePath,
  [Parameter(Mandatory = $true, ParameterSetName = 'Directory')]
  [string]$DirectoryPath,
  [string]$ExpectedVersion
)

$ErrorActionPreference = 'Stop'

function ConvertTo-PortablePath {
  param([string]$Path)

  $normalized = $Path.Replace('\', '/').TrimStart('/')
  if ([string]::IsNullOrWhiteSpace($normalized)) {
    throw 'Portable package contains an empty file path.'
  }
  if ($normalized.Split('/') | Where-Object { $_ -in @('', '.', '..') }) {
    throw "Portable package contains an invalid file path: $Path"
  }
  return $normalized
}

function Assert-WindowsFlutterRuntime {
  param([hashtable]$EntriesByPath)

  foreach ($required in @(
      'nai_launcher.exe',
      'flutter_windows.dll',
      'data/icudtl.dat'
    )) {
    if (-not $EntriesByPath.ContainsKey($required)) {
      throw "Portable package is missing required Windows Flutter runtime file: $required"
    }
    if ($EntriesByPath[$required].Length -le 0) {
      throw "Portable package contains an empty Windows Flutter runtime file: $required"
    }
  }

  $flutterAssets = @(
    $EntriesByPath.GetEnumerator() |
      Where-Object {
        $_.Key.StartsWith('data/flutter_assets/', [StringComparison]::OrdinalIgnoreCase) -and
        $_.Value.Length -gt 0
      }
  )
  if ($flutterAssets.Count -eq 0) {
    throw 'Portable package data/flutter_assets directory does not contain any non-empty files.'
  }
}

function Assert-PortableManifest {
  param(
    [hashtable]$EntriesByPath,
    [string]$ManifestJson
  )

  if (-not $EntriesByPath.ContainsKey('app_files_manifest.json')) {
    throw 'Portable package is missing required file: app_files_manifest.json'
  }

  $manifest = $ManifestJson | ConvertFrom-Json
  if ($manifest.schemaVersion -ne 1) {
    throw "Unsupported app files manifest schema: $($manifest.schemaVersion)"
  }
  if (-not [string]::IsNullOrWhiteSpace($ExpectedVersion) -and
      $manifest.version -ne $ExpectedVersion) {
    throw "Portable manifest version $($manifest.version) does not match $ExpectedVersion."
  }

  $listedFiles = @{}
  foreach ($path in @($manifest.files)) {
    $normalized = ConvertTo-PortablePath ([string]$path)
    if ($normalized -eq 'app_files_manifest.json') {
      throw 'Portable manifest must not list itself.'
    }
    if ($listedFiles.ContainsKey($normalized)) {
      throw "Portable manifest contains a duplicate file: $normalized"
    }
    if (-not $EntriesByPath.ContainsKey($normalized)) {
      throw "Portable manifest references a missing file: $normalized"
    }
    $listedFiles[$normalized] = $true
  }

  $unlisted = @(
    $EntriesByPath.Keys |
      Where-Object {
        $_ -ne 'app_files_manifest.json' -and -not $listedFiles.ContainsKey($_)
      } |
      Sort-Object
  )
  if ($unlisted.Count -gt 0) {
    throw "Portable package contains files missing from the manifest: $($unlisted -join ', ')"
  }
}

if ($PSCmdlet.ParameterSetName -eq 'Directory') {
  $resolvedDirectory = (Resolve-Path -LiteralPath $DirectoryPath).Path
  if (-not (Test-Path -LiteralPath $resolvedDirectory -PathType Container)) {
    throw "Portable package directory was not found: $DirectoryPath"
  }

  $entriesByPath = @{}
  foreach ($file in Get-ChildItem -LiteralPath $resolvedDirectory -File -Recurse) {
    $relativePath = [IO.Path]::GetRelativePath($resolvedDirectory, $file.FullName)
    $normalized = ConvertTo-PortablePath $relativePath
    if ($entriesByPath.ContainsKey($normalized)) {
      throw "Portable package directory contains a duplicate path: $normalized"
    }
    $entriesByPath[$normalized] = $file
  }

  Assert-WindowsFlutterRuntime -EntriesByPath $entriesByPath
  $manifestPath = Join-Path $resolvedDirectory 'app_files_manifest.json'
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw 'Portable package is missing required file: app_files_manifest.json'
  }
  $manifestJson = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8
  Assert-PortableManifest -EntriesByPath $entriesByPath -ManifestJson $manifestJson
  Write-Host "Verified portable package directory: $resolvedDirectory"
  return
}

$resolvedArchive = (Resolve-Path -LiteralPath $ArchivePath).Path
if (-not (Test-Path -LiteralPath $resolvedArchive -PathType Leaf)) {
  throw "Portable package archive was not found: $ArchivePath"
}
Add-Type -AssemblyName System.IO.Compression.FileSystem

$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedArchive)
try {
  $entriesByPath = @{}
  foreach ($entry in @($archive.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) })) {
    $normalized = ConvertTo-PortablePath $entry.FullName
    if ($entriesByPath.ContainsKey($normalized)) {
      throw "Portable archive contains a duplicate entry: $normalized"
    }
    $entriesByPath[$normalized] = $entry
  }

  Assert-WindowsFlutterRuntime -EntriesByPath $entriesByPath
  if (-not $entriesByPath.ContainsKey('app_files_manifest.json')) {
    throw 'Portable package is missing required file: app_files_manifest.json'
  }
  $reader = [IO.StreamReader]::new($entriesByPath['app_files_manifest.json'].Open())
  try {
    $manifestJson = $reader.ReadToEnd()
  } finally {
    $reader.Dispose()
  }
  Assert-PortableManifest -EntriesByPath $entriesByPath -ManifestJson $manifestJson
  Write-Host "Verified portable package archive: $resolvedArchive"
} finally {
  $archive.Dispose()
}
