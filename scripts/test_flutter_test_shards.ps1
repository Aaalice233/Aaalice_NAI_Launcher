#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runner = Join-Path $PSScriptRoot 'run_flutter_tests.ps1'

function Read-Shard([int]$Index, [string[]]$Roots = @()) {
    $arguments = @('-NoProfile', '-File', $runner, '-ListOnly', '-TotalShards', 6, '-ShardIndex', $Index)
    if ($Roots.Count -gt 0) { $arguments += '-Path', ($Roots -join ',') }
    $result = @(& pwsh @arguments)
    if ($LASTEXITCODE -ne 0) { throw "Shard discovery failed: $Index" }
    return $result
}

$expected = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'test') -Recurse -File -Filter '*_test.dart' |
    ForEach-Object { [IO.Path]::GetRelativePath($repoRoot, $_.FullName).Replace('\', '/') })
$seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$counts = @()
for ($index = 0; $index -lt 6; $index++) {
    $files = @(Read-Shard $index)
    $counts += $files.Count
    foreach ($file in $files) {
        if (-not $seen.Add($file)) { throw "Test assigned to multiple shards: $file" }
    }
}
if (-not $seen.SetEquals([string[]]$expected)) { throw 'Shards do not cover every test file exactly once.' }
if (($counts | Measure-Object -Maximum).Maximum - ($counts | Measure-Object -Minimum).Minimum -gt 1) {
    throw 'File counts are not balanced across shards.'
}
$first = @(Read-Shard 0)
$overlapping = @(Read-Shard 0 @('test', 'test/tool'))
if (($first -join "`n") -cne ($overlapping -join "`n")) {
    throw 'Overlapping roots changed deterministic shard membership.'
}
Write-Host "Verified $($seen.Count) test files occur exactly once across six shards: $($counts -join ', ')."
