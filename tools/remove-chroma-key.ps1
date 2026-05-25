param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [string]$KeyColor = "#00FF00",
    [int]$TransparentThreshold = 24,
    [int]$OpaqueThreshold = 120,
    [int]$DominantKeyThreshold = 18,
    [int]$DominantKeyOpaqueThreshold = 72,
    [switch]$Despill
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

if (-not ("SpriteChroma.ImageOps" -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

namespace SpriteChroma
{
    public sealed class ChromaResult
    {
        public int Width;
        public int Height;
        public int TransparentPixels;
        public int PartialPixels;
        public int OpaquePixels;
    }

    public static class ImageOps
    {
        public static ChromaResult Remove(string inputPath, string outputPath, Color key, int transparentThreshold, int opaqueThreshold, int dominantKeyThreshold, int dominantKeyOpaqueThreshold, bool despill)
        {
            DirectoryEnsure(outputPath);

            using (Bitmap source = new Bitmap(inputPath))
            using (Bitmap bitmap = ToArgb(source))
            {
                int width = bitmap.Width;
                int height = bitmap.Height;
                Rectangle rect = new Rectangle(0, 0, width, height);
                BitmapData data = bitmap.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);

                ChromaResult result = new ChromaResult();
                result.Width = width;
                result.Height = height;

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
                            int index = rowOffset + (x * 4);
                            int b = pixels[index + 0];
                            int g = pixels[index + 1];
                            int r = pixels[index + 2];
                            int a = pixels[index + 3];

                            double dr = r - key.R;
                            double dg = g - key.G;
                            double db = b - key.B;
                            double distance = Math.Sqrt((dr * dr) + (dg * dg) + (db * db));

                            int newAlpha;
                            if (distance <= transparentThreshold)
                            {
                                newAlpha = 0;
                            }
                            else if (distance >= opaqueThreshold)
                            {
                                newAlpha = a;
                            }
                            else
                            {
                                double t = (distance - transparentThreshold) / Math.Max(1.0, opaqueThreshold - transparentThreshold);
                                newAlpha = ClampToByte((int)Math.Round(a * t));
                            }

                            int keyDominance = GetDominantKeyDelta(r, g, b, key);
                            if (keyDominance >= dominantKeyThreshold)
                            {
                                double keyT = (keyDominance - dominantKeyThreshold) / Math.Max(1.0, dominantKeyOpaqueThreshold - dominantKeyThreshold);
                                keyT = Math.Max(0.0, Math.Min(1.0, keyT));
                                int dominanceAlpha = ClampToByte((int)Math.Round(a * (1.0 - keyT)));
                                if (dominanceAlpha < newAlpha)
                                {
                                    newAlpha = dominanceAlpha;
                                }
                            }

                            if (newAlpha == 0)
                            {
                                pixels[index + 0] = 0;
                                pixels[index + 1] = 0;
                                pixels[index + 2] = 0;
                                pixels[index + 3] = 0;
                                result.TransparentPixels++;
                            }
                            else
                            {
                                if (despill && newAlpha < 255)
                                {
                                    int maxRedBlue = Math.Max(r, b);
                                    int greenCap = Math.Min(g, maxRedBlue + 20);
                                    pixels[index + 1] = (byte)ClampToByte(greenCap);
                                }

                                pixels[index + 3] = (byte)newAlpha;
                                if (newAlpha < 255)
                                {
                                    result.PartialPixels++;
                                }
                                else
                                {
                                    result.OpaquePixels++;
                                }
                            }
                        }
                    }

                    Marshal.Copy(pixels, 0, data.Scan0, byteCount);
                }
                finally
                {
                    bitmap.UnlockBits(data);
                }

                bitmap.Save(outputPath, ImageFormat.Png);
                return result;
            }
        }

        private static Bitmap ToArgb(Bitmap source)
        {
            Bitmap bitmap = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb);
            using (Graphics graphics = Graphics.FromImage(bitmap))
            {
                graphics.Clear(Color.Transparent);
                graphics.DrawImageUnscaled(source, 0, 0);
            }
            return bitmap;
        }

        private static int ClampToByte(int value)
        {
            if (value < 0) return 0;
            if (value > 255) return 255;
            return value;
        }

        private static int GetDominantKeyDelta(int r, int g, int b, Color key)
        {
            if (key.G > key.R + 64 && key.G > key.B + 64)
            {
                return g - Math.Max(r, b);
            }

            if (key.R > key.G + 64 && key.R > key.B + 64)
            {
                return r - Math.Max(g, b);
            }

            if (key.B > key.R + 64 && key.B > key.G + 64)
            {
                return b - Math.Max(r, g);
            }

            return -1;
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
        throw "KeyColor must be a 6-digit hex color, for example #00FF00."
    }

    $r = [Convert]::ToInt32($text.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($text.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($text.Substring(4, 2), 16)
    return [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
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

if ($TransparentThreshold -lt 0 -or $TransparentThreshold -gt 255) {
    throw "TransparentThreshold must be between 0 and 255."
}

if ($OpaqueThreshold -lt 1 -or $OpaqueThreshold -gt 442) {
    throw "OpaqueThreshold must be between 1 and 442."
}

if ($OpaqueThreshold -le $TransparentThreshold) {
    throw "OpaqueThreshold must be greater than TransparentThreshold."
}

if ($DominantKeyThreshold -lt 0 -or $DominantKeyThreshold -gt 255) {
    throw "DominantKeyThreshold must be between 0 and 255."
}

if ($DominantKeyOpaqueThreshold -le $DominantKeyThreshold -or $DominantKeyOpaqueThreshold -gt 255) {
    throw "DominantKeyOpaqueThreshold must be greater than DominantKeyThreshold and no more than 255."
}

$inputFull = [System.IO.Path]::GetFullPath($InputPath)
$outputFull = [System.IO.Path]::GetFullPath($OutputPath)
$rootForRelative = (Get-Location).Path

if (-not (Test-Path -LiteralPath $inputFull)) {
    throw "InputPath not found: $InputPath"
}

$key = ConvertFrom-HexColor -Value $KeyColor
$result = [SpriteChroma.ImageOps]::Remove($inputFull, $outputFull, $key, $TransparentThreshold, $OpaqueThreshold, $DominantKeyThreshold, $DominantKeyOpaqueThreshold, $Despill.IsPresent)

Write-Host "Removed chroma key from $($result.Width)x$($result.Height) image."
Write-Host "Transparent: $($result.TransparentPixels)"
Write-Host "Partial: $($result.PartialPixels)"
Write-Host "Opaque: $($result.OpaquePixels)"
Write-Host "Output: $(Get-RelativePathText -BasePath $rootForRelative -Path $outputFull)"
