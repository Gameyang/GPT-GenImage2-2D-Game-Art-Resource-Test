param(
    [string]$TaskId = "20260528-comfyui-pixel-scene-feed-marathon-01",
    [string]$StopAt = "2026-05-29T09:00:00+09:00",
    [string[]]$PromptPaths = @(
        "prompts/20260527-pixel-art-imdb-top-100-scenes.md",
        "prompts/20260527-fc-era-hd2d-pixel-scenes-prompts.md"
    ),
    [ValidateSet("qwen_image", "pokemon")]
    [string[]]$Workflows = @("qwen_image", "pokemon"),
    [string]$ComfyUrl = "http://127.0.0.1:8188",
    [int]$ImagesPerPack = 4,
    [int]$Quality = 82,
    [int]$Effort = 6,
    [int]$PollSeconds = 2,
    [int]$TimeoutSeconds = 900,
    [int]$MaxPacks = 0,
    [switch]$SkipExisting,
    [switch]$ContinueOnError,
    [switch]$NoGitPush,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir ".."))
$runner = Join-Path $scriptDir "comfyui-generate.ps1"
$feedPath = Join-Path $repoRoot "public/home-feed.json"
$publicRoot = Join-Path $repoRoot "public"
$feedRoot = Join-Path $repoRoot ("public/assets/feed-optimized/$TaskId")
$taskLogPath = Join-Path $repoRoot ("docs/tasks/$TaskId.md")
$promptLogPath = Join-Path $repoRoot ("prompts/$TaskId.md")
$runStatePath = Join-Path $feedRoot "run-state.json"

if ($TaskId -notmatch "^[0-9]{8}-[a-z0-9][a-z0-9-]*$") {
    throw "TaskId must use the repo task pattern, for example 20260528-comfyui-pixel-scene-feed-marathon-01."
}

if ($ImagesPerPack -ne 4) {
    throw "This feed loop is intentionally scoped to 4-image packs."
}

if ($Quality -lt 1 -or $Quality -gt 100) {
    throw "Quality must be between 1 and 100."
}

if ($Effort -lt 0 -or $Effort -gt 6) {
    throw "Effort must be between 0 and 6."
}

if (-not (Test-Path -LiteralPath $runner)) {
    throw "Missing runner: $runner"
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

function Write-TextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }

    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Text + [Environment]::NewLine, $encoding)
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Value
    )

    $json = $Value | ConvertTo-Json -Depth 100
    Write-TextFile -Path $Path -Text $json
}

function ConvertTo-Slug {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [int]$MaxLength = 48
    )

    $slug = $Text.ToLowerInvariant() -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")
    if ([string]::IsNullOrWhiteSpace($slug)) {
        $slug = "scene"
    }
    if ($slug.Length -gt $MaxLength) {
        $slug = $slug.Substring(0, $MaxLength).Trim("-")
    }
    if ([string]::IsNullOrWhiteSpace($slug)) {
        $slug = "scene"
    }
    return $slug
}

function Get-SharpPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $relative = Get-RelativePathText -BasePath $repoRoot -Path $Path
    if (-not $relative.StartsWith("../")) {
        return "./$relative"
    }

    return ([System.IO.Path]::GetFullPath($Path)).Replace("\", "/")
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
        width = $width
        height = $height
        bytes = (Get-Item -LiteralPath $Path).Length
    }
}

function Assert-WebpOutput {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Expected WebP output was not created: $Path"
    }

    $item = Get-Item -LiteralPath $Path
    if ($item.Length -le 0) {
        throw "Expected WebP output is empty: $Path"
    }

    $info = Get-WebpInfo -Path $Path
    if ($info.width -lt 256 -or $info.height -lt 144) {
        throw "Unexpectedly small WebP dimensions $($info.width)x$($info.height): $Path"
    }

    return $info
}

function Invoke-SharpWebp {
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )

    $outputDir = Split-Path -Parent $OutputPath
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

    $tempBase = Join-Path $repoRoot (".tools/sharp-temp/$TaskId")
    New-Item -ItemType Directory -Force -Path $tempBase | Out-Null
    $tempDir = Join-Path $tempBase (".tmp-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    try {
        $arguments = @(
            "--yes",
            "--package=sharp-cli",
            "--",
            "sharp",
            "-i",
            (Get-SharpPath -Path $InputPath),
            "-o",
            (Get-SharpPath -Path $tempDir),
            "-f",
            "webp",
            "-q",
            "$Quality",
            "--alphaQuality",
            "$Quality",
            "--effort",
            "$Effort",
            "resize",
            "1280",
            "--withoutEnlargement"
        )

        & npx @arguments
        if ($LASTEXITCODE -ne 0) {
            throw "sharp-cli failed for $InputPath"
        }

        $generated = Get-ChildItem -LiteralPath $tempDir -Filter "*.webp" -File | Select-Object -First 1
        if ($null -eq $generated) {
            throw "No WebP output was generated for $InputPath"
        }

        Move-Item -LiteralPath $generated.FullName -Destination $OutputPath -Force
        Assert-WebpOutput -Path $OutputPath | Out-Null
    }
    finally {
        $tempFull = [System.IO.Path]::GetFullPath($tempDir)
        $tempBaseFull = [System.IO.Path]::GetFullPath($tempBase)
        if (-not $tempBaseFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
            $tempBaseFull += [System.IO.Path]::DirectorySeparatorChar
        }
        if ($tempFull.StartsWith($tempBaseFull, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $tempFull)) {
            Remove-Item -LiteralPath $tempFull -Recurse -Force
        }
    }
}

function Remove-TaskPng {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$AllowedRoot,
        [Parameter(Mandatory = $true)][string]$TaskMarker
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $full = [System.IO.Path]::GetFullPath($Path)
    $root = [System.IO.Path]::GetFullPath($AllowedRoot)
    if (-not $root.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $root += [System.IO.Path]::DirectorySeparatorChar
    }

    if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to delete PNG outside task root: $full"
    }
    if ([System.IO.Path]::GetExtension($full).ToLowerInvariant() -ne ".png") {
        throw "Refusing to delete non-PNG file: $full"
    }
    if ($full -notlike "*$TaskMarker*") {
        throw "Refusing to delete PNG without task marker '$TaskMarker': $full"
    }

    Remove-Item -LiteralPath $full -Force
    return $true
}

function Get-WorkflowConfig {
    param([Parameter(Mandatory = $true)][string]$Workflow)

    switch ($Workflow) {
        "qwen_image" {
            return [PSCustomObject]@{
                name = "qwen_image"
                slug = "qwen-image"
                title = "Qwen Image"
                width = 1344
                height = 768
            }
        }
        "pokemon" {
            return [PSCustomObject]@{
                name = "pokemon"
                slug = "z-image"
                title = "Z-Image"
                width = 768
                height = 432
            }
        }
        default {
            throw "Unknown workflow: $Workflow"
        }
    }
}

function Get-ImdbScenePrompts {
    param([Parameter(Mandatory = $true)][string]$Path)

    $full = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    if (-not (Test-Path -LiteralPath $full)) {
        throw "Prompt file not found: $Path"
    }

    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $full
    $pattern = "(?ms)^###\s+(\d{3})\s+-\s+(.+?)\r?\n\r?\nPrompt:\s*(.+?)(?=^###\s+\d{3}\s+-|\z)"
    $options = [System.Text.RegularExpressions.RegexOptions]::Multiline -bor [System.Text.RegularExpressions.RegexOptions]::Singleline
    $matches = [regex]::Matches($text, $pattern, $options)
    $items = New-Object System.Collections.Generic.List[object]

    foreach ($match in $matches) {
        $label = [string]$match.Groups[1].Value
        $title = ([string]$match.Groups[2].Value).Trim()
        $prompt = (([string]$match.Groups[3].Value).Trim() -replace "\s+", " ")
        $slugBase = $title -replace "\([0-9]{4}\)", ""
        $items.Add([PSCustomObject]@{
            source = "imdb-top-100"
            sourceTitle = "IMDb Top 100-Inspired Cinematic Pixel Scenes"
            sourceTag = "Cinema"
            label = $label
            title = $title
            slug = ConvertTo-Slug -Text $slugBase -MaxLength 42
            prompt = "$prompt Premium 16:9 pixel-art scene illustration, no readable text, no logo, no watermark."
        }) | Out-Null
    }

    if ($items.Count -ne 100) {
        throw "Expected 100 IMDb scene prompts, found $($items.Count)."
    }

    return $items.ToArray()
}

function Get-FcScenePrompts {
    param([Parameter(Mandatory = $true)][string]$Path)

    $full = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    if (-not (Test-Path -LiteralPath $full)) {
        throw "Prompt file not found: $Path"
    }

    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $full
    $section = ($text -split "## 100 Scene Seeds", 2)[1]
    $section = ($section -split "## Suggested Batch Naming", 2)[0]
    $matches = [regex]::Matches($section, "(?m)^\s*(\d+)\.\s+(.+?)\s*$")
    $items = New-Object System.Collections.Generic.List[object]

    foreach ($match in $matches) {
        $number = [int]$match.Groups[1].Value
        $label = "{0:D3}" -f $number
        $seed = ([string]$match.Groups[2].Value).Trim()
        $prompt = "$seed, original FC-era inspired game moment reimagined as a premium HD-2D pixel-art scene illustration, not based on any real title or character, 2.5D diorama depth, layered parallax foreground and background, crisp hand-placed pixel clusters, modern real-time game engine lighting, global illumination feel, volumetric fog, bloom, rim lighting, subtle reflections, cinematic camera, dramatic readable silhouette, rich limited palette, high-resolution output with preserved pixel-art texture, no UI, no text, no logo, no watermark, no recognizable copyrighted character, no exact game screenshot."
        $items.Add([PSCustomObject]@{
            source = "fc-hd2d"
            sourceTitle = "FC-Era HD-2D-Inspired Pixel Scenes"
            sourceTag = "HD-2D"
            label = $label
            title = "FC HD-2D Scene $label"
            slug = ConvertTo-Slug -Text $seed -MaxLength 42
            prompt = $prompt
        }) | Out-Null
    }

    if ($items.Count -ne 100) {
        throw "Expected 100 FC HD-2D scene prompts, found $($items.Count)."
    }

    return $items.ToArray()
}

function Get-SourceStartIndex {
    param(
        [Parameter(Mandatory = $true)][int]$PackIndex,
        [Parameter(Mandatory = $true)][string]$SourceKey,
        [Parameter(Mandatory = $true)][string[]]$Pattern
    )

    $sourcePackCount = 0
    for ($i = 0; $i -lt $PackIndex; $i++) {
        if ($Pattern[$i % $Pattern.Count] -eq $SourceKey) {
            $sourcePackCount++
        }
    }

    return $sourcePackCount * $ImagesPerPack
}

function New-ScenePrompt {
    param(
        [Parameter(Mandatory = $true)]$Entry,
        [Parameter(Mandatory = $true)][int]$VariantRound
    )

    if ($VariantRound -le 1) {
        return [string]$Entry.prompt
    }

    return "$($Entry.prompt) Fresh alternate variation ${VariantRound}: change the camera angle, lighting palette, foreground props, and background staging while keeping the same public-safe theme and avoiding direct frame or screenshot recreation."
}

function Add-OrReplaceFeedPost {
    param(
        [Parameter(Mandatory = $true)]$Feed,
        [Parameter(Mandatory = $true)]$Post
    )

    $remaining = @($Feed.posts | Where-Object { $_.id -ne $Post.id })
    $Feed.posts = @($Post) + $remaining
}

function ConvertTo-EnglishCount {
    param([Parameter(Mandatory = $true)][int]$Count)

    switch ($Count) {
        4 { return "Four" }
        default { return [string]$Count }
    }
}

function Test-ReadyPack {
    param(
        [Parameter(Mandatory = $true)][string]$ManifestPath,
        [Parameter(Mandatory = $true)][int]$ExpectedMedia
    )

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        return $false
    }

    try {
        $manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $ManifestPath | ConvertFrom-Json
        if ([string]$manifest.status -ne "ready") {
            return $false
        }
        $assets = @($manifest.assets)
        if ($assets.Count -ne $ExpectedMedia) {
            return $false
        }
        foreach ($asset in $assets) {
            $feedAsset = [string]$asset.feedAsset
            if ([string]::IsNullOrWhiteSpace($feedAsset)) {
                return $false
            }
            $full = Join-Path $publicRoot $feedAsset
            Assert-WebpOutput -Path $full | Out-Null
        }
        return $true
    }
    catch {
        return $false
    }
}

function Invoke-ComfyFree {
    try {
        $body = @{
            unload_models = $true
            free_memory = $true
        } | ConvertTo-Json -Compress
        Invoke-RestMethod -Uri ($ComfyUrl.TrimEnd("/") + "/free") -Method Post -ContentType "application/json" -Body $body -TimeoutSec 30 | Out-Null
        Write-Host "Called ComfyUI /free after a generation failure."
    }
    catch {
        Write-Warning "Could not call ComfyUI /free: $($_.Exception.Message)"
    }
}

function Invoke-Generation {
    param(
        [Parameter(Mandatory = $true)]$WorkflowConfig,
        [Parameter(Mandatory = $true)][string]$PackId,
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][string]$FilenamePrefix
    )

    $runnerParams = @{
        TaskId = $PackId
        Workflow = $WorkflowConfig.name
        Prompt = $Prompt
        Width = $WorkflowConfig.width
        Height = $WorkflowConfig.height
        FilenamePrefix = $FilenamePrefix
        ComfyUrl = $ComfyUrl
        PollSeconds = $PollSeconds
        TimeoutSeconds = $TimeoutSeconds
    }

    $runnerOutput = & $runner @runnerParams 2>&1
    if (-not $?) {
        throw (($runnerOutput | Out-String).Trim())
    }

    $rawDir = Join-Path $repoRoot ("raw/generated/$PackId")
    $metadata = Get-ChildItem -LiteralPath $rawDir -Filter "comfyui-generation-*-metadata.json" -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $metadata) {
        throw "No ComfyUI metadata found in $rawDir"
    }

    $metadataJson = Get-Content -Raw -Encoding UTF8 -LiteralPath $metadata.FullName | ConvertFrom-Json
    $downloadedFiles = @($metadataJson.downloadedFiles)
    if ($downloadedFiles.Count -lt 1) {
        throw "No downloaded files recorded in $($metadata.FullName)"
    }

    $downloadedFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot ([string]$downloadedFiles[0])))
    return [PSCustomObject]@{
        rawDir = $rawDir
        rawPng = $downloadedFull
        metadata = $metadata.FullName
        promptId = [string]$metadataJson.promptId
    }
}

function Assert-FocusedFeedPost {
    param(
        [Parameter(Mandatory = $true)][string]$PostId,
        [Parameter(Mandatory = $true)][int]$ExpectedMedia
    )

    $feed = Get-Content -Raw -Encoding UTF8 -LiteralPath $feedPath | ConvertFrom-Json
    $posts = @($feed.posts | Where-Object { $_.id -eq $PostId })
    if ($posts.Count -ne 1) {
        throw "Expected one feed post '$PostId', found $($posts.Count)."
    }

    $media = @($posts[0].media)
    if ($media.Count -ne $ExpectedMedia) {
        throw "Expected $ExpectedMedia media item(s) for '$PostId', found $($media.Count)."
    }

    foreach ($item in $media) {
        $url = [string]$item.url
        if ($url -notlike "*.webp") {
            throw "Feed media is not WebP: $PostId $url"
        }
        if ($url -match "^https?://") {
            throw "Expected project-relative feed media, found absolute URL: $url"
        }
        $full = Join-Path $publicRoot $url
        Assert-WebpOutput -Path $full | Out-Null
    }
}

function Assert-TaskFeed {
    $feed = Get-Content -Raw -Encoding UTF8 -LiteralPath $feedPath | ConvertFrom-Json
    $posts = @($feed.posts | Where-Object { $_.id -like "$TaskId-*" })
    $mediaCount = 0
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($post in $posts) {
        foreach ($media in @($post.media)) {
            $mediaCount++
            $url = [string]$media.url
            if ($url -notlike "*.webp") {
                throw "Non-WebP task feed media: $($post.id) $url"
            }
            $full = Join-Path $publicRoot $url
            if (-not (Test-Path -LiteralPath $full)) {
                $missing.Add("$($post.id):$url") | Out-Null
            }
        }
    }

    if ($missing.Count -gt 0) {
        throw "Missing task feed media: $($missing -join ', ')"
    }

    $publicPngs = @()
    if (Test-Path -LiteralPath $feedRoot) {
        $publicPngs = @(Get-ChildItem -LiteralPath $feedRoot -Recurse -File -Filter "*.png")
    }
    if ($publicPngs.Count -gt 0) {
        throw "Unexpected task PNG files under public feed root: $($publicPngs.Count)"
    }

    return [PSCustomObject]@{
        posts = $posts.Count
        media = $mediaCount
        publicPng = $publicPngs.Count
    }
}

function Write-RunState {
    param(
        [Parameter(Mandatory = $true)][string]$Status,
        [int]$CompletedPacks,
        [int]$GeneratedPng,
        [int]$DeletedRawPng,
        [int]$Webp,
        [int]$Committed,
        [int]$Pushed,
        [string]$CurrentPack = "",
        [string]$LastError = ""
    )

    New-Item -ItemType Directory -Force -Path $feedRoot | Out-Null
    Write-JsonFile -Path $runStatePath -Value ([PSCustomObject]@{
        schemaVersion = 1
        taskId = $TaskId
        status = $Status
        updatedAt = (Get-Date).ToString("s")
        stopAt = $script:StopAtText
        publishMode = "real-time"
        followUpMode = "similar-only"
        shutdownMode = "clean-stop"
        storageMode = "webp-only-delete-png"
        currentPack = $CurrentPack
        completedPacks = $CompletedPacks
        generatedPng = $GeneratedPng
        deletedRawPng = $DeletedRawPng
        retainedPng = 0
        webp = $Webp
        committed = $Committed
        pushed = $Pushed
        lastError = $LastError
    })
}

function Invoke-GitPublish {
    param(
        [Parameter(Mandatory = $true)][string]$CommitMessage
    )

    $paths = @(
        "public/home-feed.json",
        "public/assets/feed-optimized/$TaskId",
        "prompts/$TaskId.md",
        "docs/tasks/$TaskId.md",
        "tools/comfyui-run-prompt-feed-loop.ps1"
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $gitAddOutput = & git add -- @paths 2>&1
        $gitAddExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($gitAddExitCode -ne 0) {
        throw "git add failed. $($gitAddOutput -join [Environment]::NewLine)"
    }
    foreach ($line in @($gitAddOutput)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
            Write-Host $line
        }
    }

    $staged = @(& git diff --cached --name-only)
    $bad = @($staged | Where-Object { $_ -match "^(raw/|internal-notes/|\.tools/)" -or $_ -match "local-sources\.json$" })
    if ($bad.Count -gt 0) {
        throw "Refusing to commit private/local staged paths: $($bad -join ', ')"
    }

    $pngStaged = @($staged | Where-Object { $_ -like "*$TaskId*" -and $_ -match "\.png$" })
    if ($pngStaged.Count -gt 0) {
        throw "Refusing to commit task PNG files: $($pngStaged -join ', ')"
    }

    if ($staged.Count -eq 0) {
        return [PSCustomObject]@{ committed = $false; pushed = $false; warning = "no staged changes" }
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $gitCommitOutput = & git commit -m $CommitMessage 2>&1
        $gitCommitExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($gitCommitExitCode -ne 0) {
        throw "git commit failed. $($gitCommitOutput -join [Environment]::NewLine)"
    }
    foreach ($line in @($gitCommitOutput)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
            Write-Host $line
        }
    }

    if ($NoGitPush.IsPresent) {
        return [PSCustomObject]@{ committed = $true; pushed = $false; warning = "NoGitPush set" }
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $gitPushOutput = & git push 2>&1
        $gitPushExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($gitPushExitCode -ne 0) {
        foreach ($line in @($gitPushOutput)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
                Write-Warning $line
            }
        }
        return [PSCustomObject]@{ committed = $true; pushed = $false; warning = "git push failed" }
    }
    foreach ($line in @($gitPushOutput)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
            Write-Host $line
        }
    }

    return [PSCustomObject]@{ committed = $true; pushed = $true; warning = "" }
}

$stopAtDto = [DateTimeOffset]::Parse($StopAt)
$script:StopAtText = $stopAtDto.ToString("yyyy-MM-dd HH:mm:ss zzz")

$imdbPath = $PromptPaths[0]
$fcPath = $PromptPaths[1]
$sources = @{
    "imdb-top-100" = @(Get-ImdbScenePrompts -Path $imdbPath)
    "fc-hd2d" = @(Get-FcScenePrompts -Path $fcPath)
}

$sourcePattern = @("imdb-top-100", "fc-hd2d", "fc-hd2d", "imdb-top-100")
$plannedPacks = 50
$plannedImages = 200

if ($DryRun.IsPresent -and $MaxPacks -le 0) {
    $MaxPacks = 4
}

if ($DryRun.IsPresent) {
    Write-Host "Dry run only. No ComfyUI prompts submitted."
    Write-Host "Task: $TaskId"
    Write-Host "StopAt: $script:StopAtText"
    Write-Host "Planned base scope: $plannedPacks packs, $plannedImages images."
    for ($packIndex = 0; $packIndex -lt $MaxPacks; $packIndex++) {
        $workflowConfig = Get-WorkflowConfig -Workflow $Workflows[$packIndex % $Workflows.Count]
        $sourceKey = $sourcePattern[$packIndex % $sourcePattern.Count]
        $sourceStart = Get-SourceStartIndex -PackIndex $packIndex -SourceKey $sourceKey -Pattern $sourcePattern
        $packText = "{0:D3}" -f ($packIndex + 1)
        $labels = for ($j = 0; $j -lt $ImagesPerPack; $j++) {
            $entry = $sources[$sourceKey][($sourceStart + $j) % $sources[$sourceKey].Count]
            $entry.label
        }
        Write-Host "Pack ${packText}: $($workflowConfig.slug) / $sourceKey / entries $($labels -join ', ')"
    }
    exit 0
}

New-Item -ItemType Directory -Force -Path $feedRoot | Out-Null

$completedPacks = 0
$generatedPngCount = 0
$deletedRawPngCount = 0
$webpCount = 0
$commitCount = 0
$pushCount = 0
$lastHeartbeat = [DateTimeOffset]::MinValue

Write-RunState -Status "running" -CompletedPacks 0 -GeneratedPng 0 -DeletedRawPng 0 -Webp 0 -Committed 0 -Pushed 0

$packIndex = 0
try {
    while ($true) {
        $now = [DateTimeOffset]::Now
        if ($now -ge $stopAtDto) {
            Write-Host "Stop time reached before starting next pack: $script:StopAtText"
            break
        }
        if ($MaxPacks -gt 0 -and $packIndex -ge $MaxPacks) {
            Write-Host "MaxPacks reached: $MaxPacks"
            break
        }

        $workflowConfig = Get-WorkflowConfig -Workflow $Workflows[$packIndex % $Workflows.Count]
        $sourceKey = $sourcePattern[$packIndex % $sourcePattern.Count]
        $sourceEntries = $sources[$sourceKey]
        $sourceStart = Get-SourceStartIndex -PackIndex $packIndex -SourceKey $sourceKey -Pattern $sourcePattern
        $packNumber = $packIndex + 1
        $packText = "{0:D3}" -f $packNumber
        $packId = "$TaskId-$($workflowConfig.slug)-$sourceKey-pack-$packText"
        $packDir = Join-Path $feedRoot "$($workflowConfig.slug)/$sourceKey/pack-$packText"
        $packManifestPath = Join-Path $packDir "manifest.json"

        Write-RunState -Status "running" -CompletedPacks $completedPacks -GeneratedPng $generatedPngCount -DeletedRawPng $deletedRawPngCount -Webp $webpCount -Committed $commitCount -Pushed $pushCount -CurrentPack $packId

        if ($SkipExisting.IsPresent -and (Test-ReadyPack -ManifestPath $packManifestPath -ExpectedMedia $ImagesPerPack)) {
            Write-Host "Skipping ready existing pack: $packId"
            $completedPacks++
            $generatedPngCount += $ImagesPerPack
            $deletedRawPngCount += $ImagesPerPack
            $webpCount += $ImagesPerPack
            $packIndex++
            continue
        }

        New-Item -ItemType Directory -Force -Path $packDir | Out-Null
        Write-Host "Starting pack ${packText}: workflow=$($workflowConfig.slug), source=$sourceKey, stopAt=$script:StopAtText"

        $media = New-Object System.Collections.Generic.List[object]
        $assets = New-Object System.Collections.Generic.List[object]
        $packFailed = $false

        for ($j = 0; $j -lt $ImagesPerPack; $j++) {
            $absoluteSourceIndex = $sourceStart + $j
            $entry = $sourceEntries[$absoluteSourceIndex % $sourceEntries.Count]
            $variantRound = [int][Math]::Floor($absoluteSourceIndex / $sourceEntries.Count) + 1
            $variantText = "{0:D2}" -f $variantRound
            $itemText = "{0:D2}" -f ($j + 1)
            $fileStem = "pixel-scene-$($entry.source)-$($entry.label)-$($entry.slug)-v$variantText-$($workflowConfig.slug)"
            $webpPath = Join-Path $packDir "$fileStem-feed.webp"
            $feedAsset = Get-RelativePathText -BasePath $publicRoot -Path $webpPath
            $prompt = New-ScenePrompt -Entry $entry -VariantRound $variantRound

            if ((Test-Path -LiteralPath $webpPath) -and $SkipExisting.IsPresent) {
                $webpInfo = Assert-WebpOutput -Path $webpPath
                $media.Add([PSCustomObject]@{
                    type = "image"
                    url = $feedAsset
                    alt = "$($workflowConfig.title) $($entry.sourceTitle) $($entry.label): $($entry.title)"
                }) | Out-Null
                $assets.Add([PSCustomObject]@{
                    status = "skipped-existing"
                    source = $entry.source
                    label = $entry.label
                    title = $entry.title
                    variant = $variantRound
                    workflow = $workflowConfig.name
                    prompt = $prompt
                    rawSourceAsset = $null
                    rawPngDeleted = $false
                    feedAsset = $feedAsset
                    webp = $webpInfo
                }) | Out-Null
                continue
            }

            $rawDir = Join-Path $repoRoot ("raw/generated/$packId")
            $existingRaw = $null
            if (Test-Path -LiteralPath $rawDir) {
                $existingRaw = Get-ChildItem -LiteralPath $rawDir -Filter "$fileStem*.png" -File |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1
            }

            $generated = $null
            if ($null -ne $existingRaw) {
                Write-Host "Optimizing existing raw PNG for pack $packText item ${itemText}: $($existingRaw.Name)"
                $generated = [PSCustomObject]@{
                    rawDir = $rawDir
                    rawPng = $existingRaw.FullName
                    metadata = $null
                    promptId = $null
                }
            }
            else {
                $attempt = 0
                while ($attempt -lt 2 -and $null -eq $generated) {
                    $attempt++
                    try {
                        Write-Host "Generating pack $packText item ${itemText}: $($workflowConfig.slug) $($entry.source) $($entry.label) attempt $attempt"
                        $generated = Invoke-Generation -WorkflowConfig $workflowConfig -PackId $packId -Prompt $prompt -FilenamePrefix $fileStem
                    }
                    catch {
                        if ($attempt -ge 2) {
                            throw
                        }
                        Write-Warning "Generation failed; freeing VRAM and retrying once: $($_.Exception.Message)"
                        Invoke-ComfyFree
                        Start-Sleep -Seconds 5
                    }
                }
            }

            Invoke-SharpWebp -InputPath $generated.rawPng -OutputPath $webpPath
            $webpInfo = Assert-WebpOutput -Path $webpPath
            $generatedPngCount++
            $deleted = Remove-TaskPng -Path $generated.rawPng -AllowedRoot $generated.rawDir -TaskMarker $packId
            if ($deleted) {
                $deletedRawPngCount++
            }
            $webpCount++

            $media.Add([PSCustomObject]@{
                type = "image"
                url = $feedAsset
                alt = "$($workflowConfig.title) $($entry.sourceTitle) $($entry.label): $($entry.title)"
            }) | Out-Null

            $assets.Add([PSCustomObject]@{
                status = "generated"
                source = $entry.source
                label = $entry.label
                title = $entry.title
                variant = $variantRound
                workflow = $workflowConfig.name
                prompt = $prompt
                promptId = $generated.promptId
                rawSourceAsset = Get-RelativePathText -BasePath $repoRoot -Path $generated.rawPng
                rawPngDeleted = $deleted
                feedAsset = $feedAsset
                webp = $webpInfo
            }) | Out-Null

            $now = [DateTimeOffset]::Now
            if (($now - $lastHeartbeat).TotalMinutes -ge 30) {
                $lastHeartbeat = $now
                Write-Host "Heartbeat $($now.ToString("yyyy-MM-dd HH:mm:ss zzz")) stopAt=$script:StopAtText generatedPng=$generatedPngCount webp=$webpCount completedPacks=$completedPacks commits=$commitCount pushes=$pushCount currentPack=$packId"
            }
        }

        if ($media.Count -ne $ImagesPerPack) {
            $packFailed = $true
        }

        $status = if ($packFailed) { "failed" } else { "ready" }
        Write-JsonFile -Path $packManifestPath -Value ([PSCustomObject]@{
            schemaVersion = 1
            generatedAt = (Get-Date).ToString("s")
            taskId = $TaskId
            packId = $packId
            packNumber = $packNumber
            status = $status
            source = $sourceKey
            workflow = $workflowConfig.name
            workflowSlug = $workflowConfig.slug
            imagesPerPack = $ImagesPerPack
            feedDir = Get-RelativePathText -BasePath $repoRoot -Path $packDir
            webpOnlyDeletePng = $true
            assets = $assets.ToArray()
        })

        if ($packFailed) {
            Write-Warning "Pack did not produce $ImagesPerPack media item(s): $packId"
            if (-not $ContinueOnError.IsPresent) {
                throw "Pack failed: $packId"
            }
            $packIndex++
            continue
        }

        $feed = Get-Content -Raw -Encoding UTF8 -LiteralPath $feedPath | ConvertFrom-Json
        $countText = ConvertTo-EnglishCount -Count $media.Count
        $post = [PSCustomObject]@{
            id = $packId
            date = (Get-Date -Format "yyyy-MM-dd")
            type = "gallery"
            title = "$($workflowConfig.title) Pixel Scene Pack $packText"
            text = "$countText original public-safe 16:9 pixel art scene illustrations from the $($sourceEntries[0].sourceTitle) prompt set, generated through the local ComfyUI $($workflowConfig.title) workflow and published as optimized WebP feed media."
            media = $media.ToArray()
            url = "https://github.com/Gameyang/GPT-GenImage2-2D-Game-Art-Resource-Test/tree/main/public/assets/feed-optimized/$TaskId/$($workflowConfig.slug)/$sourceKey/pack-$packText"
            linkLabel = "View optimized WebP pack"
            tags = @($sourceEntries[0].sourceTag, $workflowConfig.title, "Pixel Art", "Non-commercial")
        }
        Add-OrReplaceFeedPost -Feed $feed -Post $post
        Write-JsonFile -Path $feedPath -Value $feed
        Assert-FocusedFeedPost -PostId $packId -ExpectedMedia $ImagesPerPack

        $completedPacks++
        Write-RunState -Status "running" -CompletedPacks $completedPacks -GeneratedPng $generatedPngCount -DeletedRawPng $deletedRawPngCount -Webp $webpCount -Committed $commitCount -Pushed $pushCount -CurrentPack $packId

        $publish = Invoke-GitPublish -CommitMessage "Add ComfyUI pixel scene pack $packText"
        if ($publish.committed) {
            $commitCount++
        }
        if ($publish.pushed) {
            $pushCount++
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$publish.warning)) {
            Write-Warning "Git publish warning for ${packId}: $($publish.warning)"
        }
        Write-RunState -Status "running" -CompletedPacks $completedPacks -GeneratedPng $generatedPngCount -DeletedRawPng $deletedRawPngCount -Webp $webpCount -Committed $commitCount -Pushed $pushCount -CurrentPack $packId

        $packIndex++
    }

    $summary = Assert-TaskFeed
    Write-RunState -Status "complete" -CompletedPacks $completedPacks -GeneratedPng $generatedPngCount -DeletedRawPng $deletedRawPngCount -Webp $webpCount -Committed $commitCount -Pushed $pushCount
    $publish = Invoke-GitPublish -CommitMessage "Update ComfyUI pixel scene feed run state"
    if ($publish.committed) {
        $commitCount++
    }
    if ($publish.pushed) {
        $pushCount++
    }
    Write-RunState -Status "complete" -CompletedPacks $completedPacks -GeneratedPng $generatedPngCount -DeletedRawPng $deletedRawPngCount -Webp $webpCount -Committed $commitCount -Pushed $pushCount
    Write-Host "Completed feed loop. posts=$($summary.posts) media=$($summary.media) webp=$webpCount generatedPng=$generatedPngCount deletedRawPng=$deletedRawPngCount commits=$commitCount pushes=$pushCount"
}
catch {
    $message = [string]$_
    Write-RunState -Status "error" -CompletedPacks $completedPacks -GeneratedPng $generatedPngCount -DeletedRawPng $deletedRawPngCount -Webp $webpCount -Committed $commitCount -Pushed $pushCount -CurrentPack "" -LastError $message
    Write-Error $message
    if (-not $ContinueOnError.IsPresent) {
        exit 1
    }
}
