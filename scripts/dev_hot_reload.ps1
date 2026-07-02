$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path -LiteralPath (Join-Path $scriptDir '..')
Set-Location -LiteralPath $repoRoot

function Resolve-ToolCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EnvironmentVariable,
        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )

    $override = [Environment]::GetEnvironmentVariable($EnvironmentVariable)
    if (-not [string]::IsNullOrWhiteSpace($override)) {
        return $override.Trim('"')
    }

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "$CommandName command not found. Add it to PATH or set $EnvironmentVariable."
    }

    return $command.Source
}

$dartCommand = Resolve-ToolCommand -EnvironmentVariable 'DART_CMD' -CommandName 'dart'
$flutterCommand = Resolve-ToolCommand -EnvironmentVariable 'FLUTTER_CMD' -CommandName 'flutter'

Write-Host '[1/2] Running build_runner...' -ForegroundColor Cyan
& $dartCommand run build_runner build --delete-conflicting-outputs

Write-Host ''
Write-Host '[2/2] Starting Flutter Windows app...' -ForegroundColor Cyan
Write-Host 'Hot reload: r    Hot restart: R    Quit: q' -ForegroundColor DarkGray
& $flutterCommand run -d windows
