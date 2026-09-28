[CmdletBinding()]
param(
    [string]$OutputRoot = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $sessionName = 'session_{0}_{1}' -f (Get-Date -Format 'yyyyMMdd_HHmmss'), ([Guid]::NewGuid().ToString('N'))
    $OutputRoot = Join-Path ([System.IO.Path]::GetTempPath()) "nai_launcher_ole_drag_inspector\$sessionName"
}
$OutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
[System.IO.Directory]::CreateDirectory($OutputRoot) | Out-Null

$executable = & (Join-Path $PSScriptRoot 'build_inspector.ps1')
if (-not (Test-Path -LiteralPath $executable)) {
    throw "OLE inspector executable was not produced: $executable"
}

Write-Output "OLE dump session: $OutputRoot"
$process = Start-Process `
    -FilePath $executable `
    -ArgumentList @('--output', $OutputRoot) `
    -Wait `
    -PassThru
if ($process.ExitCode -ne 0) {
    throw "OLE inspector exited with code $($process.ExitCode)."
}
