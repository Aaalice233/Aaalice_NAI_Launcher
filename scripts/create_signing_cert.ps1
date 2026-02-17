#Requires -RunAsAdministrator
<#
.SYNOPSIS
    NAI Launcher Windows Code Signing Certificate Generator
.DESCRIPTION
    Creates a self-signed code signing certificate for NAI Launcher Windows builds.
    Run this script as Administrator.
#>

param(
    [string]$CertName = "NAI Launcher Code Signing",
    [string]$OutputPath = "$PSScriptRoot\nai_launcher.pfx",
    [string]$Password = "NaiLauncher2024"
)

# Error handling: Stop on error
$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  NAI Launcher Code Signing Certificate Generator" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] Please run this script as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell -> Run as Administrator" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Delete old certificate files if exist
if (Test-Path $OutputPath) {
    Write-Host "[INFO] Removing old certificate file..." -ForegroundColor Yellow
    Remove-Item $OutputPath -Force
}

$thumbprintFile = "$PSScriptRoot\cert_thumbprint.txt"
if (Test-Path $thumbprintFile) {
    Remove-Item $thumbprintFile -Force
}

Write-Host "[Step 1/4] Creating self-signed code signing certificate..." -ForegroundColor Green

$cert = $null
try {
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

    Write-Host "   Certificate Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
    Write-Host "   Valid Until: $($cert.NotAfter.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
    Write-Host "   Certificate created successfully!" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to create certificate: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

Write-Host ""
Write-Host "[Step 2/4] Exporting certificate to PFX file..." -ForegroundColor Green

try {
    $securePassword = ConvertTo-SecureString -String $Password -Force -AsPlainText
    Export-PfxCertificate -Cert $cert -FilePath $OutputPath -Password $securePassword | Out-Null
    Write-Host "   Exported to: $OutputPath" -ForegroundColor Gray
    Write-Host "   PFX file created successfully!" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to export certificate: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

Write-Host ""
Write-Host "[Step 3/4] Adding certificate to Trusted Root Certificate Authorities..." -ForegroundColor Green

try {
    # Export public key certificate
    $cerPath = [System.IO.Path]::ChangeExtension($OutputPath, ".cer")
    Export-Certificate -Cert $cert -FilePath $cerPath | Out-Null
    
    # Import to Trusted Root store
    Import-Certificate -FilePath $cerPath -CertStoreLocation "Cert:\LocalMachine\Root" | Out-Null
    Remove-Item $cerPath -Force
    
    Write-Host "   Added to Trusted Root Certificate Authorities" -ForegroundColor Gray
    Write-Host "   Certificate trusted successfully!" -ForegroundColor Green
} catch {
    Write-Host "   [WARNING] Failed to add to Trusted Root (may need manual install): $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[Step 4/4] Saving certificate thumbprint..." -ForegroundColor Green

try {
    $cert.Thumbprint | Out-File -FilePath $thumbprintFile -Encoding UTF8 -NoNewline
    Write-Host "   Thumbprint saved to: $thumbprintFile" -ForegroundColor Gray
} catch {
    Write-Host "   [WARNING] Failed to save thumbprint: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Certificate Created Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Certificate File: $OutputPath" -ForegroundColor White
Write-Host "Certificate Password: $Password" -ForegroundColor White
Write-Host "Certificate Thumbprint: $($cert.Thumbprint)" -ForegroundColor White
Write-Host ""
Write-Host "[IMPORTANT NOTES]" -ForegroundColor Yellow
Write-Host "1. Keep the PFX file and password secure" -ForegroundColor Yellow
Write-Host "2. Certificate file path added to .gitignore" -ForegroundColor Yellow
Write-Host "3. Self-signed certificates are for testing/internal use only" -ForegroundColor Yellow
Write-Host "4. First-time users may still see SmartScreen warning but can proceed" -ForegroundColor Yellow
Write-Host ""
Write-Host "You can now run build_release.bat to sign your executable!" -ForegroundColor Green
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
