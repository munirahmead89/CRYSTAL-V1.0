# Resizes PNGs in place (or to a target folder) using System.Drawing.
#
#   powershell -File tools\resize_png.ps1 -In <path> [-Out <path>] [-Max 1080] [-MaxHeight 0]
#
# -Max is the maximum width in pixels; -MaxHeight additionally caps the height.
# Both are only applied when they actually shrink the image, so small images are
# never upscaled.
param(
    [Parameter(Mandatory = $true)][string]$In,
    [string]$Out,
    [int]$Max = 1080,
    [int]$MaxHeight = 0
)

Add-Type -AssemblyName System.Drawing

if (-not $Out) {
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($In)
    $ext = [System.IO.Path]::GetExtension($In)
    $Out = [System.IO.Path]::Combine(
        [System.IO.Path]::GetDirectoryName($In), "$stem`.$ext")
}

$src = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $In))
try {
    $scale = 1.0
    if ($Max -gt 0) { $scale = [Math]::Min($scale, $Max / $src.Width) }
    if ($MaxHeight -gt 0) { $scale = [Math]::Min($scale, $MaxHeight / $src.Height) }

    $w = [int][Math]::Round($src.Width * $scale)
    $h = [int][Math]::Round($src.Height * $scale)

    # Nearest-neighbour-free downscale reads better for UI text than
    # DrawImage's default bicubic at large reductions.
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.DrawImage($src, 0, 0, $w, $h)
    } finally { $g.Dispose() }

    try { $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png) }
    finally { $bmp.Dispose() }

    Write-Host ("{0} -> {1}x{2}  {3:N0} KB" -f `
        [System.IO.Path]::GetFileName($In), $w, $h, ((Get-Item $Out).Length / 1KB))
} finally { $src.Dispose() }