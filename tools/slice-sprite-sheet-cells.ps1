param(
    [string]$SourceSheet = "public/assets/characters/sideview-pixel/animation/animation-sheet-01-adventurer-swordsman.png",
    [string]$OutputRoot = "experiments/20260525-grid-cell-pivot-test",
    [string]$CharacterId = "animation-sheet-01-adventurer-swordsman",
    [int]$Columns = 4,
    [int]$Rows = 4,
    [string[]]$Actions = @("idle", "move", "jump", "attack")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

if (-not ("SpriteCellSlice.ImageOps" -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;

namespace SpriteCellSlice
{
    public sealed class ImageInfo
    {
        public int Width;
        public int Height;
        public string PixelFormat;
    }

    public static class ImageOps
    {
        public static ImageInfo SliceCell(string sourcePath, string outputPath, int sourceX, int sourceY, int sourceW, int sourceH, int cellW, int cellH)
        {
            DirectoryEnsure(outputPath);

            using (Bitmap source = new Bitmap(sourcePath))
            using (Bitmap output = new Bitmap(cellW, cellH, PixelFormat.Format32bppArgb))
            using (Graphics graphics = Graphics.FromImage(output))
            {
                UsePixelArtSettings(graphics);
                graphics.Clear(Color.Transparent);
                Rectangle sourceRect = new Rectangle(sourceX, sourceY, sourceW, sourceH);
                Rectangle targetRect = new Rectangle(0, 0, sourceW, sourceH);
                graphics.DrawImage(source, targetRect, sourceRect, GraphicsUnit.Pixel);
                output.Save(outputPath, ImageFormat.Png);
            }

            return GetInfo(outputPath);
        }

        public static void ComposeSheet(string[] framePaths, string outputPath, int cellW, int cellH, int columns)
        {
            int rows = (int)Math.Ceiling(framePaths.Length / (double)columns);
            DirectoryEnsure(outputPath);

            using (Bitmap output = new Bitmap(cellW * columns, cellH * rows, PixelFormat.Format32bppArgb))
            using (Graphics graphics = Graphics.FromImage(output))
            {
                UsePixelArtSettings(graphics);
                graphics.Clear(Color.Transparent);

                for (int i = 0; i < framePaths.Length; i++)
                {
                    using (Bitmap frame = new Bitmap(framePaths[i]))
                    {
                        int x = (i % columns) * cellW;
                        int y = (i / columns) * cellH;
                        graphics.DrawImageUnscaled(frame, x, y);
                    }
                }

                output.Save(outputPath, ImageFormat.Png);
            }
        }

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

    $json = $Value | ConvertTo-Json -Depth 20
    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $encoding)
}

if ($Columns -lt 1 -or $Rows -lt 1) {
    throw "Columns and Rows must be positive."
}

if ($Actions.Count -ne $Rows) {
    throw "Actions count must match Rows."
}

$sourceFull = [System.IO.Path]::GetFullPath($SourceSheet)
$outputFull = [System.IO.Path]::GetFullPath($OutputRoot)
$rootForRelative = (Get-Location).Path

if (-not (Test-Path -LiteralPath $sourceFull)) {
    throw "SourceSheet not found: $SourceSheet"
}

$sourceInfo = [SpriteCellSlice.ImageOps]::GetInfo($sourceFull)
$cellWidth = [int][Math]::Ceiling($sourceInfo.Width / [double]$Columns)
$cellHeight = [int][Math]::Ceiling($sourceInfo.Height / [double]$Rows)

$framesRoot = Join-Path (Join-Path $outputFull "frames") $CharacterId
$sheetsRoot = Join-Path $outputFull "sheets"
New-Item -ItemType Directory -Force -Path $framesRoot | Out-Null
New-Item -ItemType Directory -Force -Path $sheetsRoot | Out-Null

$framePaths = New-Object System.Collections.Generic.List[string]
$frameMetadata = New-Object System.Collections.Generic.List[object]
$animations = [ordered]@{}

for ($row = 0; $row -lt $Rows; $row++) {
    $action = $Actions[$row]
    $animations[$action] = @()

    for ($column = 0; $column -lt $Columns; $column++) {
        $frameName = "{0}-{1:00}.png" -f $action, ($column + 1)
        $sourceX = $column * $cellWidth
        $sourceY = $row * $cellHeight
        $sourceW = [Math]::Max(0, [Math]::Min($cellWidth, $sourceInfo.Width - $sourceX))
        $sourceH = [Math]::Max(0, [Math]::Min($cellHeight, $sourceInfo.Height - $sourceY))
        $outputPath = Join-Path $framesRoot $frameName

        [SpriteCellSlice.ImageOps]::SliceCell($sourceFull, $outputPath, $sourceX, $sourceY, $sourceW, $sourceH, $cellWidth, $cellHeight) | Out-Null
        $framePaths.Add($outputPath) | Out-Null
        $animations[$action] += $frameName

        $frameMetadata.Add([PSCustomObject]@{
            name = $frameName
            action = $action
            row = $row
            column = $column
            sourceRect = [PSCustomObject]@{
                x = $sourceX
                y = $sourceY
                w = $sourceW
                h = $sourceH
            }
            output = (Get-RelativePathText -BasePath $rootForRelative -Path $outputPath)
            cellSize = [PSCustomObject]@{
                w = $cellWidth
                h = $cellHeight
            }
            pivot = [PSCustomObject]@{
                x = [int][Math]::Floor($cellWidth / 2)
                y = $cellHeight - 1
            }
        }) | Out-Null
    }
}

$sheetPath = Join-Path $sheetsRoot ($CharacterId + ".png")
[SpriteCellSlice.ImageOps]::ComposeSheet($framePaths.ToArray(), $sheetPath, $cellWidth, $cellHeight, $Columns)

$metadata = [PSCustomObject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    tool = "tools/slice-sprite-sheet-cells.ps1"
    sourceSheet = (Get-RelativePathText -BasePath $rootForRelative -Path $sourceFull)
    outputRoot = (Get-RelativePathText -BasePath $rootForRelative -Path $outputFull)
    settings = [PSCustomObject]@{
        columns = $Columns
        rows = $Rows
        cellSize = [PSCustomObject]@{
            w = $cellWidth
            h = $cellHeight
        }
        actions = $Actions
    }
    characters = @(
        [PSCustomObject]@{
            id = $CharacterId
            input = (Get-RelativePathText -BasePath $rootForRelative -Path $sourceFull)
            outputFrames = (Get-RelativePathText -BasePath $rootForRelative -Path $framesRoot)
            outputSheet = (Get-RelativePathText -BasePath $rootForRelative -Path $sheetPath)
            frameCount = $frameMetadata.Count
            cellSize = [PSCustomObject]@{
                w = $cellWidth
                h = $cellHeight
            }
            targetPivot = [PSCustomObject]@{
                x = [int][Math]::Floor($cellWidth / 2)
                y = $cellHeight - 1
            }
            animations = $animations
            frames = $frameMetadata.ToArray()
        }
    )
}

$metadataPath = Join-Path $outputFull "metadata.json"
Write-JsonFile -Path $metadataPath -Value $metadata

Write-Host "Sliced $($frameMetadata.Count) fixed-cell frame(s)."
Write-Host "Cell: ${cellWidth}x${cellHeight}"
Write-Host "Metadata: $(Get-RelativePathText -BasePath $rootForRelative -Path $metadataPath)"
