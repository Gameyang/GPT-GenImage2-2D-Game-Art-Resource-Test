param(
    [string]$InputPath = "raw/references/Gemini_Generated_Image_1ysr8x1ysr8x1ysr.png",
    [string]$OutputRoot = "experiments/20260528-gemini-1ysr-keyed-animation",
    [string]$AssetId = "gemini-1ysr-ocad-keyed",
    [string]$KeyColor = "#FF0000",
    [int]$KeyDistanceThreshold = 8,
    [int]$FrameDelayMs = 100,
    [switch]$KeepExisting
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

if (-not ("OcadKeyedAnimation.ImageOps" -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.Serialization;

namespace OcadKeyedAnimation
{
    public sealed class ImageInfo
    {
        public int Width;
        public int Height;
        public string PixelFormat;
    }

    public sealed class FrameStats
    {
        public int Width;
        public int Height;
        public int TransparentPixels;
        public int OpaquePixels;
        public int PartialPixels;
        public int BboxX;
        public int BboxY;
        public int BboxWidth;
        public int BboxHeight;
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

        public static FrameStats NormalizeTransparentSheet(string inputPath, string outputPath, Color key, int keyDistanceThreshold)
        {
            DirectoryEnsure(outputPath);

            using (Bitmap source = new Bitmap(inputPath))
            using (Bitmap output = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb))
            {
                FrameStats stats = CopyRegion(source, output, new Rectangle(0, 0, source.Width, source.Height), key, keyDistanceThreshold);
                output.Save(outputPath, ImageFormat.Png);
                return stats;
            }
        }

        public static FrameStats SliceRegion(string inputPath, string outputPath, int x, int y, int width, int height, Color key, int keyDistanceThreshold)
        {
            DirectoryEnsure(outputPath);

            using (Bitmap source = new Bitmap(inputPath))
            using (Bitmap output = new Bitmap(width, height, PixelFormat.Format32bppArgb))
            {
                FrameStats stats = CopyRegion(source, output, new Rectangle(x, y, width, height), key, keyDistanceThreshold);
                output.Save(outputPath, ImageFormat.Png);
                return stats;
            }
        }

        public static ImageInfo FlipHorizontal(string inputPath, string outputPath)
        {
            DirectoryEnsure(outputPath);

            using (Bitmap source = new Bitmap(inputPath))
            using (Bitmap output = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb))
            using (Graphics graphics = Graphics.FromImage(output))
            {
                UseSpriteSettings(graphics);
                graphics.Clear(Color.Transparent);
                graphics.TranslateTransform(source.Width, 0);
                graphics.ScaleTransform(-1, 1);
                graphics.DrawImageUnscaled(source, 0, 0);
                output.Save(outputPath, ImageFormat.Png);
            }

            return GetInfo(outputPath);
        }

        public static void SaveAnimatedGif(string[] framePaths, string outputPath, int delayMs)
        {
            if (framePaths.Length == 0)
            {
                throw new InvalidOperationException("Cannot create GIF without frames: " + outputPath);
            }

            ImageCodecInfo gifEncoder = null;
            foreach (ImageCodecInfo codec in ImageCodecInfo.GetImageEncoders())
            {
                if (codec.MimeType == "image/gif")
                {
                    gifEncoder = codec;
                    break;
                }
            }

            if (gifEncoder == null)
            {
                throw new InvalidOperationException("GIF encoder is not available in this environment.");
            }

            int delayHundredths = Math.Max(1, (int)Math.Round(delayMs / 10.0));
            byte[] delayBytes = new byte[framePaths.Length * 4];
            for (int i = 0; i < framePaths.Length; i++)
            {
                BitConverter.GetBytes(delayHundredths).CopyTo(delayBytes, i * 4);
            }

            byte[] loopBytes = new byte[] { 0, 0 };
            DirectoryEnsure(outputPath);
            if (File.Exists(outputPath))
            {
                File.Delete(outputPath);
            }

            using (Bitmap firstFrame = new Bitmap(framePaths[0]))
            {
                firstFrame.SetPropertyItem(NewPropertyItem(0x5100, 4, delayBytes));
                firstFrame.SetPropertyItem(NewPropertyItem(0x5101, 3, loopBytes));

                using (EncoderParameters encoderParameters = new EncoderParameters(1))
                {
                    encoderParameters.Param[0] = new EncoderParameter(Encoder.SaveFlag, (long)EncoderValue.MultiFrame);
                    firstFrame.Save(outputPath, gifEncoder, encoderParameters);

                    encoderParameters.Param[0] = new EncoderParameter(Encoder.SaveFlag, (long)EncoderValue.FrameDimensionTime);
                    for (int i = 1; i < framePaths.Length; i++)
                    {
                        using (Bitmap frame = new Bitmap(framePaths[i]))
                        {
                            if (frame.Width != firstFrame.Width || frame.Height != firstFrame.Height)
                            {
                                throw new InvalidOperationException(
                                    "Frame size mismatch in " + outputPath + ": " + framePaths[i] +
                                    " is " + frame.Width + "x" + frame.Height +
                                    ", expected " + firstFrame.Width + "x" + firstFrame.Height + "."
                                );
                            }

                            firstFrame.SaveAdd(frame, encoderParameters);
                        }
                    }

                    encoderParameters.Param[0] = new EncoderParameter(Encoder.SaveFlag, (long)EncoderValue.Flush);
                    firstFrame.SaveAdd(encoderParameters);
                }
            }
        }

        private static FrameStats CopyRegion(Bitmap source, Bitmap output, Rectangle sourceRect, Color key, int keyDistanceThreshold)
        {
            FrameStats stats = new FrameStats();
            stats.Width = output.Width;
            stats.Height = output.Height;
            int left = output.Width;
            int top = output.Height;
            int right = -1;
            int bottom = -1;

            for (int y = 0; y < output.Height; y++)
            {
                for (int x = 0; x < output.Width; x++)
                {
                    int sourceX = sourceRect.X + x;
                    int sourceY = sourceRect.Y + y;
                    Color pixel = Color.Transparent;
                    if (sourceX >= 0 && sourceX < source.Width && sourceY >= 0 && sourceY < source.Height)
                    {
                        pixel = source.GetPixel(sourceX, sourceY);
                    }

                    if (pixel.A == 0 || IsKey(pixel, key, keyDistanceThreshold))
                    {
                        output.SetPixel(x, y, Color.Transparent);
                        stats.TransparentPixels++;
                        continue;
                    }

                    output.SetPixel(x, y, pixel);
                    if (pixel.A < 255)
                    {
                        stats.PartialPixels++;
                    }
                    else
                    {
                        stats.OpaquePixels++;
                    }

                    if (x < left) left = x;
                    if (y < top) top = y;
                    if (x > right) right = x;
                    if (y > bottom) bottom = y;
                }
            }

            if (right >= left && bottom >= top)
            {
                stats.BboxX = left;
                stats.BboxY = top;
                stats.BboxWidth = right - left + 1;
                stats.BboxHeight = bottom - top + 1;
            }
            else
            {
                stats.BboxX = 0;
                stats.BboxY = 0;
                stats.BboxWidth = 0;
                stats.BboxHeight = 0;
            }

            return stats;
        }

        private static bool IsKey(Color pixel, Color key, int keyDistanceThreshold)
        {
            if (pixel.A == 0)
            {
                return true;
            }

            double dr = pixel.R - key.R;
            double dg = pixel.G - key.G;
            double db = pixel.B - key.B;
            return Math.Sqrt((dr * dr) + (dg * dg) + (db * db)) <= keyDistanceThreshold;
        }

        private static PropertyItem NewPropertyItem(int id, short type, byte[] value)
        {
            PropertyItem propertyItem = (PropertyItem)FormatterServices.GetUninitializedObject(typeof(PropertyItem));
            propertyItem.Id = id;
            propertyItem.Type = type;
            propertyItem.Len = value.Length;
            propertyItem.Value = value;
            return propertyItem;
        }

        private static void UseSpriteSettings(Graphics graphics)
        {
            graphics.CompositingMode = CompositingMode.SourceOver;
            graphics.CompositingQuality = CompositingQuality.HighSpeed;
            graphics.InterpolationMode = InterpolationMode.NearestNeighbor;
            graphics.PixelOffsetMode = PixelOffsetMode.Half;
            graphics.SmoothingMode = SmoothingMode.None;
        }

        private static void DirectoryEnsure(string outputPath)
        {
            string directory = Path.GetDirectoryName(outputPath);
            if (!String.IsNullOrEmpty(directory))
            {
                Directory.CreateDirectory(directory);
            }
        }
    }
}
"@
}

function ConvertFrom-HexColor {
    param([Parameter(Mandatory = $true)][string]$Value)

    $text = $Value.Trim()
    if ($text.StartsWith("#")) {
        $text = $text.Substring(1)
    }

    if ($text.Length -ne 6 -or $text -notmatch "^[0-9a-fA-F]{6}$") {
        throw "KeyColor must be a 6-digit hex color, for example #FF0000."
    }

    return [System.Drawing.Color]::FromArgb(
        255,
        [Convert]::ToInt32($text.Substring(0, 2), 16),
        [Convert]::ToInt32($text.Substring(2, 2), 16),
        [Convert]::ToInt32($text.Substring(4, 2), 16)
    )
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

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )

    $json = $Value | ConvertTo-Json -Depth 30
    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $encoding)
}

function New-Rect {
    param([int]$X, [int]$Y, [int]$W, [int]$H)
    return [PSCustomObject]@{ x = $X; y = $Y; w = $W; h = $H }
}

if ($KeyDistanceThreshold -lt 0 -or $KeyDistanceThreshold -gt 442) {
    throw "KeyDistanceThreshold must be between 0 and 442."
}
if ($FrameDelayMs -lt 10) {
    throw "FrameDelayMs must be 10 or greater."
}

$inputFull = [System.IO.Path]::GetFullPath($InputPath)
$outputFull = [System.IO.Path]::GetFullPath($OutputRoot)
$rootForRelative = (Get-Location).Path

if (-not (Test-Path -LiteralPath $inputFull)) {
    throw "InputPath not found: $InputPath"
}

if ((Test-Path -LiteralPath $outputFull) -and -not $KeepExisting.IsPresent) {
    $outputFullWithSeparator = $outputFull
    if (-not $outputFullWithSeparator.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $outputFullWithSeparator += [System.IO.Path]::DirectorySeparatorChar
    }
    $workspaceFull = [System.IO.Path]::GetFullPath($rootForRelative)
    if (-not $workspaceFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $workspaceFull += [System.IO.Path]::DirectorySeparatorChar
    }
    if (-not $outputFullWithSeparator.StartsWith($workspaceFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean OutputRoot outside workspace: $outputFull"
    }
    Remove-Item -LiteralPath $outputFull -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $outputFull | Out-Null
$framesRoot = Join-Path $outputFull "frames"
$playbackRoot = Join-Path $outputFull "playback"
$sheetRoot = Join-Path $outputFull "sheets"
New-Item -ItemType Directory -Force -Path $framesRoot | Out-Null
New-Item -ItemType Directory -Force -Path $playbackRoot | Out-Null
New-Item -ItemType Directory -Force -Path $sheetRoot | Out-Null

# From systemchester/Spritesheetweapon:
# 05-成品项目/AI像素商K/ocad/ocad_spritesheet_generator.gd
$regions = [ordered]@{
    "uk1xb" = New-Rect 0 168 42 42; "m5je3" = New-Rect 42 168 42 42; "2ij6o" = New-Rect 84 168 42 42
    "kmxfq" = New-Rect 126 168 42 42; "cpoga" = New-Rect 168 168 42 42; "02845" = New-Rect 210 168 42 42
    "hg6s0" = New-Rect 0 210 42 42; "kwjof" = New-Rect 42 210 42 42
    "5u6fn" = New-Rect 126 84 21 42; "t2na7" = New-Rect 147 84 21 42; "3kx8u" = New-Rect 168 84 21 42
    "y5pas" = New-Rect 189 84 21 42; "8pc1g" = New-Rect 210 84 21 42; "3cyhk" = New-Rect 231 84 21 42
    "w25ly" = New-Rect 168 126 21 42; "rdd8s" = New-Rect 189 210 63 42; "72hcl" = New-Rect 210 126 21 42
    "rydce" = New-Rect 189 126 21 42; "1et3y" = New-Rect 231 126 21 42; "uwgfa" = New-Rect 147 210 21 42
    "y65iy" = New-Rect 168 210 21 42; "8al5y" = New-Rect 105 210 21 42; "3js2j" = New-Rect 126 210 21 42
    "bbcvv" = New-Rect 0 126 28 42; "foxtp" = New-Rect 28 126 28 42; "aw8dg" = New-Rect 56 126 28 42
    "evrtr" = New-Rect 84 126 28 42; "pyoh8" = New-Rect 112 126 28 42; "t4rff" = New-Rect 140 126 28 42
    "koy62" = New-Rect 0 0 21 42; "3ygc0" = New-Rect 21 0 21 42; "yfrrb" = New-Rect 42 0 21 42
    "2enbr" = New-Rect 63 0 21 42; "s2yql" = New-Rect 84 0 21 42; "idc64" = New-Rect 105 0 21 42
    "8mwul" = New-Rect 0 42 21 42; "snwwj" = New-Rect 21 42 21 42; "ynglr" = New-Rect 42 42 21 42
    "p3oo0" = New-Rect 63 42 21 42; "pfwvy" = New-Rect 84 42 21 42; "tvkvf" = New-Rect 105 42 21 42
    "20ynl" = New-Rect 84 210 21 42; "3c66l" = New-Rect 0 84 21 42; "wq5ia" = New-Rect 21 84 21 42
    "11gwb" = New-Rect 42 84 21 42; "iitav" = New-Rect 63 84 21 42; "360a7" = New-Rect 84 84 21 42
    "ffd0g" = New-Rect 105 84 21 42; "ahlcx" = New-Rect 126 0 21 42; "4i3vm" = New-Rect 147 0 21 42
    "0qwcd" = New-Rect 168 0 21 42; "y1030" = New-Rect 189 0 21 42; "3sl87" = New-Rect 210 0 21 42
    "8kwsb" = New-Rect 231 0 21 42; "umveo" = New-Rect 126 42 21 42; "v6ado" = New-Rect 147 42 21 42
    "syfy0" = New-Rect 168 42 21 42; "us0w8" = New-Rect 189 42 21 42; "pf2m2" = New-Rect 210 42 21 42
    "876dv" = New-Rect 231 42 21 42
}

$animations = @(
    [PSCustomObject]@{ name = "attractL"; frames = @("uk1xb","m5je3","2ij6o","kmxfq","cpoga","02845","hg6s0","kwjof"); loop = $false; speed = 10.0 }
    [PSCustomObject]@{ name = "climb"; frames = @("5u6fn","t2na7","3kx8u","y5pas","8pc1g","3cyhk"); loop = $true; speed = 7.0 }
    [PSCustomObject]@{ name = "defence"; frames = @("w25ly"); loop = $true; speed = 5.0 }
    [PSCustomObject]@{ name = "die"; frames = @("rdd8s"); loop = $true; speed = 5.0 }
    [PSCustomObject]@{ name = "idleL"; frames = @("72hcl"); loop = $true; speed = 5.0 }
    [PSCustomObject]@{ name = "idledown"; frames = @("rydce"); loop = $true; speed = 5.0 }
    [PSCustomObject]@{ name = "idleup"; frames = @("1et3y"); loop = $true; speed = 5.0 }
    [PSCustomObject]@{ name = "item"; frames = @("uwgfa","y65iy"); loop = $false; speed = 5.0 }
    [PSCustomObject]@{ name = "jump"; frames = @("8al5y","3js2j"); loop = $true; speed = 1.0 }
    [PSCustomObject]@{ name = "runL"; frames = @("bbcvv","foxtp","aw8dg","evrtr","pyoh8","t4rff"); loop = $true; speed = 10.0 }
    [PSCustomObject]@{ name = "rundown"; frames = @("koy62","3ygc0","yfrrb","2enbr","s2yql","idc64"); loop = $true; speed = 10.0 }
    [PSCustomObject]@{ name = "runup"; frames = @("8mwul","snwwj","ynglr","p3oo0","pfwvy","tvkvf"); loop = $true; speed = 10.0 }
    [PSCustomObject]@{ name = "sitdown"; frames = @("20ynl"); loop = $false; speed = 5.0 }
    [PSCustomObject]@{ name = "walkL"; frames = @("3c66l","wq5ia","11gwb","iitav","360a7","ffd0g"); loop = $true; speed = 5.0 }
    [PSCustomObject]@{ name = "walkdown"; frames = @("ahlcx","4i3vm","0qwcd","y1030","3sl87","8kwsb"); loop = $true; speed = 5.0 }
    [PSCustomObject]@{ name = "walkup"; frames = @("umveo","v6ado","syfy0","us0w8","pf2m2","876dv"); loop = $true; speed = 5.0 }
)

$sourceInfo = [OcadKeyedAnimation.ImageOps]::GetInfo($inputFull)
foreach ($entry in $regions.GetEnumerator()) {
    $r = $entry.Value
    if (($r.x + $r.w) -gt $sourceInfo.Width -or ($r.y + $r.h) -gt $sourceInfo.Height) {
        throw "Region '$($entry.Key)' is outside source bounds $($sourceInfo.Width)x$($sourceInfo.Height)."
    }
}

$key = ConvertFrom-HexColor -Value $KeyColor
$sheetPath = Join-Path $sheetRoot "$AssetId-transparent.png"
$sheetStats = [OcadKeyedAnimation.ImageOps]::NormalizeTransparentSheet($inputFull, $sheetPath, $key, $KeyDistanceThreshold)

$frameLookup = @{}
$frameRecords = New-Object System.Collections.Generic.List[object]
foreach ($entry in $regions.GetEnumerator()) {
    $keyName = $entry.Key
    $r = $entry.Value
    $framePath = Join-Path $framesRoot "$keyName.png"
    $stats = [OcadKeyedAnimation.ImageOps]::SliceRegion($inputFull, $framePath, $r.x, $r.y, $r.w, $r.h, $key, $KeyDistanceThreshold)
    $relativeFramePath = Get-RelativePathText -BasePath $rootForRelative -Path $framePath
    $frameLookup[$keyName] = $framePath
    $frameRecords.Add([PSCustomObject]@{
        key = $keyName
        output = $relativeFramePath
        sourceRect = $r
        transparentPixels = $stats.TransparentPixels
        opaquePixels = $stats.OpaquePixels
        partialPixels = $stats.PartialPixels
        bbox = [PSCustomObject]@{
            x = $stats.BboxX
            y = $stats.BboxY
            w = $stats.BboxWidth
            h = $stats.BboxHeight
        }
    }) | Out-Null
}

$animationRecords = New-Object System.Collections.Generic.List[object]
foreach ($anim in $animations) {
    $framePaths = @($anim.frames | ForEach-Object { $frameLookup[$_] })
    $playbackPath = Join-Path $playbackRoot "$AssetId-$($anim.name).gif"
    [OcadKeyedAnimation.ImageOps]::SaveAnimatedGif($framePaths, $playbackPath, $FrameDelayMs)
    $firstRect = $regions[$anim.frames[0]]
    $animationRecords.Add([PSCustomObject]@{
        name = $anim.name
        frames = $anim.frames
        frameCount = $anim.frames.Count
        loop = $anim.loop
        speed = $anim.speed
        frameSize = [PSCustomObject]@{
            w = $firstRect.w
            h = $firstRect.h
        }
        playback = Get-RelativePathText -BasePath $rootForRelative -Path $playbackPath
    }) | Out-Null
}

$manifest = [PSCustomObject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    tool = "tools/export-ocad-keyed-animation.ps1"
    assetId = $AssetId
    sourceSheet = Get-RelativePathText -BasePath $rootForRelative -Path $inputFull
    sourceSize = [PSCustomObject]@{
        w = $sourceInfo.Width
        h = $sourceInfo.Height
    }
    sourcePixelFormat = $sourceInfo.PixelFormat
    sourceKeyFile = "https://github.com/systemchester/Spritesheetweapon/blob/master/05-%E6%88%90%E5%93%81%E9%A1%B9%E7%9B%AE/AI%E5%83%8F%E7%B4%A0%E5%95%86K/ocad/ocad_spritesheet_generator.gd"
    settings = [PSCustomObject]@{
        keyColor = $KeyColor
        keyDistanceThreshold = $KeyDistanceThreshold
        frameDelayMs = $FrameDelayMs
    }
    outputs = [PSCustomObject]@{
        transparentSheet = Get-RelativePathText -BasePath $rootForRelative -Path $sheetPath
        framesDirectory = Get-RelativePathText -BasePath $rootForRelative -Path $framesRoot
        playbackDirectory = Get-RelativePathText -BasePath $rootForRelative -Path $playbackRoot
    }
    transparentSheetStats = [PSCustomObject]@{
        transparentPixels = $sheetStats.TransparentPixels
        opaquePixels = $sheetStats.OpaquePixels
        partialPixels = $sheetStats.PartialPixels
    }
    regions = $regions
    animations = $animationRecords.ToArray()
    frames = $frameRecords.ToArray()
    godotUsage = [PSCustomObject]@{
        generator = "SpriteFrames built from AtlasTexture regions"
        rightFacingHint = "The source project mirrors left-facing animations with AnimatedSprite2D.flip_h instead of duplicating right-facing atlas keys."
    }
}

$manifestPath = Join-Path $outputFull "metadata.json"
Write-JsonFile -Path $manifestPath -Value $manifest

Write-Host "Exported $($regions.Count) keyed frame(s)."
Write-Host "Generated $($animationRecords.Count) animation GIF(s)."
Write-Host "Transparent sheet: $(Get-RelativePathText -BasePath $rootForRelative -Path $sheetPath)"
Write-Host "Metadata: $(Get-RelativePathText -BasePath $rootForRelative -Path $manifestPath)"
