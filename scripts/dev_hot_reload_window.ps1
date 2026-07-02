$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$runner = Join-Path $scriptDir 'dev_hot_reload.ps1'
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir '..')

$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $pwsh) {
    throw 'pwsh command not found. Install PowerShell 7 or add it to PATH.'
}

Start-Process `
    -FilePath $pwsh.Source `
    -ArgumentList @(
        '-NoExit',
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        $runner
    ) `
    -WorkingDirectory $repoRoot `
    -WindowStyle Normal
