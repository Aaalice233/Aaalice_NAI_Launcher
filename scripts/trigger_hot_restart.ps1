$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$reloadScript = Join-Path $scriptDir 'trigger_hot_reload.ps1'

if (-not (Test-Path -LiteralPath $reloadScript -PathType Leaf)) {
    throw "Hot-reload helper not found: $reloadScript"
}

& $reloadScript -Restart
