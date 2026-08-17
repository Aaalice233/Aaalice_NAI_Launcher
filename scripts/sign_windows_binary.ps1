param(
  [Parameter(Mandatory = $true)]
  [string[]]$Path,

  [Parameter(Mandatory = $true)]
  [string]$CertificatePath,

  [Parameter(Mandatory = $true)]
  [string]$CertificatePassword,

  [string]$TimestampUrl = "http://timestamp.digicert.com"
)

$ErrorActionPreference = 'Stop'

function Find-SignTool {
  $command = Get-Command "signtool.exe" -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $kitsRoot = Join-Path ${env:ProgramFiles(x86)} "Windows Kits/10/bin"
  if (Test-Path -LiteralPath $kitsRoot) {
    $candidate = Get-ChildItem -LiteralPath $kitsRoot -Filter "signtool.exe" -File -Recurse |
      Where-Object { $_.FullName -match '[\\/]x64[\\/]signtool\.exe$' } |
      Sort-Object FullName -Descending |
      Select-Object -First 1
    if ($candidate) {
      return $candidate.FullName
    }
  }

  throw "signtool.exe was not found. Install the Windows SDK signing tools."
}

if (-not (Test-Path -LiteralPath $CertificatePath)) {
  throw "Signing certificate was not found: $CertificatePath"
}

$signTool = Find-SignTool
foreach ($binaryPath in $Path) {
  if (-not (Test-Path -LiteralPath $binaryPath)) {
    throw "Binary to sign was not found: $binaryPath"
  }

  & $signTool sign `
    /fd SHA256 `
    /td SHA256 `
    /tr $TimestampUrl `
    /f $CertificatePath `
    /p $CertificatePassword `
    $binaryPath
  if ($LASTEXITCODE -ne 0) {
    throw "signtool failed to sign: $binaryPath"
  }

  & $signTool verify /pa /v $binaryPath
  if ($LASTEXITCODE -ne 0) {
    throw "Authenticode verification failed: $binaryPath"
  }

  Write-Host "Signed and verified: $binaryPath"
}
