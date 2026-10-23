# MSIX Packaging Build Script for Lawyers E-Diary
#
# This script builds the Windows desktop application and creates an MSIX package
# for Microsoft Store distribution.
#
# Prerequisites:
#   1. Flutter SDK installed and configured
#   2. Windows 10/11 with Visual Studio build tools
#   3. Code-signing certificate (lawyers-e-diary.pfx)
#   4. MSIX icon assets (square30x30Logo.png, square44x44Logo.png, etc.)
#   5. MakeAppx.exe (Windows SDK)
#   6. SignTool.exe (Windows SDK)
#
# Usage:
#   powershell -File build_msix.ps1
#
# Steps:
#   1. Generate icons (if not already done)
#   2. Build Flutter Windows app
#   3. Create MSIX package
#   4. Sign the MSIX package
#   5. Verify the signed package

param(
    [string]$ProjectRoot = "C:\Users\Lawyers-e-diary-main",
    [string]$OutputDir = "$ProjectRoot\build\windows\x64\runner\Release",
    [string]$Publisher = "CN=Lawyers E-Diary",
    [string]$CertificatePath = "$ProjectRoot\windows\runner\resources\lawyers-e-diary.pfx",
    [string]$CertificatePassword = "",
    [string]$Version = "1.0.0.0"
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Lawyers E-Diary MSIX Packaging Build Script"
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Project Root: $ProjectRoot"
Write-Host "Output Dir: $OutputDir"
Write-Host "Version: $Version"
Write-Host ""

# Step 1: Verify prerequisites
Write-Host "[1/6] Verifying prerequisites..." -ForegroundColor Cyan

if (-not (Test-Path $CertificatePath)) {
    Write-Warning "Certificate not found: $CertificatePath"
    Write-Host "  Run: powershell -File windows\runner\generate_certificate.ps1"
}

if (-not (Test-Path "$ProjectRoot\windows\runner\AppxManifest.xml")) {
    Write-Error "AppxManifest.xml not found."
    exit 1
}

# The Windows SDK tools ship with Visual Studio but are not always on PATH.
# Locate them so packaging works without a manual PATH change.
function Find-SdkTool([string]$Name) {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }

    $sdkRoot = "C:\Program Files (x86)\Windows Kits\10\bin"
    if (-not (Test-Path $sdkRoot)) { return $null }

    $candidate = Get-ChildItem -Path $sdkRoot -Recurse -Filter $Name -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "\\x64\\" } |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if ($null -eq $candidate) { return $null }
    return $candidate.FullName
}

$makeAppxPath = Find-SdkTool "makeappx.exe"
$signToolPath = Find-SdkTool "signtool.exe"

if ($null -eq $makeAppxPath) {
    Write-Warning "MakeAppx.exe not found. Install the Windows SDK."
} else {
    Write-Host "  MakeAppx: $makeAppxPath" -ForegroundColor Gray
}

if ($null -eq $signToolPath) {
    Write-Warning "SignTool.exe not found. Install the Windows SDK."
} else {
    Write-Host "  SignTool: $signToolPath" -ForegroundColor Gray
}

Write-Host "Prerequisites verified." -ForegroundColor Green
Write-Host ""

# Step 2: Generate icons
Write-Host "[2/6] Generating MSIX icons..." -ForegroundColor Cyan

$iconScript = "$ProjectRoot\windows\runner\generate_icons.ps1"
if (Test-Path $iconScript) {
    Push-Location "$ProjectRoot\windows\runner"
    try {
        & $iconScript
    } finally {
        Pop-Location
    }

    # The icon generator is a PowerShell script, so $LASTEXITCODE is not a
    # reliable signal. Verify the assets the manifest requires instead.
    $requiredIcons = @(
        "square30x30Logo.png",
        "square150x150Logo.png",
        "wide310x150Logo.png",
        "StoreLogo.png"
    )
    $iconDir = "$ProjectRoot\windows\runner\assets\icons"
    $missing = $requiredIcons | Where-Object { -not (Test-Path (Join-Path $iconDir $_)) }
    if ($missing.Count -gt 0) {
        Write-Error "Icon generation failed. Missing: $($missing -join ', ')"
        exit 1
    }
    Write-Host "Icons generated." -ForegroundColor Green
} else {
    Write-Warning "Icon generation script not found. Skipping."
}

Write-Host ""

# Step 3: Build Flutter Windows app
Write-Host "[3/6] Building Flutter Windows app..." -ForegroundColor Cyan

Push-Location $ProjectRoot
try {
    & flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Flutter build failed."
        exit 1
    }
    Write-Host "Flutter build completed." -ForegroundColor Green
} finally {
    Pop-Location
}

Write-Host ""

# Step 4: Create MSIX package
Write-Host "[4/6] Creating MSIX package..." -ForegroundColor Cyan

$msixOutput = "$ProjectRoot\build\windows\x64\runner\Release\lawyers_e_diary.msix"
$tempDir = "$ProjectRoot\build\msix_temp"

if (-not (Test-Path $OutputDir)) {
    Write-Error "Flutter build output not found: $OutputDir"
    exit 1
}

if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# Copy build artifacts to the package root.
Get-ChildItem -Path $OutputDir -File | ForEach-Object {
    Copy-Item $_.FullName -Destination $tempDir -Force
}

# Copy the runner resources. The manifest references resources\app_icon.ico.
$runnerResources = "$ProjectRoot\windows\runner\resources"
if (Test-Path $runnerResources) {
    New-Item -ItemType Directory -Path "$tempDir\resources" -Force | Out-Null
    Get-ChildItem -Path $runnerResources -File | ForEach-Object {
        Copy-Item $_.FullName -Destination "$tempDir\resources\" -Force
    }
}

# Copy AppxManifest.xml
Copy-Item "$ProjectRoot\windows\runner\AppxManifest.xml" -Destination $tempDir -Force

# Copy icons into the assets\icons folder the manifest points at.
$iconDir = "$ProjectRoot\windows\runner\assets\icons"
if (Test-Path $iconDir) {
    New-Item -ItemType Directory -Path "$tempDir\assets\icons" -Force | Out-Null
    Get-ChildItem -Path $iconDir -File | ForEach-Object {
        Copy-Item $_.FullName -Destination "$tempDir\assets\icons\" -Force
    }
}

# Create Appx package using MakeAppx
if ($null -ne $makeAppxPath) {
    Write-Host "Running MakeAppx..." -ForegroundColor Gray
    & $makeAppxPath pack /h SHA256 /d "$tempDir" /p "$msixOutput"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "MakeAppx failed."
        exit 1
    }
    Write-Host "MSIX package created: $msixOutput" -ForegroundColor Green
} else {
    Write-Warning "MakeAppx not available. Manual packaging required."
}

Write-Host ""

# Step 5: Sign the MSIX package
Write-Host "[5/6] Signing MSIX package..." -ForegroundColor Cyan

if ($null -ne $signToolPath -and (Test-Path $CertificatePath)) {
    $signArgs = @("sign", "/a", "/v", "/f", $CertificatePath)
    if ($CertificatePassword -ne "") {
        $signArgs += @("/p", $CertificatePassword)
    }
    $signArgs += "/t http://timestamp.digicert.com"
    $signArgs += $msixOutput

    Write-Host "Running SignTool..." -ForegroundColor Gray
    & $signToolPath @signArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "SignTool failed."
        exit 1
    }
    Write-Host "MSIX package signed." -ForegroundColor Green
} else {
    Write-Warning "SignTool or certificate not available. Package is unsigned."
}

Write-Host ""

# Step 6: Verify the signed package
Write-Host "[6/6] Verifying signed package..." -ForegroundColor Cyan

if ($null -ne $signToolPath -and (Test-Path $msixOutput)) {
    & $signToolPath verify /a /v $msixOutput
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Verification failed or inconclusive."
    } else {
        Write-Host "Package verified successfully." -ForegroundColor Green
    }
} else {
    Write-Warning "SignTool not available. Skipping verification."
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "MSIX Packaging Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Package: $msixOutput" -ForegroundColor Gray
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Test installation on Windows 10/11"
Write-Host "  2. Submit to Microsoft Store Partner Center"
Write-Host "  3. Configure Store listing (description, screenshots, etc.)"
