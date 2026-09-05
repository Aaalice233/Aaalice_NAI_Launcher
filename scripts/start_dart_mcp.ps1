[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

# Codex may inherit a PATH without Flutter; reuse the SDK selected by the project.
$flutterSdk = $env:FLUTTER_SDK
$propertiesPath = Join-Path $repoRoot 'android/local.properties'
if ([string]::IsNullOrWhiteSpace($flutterSdk) -and (Test-Path -LiteralPath $propertiesPath)) {
    $sdkSetting = Get-Content -LiteralPath $propertiesPath -Encoding UTF8 |
        Where-Object { $_ -match '^flutter\.sdk=' } |
        Select-Object -First 1
    if ($sdkSetting) {
        $flutterSdk = $sdkSetting.Substring('flutter.sdk='.Length).Replace('\\', '\').Replace('\:', ':')
    }
}
if ([string]::IsNullOrWhiteSpace($flutterSdk)) {
    $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterCommand) {
        $flutterSdk = Split-Path -Parent (Split-Path -Parent $flutterCommand.Source)
    }
}
if ([string]::IsNullOrWhiteSpace($flutterSdk)) {
    throw 'Flutter SDK not found. Set FLUTTER_SDK, configure flutter.sdk in android/local.properties, or add Flutter to PATH.'
}

$flutterSdk = (Resolve-Path -LiteralPath $flutterSdk).Path
$dartName = if ($IsWindows) { 'dart.exe' } else { 'dart' }
$dartCommand = Join-Path $flutterSdk "bin/cache/dart-sdk/bin/$dartName"
if (-not (Test-Path -LiteralPath $dartCommand -PathType Leaf)) {
    throw "Dart executable not found: $dartCommand"
}
$env:PATH = (Join-Path $flutterSdk 'bin') + [IO.Path]::PathSeparator + $env:PATH
$env:PUB_HOSTED_URL = 'https://pub.dev'
$env:FLUTTER_STORAGE_BASE_URL = $null

# Forward raw streams; PowerShell's native-command pipeline closes redirected
# stdin too early, and inherited console handles are not reliable on Windows.
$startInfo = [Diagnostics.ProcessStartInfo]::new($dartCommand)
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardInput = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.WorkingDirectory = $repoRoot
$startInfo.ArgumentList.Add('mcp-server')
$startInfo.ArgumentList.Add('--flutter-sdk')
$startInfo.ArgumentList.Add($flutterSdk)
$process = [Diagnostics.Process]::Start($startInfo)
try {
    $inputCopy = [Console]::OpenStandardInput().CopyToAsync($process.StandardInput.BaseStream)
    $outputCopy = $process.StandardOutput.BaseStream.CopyToAsync([Console]::OpenStandardOutput())
    $errorCopy = $process.StandardError.BaseStream.CopyToAsync([Console]::OpenStandardError())
    $inputClosed = $false
    while (-not $process.WaitForExit(100)) {
        if (-not $inputClosed -and $inputCopy.IsCompleted) {
            $inputCopy.GetAwaiter().GetResult()
            $process.StandardInput.Close()
            $inputClosed = $true
        }
    }
    $outputCopy.GetAwaiter().GetResult()
    $errorCopy.GetAwaiter().GetResult()
    exit $process.ExitCode
}
finally {
    $process.Dispose()
}
