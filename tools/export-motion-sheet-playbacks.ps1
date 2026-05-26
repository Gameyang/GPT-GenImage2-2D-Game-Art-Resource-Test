param(
    [string]$InputDirectory = "public/assets/characters/20260525-sideview-8x4-motion-sheets",
    [string]$OutputRoot = "public/assets/characters/20260525-sideview-8x4-motion-sheets",
    [int]$Columns = 8,
    [int]$Rows = 4,
    [string[]]$Actions = @("idle", "run", "attack", "jump"),
    [int]$FrameDelayMs = 85,
    [bool]$AlignPivot = $true,
    [ValidateSet("BottomCenter", "Center", "Centroid")]
    [string]$PivotMode = "BottomCenter",
    [int]$BackgroundDistanceThreshold = 42,
    [string[]]$PreserveVerticalActions = @("idle", "run", "attack"),
    [string[]]$AllowVerticalMotionActions = @("jump"),
    [switch]$KeepFrames
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

if (-not ("MotionSheetExport.ImageOps" -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;

namespace MotionSheetExport
{
    public sealed class ImageInfo
    {
        public int Width;
        public int Height;
        public string PixelFormat;
    }

    public sealed class CellMetrics
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
        public double BottomY;
        public int BackgroundR;
        public int BackgroundG;
        public int BackgroundB;
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

        public static ImageInfo SliceCell(string sourcePath, string outputPath, int sourceX, int sourceY, int cellW, int cellH)
        {
            DirectoryEnsure(outputPath);

            using (Bitmap source = new Bitmap(sourcePath))
            using (Bitmap output = new Bitmap(cellW, cellH, PixelFormat.Format32bppArgb))
            using (Graphics graphics = Graphics.FromImage(output))
            {
                UseSpriteSettings(graphics);
                graphics.Clear(Color.Transparent);
                Rectangle sourceRect = new Rectangle(sourceX, sourceY, cellW, cellH);
                Rectangle targetRect = new Rectangle(0, 0, cellW, cellH);
                graphics.DrawImage(source, targetRect, sourceRect, GraphicsUnit.Pixel);
                output.Save(outputPath, ImageFormat.Png);
            }

            return GetInfo(outputPath);
        }

        public static CellMetrics AnalyzeCell(string sourcePath, int sourceX, int sourceY, int cellW, int cellH, int backgroundDistanceThreshold)
        {
            using (Bitmap source = new Bitmap(sourcePath))
            {
                Color background = EstimateBackground(source, sourceX, sourceY, cellW, cellH);
                int left = cellW;
                int top = cellH;
                int right = -1;
                int bottom = -1;
                int count = 0;
                double sumX = 0;
                double sumY = 0;

                for (int y = 0; y < cellH; y++)
                {
                    for (int x = 0; x < cellW; x++)
                    {
                        Color pixel = source.GetPixel(sourceX + x, sourceY + y);
                        if (ColorDistance(pixel, background) > backgroundDistanceThreshold)
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

                CellMetrics result = new CellMetrics();
                result.Width = cellW;
                result.Height = cellH;
                result.PixelCount = count;
                result.BackgroundR = background.R;
                result.BackgroundG = background.G;
                result.BackgroundB = background.B;

                if (count == 0)
                {
                    result.BboxX = 0;
                    result.BboxY = 0;
                    result.BboxWidth = 0;
                    result.BboxHeight = 0;
                    result.CenterX = (cellW - 1) / 2.0;
                    result.CenterY = (cellH - 1) / 2.0;
                    result.CentroidX = result.CenterX;
                    result.CentroidY = result.CenterY;
                    result.LowerCenterX = result.CenterX;
                    result.BottomY = cellH - 1;
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
                result.BottomY = bottom;

                int lowerStart = top + (int)Math.Floor(bboxHeight * 0.55);
                int lowerCount = 0;
                double lowerSumX = 0;

                for (int y = lowerStart; y <= bottom; y++)
                {
                    for (int x = left; x <= right; x++)
                    {
                        Color pixel = source.GetPixel(sourceX + x, sourceY + y);
                        if (ColorDistance(pixel, background) > backgroundDistanceThreshold)
                        {
                            lowerCount++;
                            lowerSumX += x;
                        }
                    }
                }

                result.LowerCenterX = lowerCount > 0 ? lowerSumX / lowerCount : result.CenterX;
                return result;
            }
        }

        public static ImageInfo DrawAlignedCell(string sourcePath, string outputPath, int sourceX, int sourceY, int cellW, int cellH, int offsetX, int offsetY)
        {
            DirectoryEnsure(outputPath);

            using (Bitmap source = new Bitmap(sourcePath))
            using (Bitmap output = new Bitmap(cellW, cellH, PixelFormat.Format32bppArgb))
            using (Graphics graphics = Graphics.FromImage(output))
            {
                UseSpriteSettings(graphics);
                Color background = EstimateBackground(source, sourceX, sourceY, cellW, cellH);
                graphics.Clear(background);
                Rectangle sourceRect = new Rectangle(sourceX, sourceY, cellW, cellH);
                Rectangle targetRect = new Rectangle(offsetX, offsetY, cellW, cellH);
                graphics.DrawImage(source, targetRect, sourceRect, GraphicsUnit.Pixel);
                output.Save(outputPath, ImageFormat.Png);
            }

            return GetInfo(outputPath);
        }

        private static Color EstimateBackground(Bitmap source, int sourceX, int sourceY, int cellW, int cellH)
        {
            int patch = Math.Max(2, Math.Min(8, Math.Min(cellW, cellH) / 8));
            long r = 0;
            long g = 0;
            long b = 0;
            int count = 0;

            AccumulatePatch(source, sourceX + 1, sourceY + 1, patch, patch, ref r, ref g, ref b, ref count);
            AccumulatePatch(source, sourceX + cellW - patch - 1, sourceY + 1, patch, patch, ref r, ref g, ref b, ref count);
            AccumulatePatch(source, sourceX + 1, sourceY + cellH - patch - 1, patch, patch, ref r, ref g, ref b, ref count);
            AccumulatePatch(source, sourceX + cellW - patch - 1, sourceY + cellH - patch - 1, patch, patch, ref r, ref g, ref b, ref count);

            if (count == 0)
            {
                return Color.White;
            }

            return Color.FromArgb(255, (int)(r / count), (int)(g / count), (int)(b / count));
        }

        private static void AccumulatePatch(Bitmap source, int startX, int startY, int width, int height, ref long r, ref long g, ref long b, ref int count)
        {
            int x0 = Math.Max(0, Math.Min(source.Width - 1, startX));
            int y0 = Math.Max(0, Math.Min(source.Height - 1, startY));
            int x1 = Math.Max(0, Math.Min(source.Width, x0 + width));
            int y1 = Math.Max(0, Math.Min(source.Height, y0 + height));

            for (int y = y0; y < y1; y++)
            {
                for (int x = x0; x < x1; x++)
                {
                    Color pixel = source.GetPixel(x, y);
                    r += pixel.R;
                    g += pixel.G;
                    b += pixel.B;
                    count++;
                }
            }
        }

        private static double ColorDistance(Color pixel, Color background)
        {
            double dr = pixel.R - background.R;
            double dg = pixel.G - background.G;
            double db = pixel.B - background.B;
            return Math.Sqrt((dr * dr) + (dg * dg) + (db * db));
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

function New-PropertyItem {
    param(
        [Parameter(Mandatory = $true)][int]$Id,
        [Parameter(Mandatory = $true)][Int16]$Type,
        [Parameter(Mandatory = $true)][byte[]]$Value
    )

    $propertyItem = [System.Runtime.Serialization.FormatterServices]::GetUninitializedObject([System.Drawing.Imaging.PropertyItem])
    $propertyItem.Id = $Id
    $propertyItem.Type = $Type
    $propertyItem.Len = $Value.Length
    $propertyItem.Value = $Value
    return $propertyItem
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

function Get-MedianNumber {
    param([Parameter(Mandatory = $true)][double[]]$Values)

    if ($Values.Count -eq 0) {
        return 0
    }

    $sorted = @($Values | Sort-Object)
    $middle = [int][Math]::Floor($sorted.Count / 2)
    if (($sorted.Count % 2) -eq 1) {
        return [double]$sorted[$middle]
    }

    return ([double]$sorted[$middle - 1] + [double]$sorted[$middle]) / 2.0
}

function Test-ActionListed {
    param(
        [Parameter(Mandatory = $true)][string]$Action,
        [AllowEmptyCollection()][string[]]$List = @()
    )

    if ($null -eq $List -or $List.Count -eq 0) {
        return $false
    }

    foreach ($item in $List) {
        if ($Action.Equals($item, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
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
            return [PSCustomObject]@{
                x = [Math]::Round($Metrics.LowerCenterX, 3)
                y = [Math]::Round($Metrics.BottomY, 3)
            }
        }
    }
}

function Get-MedianFilteredValues {
    param([Parameter(Mandatory = $true)][double[]]$Values)

    $filtered = New-Object System.Collections.Generic.List[double]
    for ($index = 0; $index -lt $Values.Count; $index++) {
        $window = New-Object System.Collections.Generic.List[double]
        if ($index -gt 0) {
            $window.Add($Values[$index - 1]) | Out-Null
        }
        $window.Add($Values[$index]) | Out-Null
        if ($index -lt ($Values.Count - 1)) {
            $window.Add($Values[$index + 1]) | Out-Null
        }

        $filtered.Add((Get-MedianNumber -Values $window.ToArray())) | Out-Null
    }

    return $filtered.ToArray()
}

function Set-FrameAlignment {
    param(
        [Parameter(Mandatory = $true)][array]$Frames,
        [Parameter(Mandatory = $true)][bool]$Enabled
    )

    foreach ($actionGroup in ($Frames | Group-Object action)) {
        $actionFrames = @($actionGroup.Group | Sort-Object row, column)
        $targetX = Get-MedianNumber -Values ([double[]]@($actionFrames | ForEach-Object { [double]$_.rawPivot.x }))

        if (-not $Enabled) {
            foreach ($frame in $actionFrames) {
                $correctedPivot = [PSCustomObject]@{
                    x = [Math]::Round($frame.rawPivot.x, 3)
                    y = [Math]::Round($frame.rawPivot.y, 3)
                }
                $frame | Add-Member -NotePropertyName correctedPivot -NotePropertyValue $correctedPivot
                $frame | Add-Member -NotePropertyName drawOffset -NotePropertyValue ([PSCustomObject]@{ x = 0; y = 0 })
            }
            continue
        }

        if (Test-ActionListed -Action $actionGroup.Name -List $PreserveVerticalActions) {
            $targetY = ($actionFrames | ForEach-Object { [double]$_.rawPivot.y } | Measure-Object -Maximum).Maximum
            foreach ($frame in $actionFrames) {
                $correctedPivot = [PSCustomObject]@{
                    x = [Math]::Round($targetX, 3)
                    y = [Math]::Round($targetY, 3)
                }
                $frame | Add-Member -NotePropertyName correctedPivot -NotePropertyValue $correctedPivot
                $frame | Add-Member -NotePropertyName drawOffset -NotePropertyValue ([PSCustomObject]@{
                    x = [int][Math]::Round($correctedPivot.x - $frame.rawPivot.x)
                    y = [int][Math]::Round($correctedPivot.y - $frame.rawPivot.y)
                })
            }
            continue
        }

        if (Test-ActionListed -Action $actionGroup.Name -List $AllowVerticalMotionActions) {
            $filteredY = Get-MedianFilteredValues -Values ([double[]]@($actionFrames | ForEach-Object { [double]$_.rawPivot.y }))
            for ($index = 0; $index -lt $actionFrames.Count; $index++) {
                $frame = $actionFrames[$index]
                $correctedPivot = [PSCustomObject]@{
                    x = [Math]::Round($targetX, 3)
                    y = [Math]::Round($filteredY[$index], 3)
                }
                $frame | Add-Member -NotePropertyName correctedPivot -NotePropertyValue $correctedPivot
                $frame | Add-Member -NotePropertyName drawOffset -NotePropertyValue ([PSCustomObject]@{
                    x = [int][Math]::Round($correctedPivot.x - $frame.rawPivot.x)
                    y = [int][Math]::Round($correctedPivot.y - $frame.rawPivot.y)
                })
            }
            continue
        }

        $fallbackY = Get-MedianNumber -Values ([double[]]@($actionFrames | ForEach-Object { [double]$_.rawPivot.y }))
        foreach ($frame in $actionFrames) {
            $correctedPivot = [PSCustomObject]@{
                x = [Math]::Round($targetX, 3)
                y = [Math]::Round($fallbackY, 3)
            }
            $frame | Add-Member -NotePropertyName correctedPivot -NotePropertyValue $correctedPivot
            $frame | Add-Member -NotePropertyName drawOffset -NotePropertyValue ([PSCustomObject]@{
                x = [int][Math]::Round($correctedPivot.x - $frame.rawPivot.x)
                y = [int][Math]::Round($correctedPivot.y - $frame.rawPivot.y)
            })
        }
    }
}

function Get-PlaybackFileName {
    param([Parameter(Mandatory = $true)][string]$CharacterId)

    if ($CharacterId -match "^sheet-(.+)$") {
        return "playback-$($Matches[1]).gif"
    }

    return "playback-$CharacterId.gif"
}

function Save-AnimatedGif {
    param(
        [Parameter(Mandatory = $true)][string[]]$FramePaths,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][int]$DelayMs
    )

    if ($FramePaths.Count -eq 0) {
        throw "Cannot create GIF without frames: $OutputPath"
    }

    $gifEncoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
        Where-Object { $_.MimeType -eq "image/gif" } |
        Select-Object -First 1

    if ($null -eq $gifEncoder) {
        throw "GIF encoder is not available in this environment."
    }

    $delayHundredths = [Math]::Max(1, [int][Math]::Round($DelayMs / 10.0))
    $delayBytes = New-Object byte[] ($FramePaths.Count * 4)
    for ($i = 0; $i -lt $FramePaths.Count; $i++) {
        [BitConverter]::GetBytes($delayHundredths).CopyTo($delayBytes, $i * 4)
    }

    $loopBytes = [byte[]](0, 0)
    $directory = [System.IO.Path]::GetDirectoryName($OutputPath)
    if (-not [String]::IsNullOrEmpty($directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }

    if (Test-Path -LiteralPath $OutputPath) {
        Remove-Item -LiteralPath $OutputPath
    }

    $firstFrame = [System.Drawing.Bitmap]::new($FramePaths[0])
    try {
        $firstFrame.SetPropertyItem((New-PropertyItem -Id 0x5100 -Type 4 -Value $delayBytes))
        $firstFrame.SetPropertyItem((New-PropertyItem -Id 0x5101 -Type 3 -Value $loopBytes))

        $encoderParameters = [System.Drawing.Imaging.EncoderParameters]::new(1)
        $encoderParameters.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new(
            [System.Drawing.Imaging.Encoder]::SaveFlag,
            [int][System.Drawing.Imaging.EncoderValue]::MultiFrame
        )
        $firstFrame.Save($OutputPath, $gifEncoder, $encoderParameters)

        $encoderParameters.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new(
            [System.Drawing.Imaging.Encoder]::SaveFlag,
            [int][System.Drawing.Imaging.EncoderValue]::FrameDimensionTime
        )
        for ($i = 1; $i -lt $FramePaths.Count; $i++) {
            $frame = [System.Drawing.Bitmap]::new($FramePaths[$i])
            try {
                if ($frame.Width -ne $firstFrame.Width -or $frame.Height -ne $firstFrame.Height) {
                    throw "Frame size mismatch in $OutputPath`: $($FramePaths[$i]) is $($frame.Width)x$($frame.Height), expected $($firstFrame.Width)x$($firstFrame.Height)."
                }

                $firstFrame.SaveAdd($frame, $encoderParameters)
            }
            finally {
                $frame.Dispose()
            }
        }

        $encoderParameters.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new(
            [System.Drawing.Imaging.Encoder]::SaveFlag,
            [int][System.Drawing.Imaging.EncoderValue]::Flush
        )
        $firstFrame.SaveAdd($encoderParameters)
    }
    finally {
        $firstFrame.Dispose()
    }
}

if ($Columns -lt 1 -or $Rows -lt 1) {
    throw "Columns and Rows must be positive."
}

if ($Actions.Count -ne $Rows) {
    throw "Actions count must match Rows."
}

if ($FrameDelayMs -lt 10) {
    throw "FrameDelayMs must be 10 or greater."
}
if ($BackgroundDistanceThreshold -lt 1 -or $BackgroundDistanceThreshold -gt 442) {
    throw "BackgroundDistanceThreshold must be between 1 and 442."
}

$inputFull = [System.IO.Path]::GetFullPath($InputDirectory)
$outputFull = [System.IO.Path]::GetFullPath($OutputRoot)
$rootForRelative = (Get-Location).Path

if (-not (Test-Path -LiteralPath $inputFull)) {
    throw "InputDirectory not found: $InputDirectory"
}

New-Item -ItemType Directory -Force -Path $outputFull | Out-Null
$framesOutputRoot = Join-Path $outputFull "frames"
New-Item -ItemType Directory -Force -Path $framesOutputRoot | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $outputFull "playback") | Out-Null

$characters = New-Object System.Collections.Generic.List[object]
$skipped = New-Object System.Collections.Generic.List[object]
$sheets = @(Get-ChildItem -LiteralPath $inputFull -File -Filter "*.png" | Sort-Object Name)

foreach ($sheet in $sheets) {
    $sourceInfo = [MotionSheetExport.ImageOps]::GetInfo($sheet.FullName)

    if (($sourceInfo.Width % $Columns) -ne 0 -or ($sourceInfo.Height % $Rows) -ne 0) {
        $skipped.Add([PSCustomObject]@{
            sourceSheet = (Get-RelativePathText -BasePath $rootForRelative -Path $sheet.FullName)
            sourceSize = [PSCustomObject]@{
                w = $sourceInfo.Width
                h = $sourceInfo.Height
            }
            reason = "Source dimensions do not divide cleanly into ${Columns}x${Rows}."
        }) | Out-Null
        continue
    }

    $characterId = [System.IO.Path]::GetFileNameWithoutExtension($sheet.Name)
    $cellWidth = [int]($sourceInfo.Width / $Columns)
    $cellHeight = [int]($sourceInfo.Height / $Rows)
    $framesRoot = Join-Path $framesOutputRoot $characterId
    New-Item -ItemType Directory -Force -Path $framesRoot | Out-Null

    $frameDescriptors = New-Object System.Collections.Generic.List[object]
    $animations = [ordered]@{}

    for ($row = 0; $row -lt $Rows; $row++) {
        $action = $Actions[$row]
        $animations[$action] = @()

        for ($column = 0; $column -lt $Columns; $column++) {
            $frameName = "{0}-{1:00}.png" -f $action, ($column + 1)
            $sourceX = $column * $cellWidth
            $sourceY = $row * $cellHeight
            $outputPath = Join-Path $framesRoot $frameName
            $metrics = [MotionSheetExport.ImageOps]::AnalyzeCell($sheet.FullName, $sourceX, $sourceY, $cellWidth, $cellHeight, $BackgroundDistanceThreshold)
            $rawPivot = Get-RawPivot -Metrics $metrics -Mode $PivotMode

            $animations[$action] += $frameName

            $frameDescriptors.Add([PSCustomObject]@{
                name = $frameName
                action = $action
                row = $row
                column = $column
                outputPath = $outputPath
                sourceRect = [PSCustomObject]@{
                    x = $sourceX
                    y = $sourceY
                    w = $cellWidth
                    h = $cellHeight
                }
                cellSize = [PSCustomObject]@{
                    w = $cellWidth
                    h = $cellHeight
                }
                backgroundColor = [PSCustomObject]@{
                    r = $metrics.BackgroundR
                    g = $metrics.BackgroundG
                    b = $metrics.BackgroundB
                }
                bbox = [PSCustomObject]@{
                    x = $metrics.BboxX
                    y = $metrics.BboxY
                    w = $metrics.BboxWidth
                    h = $metrics.BboxHeight
                }
                foregroundPixels = $metrics.PixelCount
                rawPivot = $rawPivot
            }) | Out-Null
        }
    }

    Set-FrameAlignment -Frames $frameDescriptors.ToArray() -Enabled $AlignPivot

    $framePaths = New-Object System.Collections.Generic.List[string]
    $frameMetadata = New-Object System.Collections.Generic.List[object]

    foreach ($frame in $frameDescriptors) {
        if ($AlignPivot) {
            [MotionSheetExport.ImageOps]::DrawAlignedCell(
                $sheet.FullName,
                $frame.outputPath,
                $frame.sourceRect.x,
                $frame.sourceRect.y,
                $cellWidth,
                $cellHeight,
                $frame.drawOffset.x,
                $frame.drawOffset.y
            ) | Out-Null
        } else {
            [MotionSheetExport.ImageOps]::SliceCell($sheet.FullName, $frame.outputPath, $frame.sourceRect.x, $frame.sourceRect.y, $cellWidth, $cellHeight) | Out-Null
        }

        $framePaths.Add($frame.outputPath) | Out-Null

        $frameMetadata.Add([PSCustomObject]@{
            name = $frame.name
            action = $frame.action
            row = $frame.row
            column = $frame.column
            sourceRect = $frame.sourceRect
            output = if ($KeepFrames.IsPresent) {
                Get-RelativePathText -BasePath $rootForRelative -Path $frame.outputPath
            } else {
                $null
            }
            cellSize = $frame.cellSize
            backgroundColor = $frame.backgroundColor
            bbox = $frame.bbox
            foregroundPixels = $frame.foregroundPixels
            rawPivot = $frame.rawPivot
            correctedPivot = $frame.correctedPivot
            drawOffset = $frame.drawOffset
        }) | Out-Null
    }

    $playbackPath = Join-Path (Join-Path $outputFull "playback") (Get-PlaybackFileName -CharacterId $characterId)
    Save-AnimatedGif -FramePaths $framePaths.ToArray() -OutputPath $playbackPath -DelayMs $FrameDelayMs

    $characters.Add([PSCustomObject]@{
        id = $characterId
        sourceSheet = (Get-RelativePathText -BasePath $rootForRelative -Path $sheet.FullName)
        sourceSize = [PSCustomObject]@{
            w = $sourceInfo.Width
            h = $sourceInfo.Height
        }
        sourcePixelFormat = $sourceInfo.PixelFormat
        framesRetained = $KeepFrames.IsPresent
        outputFrames = if ($KeepFrames.IsPresent) {
            Get-RelativePathText -BasePath $rootForRelative -Path $framesRoot
        } else {
            $null
        }
        playback = (Get-RelativePathText -BasePath $rootForRelative -Path $playbackPath)
        frameCount = $frameMetadata.Count
        cellSize = [PSCustomObject]@{
            w = $cellWidth
            h = $cellHeight
        }
        animations = $animations
        frames = $frameMetadata.ToArray()
    }) | Out-Null
}

if (-not $KeepFrames.IsPresent) {
    $framesOutputFull = [System.IO.Path]::GetFullPath($framesOutputRoot)
    $outputFullWithSeparator = $outputFull
    if (-not $outputFullWithSeparator.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $outputFullWithSeparator += [System.IO.Path]::DirectorySeparatorChar
    }

    if (-not $framesOutputFull.StartsWith($outputFullWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to delete temporary frames outside OutputRoot: $framesOutputFull"
    }

    if (Test-Path -LiteralPath $framesOutputFull) {
        Remove-Item -LiteralPath $framesOutputFull -Recurse -Force
    }
}

$metadata = [PSCustomObject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    tool = "tools/export-motion-sheet-playbacks.ps1"
    inputDirectory = (Get-RelativePathText -BasePath $rootForRelative -Path $inputFull)
    outputRoot = (Get-RelativePathText -BasePath $rootForRelative -Path $outputFull)
    settings = [PSCustomObject]@{
        columns = $Columns
        rows = $Rows
        actions = $Actions
        frameDelayMs = $FrameDelayMs
        keepFrames = $KeepFrames.IsPresent
        alignment = [PSCustomObject]@{
            enabled = $AlignPivot
            pivotMode = $PivotMode
            backgroundDistanceThreshold = $BackgroundDistanceThreshold
            preserveVerticalActions = $PreserveVerticalActions
            allowVerticalMotionActions = $AllowVerticalMotionActions
        }
    }
    characters = $characters.ToArray()
    skipped = $skipped.ToArray()
}

$metadataPath = Join-Path $outputFull "metadata.json"
Write-JsonFile -Path $metadataPath -Value $metadata

Write-Host "Processed $($characters.Count) motion sheet(s)."
Write-Host "Skipped $($skipped.Count) motion sheet(s)."
Write-Host "Metadata: $(Get-RelativePathText -BasePath $rootForRelative -Path $metadataPath)"
