# Normalises a raw device screenshot into a store-ready image.
#
#   powershell -File tools\prepare_store_image.ps1 -In raw.png -Out store.png [-Ratio 2.0] [-Bg "#000000"]
#
# APKPure's rules this enforces:
#   - JPEG or 24-bit PNG, NO ALPHA. System.Drawing's PNG encoder emits RGBA by
#     default, so the image is re-rendered into a Format24bppRgb bitmap; that
#     drops the alpha channel entirely rather than just setting it opaque.
#   - minimum dimension >= 320px, maximum <= 3840px.
#   - maximum dimension must not exceed 2x the minimum.
#
# A Pixel-class phone screen is about 1080x2424, i.e. 2.24:1, which FAILS the
# ratio rule. Rather than crop away ~260px of real UI, the image is padded
# outwards with a background colour so the full screen survives and the canvas
# lands on exactly the requested ratio.
param(
    [Parameter(Mandatory = $true)][string]$In,
    [Parameter(Mandatory = $true)][string]$Out,
    [double]$Ratio = 2.0,
    [string]$Bg = "#000000"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $In).Path)
try {
    # --- work out a canvas that satisfies ratio and the absolute bounds -------
    # Start from the source size and change as little as possible. Growing the
    # canvas to the 3840 maximum would be actively harmful: it upscales the
    # screenshot and leaves it floating in a wide empty gutter.
    $w = $src.Width
    $h = $src.Height

    $long = [Math]::Max($w, $h)
    $shortSide = [Math]::Min($w, $h)
    if ($long -gt $Ratio * $shortSide) {
        # Too elongated for the rule. The side to change is the SHORT one, and
        # it grows to long / Ratio (dividing, not multiplying - a 1080x2424
        # phone screen needs width 1212 to satisfy 2424 <= 2 * 1212).
        if ($h -gt $w) { $w = [int][Math]::Ceiling($h / $Ratio) }
        else { $h = [int][Math]::Ceiling($w / $Ratio) }
    }

    # Only ever scale DOWN, and only when an absolute bound is breached.
    $longest = [Math]::Max($w, $h)
    if ($longest -gt 3840) {
        $scale = 3840.0 / $longest
        $w = [int][Math]::Floor($w * $scale)
        $h = [int][Math]::Floor($h * $scale)
    }
    $short = [Math]::Min($w, $h)
    if ($short -lt 320) {
        $scale = 320.0 / $short
        $w = [int][Math]::Ceiling($w * $scale)
        $h = [int][Math]::Ceiling($h * $scale)
    }

    $bgColor = [System.Drawing.ColorTranslator]::FromHtml($Bg)

    # Format24bppRgb is the whole point: the result has no alpha channel at all.
    $canvas = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    try {
        $g = [System.Drawing.Graphics]::FromImage($canvas)
        try {
            $g.Clear($bgColor)                      # fills every pixel, incl. padding
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            # Centre the screenshot on the padded canvas.
            $x = [int](($w - $src.Width) / 2)
            $y = [int](($h - $src.Height) / 2)
            $g.DrawImage($src, $x, $y, $src.Width, $src.Height)
        } finally { $g.Dispose() }

        # --- verify before writing -------------------------------------------
        if ($canvas.PixelFormat -ne [System.Drawing.Imaging.PixelFormat]::Format24bppRgb) {
            throw "pixel format is $($canvas.PixelFormat), expected Format24bppRgb"
        }
        $short = [Math]::Min($w, $h); $long = [Math]::Max($w, $h)
        if ($short -lt 320) { throw "minimum dimension $short is below 320" }
        if ($long -gt 3840) { throw "maximum dimension $long exceeds 3840" }
        if ($long -gt 2 * $short) { throw "aspect $w x $h violates max <= 2 x min" }

        $outDir = Split-Path -Parent $Out
        if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
        $canvas.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)

        Write-Host ("{0} -> {1}x{2}  ratio {3:N3}  24-bit  {4:N0} KB" -f `
            [System.IO.Path]::GetFileName($Out), $w, $h, ($long / $short), ((Get-Item $Out).Length / 1KB))
    } finally { $canvas.Dispose() }
} finally { $src.Dispose() }