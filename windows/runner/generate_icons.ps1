# Icon Generation Script for Lawyers E-Diary Windows Packaging
# Uses the final shared LED brand asset as the single source of truth.
# Run before flutter build windows to refresh the executable icon, and before packaging to refresh MSIX tile assets.

param(
    [string]$SourceImage = "",
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($SourceImage)) { $SourceImage = Join-Path $scriptRoot "..\..\assets\images\master logo.png" }
if ([string]::IsNullOrWhiteSpace($OutputDir)) { $OutputDir = Join-Path $scriptRoot "assets\icons" }
$SourceImage = [System.IO.Path]::GetFullPath($SourceImage)
$OutputDir = [System.IO.Path]::GetFullPath($OutputDir)
$AppIconPath = Join-Path $scriptRoot "resources\app_icon.ico"

if (-not (Test-Path $SourceImage)) { throw "Final LED logo source not found: $SourceImage" }
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

$iconSizes = @(
    @{ Name = "square30x30Logo.png"; Size = 30 }
    @{ Name = "square44x44Logo.png"; Size = 44 }
    @{ Name = "square71x71Logo.png"; Size = 71 }
    @{ Name = "square150x150Logo.png"; Size = 150 }
    @{ Name = "square310x310Logo.png"; Size = 310 }
    @{ Name = "StoreLogo.png"; Size = 50 }
    @{ Name = "wide310x150Logo.png"; Width = 310; Height = 150 }
)

$magickCommand = Get-Command magick -ErrorAction SilentlyContinue
if ($null -ne $magickCommand) {
    Write-Host "Generating Windows icons from the final LED logo..." -ForegroundColor Green
    foreach ($icon in $iconSizes) {
        $outPath = Join-Path $OutputDir $icon.Name
        if ($icon.Width -and $icon.Height) {
            & magick $SourceImage -resize "140x140" -gravity center -background none -extent "$($icon.Width)x$($icon.Height)" $outPath
        } else {
            $size = $icon.Size
            & magick $SourceImage -resize "${size}x${size}" -gravity center -background none -extent "${size}x${size}" $outPath
        }
        if ($LASTEXITCODE -ne 0) { throw "Failed to generate $($icon.Name)" }
        Write-Host "  Generated $($icon.Name)" -ForegroundColor Gray
    }
    & magick $SourceImage -define icon:auto-resize=256,128,64,48,32,16 $AppIconPath
    if ($LASTEXITCODE -ne 0) { throw "Failed to generate the Windows executable icon." }
} else {
    Write-Warning "ImageMagick not found; using System.Drawing fallback."
    Add-Type -AssemblyName System.Drawing
    $source = [System.Drawing.Image]::FromFile($SourceImage)
    try {
        foreach ($icon in $iconSizes) {
            if ($icon.Width -and $icon.Height) { $width = [int]$icon.Width; $height = [int]$icon.Height; $maxDimension = 140 }
            else { $width = [int]$icon.Size; $height = [int]$icon.Size; $maxDimension = [Math]::Min($width, $height) }
            $bitmap = New-Object System.Drawing.Bitmap $width, $height
            try {
                $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
                try {
                    $graphics.Clear([System.Drawing.Color]::Transparent)
                    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $scale = [Math]::Min($maxDimension / $source.Width, $maxDimension / $source.Height)
                    $drawWidth = [int][Math]::Round($source.Width * $scale)
                    $drawHeight = [int][Math]::Round($source.Height * $scale)
                    $x = [int](($width - $drawWidth) / 2); $y = [int](($height - $drawHeight) / 2)
                    $graphics.DrawImage($source, $x, $y, $drawWidth, $drawHeight)
                } finally { $graphics.Dispose() }
                $bitmap.Save((Join-Path $OutputDir $icon.Name), [System.Drawing.Imaging.ImageFormat]::Png)
            } finally { $bitmap.Dispose() }
            Write-Host "  Generated $($icon.Name)" -ForegroundColor Gray
        }
        $iconBitmap = New-Object System.Drawing.Bitmap 256, 256
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($iconBitmap)
            try {
                $graphics.Clear([System.Drawing.Color]::Transparent)
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $scale = [Math]::Min(240.0 / $source.Width, 240.0 / $source.Height)
                $drawWidth = [int][Math]::Round($source.Width * $scale); $drawHeight = [int][Math]::Round($source.Height * $scale)
                $graphics.DrawImage($source, [int]((256 - $drawWidth) / 2), [int]((256 - $drawHeight) / 2), $drawWidth, $drawHeight)
            } finally { $graphics.Dispose() }
            $hIcon = $iconBitmap.GetHicon()
            try {
                $iconObject = [System.Drawing.Icon]::FromHandle($hIcon)
                $stream = [System.IO.File]::Open($AppIconPath, [System.IO.FileMode]::Create)
                try { $iconObject.Save($stream) } finally { $stream.Dispose() }
            } finally {
                Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class LedIconNativeMethods { [DllImport("user32.dll", SetLastError=true)] public static extern bool DestroyIcon(IntPtr hIcon); }
"@ -ErrorAction SilentlyContinue
                [LedIconNativeMethods]::DestroyIcon($hIcon) | Out-Null
            }
        } finally { $iconBitmap.Dispose() }
    } finally { $source.Dispose() }
}

Write-Host "`nWindows icon generation complete." -ForegroundColor Green
Write-Host "Source: $SourceImage"
Write-Host "Executable icon: $AppIconPath"
Write-Host "MSIX icons: $OutputDir"