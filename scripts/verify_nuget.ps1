$ErrorActionPreference = 'Stop'

$nuget = Get-Command 'nuget.exe' `
  -CommandType Application `
  -ErrorAction SilentlyContinue |
  Select-Object -First 1

if (-not $nuget) {
  throw 'NuGet CLI was not found on PATH. Windows builds that include flutter_inappwebview require nuget.exe. Install it from https://learn.microsoft.com/nuget/install-nuget-client-tools and add its directory to PATH before running a Windows build.'
}

$helpOutput = @(& $nuget.Source help 2>&1)
if ($LASTEXITCODE -ne 0) {
  throw "NuGet CLI validation failed: $($nuget.Source)"
}

$versionLine = $helpOutput | Select-Object -First 1
Write-Host "NuGet CLI ready: $versionLine ($($nuget.Source))"
