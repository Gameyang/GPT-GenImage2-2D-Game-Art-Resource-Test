param(
    [string]$InputRoot = "public/assets/characters/sideview-pixel/animation/frames",
    [string]$OutputRoot = "experiments/20260525-sprite-pivot-alignment",
    [ValidateSet("BottomCenter", "Center", "Centroid")]
    [string]$PivotMode = "BottomCenter",
    [int]$AlphaThreshold = 1,
    [int]$Margin = 12,
    [int]$Columns = 4,
    [int]$MaxPivotStepX = 10,
    [int]$MaxPivotStepY = 8,
    [double]$Smoothing = 0.35
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

if (-not ("SpritePivot.ImageOps" -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

namespace SpritePivot
{
    public sealed class FrameMetrics
    {
        public int Width;
        public int Height;
        public int BboxX;
        public int BboxY;
        public int BboxWidth;
        public int BboxHeight;
        public int PixelCount;
        public double CenterX;
        public double CenterY;
        public double CentroidX;
        public double CentroidY;
        public double LowerCenterX;
    }

    public static class ImageOps
    {
        public static FrameMetrics Measure(string path, int alphaThreshold)
        {
            using (Bitmap source = new Bitmap(path))
            using (Bitmap bitmap = ToArgb(source))
            {
                int width = bitmap.Width;
                int height = bitmap.Height;
                int left = width;
                int top = height;
                int right = -1;
                int bottom = -1;
                int count = 0;
                double sumX = 0;
                double sumY = 0;

                Rectangle rect = new Rectangle(0, 0, width, height);
                BitmapData data = bitmap.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
                try
                {
                    int byteCount = Math.Abs(data.Stride) * height;
                    byte[] pixels = new byte[byteCount];
                    Marshal.Copy(data.Scan0, pixels, 0, byteCount);

                    for (int y = 0; y < height; y++)
                    {
                        int rowOffset = y * data.Stride;
                        for (int x = 0; x < width; x++)
                        {
                            byte alpha = pixels[rowOffset + (x * 4) + 3];
                            if (alpha >= alphaThreshold)
                            {
                                if (x < left) left = x;
                                if (y < top) top = y;
                                if (x > right) right = x;
                                if (y > bottom) bottom = y;
                                count++;
                                sumX += x;
                                sumY += y;
                            }
                        }
                    }

                    FrameMetrics result = new FrameMetrics();
                    result.Width = width;
                    result.Height = height;
                    result.PixelCount = count;

                    if (count == 0)
                    {
                        result.BboxX = 0;
                        result.BboxY = 0;
                        result.BboxWidth = 0;
                        result.BboxHeight = 0;
                        result.CenterX = (width - 1) / 2.0;
                        result.CenterY = (height - 1) / 2.0;
                        result.CentroidX = result.CenterX;
                        result.CentroidY = result.CenterY;
                        result.LowerCenterX = result.CenterX;
                        return result;
                    }

                    int bboxWidth = right - left + 1;
                    int bboxHeight = bottom - top + 1;
                    result.BboxX = left;
                    result.BboxY = top;
                    result.BboxWidth = bboxWidth;
                    result.BboxHeight = bboxHeight;
                    result.CenterX = left + ((bboxWidth - 1) / 2.0);
                    result.CenterY = top + ((bboxHeight - 1) / 2.0);
                    result.CentroidX = sumX / count;
                    result.CentroidY = sumY / count;

                    int lowerStart = top + (int)Math.Floor(bboxHeight * 0.55);
                    int lowerCount = 0;
                    double lowerSumX = 0;

                    for (int y = lowerStart; y <= bottom; y++)
                    {
                        int rowOffset = y * data.Stride;
                        for (int x = left; x <= right; x++)
                        {
                            byte alpha = pixels[rowOffset + (x * 4) + 3];
                            if (alpha >= alphaThreshold)
                            {
                                lowerCount++;
                                lowerSumX += x;
                            }
                        }
                    }

                    result.LowerCenterX = lowerCount > 0 ? lowerSumX / lowerCount : result.CenterX;
                    return result;
                }
                finally
                {
                    bitmap.UnlockBits(data);
                }
            }
        }

        public static void DrawAligned(string sourcePath, string outputPath, int width, int height, int offsetX, int offsetY)
        {
            DirectoryEnsure(outputPath);
            using (Bitmap source = new Bitmap(sourcePath))
            using (Bitmap output = new Bitmap(width, height, PixelFormat.Format32bppArgb))
            using (Graphics graphics = Graphics.FromImage(output))
            {
                UsePixelArtSettings(graphics);
                graphics.Clear(Color.Transparent);
                graphics.DrawImageUnscaled(source, offsetX, offsetY);
                output.Save(outputPath, ImageFormat.Png);
            }
        }

        public static void ComposeSheet(string[] framePaths, string outputPath, int cellWidth, int cellHeight, int columns)
        {
            if (columns < 1) columns = 1;
            int rows = (int)Math.Ceiling(framePaths.Length / (double)columns);
            DirectoryEnsure(outputPath);

            using (Bitmap output = new Bitmap(cellWidth * columns, cellHeight * rows, PixelFormat.Format32bppArgb))
            using (Graphics graphics = Graphics.FromImage(output))
            {
                UsePixelArtSettings(graphics);
                graphics.Clear(Color.Transparent);

                for (int i = 0; i < framePaths.Length; i++)
                {
                    using (Bitmap frame = new Bitmap(framePaths[i]))
                    {
                        int x = (i % columns) * cellWidth;
                        int y = (i / columns) * cellHeight;
                        graphics.DrawImageUnscaled(frame, x, y);
                    }
                }

                output.Save(outputPath, ImageFormat.Png);
            }
        }

        private static Bitmap ToArgb(Bitmap source)
        {
            Bitmap bitmap = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb);
            using (Graphics graphics = Graphics.FromImage(bitmap))
            {
                UsePixelArtSettings(graphics);
                graphics.Clear(Color.Transparent);
                graphics.DrawImageUnscaled(source, 0, 0);
            }
            return bitmap;
        }

        private static void UsePixelArtSettings(Graphics graphics)
        {
            graphics.CompositingMode = CompositingMode.SourceOver;
            graphics.CompositingQuality = CompositingQuality.HighSpeed;
            graphics.InterpolationMode = InterpolationMode.NearestNeighbor;
            graphics.PixelOffsetMode = PixelOffsetMode.Half;
            graphics.SmoothingMode = SmoothingMode.None;
        }

        private static void DirectoryEnsure(string outputPath)
        {
            string directory = System.IO.Path.GetDirectoryName(outputPath);
            if (!String.IsNullOrEmpty(directory))
            {
                System.IO.Directory.CreateDirectory(directory);
            }
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

function Get-ActionName {
    param([string]$FileName)

    $stem = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    if ($stem -match "^(.+)-\d+$") {
        return $Matches[1]
    }

    return $stem
}

function Get-ActionSortIndex {
    param([string]$Action)

    switch ($Action) {
        "idle" { return 0 }
        "move" { return 1 }
        "walk" { return 1 }
        "run" { return 1 }
        "jump" { return 2 }
        "attack" { return 3 }
        default { return 100 }
    }
}

function Get-RawPivot {
    param(
        [Parameter(Mandatory = $true)]$Metrics,
        [Parameter(Mandatory = $true)][string]$Mode
    )

    switch ($Mode) {
        "Center" {
            return [PSCustomObject]@{
                x = [Math]::Round($Metrics.CenterX, 3)
                y = [Math]::Round($Metrics.CenterY, 3)
            }
        }
        "Centroid" {
            return [PSCustomObject]@{
                x = [Math]::Round($Metrics.CentroidX, 3)
                y = [Math]::Round($Metrics.CentroidY, 3)
            }
        }
        default {
            $bottom = if ($Metrics.BboxHeight -gt 0) {
                $Metrics.BboxY + $Metrics.BboxHeight - 1
            } else {
                $Metrics.Height - 1
            }

            return [PSCustomObject]@{
                x = [Math]::Round($Metrics.LowerCenterX, 3)
                y = [Math]::Round($bottom, 3)
            }
        }
    }
}

function Clamp-Delta {
    param(
        [double]$Delta,
        [double]$Limit
    )

    if ($Delta -gt $Limit) { return $Limit }
    if ($Delta -lt -$Limit) { return -$Limit }
    return $Delta
}

function Get-SmoothedPivots {
    param(
        [Parameter(Mandatory = $true)][array]$Frames
    )

    $previous = $null

    foreach ($frame in $Frames) {
        $raw = $frame.rawPivot

        if ($null -eq $previous) {
            $smoothed = [PSCustomObject]@{
                x = [Math]::Round($raw.x)
                y = [Math]::Round($raw.y)
            }
        } else {
            $boundedX = $previous.x + (Clamp-Delta -Delta ($raw.x - $previous.x) -Limit $MaxPivotStepX)
            $boundedY = $previous.y + (Clamp-Delta -Delta ($raw.y - $previous.y) -Limit $MaxPivotStepY)

            $smoothed = [PSCustomObject]@{
                x = [Math]::Round($previous.x + (($boundedX - $previous.x) * $Smoothing))
                y = [Math]::Round($previous.y + (($boundedY - $previous.y) * $Smoothing))
            }
        }

        $frame | Add-Member -NotePropertyName smoothedPivot -NotePropertyValue $smoothed
        $previous = $smoothed
    }
}

function Get-FrameGroups {
    param([Parameter(Mandatory = $true)][string]$Root)

    $directories = Get-ChildItem -LiteralPath $Root -Directory
    if ($directories.Count -gt 0) {
        return $directories
    }

    return @((Get-Item -LiteralPath $Root))
}

if ($Margin -lt 0) {
    throw "Margin must be 0 or greater."
}
if ($AlphaThreshold -lt 1 -or $AlphaThreshold -gt 255) {
    throw "AlphaThreshold must be between 1 and 255."
}
if ($Smoothing -lt 0 -or $Smoothing -gt 1) {
    throw "Smoothing must be between 0 and 1."
}

$inputFull = [System.IO.Path]::GetFullPath($InputRoot)
$outputFull = [System.IO.Path]::GetFullPath($OutputRoot)

if (-not (Test-Path -LiteralPath $inputFull)) {
    throw "InputRoot not found: $InputRoot"
}

New-Item -ItemType Directory -Force -Path $outputFull | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $outputFull "frames") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $outputFull "sheets") | Out-Null

$rootForRelative = (Get-Location).Path
$characters = New-Object System.Collections.Generic.List[object]

foreach ($characterDirectory in (Get-FrameGroups -Root $inputFull | Sort-Object Name)) {
    $pngFiles = Get-ChildItem -LiteralPath $characterDirectory.FullName -File -Filter "*.png" | Sort-Object Name
    if ($pngFiles.Count -eq 0) {
        continue
    }

    $characterId = $characterDirectory.Name
    $frames = New-Object System.Collections.Generic.List[object]

    foreach ($file in $pngFiles) {
        $metrics = [SpritePivot.ImageOps]::Measure($file.FullName, $AlphaThreshold)
        $action = Get-ActionName -FileName $file.Name
        $rawPivot = Get-RawPivot -Metrics $metrics -Mode $PivotMode

        $frames.Add([PSCustomObject]@{
            name = $file.Name
            action = $action
            actionSort = Get-ActionSortIndex -Action $action
            sourcePath = $file.FullName
            sourceSize = [PSCustomObject]@{
                w = $metrics.Width
                h = $metrics.Height
            }
            bbox = [PSCustomObject]@{
                x = $metrics.BboxX
                y = $metrics.BboxY
                w = $metrics.BboxWidth
                h = $metrics.BboxHeight
            }
            alphaPixels = $metrics.PixelCount
            rawPivot = $rawPivot
        }) | Out-Null
    }

    $orderedFrames = @($frames | Sort-Object actionSort, action, name)
    $actionGroups = $orderedFrames | Group-Object action
    foreach ($actionGroup in $actionGroups) {
        Get-SmoothedPivots -Frames @($actionGroup.Group | Sort-Object name)
    }

    $minLeft = 0.0
    $minTop = 0.0
    $maxRight = 0.0
    $maxBottom = 0.0

    foreach ($frame in $orderedFrames) {
        if ($frame.bbox.w -le 0 -or $frame.bbox.h -le 0) {
            continue
        }

        $left = $frame.bbox.x - $frame.smoothedPivot.x
        $top = $frame.bbox.y - $frame.smoothedPivot.y
        $right = ($frame.bbox.x + $frame.bbox.w) - $frame.smoothedPivot.x
        $bottom = ($frame.bbox.y + $frame.bbox.h) - $frame.smoothedPivot.y

        if ($left -lt $minLeft) { $minLeft = $left }
        if ($top -lt $minTop) { $minTop = $top }
        if ($right -gt $maxRight) { $maxRight = $right }
        if ($bottom -gt $maxBottom) { $maxBottom = $bottom }
    }

    $cellWidth = [int][Math]::Ceiling(($maxRight - $minLeft) + ($Margin * 2))
    $cellHeight = [int][Math]::Ceiling(($maxBottom - $minTop) + ($Margin * 2))
    if ($cellWidth -lt 1) { $cellWidth = 1 }
    if ($cellHeight -lt 1) { $cellHeight = 1 }

    $targetPivot = [PSCustomObject]@{
        x = [int][Math]::Round($Margin - $minLeft)
        y = [int][Math]::Round($Margin - $minTop)
    }

    $characterOutputDir = Join-Path (Join-Path $outputFull "frames") $characterId
    New-Item -ItemType Directory -Force -Path $characterOutputDir | Out-Null
    $sheetFramePaths = New-Object System.Collections.Generic.List[string]

    foreach ($frame in $orderedFrames) {
        $offsetX = [int]($targetPivot.x - $frame.smoothedPivot.x)
        $offsetY = [int]($targetPivot.y - $frame.smoothedPivot.y)
        $outputPath = Join-Path $characterOutputDir $frame.name

        [SpritePivot.ImageOps]::DrawAligned($frame.sourcePath, $outputPath, $cellWidth, $cellHeight, $offsetX, $offsetY)
        $sheetFramePaths.Add($outputPath) | Out-Null

        $spriteSourceSize = [PSCustomObject]@{
            x = $offsetX + $frame.bbox.x
            y = $offsetY + $frame.bbox.y
            w = $frame.bbox.w
            h = $frame.bbox.h
        }

        $frame | Add-Member -NotePropertyName sourcePathRelative -NotePropertyValue (Get-RelativePathText -BasePath $rootForRelative -Path $frame.sourcePath)
        $frame | Add-Member -NotePropertyName outputPath -NotePropertyValue $outputPath
        $frame | Add-Member -NotePropertyName outputPathRelative -NotePropertyValue (Get-RelativePathText -BasePath $rootForRelative -Path $outputPath)
        $frame | Add-Member -NotePropertyName drawOffset -NotePropertyValue ([PSCustomObject]@{ x = $offsetX; y = $offsetY })
        $frame | Add-Member -NotePropertyName spriteSourceSize -NotePropertyValue $spriteSourceSize
    }

    $sheetPath = Join-Path (Join-Path $outputFull "sheets") ($characterId + ".png")
    [SpritePivot.ImageOps]::ComposeSheet($sheetFramePaths.ToArray(), $sheetPath, $cellWidth, $cellHeight, $Columns)

    $animations = [ordered]@{}
    foreach ($actionGroup in ($orderedFrames | Group-Object action | Sort-Object { Get-ActionSortIndex -Action $_.Name }, Name)) {
        $animations[$actionGroup.Name] = @($actionGroup.Group | Sort-Object name | ForEach-Object { $_.name })
    }

    $metadataFrames = @($orderedFrames | ForEach-Object {
        [PSCustomObject]@{
            name = $_.name
            action = $_.action
            source = $_.sourcePathRelative
            output = $_.outputPathRelative
            sourceSize = $_.sourceSize
            bbox = $_.bbox
            rawPivot = $_.rawPivot
            smoothedPivot = $_.smoothedPivot
            targetPivot = $targetPivot
            drawOffset = $_.drawOffset
            spriteSourceSize = $_.spriteSourceSize
            alphaPixels = $_.alphaPixels
        }
    })

    $characters.Add([PSCustomObject]@{
        id = $characterId
        input = (Get-RelativePathText -BasePath $rootForRelative -Path $characterDirectory.FullName)
        outputFrames = (Get-RelativePathText -BasePath $rootForRelative -Path $characterOutputDir)
        outputSheet = (Get-RelativePathText -BasePath $rootForRelative -Path $sheetPath)
        frameCount = $orderedFrames.Count
        cellSize = [PSCustomObject]@{
            w = $cellWidth
            h = $cellHeight
        }
        targetPivot = $targetPivot
        animations = $animations
        frames = $metadataFrames
    }) | Out-Null
}

$manifest = [PSCustomObject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    tool = "tools/align-sprite-pivots.ps1"
    inputRoot = (Get-RelativePathText -BasePath $rootForRelative -Path $inputFull)
    outputRoot = (Get-RelativePathText -BasePath $rootForRelative -Path $outputFull)
    settings = [PSCustomObject]@{
        pivotMode = $PivotMode
        alphaThreshold = $AlphaThreshold
        margin = $Margin
        columns = $Columns
        maxPivotStepX = $MaxPivotStepX
        maxPivotStepY = $MaxPivotStepY
        smoothing = $Smoothing
    }
    characters = $characters.ToArray()
}

$metadataPath = Join-Path $outputFull "metadata.json"
$manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $metadataPath -Encoding UTF8

Write-Host "Aligned $($characters.Count) sprite frame set(s)."
Write-Host "Metadata: $(Get-RelativePathText -BasePath $rootForRelative -Path $metadataPath)"
