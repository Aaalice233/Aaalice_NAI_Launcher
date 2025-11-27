$ProgressPreference = 'SilentlyContinue'
Write-Host "Downloading Flutter SDK..."
Write-Host "This may take 5-10 minutes depending on your internet speed."
Write-Host ""

$url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip"
$output = "E:\flutter_sdk.zip"

try {
    Invoke-WebRequest -Uri $url -OutFile $output
    Write-Host "Download completed successfully!"
    Write-Host "File saved to: $output"
} catch {
    Write-Host "Download failed: $_"
    exit 1
}
