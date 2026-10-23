# Self-signed certificate generation script for Lawyers E-Diary MSIX packaging.
#
# This script generates a self-signed code-signing certificate (.pfx) with
# publisher CN "Lawyers E-Diary" for MSIX packaging.
#
# Requirements: Windows 10/11 with PowerShell and signtool.exe
#
# Usage:
#   powershell -File generate_certificate.ps1
#
# Output:
#   windows/runner/resources/lawyers-e-diary.pfx
#   windows/runner/resources/lawyers-e-diary.cer

param(
    [string]$OutputDir = "$PSScriptRoot\resources",
    [string]$Publisher = "CN=Lawyers E-Diary",
    [int]$ValidYears = 5
)

$ErrorActionPreference = "Stop"

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "Created output directory: $OutputDir" -ForegroundColor Green
}

$certPath = Join-Path $OutputDir "lawyers-e-diary.pfx"
$cerPath = Join-Path $OutputDir "lawyers-e-diary.cer"
$certName = "Lawyers E-Diary MSIX Signing Certificate"

Write-Host "Generating self-signed certificate..." -ForegroundColor Cyan
Write-Host "  Publisher: $Publisher"
Write-Host "  Validity: $ValidYears years"
Write-Host "  Output: $certPath"

# Generate self-signed certificate
$cert = New-SelfSignedCertificate `
    -Type CodeSigningCert `
    -FriendlyName $certName `
    -Subject $Publisher `
    -CertStoreLocation "cert:\CurrentUser\My" `
    -KeyUsage DigitalSignature,KeyCertSign `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -HashAlgorithm SHA256 `
    -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" `
    -NotBefore (Get-Date) `
    -NotAfter (Get-Date).AddYears($ValidYears) `
    -TextExtension @("2.5.4.3={text}Lawyers E-Diary")

if ($null -eq $cert) {
    Write-Error "Failed to generate certificate."
    exit 1
}

Write-Host "  Certificate Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
Write-Host "  Subject: $($cert.Subject)" -ForegroundColor Gray

# Export as PFX (with private key)
$securePassword = ConvertTo-SecureString -String "" -AsPlainText -Force
Export-PfxCertificate -Cert $cert -FilePath $certPath -Password $securePassword -ExportOptions ExportWithPrivateKey

if ($?) {
    Write-Host "  PFX exported: $certPath" -ForegroundColor Green
} else {
    Write-Error "Failed to export PFX certificate."
    exit 1
}

# Export as CER (public key, for distribution)
Export-Certificate -Cert $cert -FilePath $cerPath -Type CERT

if ($?) {
    Write-Host "  CER exported: $cerPath" -ForegroundColor Green
} else {
    Write-Warning "Failed to export CER certificate."
}

# Display certificate details
Write-Host "`nCertificate Details:" -ForegroundColor Cyan
Write-Host "  Subject: $($cert.Subject)"
Write-Host "  Issuer: $($cert.Issuer)"
Write-Host "  Thumbprint: $($cert.Thumbprint)"
Write-Host "  Serial: $($cert.SerialNumber)"
Write-Host "  Not Before: $($cert.NotBefore)"
Write-Host "  Not After: $($cert.NotAfter)"

# Verify the certificate
Write-Host "`nVerifying certificate..." -ForegroundColor Cyan
$verifyCert = Get-PfxCertificate -FilePath $certPath
Write-Host "  Verified: $($verifyCert.Subject)"
Write-Host "  Has Private Key: $($null -ne $verifyCert.PrivateKey)"

Write-Host "`nCertificate generation complete." -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run: powershell -File generate_icons.ps1"
Write-Host "  2. Run: powershell -File build_msix.ps1"
Write-Host "  3. Submit to Microsoft Store"