param(
    [string]$FeedPath = "public/home-feed.json",
    [string]$OutputDir = "public/assets/feed-optimized/20260525-home-feed-webp-optimized-assets",
    [string]$PreviousOptimizedDir = "assets/feed-optimized/20260525-home-feed-optimized-assets",
    [string]$AnimationSourceDir = "assets/characters/sideview-pixel/animation/playback",
    [int]$BackgroundMaxWidth = 960,
    [int]$CharacterMaxHeight = 640,
    [int]$AnimationMaxWidth = 640,
    [int]$BackgroundQuality = 78,
    [int]$CharacterQuality = 80,
    [int]$AnimationQuality = 72,
    [int]$AlphaQuality = 80,
    [int]$Effort = 6
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

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

function Get-SharpInputPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $relative = Get-RelativePathText -BasePath $Root -Path $Path
    if (-not $relative.StartsWith("../")) {
        return "./$relative"
    }

    return ([System.IO.Path]::GetFullPath($Path)).Replace("\", "/")
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

function Get-WebpTargetName {
    param([Parameter(Mandatory = $true)][string]$Url)

    $stem = [System.IO.Path]::GetFileNameWithoutExtension($Url)
    if ($stem.EndsWith("-feed")) {
        return "$stem.webp"
    }

    return "$stem-feed.webp"
}

function Read-UInt24LE {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [Parameter(Mandatory = $true)][int]$Offset
    )

    return [int]$Bytes[$Offset] -bor ([int]$Bytes[$Offset + 1] -shl 8) -bor ([int]$Bytes[$Offset + 2] -shl 16)
}

function Get-WebpInfo {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 12) {
        throw "Invalid WebP file: $Path"
    }

    $header = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 4)
    $format = [System.Text.Encoding]::ASCII.GetString($bytes, 8, 4)
    if ($header -ne "RIFF" -or $format -ne "WEBP") {
        throw "Invalid WebP file: $Path"
    }

    $width = $null
    $height = $null
    $hasAnimation = $false
    $frameCount = 0
    $offset = 12

    while ($offset + 8 -le $bytes.Length) {
        $chunkType = [System.Text.Encoding]::ASCII.GetString($bytes, $offset, 4)
        $chunkSize = [BitConverter]::ToUInt32($bytes, $offset + 4)
        $dataOffset = $offset + 8

        if ($dataOffset + $chunkSize -gt $bytes.Length) {
            break
        }

        switch ($chunkType) {
            "VP8X" {
                if ($chunkSize -ge 10) {
                    $flags = $bytes[$dataOffset]
                    $hasAnimation = $hasAnimation -or (($flags -band 0x02) -ne 0)
                    $width = (Read-UInt24LE -Bytes $bytes -Offset ($dataOffset + 4)) + 1
                    $height = (Read-UInt24LE -Bytes $bytes -Offset ($dataOffset + 7)) + 1
                }
            }
            "VP8L" {
                if ($chunkSize -ge 5 -and $bytes[$dataOffset] -eq 0x2F) {
                    $bits = [uint32]$bytes[$dataOffset + 1] -bor
                        ([uint32]$bytes[$dataOffset + 2] -shl 8) -bor
                        ([uint32]$bytes[$dataOffset + 3] -shl 16) -bor
                        ([uint32]$bytes[$dataOffset + 4] -shl 24)
                    $width = [int](($bits -band 0x3FFF) + 1)
                    $height = [int]((($bits -shr 14) -band 0x3FFF) + 1)
                }
            }
            "VP8 " {
                if ($chunkSize -ge 10) {
                    $width = [BitConverter]::ToUInt16($bytes, $dataOffset + 6) -band 0x3FFF
                    $height = [BitConverter]::ToUInt16($bytes, $dataOffset + 8) -band 0x3FFF
                }
            }
            "ANIM" {
                $hasAnimation = $true
            }
            "ANMF" {
                $frameCount++
                $hasAnimation = $true
            }
        }

        $offset = $dataOffset + [int]$chunkSize
        if (($chunkSize % 2) -eq 1) {
            $offset++
        }
    }

    if ($null -eq $width -or $null -eq $height) {
        throw "Could not read WebP dimensions: $Path"
    }

    return [PSCustomObject]@{
        w = $width
        h = $height
        format = "webp"
        animated = $hasAnimation
        frames = if ($frameCount -gt 0) { $frameCount } else { 1 }
    }
}

function Get-ImageInfo {
    param([Parameter(Mandatory = $true)][string]$Path)

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($extension -eq ".webp") {
        return Get-WebpInfo -Path $Path
    }

    $image = [System.Drawing.Image]::FromFile($Path)
    try {
        $frames = 1
        if ($image.FrameDimensionsList.Count -gt 0) {
            $dimension = [System.Drawing.Imaging.FrameDimension]::new($image.FrameDimensionsList[0])
            $frames = $image.GetFrameCount($dimension)
        }

        return [PSCustomObject]@{
            w = $image.Width
            h = $image.Height
            format = $extension.TrimStart(".")
            animated = ($frames -gt 1)
            frames = $frames
        }
    }
    finally {
        $image.Dispose()
    }
}

function Invoke-SharpWebp {
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$TempDir,
        [Parameter(Mandatory = $true)][bool]$Animated,
        [Parameter(Mandatory = $true)][int]$Quality,
        [Parameter(Mandatory = $true)][string]$ResizeMode
    )

    $sharpInput = Get-SharpInputPath -Root (Get-Location).Path -Path $InputPath
    $arguments = @("--yes", "--package=sharp-cli", "--", "sharp")
    if ($Animated) {
        $arguments += "--animated"
    }

    $arguments += @(
        "-i", $sharpInput,
        "-o", $TempDir,
        "-f", "webp",
        "-q", "$Quality",
        "--alphaQuality", "$AlphaQuality",
        "--effort", "$Effort"
    )

    switch ($ResizeMode) {
        "background" {
            $arguments += @("resize", "$BackgroundMaxWidth", "--withoutEnlargement")
        }
        "character" {
            $arguments += @("resize", "--height", "$CharacterMaxHeight", "--withoutEnlargement")
        }
        "animation" {
            $arguments += @("resize", "$AnimationMaxWidth", "--withoutEnlargement")
        }
        default {
            throw "Unknown resize mode: $ResizeMode"
        }
    }

    & npx @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "sharp-cli failed for $InputPath"
    }
}

function Get-ResizeMode {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$MediaType
    )

    if ($MediaType -eq "gif" -or $Url.ToLowerInvariant().EndsWith(".gif")) {
        return "animation"
    }

    if ($Url -like "assets/backgrounds/*" -or $Url -like "assets/feed-optimized/*background-*") {
        return "background"
    }

    return "character"
}

function Get-QualityForMode {
    param([Parameter(Mandatory = $true)][string]$ResizeMode)

    switch ($ResizeMode) {
        "background" { return $BackgroundQuality }
        "animation" { return $AnimationQuality }
        default { return $CharacterQuality }
    }
}

function Get-CanonicalSourceUrl {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$ResizeMode,
        [Parameter(Mandatory = $true)][string]$FeedDirectory
    )

    if (-not $Url.ToLowerInvariant().EndsWith(".webp")) {
        return $Url
    }

    $stem = [System.IO.Path]::GetFileNameWithoutExtension($Url)
    $sourceStem = if ($stem.EndsWith("-feed")) {
        $stem.Substring(0, $stem.Length - 5)
    } else {
        $stem
    }

    $candidates = switch ($ResizeMode) {
        "background" {
            @(
                (Join-Path $PreviousOptimizedDir "$stem.jpg").Replace("\", "/"),
                (Join-Path $PreviousOptimizedDir "$sourceStem-feed.jpg").Replace("\", "/"),
                (Join-Path $PreviousOptimizedDir "$sourceStem.jpg").Replace("\", "/")
            )
        }
        "animation" {
            @(
                (Join-Path $AnimationSourceDir "$sourceStem.gif").Replace("\", "/"),
                (Join-Path $AnimationSourceDir "$stem.gif").Replace("\", "/")
            )
        }
        default {
            @(
                (Join-Path $PreviousOptimizedDir "$stem.png").Replace("\", "/"),
                (Join-Path $PreviousOptimizedDir "$sourceStem-feed.png").Replace("\", "/"),
                (Join-Path $PreviousOptimizedDir "$sourceStem.png").Replace("\", "/")
            )
        }
    }

    foreach ($candidate in $candidates) {
        $candidateFull = [System.IO.Path]::GetFullPath((Join-Path $FeedDirectory $candidate))
        if (Test-Path -LiteralPath $candidateFull) {
            return $candidate
        }
    }

    return $Url
}

if ($BackgroundMaxWidth -lt 1 -or $CharacterMaxHeight -lt 1 -or $AnimationMaxWidth -lt 1) {
    throw "Max dimensions must be positive."
}

foreach ($quality in @($BackgroundQuality, $CharacterQuality, $AnimationQuality, $AlphaQuality)) {
    if ($quality -lt 1 -or $quality -gt 100) {
        throw "Quality values must be between 1 and 100."
    }
}

if ($Effort -lt 0 -or $Effort -gt 6) {
    throw "Effort must be between 0 and 6."
}

$root = (Get-Location).Path
$feedFull = [System.IO.Path]::GetFullPath($FeedPath)
$feedDirectory = Split-Path $feedFull -Parent
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
        if ($media.type -notin @("image", "gif")) {
            continue
        }

        $url = [string]$media.url
        if ($seen.ContainsKey($url)) {
            $media.url = $seen[$url]
            continue
        }

        $resizeMode = Get-ResizeMode -Url $url -MediaType ([string]$media.type)
        $sourceUrl = Get-CanonicalSourceUrl -Url $url -ResizeMode $resizeMode -FeedDirectory $feedDirectory
        $sourceFull = [System.IO.Path]::GetFullPath((Join-Path $feedDirectory $sourceUrl))
        if (-not (Test-Path -LiteralPath $sourceFull)) {
            throw "Feed media file not found: $sourceUrl"
        }

        $quality = Get-QualityForMode -ResizeMode $resizeMode
        $targetName = Get-WebpTargetName -Url $url
        $targetFull = Join-Path $outputFull $targetName
        $tempDir = Join-Path $outputFull (".tmp-" + [Guid]::NewGuid().ToString("N"))

        New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
        try {
            Invoke-SharpWebp -InputPath $sourceFull -TempDir $tempDir -Animated ($resizeMode -eq "animation") -Quality $quality -ResizeMode $resizeMode

            $generated = Get-ChildItem -LiteralPath $tempDir -Filter "*.webp" -File | Select-Object -First 1
            if ($null -eq $generated) {
                throw "No WebP output was generated for $url"
            }

            Move-Item -LiteralPath $generated.FullName -Destination $targetFull -Force
        }
        finally {
            $tempFull = [System.IO.Path]::GetFullPath($tempDir)
            if ($tempFull.StartsWith($outputFull, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $tempFull)) {
                Remove-Item -LiteralPath $tempFull -Recurse -Force
            }
        }

        $optimizedRelative = Get-RelativePathText -BasePath $feedDirectory -Path $targetFull
        $media.url = $optimizedRelative
        $seen[$url] = $optimizedRelative

        $sourceBytes = (Get-Item -LiteralPath $sourceFull).Length
        $targetBytes = (Get-Item -LiteralPath $targetFull).Length
        $savedBytes = $sourceBytes - $targetBytes
        $savedPercent = if ($sourceBytes -gt 0) { [Math]::Round(($savedBytes / $sourceBytes) * 100, 2) } else { 0 }
        $sourceInfo = Get-ImageInfo -Path $sourceFull
        $targetInfo = Get-ImageInfo -Path $targetFull

        $results.Add([PSCustomObject]@{
            postId = $post.id
            previousFeedUrl = $url
            source = $sourceUrl
            optimized = $optimizedRelative
            mediaType = $media.type
            resizeMode = $resizeMode
            quality = $quality
            sourceBytes = $sourceBytes
            optimizedBytes = $targetBytes
            savedBytes = $savedBytes
            savedPercent = $savedPercent
            sourceSize = $sourceInfo
            optimizedSize = $targetInfo
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
    tool = "tools/optimize-home-feed-webp.ps1"
    feed = (Get-RelativePathText -BasePath $root -Path $feedFull)
    outputDir = (Get-RelativePathText -BasePath $root -Path $outputFull)
    settings = [PSCustomObject]@{
        backgroundMaxWidth = $BackgroundMaxWidth
        characterMaxHeight = $CharacterMaxHeight
        animationMaxWidth = $AnimationMaxWidth
        backgroundQuality = $BackgroundQuality
        characterQuality = $CharacterQuality
        animationQuality = $AnimationQuality
        alphaQuality = $AlphaQuality
        effort = $Effort
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
Write-JsonFile -Path $manifestPath -Value $manifest
Write-JsonFile -Path $feedFull -Value $feed

Write-Host "Optimized $($results.Count) home feed media item(s) to WebP."
Write-Host "Saved $totalSaved byte(s), $totalSavedPercent%."
Write-Host "Manifest: $(Get-RelativePathText -BasePath $root -Path $manifestPath)"
