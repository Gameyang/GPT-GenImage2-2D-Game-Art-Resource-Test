param(
    [string]$MetadataPath = "experiments/20260525-sprite-pivot-alignment/metadata.json",
    [string]$OutputDirectory = "experiments/20260525-sprite-pivot-alignment/playback",
    [int]$FrameDelayMs = 100
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

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

function Get-PlaybackFileName {
    param([Parameter(Mandatory = $true)][string]$CharacterId)

    if ($CharacterId -match "^animation-sheet-(.+)$") {
        return "playback-$($Matches[1]).gif"
    }

    return "$CharacterId.gif"
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

if ($FrameDelayMs -lt 10) {
    throw "FrameDelayMs must be 10 or greater."
}

$metadataFull = [System.IO.Path]::GetFullPath($MetadataPath)
if (-not (Test-Path -LiteralPath $metadataFull)) {
    throw "MetadataPath not found: $MetadataPath"
}

$rootForRelative = (Get-Location).Path
$outputFull = [System.IO.Path]::GetFullPath($OutputDirectory)
$metadata = Get-Content -LiteralPath $metadataFull -Raw | ConvertFrom-Json
$outputs = New-Object System.Collections.Generic.List[object]

foreach ($character in $metadata.characters) {
    $framePaths = @($character.frames | ForEach-Object {
        $framePath = [System.IO.Path]::GetFullPath($_.output)
        if (-not (Test-Path -LiteralPath $framePath)) {
            throw "Frame not found: $($_.output)"
        }
        $framePath
    })

    $outputPath = Join-Path $outputFull (Get-PlaybackFileName -CharacterId $character.id)
    Save-AnimatedGif -FramePaths $framePaths -OutputPath $outputPath -DelayMs $FrameDelayMs

    $outputs.Add([PSCustomObject]@{
        character = $character.id
        frameCount = $framePaths.Count
        output = (Get-RelativePathText -BasePath $rootForRelative -Path $outputPath)
    }) | Out-Null
}

Write-Host "Generated $($outputs.Count) playback GIF(s)."
foreach ($output in $outputs) {
    Write-Host "$($output.output) ($($output.frameCount) frames)"
}
