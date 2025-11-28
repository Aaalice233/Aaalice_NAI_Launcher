if (Test-Path E:\flutter_sdk.zip) {
    $size = (Get-Item E:\flutter_sdk.zip).Length
    $sizeMB = [math]::Round($size/1MB, 1)
    Write-Host "Downloaded: $sizeMB MB / ~1200 MB"
} else {
    Write-Host "Download starting..."
}
