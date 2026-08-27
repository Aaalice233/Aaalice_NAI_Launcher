function Enter-DevelopmentSourceLock {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Run', 'Generate')]
        [string]$Mode
    )

    $lockDirectory = Join-Path $ProjectRoot 'tool/.tmp/dev-sessions'
    New-Item -ItemType Directory -Path $lockDirectory -Force | Out-Null
    $lockPath = Join-Path $lockDirectory 'generated-sources.lock'

    if (-not (Test-Path $lockPath)) {
        $bootstrap = [System.IO.File]::Open(
            $lockPath,
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::ReadWrite
        )
        $bootstrap.Dispose()
    }

    $access = if ($Mode -eq 'Generate') {
        [System.IO.FileAccess]::ReadWrite
    }
    else {
        [System.IO.FileAccess]::Read
    }
    $share = if ($Mode -eq 'Generate') {
        [System.IO.FileShare]::None
    }
    else {
        [System.IO.FileShare]::Read
    }
    $timeoutSeconds = if ($Mode -eq 'Generate') { 3 } else { 300 }
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)

    do {
        try {
            return [System.IO.File]::Open(
                $lockPath,
                [System.IO.FileMode]::Open,
                $access,
                $share
            )
        }
        catch [System.IO.IOException] {
            if ((Get-Date) -ge $deadline) {
                if ($Mode -eq 'Generate') {
                    throw 'Cannot regenerate Dart sources while a Windows or Android Flutter session is running. Stop both sessions, run generation once, then start both sessions.'
                }
                throw 'Timed out waiting for Dart source generation to finish before starting Flutter.'
            }
            Start-Sleep -Milliseconds 250
        }
    } while ($true)
}

function Assert-GeneratedSourcesReady {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $libPath = Join-Path $ProjectRoot 'lib'
    $partPattern = '^\s*part\s+[''\"](?<relative>[^''\"]+\.(?:g|freezed)\.dart)[''\"]\s*;'
    $missing = [System.Collections.Generic.List[string]]::new()

    foreach ($sourceFile in Get-ChildItem -Path $libPath -Recurse -File -Filter '*.dart') {
        if ($sourceFile.Name -match '\.(?:g|freezed)\.dart$') {
            continue
        }

        foreach ($match in Select-String -Path $sourceFile.FullName -Pattern $partPattern) {
            $relativePartPath = $match.Matches[0].Groups['relative'].Value
            $generatedPath = Join-Path $sourceFile.DirectoryName $relativePartPath
            if (-not (Test-Path $generatedPath -PathType Leaf)) {
                $relativeSourcePath = [System.IO.Path]::GetRelativePath($ProjectRoot, $sourceFile.FullName)
                $missing.Add("$relativeSourcePath -> $relativePartPath")
            }
        }
    }

    if ($missing.Count -eq 0) {
        return
    }

    $sample = @($missing | Select-Object -First 12) -join [Environment]::NewLine
    $remaining = if ($missing.Count -gt 12) {
        [Environment]::NewLine + "... and $($missing.Count - 12) more"
    }
    else {
        ''
    }
    throw "Generated Dart sources are incomplete ($($missing.Count) missing). Run 'dart run build_runner build --delete-conflicting-outputs' with both Flutter sessions stopped.`n$sample$remaining"
}
