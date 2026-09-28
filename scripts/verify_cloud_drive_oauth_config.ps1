param(
    [ValidateSet('windows', 'macos', 'android')]
    [string]$Platform = 'windows',
    [switch]$RequireConfigured
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$keys = @(
    "GOOGLE_DRIVE_$($Platform.ToUpperInvariant())_CLIENT_ID",
    "GOOGLE_DRIVE_$($Platform.ToUpperInvariant())_REDIRECT_URI",
    "ONEDRIVE_$($Platform.ToUpperInvariant())_CLIENT_ID",
    "ONEDRIVE_$($Platform.ToUpperInvariant())_REDIRECT_URI",
    'ONEDRIVE_TENANT_ID'
)
if ($Platform -eq 'windows') {
    $keys += 'GOOGLE_DRIVE_WINDOWS_CLIENT_SECRET'
}
$dartArgs = @()
foreach ($key in $keys) {
    $value = [Environment]::GetEnvironmentVariable($key)
    if ($IsWindows -and [string]::IsNullOrWhiteSpace($value)) {
        $value = [Environment]::GetEnvironmentVariable(
            $key,
            [EnvironmentVariableTarget]::User
        )
    }
    if ($IsWindows -and [string]::IsNullOrWhiteSpace($value)) {
        $value = [Environment]::GetEnvironmentVariable(
            $key,
            [EnvironmentVariableTarget]::Machine
        )
    }
    if (-not [string]::IsNullOrWhiteSpace($value)) {
        $dartArgs += "--define=$key=$value"
    }
}
$dartArgs += @('run', 'tool/cloud_drive_oauth_diagnostic.dart', "--platform=$Platform")
if ($RequireConfigured) { $dartArgs += '--require-configured' }

Push-Location $root
try {
    & dart @dartArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Cloud Drive OAuth configuration validation failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}
