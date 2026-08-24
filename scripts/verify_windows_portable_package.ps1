param(
  [Parameter(Mandatory = $true)]
  [string]$ArchivePath,
  [string]$ExpectedVersion
)

$ErrorActionPreference = 'Stop'

$resolvedArchive = Resolve-Path -LiteralPath $ArchivePath
Add-Type -AssemblyName System.IO.Compression.FileSystem

$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedArchive)
try {
  $files = @($archive.Entries | Where-Object { -not [string]::IsNullOrEmpty($_.Name) })
  $entriesByPath = @{}
  foreach ($entry in $files) {
    $normalized = $entry.FullName.Replace('\', '/').TrimStart('/')
    if ($entriesByPath.ContainsKey($normalized)) {
      throw "Portable archive contains a duplicate entry: $normalized"
    }
    $entriesByPath[$normalized] = $entry
  }

  foreach ($required in @('nai_launcher.exe', 'app_files_manifest.json')) {
    if (-not $entriesByPath.ContainsKey($required)) {
      throw "Portable archive is missing required file: $required"
    }
  }

  $manifestEntry = $entriesByPath['app_files_manifest.json']
  $reader = [System.IO.StreamReader]::new($manifestEntry.Open())
  try {
    $manifest = $reader.ReadToEnd() | ConvertFrom-Json
  } finally {
    $reader.Dispose()
  }

  if ($manifest.schemaVersion -ne 1) {
    throw "Unsupported app files manifest schema: $($manifest.schemaVersion)"
  }
  if (-not [string]::IsNullOrWhiteSpace($ExpectedVersion) -and
      $manifest.version -ne $ExpectedVersion) {
    throw "Portable manifest version $($manifest.version) does not match $ExpectedVersion."
  }

  $manifestFiles = @($manifest.files)
  $listedFiles = @{}
  foreach ($path in $manifestFiles) {
    $normalized = ([string]$path).Replace('\', '/').TrimStart('/')
    if ([string]::IsNullOrWhiteSpace($normalized)) {
      throw 'Portable manifest contains an empty file path.'
    }
    if ($listedFiles.ContainsKey($normalized)) {
      throw "Portable manifest contains a duplicate file: $normalized"
    }
    if (-not $entriesByPath.ContainsKey($normalized)) {
      throw "Portable manifest references a missing file: $normalized"
    }
    $listedFiles[$normalized] = $true
  }

  $unlisted = @(
    $entriesByPath.Keys |
      Where-Object {
        $_ -ne 'app_files_manifest.json' -and -not $listedFiles.ContainsKey($_)
      } |
      Sort-Object
  )
  if ($unlisted.Count -gt 0) {
    throw "Portable archive contains files missing from the manifest: $($unlisted -join ', ')"
  }

  Write-Host "Verified portable package: $resolvedArchive"
} finally {
  $archive.Dispose()
}
