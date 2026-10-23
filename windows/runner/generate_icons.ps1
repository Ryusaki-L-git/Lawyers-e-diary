# Icon Generation Script for Lawyers E-Diary MSIX Packaging
# This script generates all required MSIX icon sizes from the source app_icon.ico
# Run from: C:\Users\Lawyers-e-diary-main\windows\runner\
#
# Requirements: ImageMagick (https://www.imagemagick.org/) or PowerShell with System.Drawing

param(
    [string]$SourceIcon = "",
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"

# Resolve the default paths relative to this script so the script works from
# any working directory.
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($SourceIcon)) {
    $SourceIcon = Join-Path $scriptRoot "resources\app_icon.ico"
}
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $scriptRoot "assets\icons"
}

# Required MSIX icon sizes (width x height in pixels)
$iconSizes = @(
    @{ Name = "square30x30Logo.png";    Size = 30  }
    @{ Name = "square44x44Logo.png";    Size = 44  }
    @{ Name = "square71x71Logo.png";    Size = 71  }
    @{ Name = "square150x150Logo.png";  Size = 150 }
    @{ Name = "square310x310Logo.png";  Size = 310 }
    @{ Name = "StoreLogo.png";          Size = 50  }
    @{ Name = "wide310x150Logo.png";    Width = 310; Height = 150 }
)

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "Created output directory: $OutputDir"
}

# Check if source icon exists
if (-not (Test-Path $SourceIcon)) {
    Write-Error "Source icon not found: $SourceIcon"
    exit 1
}

# Check for ImageMagick
$hasMagick = $null -ne (Get-Command magick -ErrorAction SilentlyContinue)

if ($hasMagick) {
    Write-Host "Using ImageMagick for icon generation..." -ForegroundColor Green
    
    foreach ($icon in $iconSizes) {
        $outPath = Join-Path $OutputDir $icon.Name
        
        if ($icon.Width -and $icon.Height) {
            # Wide icon (non-square)
            magick convert $SourceIcon -resize "$($icon.Width)x$($icon.Height)!" -background none $outPath
        } else {
            # Square icon
            $size = $icon.Size
            magick convert $SourceIcon -resize "${size}x${size}!" -background none $outPath
        }
        
        if ($?) {
            Write-Host "  Generated: $($icon.Name) ($($icon.Size)x$($icon.Size))" -ForegroundColor Gray
        } else {
            Write-Warning "Failed to generate: $($icon.Name)"
        }
    }
} else {
    Write-Warning "ImageMagick not found. Attempting fallback with System.Drawing..."
    
    Add-Type -AssemblyName System.Drawing
    
    $sourceImage = [System.Drawing.Image]::FromFile($SourceIcon)
    
    foreach ($icon in $iconSizes) {
        $outPath = Join-Path $OutputDir $icon.Name
        
        if ($icon.Width -and $icon.Height) {
            $bitmap = New-Object System.Drawing.Bitmap $icon.Width, $icon.Height
        } else {
            $bitmap = New-Object System.Drawing.Bitmap $icon.Size, $icon.Size
        }
        
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.Clear([System.Drawing.Color]::Transparent)
        
        # Calculate centered scaling
        if ($icon.Width -and $icon.Height) {
            $scaleX = $icon.Width / $sourceImage.Width
            $scaleY = $icon.Height / $sourceImage.Height
            $scale = [Math]::Min($scaleX, $scaleY)
            $destWidth = [int]($sourceImage.Width * $scale)
            $destHeight = [int]($sourceImage.Height * $scale)
            $x = [int](($icon.Width - $destWidth) / 2)
            $y = [int](($icon.Height - $destHeight) / 2)
        } else {
            $scale = $icon.Size / [Math]::Max($sourceImage.Width, $sourceImage.Height)
            $destWidth = [int]($sourceImage.Width * $scale)
            $destHeight = [int]($sourceImage.Height * $scale)
            $x = [int](($icon.Size - $destWidth) / 2)
            $y = [int](($icon.Size - $destHeight) / 2)
        }
        
        $graphics.DrawImage($sourceImage, $x, $y, $destWidth, $destHeight)
        $graphics.Dispose()
        $bitmap.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose()
        
        Write-Host "  Generated: $($icon.Name)" -ForegroundColor Gray
    }
    
    $sourceImage.Dispose()
}

Write-Host "`nIcon generation complete. Files in: $OutputDir" -ForegroundColor Green
Get-ChildItem $OutputDir | Select-Object Name, Length | Format-Table -AutoSize