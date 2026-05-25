param(
    [string]$FeedPath = "public/home-feed.json",
    [string]$OutputDir = "public/assets/feed-optimized/20260525-home-feed-optimized-assets",
    [int]$BackgroundMaxWidth = 1280,
    [int]$CharacterMaxHeight = 768,
    [int]$JpegQuality = 82
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

if (-not ("HomeFeedOptimize.ImageOps" -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;

namespace HomeFeedOptimize
{
    public sealed class ImageInfo
    {
        public int Width;
        public int Height;
        public string PixelFormat;
    }

    public static class ImageOps
    {
        public static ImageInfo GetInfo(string path)
        {
            using (Image image = Image.FromFile(path))
            {
                return new ImageInfo
                {
                    Width = image.Width,
                    Height = image.Height,
                    PixelFormat = image.PixelFormat.ToString()
                };
            }
        }

        public static ImageInfo ResizePng(string sourcePath, string outputPath, int maxWidth, int maxHeight)
        {
            using (Bitmap source = new Bitmap(sourcePath))
            {
                Size size = FitWithin(source.Width, source.Height, maxWidth, maxHeight);
                Directory.CreateDirectory(Path.GetDirectoryName(outputPath));

                using (Bitmap output = new Bitmap(size.Width, size.Height, PixelFormat.Format32bppArgb))
                using (Graphics graphics = Graphics.FromImage(output))
                {
                    UsePixelArtSettings(graphics);
                    graphics.Clear(Color.Transparent);
                    graphics.DrawImage(source, new Rectangle(0, 0, size.Width, size.Height), new Rectangle(0, 0, source.Width, source.Height), GraphicsUnit.Pixel);
                    output.Save(outputPath, ImageFormat.Png);
                }

                return GetInfo(outputPath);
            }
        }

        public static ImageInfo ResizeJpeg(string sourcePath, string outputPath, int maxWidth, int maxHeight, long quality)
        {
            using (Bitmap source = new Bitmap(sourcePath))
            {
                Size size = FitWithin(source.Width, source.Height, maxWidth, maxHeight);
                Directory.CreateDirectory(Path.GetDirectoryName(outputPath));

                using (Bitmap output = new Bitmap(size.Width, size.Height, PixelFormat.Format24bppRgb))
                using (Graphics graphics = Graphics.FromImage(output))
                {
                    UsePixelArtSettings(graphics);
                    graphics.Clear(Color.Black);
                    graphics.DrawImage(source, new Rectangle(0, 0, size.Width, size.Height), new Rectangle(0, 0, source.Width, source.Height), GraphicsUnit.Pixel);

                    ImageCodecInfo encoder = ImageCodecInfo.GetImageEncoders().First(codec => codec.FormatID == ImageFormat.Jpeg.Guid);
                    using (EncoderParameters parameters = new EncoderParameters(1))
                    {
                        parameters.Param[0] = new EncoderParameter(Encoder.Quality, quality);
                        output.Save(outputPath, encoder, parameters);
                    }
                }

                return GetInfo(outputPath);
            }
        }

        private static Size FitWithin(int width, int height, int maxWidth, int maxHeight)
        {
            double scaleX = maxWidth > 0 ? maxWidth / (double)width : 1.0;
            double scaleY = maxHeight > 0 ? maxHeight / (double)height : 1.0;
            double scale = Math.Min(1.0, Math.Min(scaleX, scaleY));
            int outWidth = Math.Max(1, (int)Math.Round(width * scale));
            int outHeight = Math.Max(1, (int)Math.Round(height * scale));
            return new Size(outWidth, outHeight);
        }

        private static void UsePixelArtSettings(Graphics graphics)
        {
            graphics.CompositingMode = CompositingMode.SourceOver;
            graphics.CompositingQuality = CompositingQuality.HighSpeed;
            graphics.InterpolationMode = InterpolationMode.NearestNeighbor;
            graphics.PixelOffsetMode = PixelOffsetMode.Half;
            graphics.SmoothingMode = SmoothingMode.None;
        }
    }
}
"@
}

function Get-RelativePathText {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $baseFull = [System.IO.Path]::GetFullPath($BasePath)
    if (-not $baseFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $baseFull += [System.IO.Path]::DirectorySeparatorChar
    }

    $pathFull = [System.IO.Path]::GetFullPath($Path)
    $baseUri = [Uri]::new($baseFull)
    $pathUri = [Uri]::new($pathFull)
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace("\", "/")
}

function Get-OptimizedFileName {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$Extension
    )

    $stem = [System.IO.Path]::GetFileNameWithoutExtension($Url)
    return "$stem-feed$Extension"
}

if ($JpegQuality -lt 1 -or $JpegQuality -gt 100) {
    throw "JpegQuality must be between 1 and 100."
}

$root = (Get-Location).Path
$feedFull = [System.IO.Path]::GetFullPath($FeedPath)
$outputFull = [System.IO.Path]::GetFullPath($OutputDir)

if (-not (Test-Path -LiteralPath $feedFull)) {
    throw "FeedPath not found: $FeedPath"
}

New-Item -ItemType Directory -Force -Path $outputFull | Out-Null

$feed = Get-Content -LiteralPath $feedFull -Raw | ConvertFrom-Json
$results = New-Object System.Collections.Generic.List[object]
$seen = @{}

foreach ($post in $feed.posts) {
    if (-not ($post.PSObject.Properties.Name -contains "media")) {
        continue
    }

    foreach ($media in $post.media) {
        if ($media.type -ne "image") {
            continue
        }

        $url = [string]$media.url
        if ($seen.ContainsKey($url)) {
            continue
        }
        $seen[$url] = $true

        $sourceFull = [System.IO.Path]::GetFullPath((Join-Path (Split-Path $feedFull -Parent) $url))
        if (-not (Test-Path -LiteralPath $sourceFull)) {
            throw "Feed media file not found: $url"
        }

        $isBackground = $url -like "assets/backgrounds/*"
        $extension = if ($isBackground) { ".jpg" } else { ".png" }
        $targetName = Get-OptimizedFileName -Url $url -Extension $extension
        $targetFull = Join-Path $outputFull $targetName

        $sourceInfo = [HomeFeedOptimize.ImageOps]::GetInfo($sourceFull)
        if ($isBackground) {
            $targetInfo = [HomeFeedOptimize.ImageOps]::ResizeJpeg($sourceFull, $targetFull, $BackgroundMaxWidth, 0, $JpegQuality)
        } else {
            $targetInfo = [HomeFeedOptimize.ImageOps]::ResizePng($sourceFull, $targetFull, 0, $CharacterMaxHeight)
        }

        $sourceBytes = (Get-Item -LiteralPath $sourceFull).Length
        $targetBytes = (Get-Item -LiteralPath $targetFull).Length
        $savedBytes = $sourceBytes - $targetBytes
        $savedPercent = if ($sourceBytes -gt 0) { [Math]::Round(($savedBytes / $sourceBytes) * 100, 2) } else { 0 }

        $results.Add([PSCustomObject]@{
            postId = $post.id
            source = $url
            optimized = (Get-RelativePathText -BasePath (Split-Path $feedFull -Parent) -Path $targetFull)
            mediaType = "image"
            format = if ($isBackground) { "jpeg" } else { "png" }
            sourceBytes = $sourceBytes
            optimizedBytes = $targetBytes
            savedBytes = $savedBytes
            savedPercent = $savedPercent
            sourceSize = [PSCustomObject]@{
                w = $sourceInfo.Width
                h = $sourceInfo.Height
                pixelFormat = $sourceInfo.PixelFormat
            }
            optimizedSize = [PSCustomObject]@{
                w = $targetInfo.Width
                h = $targetInfo.Height
                pixelFormat = $targetInfo.PixelFormat
            }
        }) | Out-Null
    }
}

$totalSource = ($results | Measure-Object -Property sourceBytes -Sum).Sum
$totalOptimized = ($results | Measure-Object -Property optimizedBytes -Sum).Sum
$totalSaved = $totalSource - $totalOptimized
$totalSavedPercent = if ($totalSource -gt 0) { [Math]::Round(($totalSaved / $totalSource) * 100, 2) } else { 0 }

$manifest = [PSCustomObject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    tool = "tools/optimize-home-feed-images.ps1"
    feed = (Get-RelativePathText -BasePath $root -Path $feedFull)
    outputDir = (Get-RelativePathText -BasePath $root -Path $outputFull)
    settings = [PSCustomObject]@{
        backgroundMaxWidth = $BackgroundMaxWidth
        characterMaxHeight = $CharacterMaxHeight
        jpegQuality = $JpegQuality
    }
    totals = [PSCustomObject]@{
        sourceBytes = $totalSource
        optimizedBytes = $totalOptimized
        savedBytes = $totalSaved
        savedPercent = $totalSavedPercent
    }
    assets = $results.ToArray()
}

$manifestPath = Join-Path $outputFull "manifest.json"
$manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Host "Optimized $($results.Count) feed image(s)."
Write-Host "Saved $totalSaved byte(s), $totalSavedPercent%."
Write-Host "Manifest: $(Get-RelativePathText -BasePath $root -Path $manifestPath)"
