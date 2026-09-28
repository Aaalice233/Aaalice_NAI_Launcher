[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'windows\bin\OleDragInspector.exe')
)

$ErrorActionPreference = 'Stop'

$cscCandidates = @(
    'C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\Roslyn\csc.exe',
    'C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\Roslyn\csc.exe',
    'C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\Roslyn\csc.exe',
    'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\Roslyn\csc.exe'
)
$csc = $cscCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $csc) {
    throw 'Visual Studio 2022 Roslyn csc.exe was not found.'
}

$framework = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319'
$referenceNames = @(
    'mscorlib.dll',
    'System.dll',
    'System.Core.dll',
    'System.Drawing.dll',
    'System.Runtime.Serialization.dll',
    'System.Web.Extensions.dll',
    'System.Windows.Forms.dll'
)
$references = foreach ($name in $referenceNames) {
    $path = Join-Path $framework $name
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required .NET Framework assembly is missing: $path"
    }
    "/reference:$path"
}

$sourcePath = Join-Path $PSScriptRoot 'windows\Program.cs'
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $resolvedOutput
[System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null

& $csc `
    /nologo `
    /target:winexe `
    /platform:x64 `
    /langversion:latest `
    /nullable:enable `
    /warnaserror+ `
    "/out:$resolvedOutput" `
    $references `
    $sourcePath
if ($LASTEXITCODE -ne 0) {
    throw "OLE inspector compilation failed with exit code $LASTEXITCODE."
}

Write-Output $resolvedOutput
