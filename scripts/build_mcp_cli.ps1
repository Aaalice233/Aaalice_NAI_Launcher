param(
  [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$isMac = $IsMacOS -eq $true
$binaryName = if ($isMac) { 'nai_launcher_mcp' } else { 'nai_launcher_mcp.exe' }

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = if ($isMac) {
    'build/macos/Build/Products/Release/Aaalice NAI Launcher.app/Contents/MacOS/nai_launcher_mcp'
  } else {
    'build/windows/x64/runner/Release/nai_launcher_mcp.exe'
  }
}
if (-not [IO.Path]::IsPathRooted($OutputPath)) {
  $OutputPath = Join-Path $root $OutputPath
}

$stagingPath = Join-Path $root 'tool/.tmp/mcp_cli'

Push-Location $root
try {
  if (Test-Path -LiteralPath $stagingPath) {
    Remove-Item -LiteralPath $stagingPath -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $stagingPath | Out-Null

  # dart compile exe refuses packages whose dependency graph declares build
  # hooks, so the proxy is produced with the bundle builder and lifted out.
  dart build cli --target bin/nai_launcher_mcp.dart --output $stagingPath
  if ($LASTEXITCODE -ne 0) {
    throw "dart build cli failed with exit code $LASTEXITCODE"
  }

  $builtBinary = Join-Path $stagingPath "bundle/bin/$binaryName"
  if (-not (Test-Path -LiteralPath $builtBinary -PathType Leaf)) {
    throw "dart build cli did not produce the MCP CLI executable: $builtBinary"
  }

  $outputDirectory = Split-Path -Parent $OutputPath
  if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
  }
  Copy-Item -LiteralPath $builtBinary -Destination $OutputPath -Force
  if ($isMac) {
    chmod +x $OutputPath
  }

  $outputFile = Get-Item -LiteralPath $OutputPath
  if ($outputFile.Length -le 0) {
    throw "MCP CLI executable is empty: $OutputPath"
  }

  Remove-Item -LiteralPath $stagingPath -Recurse -Force
  $sizeMb = [math]::Round($outputFile.Length / 1MB, 1)
  Write-Host "Built MCP stdio proxy: $OutputPath ($sizeMb MB)"
} finally {
  Pop-Location
}
