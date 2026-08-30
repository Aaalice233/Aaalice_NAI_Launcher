[CmdletBinding()]
param(
    [string]$LockFile = 'pubspec.lock'
)

$ErrorActionPreference = 'Stop'

$officialHostedUrl = 'https://pub.dev'
$effectiveHostedUrl = $env:PUB_HOSTED_URL
if (-not [string]::IsNullOrWhiteSpace($effectiveHostedUrl) -and $effectiveHostedUrl -ne $officialHostedUrl) {
    throw "PUB_HOSTED_URL 当前为 '$effectiveHostedUrl'。本项目只允许 '$officialHostedUrl'。请删除用户级镜像环境变量并重启终端。"
}

$effectiveStorageUrl = $env:FLUTTER_STORAGE_BASE_URL
if (-not [string]::IsNullOrWhiteSpace($effectiveStorageUrl)) {
    throw "FLUTTER_STORAGE_BASE_URL 当前为 '$effectiveStorageUrl'。本项目必须使用 Flutter 默认官方存储源，请删除该环境变量并重启终端。"
}

if (-not (Test-Path -LiteralPath $LockFile -PathType Leaf)) {
    throw "找不到 lockfile：$LockFile"
}

$packages = @()
$current = $null
foreach ($line in Get-Content -LiteralPath $LockFile -Encoding UTF8) {
    if ($line -match '^  ([^\s][^:]*):\s*$') {
        if ($null -ne $current) {
            $packages += [pscustomobject]$current
        }
        $current = @{
            Name = $Matches[1]
            Source = $null
            Url = $null
        }
        continue
    }
    if ($null -eq $current) {
        continue
    }
    if ($line -match '^    source:\s+(\S+)\s*$') {
        $current.Source = $Matches[1]
        continue
    }
    if ($line -match '^      url:\s+"([^"]+)"\s*$') {
        $current.Url = $Matches[1]
    }
}
if ($null -ne $current) {
    $packages += [pscustomobject]$current
}

$hostedPackages = @($packages | Where-Object { $_.Source -eq 'hosted' })
if ($hostedPackages.Count -eq 0) {
    throw "$LockFile 中没有找到 hosted package，无法验证源地址。"
}

$invalidPackages = @(
    $hostedPackages |
        Where-Object { $_.Url -ne $officialHostedUrl } |
        Sort-Object Name
)
if ($invalidPackages.Count -gt 0) {
    $details = $invalidPackages |
        Select-Object -First 10 |
        ForEach-Object { "- $($_.Name): $($_.Url ?? '(missing URL)')" }
    $remaining = $invalidPackages.Count - $details.Count
    $suffix = if ($remaining -gt 0) {
        "`n- ... 另有 $remaining 个 package"
    }
    else {
        ''
    }
    throw "${LockFile} 包含 $($invalidPackages.Count) 个非官方 hosted source：`n$($details -join [Environment]::NewLine)$suffix"
}

Write-Host "Verified Flutter uses its default storage source and $($hostedPackages.Count) hosted packages use $officialHostedUrl"
