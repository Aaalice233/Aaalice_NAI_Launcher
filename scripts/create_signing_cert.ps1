# Windows 自签名证书生成脚本
# 使用方法: 以管理员身份运行 PowerShell，执行此脚本

param(
    [string]$CertName = "NAI Launcher Code Signing",
    [string]$OutputPath = "$PSScriptRoot\nai_launcher.pfx",
    [string]$Password = "NaiLauncher2024"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  NAI Launcher Windows 签名证书生成器" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查是否以管理员身份运行
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[错误] 请以管理员身份运行此脚本！" -ForegroundColor Red
    Write-Host "右键点击 PowerShell -> 以管理员身份运行" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "[1/4] 创建自签名代码签名证书..." -ForegroundColor Green

try {
    # 创建自签名证书
    $cert = New-SelfSignedCertificate `
        -Type CodeSigningCert `
        -Subject "CN=$CertName" `
        -KeyUsage DigitalSignature `
        -FriendlyName $CertName `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -NotAfter (Get-Date).AddYears(5) `
        -HashAlgorithm SHA256 `
        -KeySpec Signature `
        -KeyLength 2048

    Write-Host "   证书指纹: $($cert.Thumbprint)" -ForegroundColor Gray
    Write-Host "   有效期至: $($cert.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
} catch {
    Write-Host "[错误] 创建证书失败: $_" -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""
Write-Host "[2/4] 导出证书为 PFX 文件..." -ForegroundColor Green

try {
    $securePassword = ConvertTo-SecureString -String $Password -Force -AsPlainText
    Export-PfxCertificate -Cert $cert -FilePath $OutputPath -Password $securePassword | Out-Null
    Write-Host "   已导出到: $OutputPath" -ForegroundColor Gray
} catch {
    Write-Host "[错误] 导出证书失败: $_" -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""
Write-Host "[3/4] 将证书添加到受信任的根证书颁发机构..." -ForegroundColor Green

try {
    # 导出公钥证书
    $cerPath = [System.IO.Path]::ChangeExtension($OutputPath, ".cer")
    Export-Certificate -Cert $cert -FilePath $cerPath | Out-Null
    
    # 导入到受信任的根证书存储区
    Import-Certificate -FilePath $cerPath -CertStoreLocation "Cert:\LocalMachine\Root" | Out-Null
    Remove-Item $cerPath -Force
    
    Write-Host "   已添加到受信任的根证书颁发机构" -ForegroundColor Gray
} catch {
    Write-Host "[警告] 添加到受信任根证书失败（可能需要手动添加）: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[4/4] 完成!" -ForegroundColor Green
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  证书创建成功！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "证书文件: $OutputPath" -ForegroundColor White
Write-Host "证书密码: $Password" -ForegroundColor White
Write-Host "证书指纹: $($cert.Thumbprint)" -ForegroundColor White
Write-Host ""
Write-Host "[重要提示]" -ForegroundColor Yellow
Write-Host "1. 请妥善保管 PFX 文件和密码" -ForegroundColor Yellow
Write-Host "2. 已将证书文件路径添加到 .gitignore" -ForegroundColor Yellow
Write-Host "3. 自签名证书仅适用于测试和内部分发" -ForegroundColor Yellow
Write-Host "4. 首次安装时，用户仍可能看到 SmartScreen 警告，但可以选择继续安装" -ForegroundColor Yellow
Write-Host ""

# 保存证书指纹到文件供构建脚本使用
$thumbprintFile = "$PSScriptRoot\cert_thumbprint.txt"
$cert.Thumbprint | Out-File -FilePath $thumbprintFile -Encoding UTF8 -NoNewline
Write-Host "证书指纹已保存到: $thumbprintFile" -ForegroundColor Gray

pause
