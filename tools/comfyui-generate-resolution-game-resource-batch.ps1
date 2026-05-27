param(
    [string]$TaskId = "20260527-comfyui-weapon-shop-ui-resolution-batch-01",
    [string[]]$Workflow = @("pokemon"),
    [string[]]$Categories = @("weapons", "shop-ui"),
    [string[]]$Sizes = @(),
    [int[]]$Resolutions = @(64, 128),
    [string]$CatalogPath = "tools/comfyui-resolution-resource-catalog.json",
    [string]$ComfyUrl = "http://127.0.0.1:8188",
    [int]$SourceSize = 0,
    [int]$TimeoutSeconds = 900,
    [int]$PollSeconds = 2,
    [int]$Quality = 90,
    [int]$Effort = 6,
    [int]$MaxItemsPerPack = 9,
    [switch]$SkipExisting,
    [switch]$ContinueOnError,
    [switch]$NoFeedUpdate,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir ".."))
$runner = Join-Path $scriptDir "comfyui-generate.ps1"

if (-not (Test-Path -LiteralPath $runner)) {
    throw "Missing runner: $runner"
}

if ($TaskId -notmatch "^[0-9]{8}-[a-z0-9][a-z0-9-]*$") {
    throw "TaskId must use the repo task pattern, for example 20260527-comfyui-weapon-shop-ui-resolution-batch-01."
}

if ($SourceSize -lt 0) {
    throw "SourceSize must be 0 for workflow defaults, or 64 and greater."
}

if ($SourceSize -gt 0 -and $SourceSize -lt 64) {
    throw "SourceSize must be 0 for workflow defaults, or 64 and greater."
}

if ($MaxItemsPerPack -lt 1 -or $MaxItemsPerPack -gt 9) {
    throw "MaxItemsPerPack must be between 1 and 9."
}

if ($Quality -lt 1 -or $Quality -gt 100) {
    throw "Quality must be between 1 and 100."
}

if ($Effort -lt 0 -or $Effort -gt 6) {
    throw "Effort must be between 0 and 6."
}

function Resolve-RepoPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [bool]$MustExist = $true
    )

    $resolved = if ([System.IO.Path]::IsPathRooted($Path)) {
        [System.IO.Path]::GetFullPath($Path)
    }
    else {
        [System.IO.Path]::GetFullPath((Join-Path $repoRoot $Path))
    }

    if ($MustExist -and -not (Test-Path -LiteralPath $resolved)) {
        throw "Path not found: $Path"
    }

    return $resolved
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

function Get-WorkflowConfig {
    param([Parameter(Mandatory = $true)][string]$WorkflowName)

    switch ($WorkflowName) {
        "qwen_image" {
            return [PSCustomObject]@{
                slug = "qwen-image"
                title = "Qwen Image"
                sourceSize = 1024
                style = "Premium pixel art marketplace asset, original non-branded game resource, crisp readable silhouette, limited palette, clean outline, polished 2D RPG production quality"
            }
        }
        "pokemon" {
            return [PSCustomObject]@{
                slug = "z-image"
                title = "Z-Image"
                sourceSize = 512
                style = "Clean collectible-game pixel art asset, original non-branded design, bold readable forms, simple color grouping, chunky pixel clusters, polished marketplace preview quality"
            }
        }
        "hidream_o1" {
            return [PSCustomObject]@{
                slug = "hidream-o1"
                title = "HiDream O1"
                sourceSize = 768
                style = "High-resolution premium pixel art game resource, original non-branded marketplace asset, detailed but readable forms, refined lighting, crisp 2D production art quality"
            }
        }
        default {
            throw "Unknown workflow: $WorkflowName"
        }
    }
}

function Get-CategoryConfig {
    param(
        [Parameter(Mandatory = $true)]$Catalog,
        [Parameter(Mandatory = $true)][string]$CategorySlug
    )

    $matches = @($Catalog.categories | Where-Object { [string]$_.slug -eq $CategorySlug })
    if ($matches.Count -ne 1) {
        throw "Expected exactly one catalog category for '$CategorySlug', found $($matches.Count)."
    }

    return $matches[0]
}

function ConvertTo-SizeSpec {
    param([Parameter(Mandatory = $true)][string]$Text)

    $trimmed = $Text.Trim().ToLowerInvariant()
    if ($trimmed -match "^([0-9]+)x([0-9]+)$") {
        $width = [int]$Matches[1]
        $height = [int]$Matches[2]
        if ($width -lt 1 -or $height -lt 1) {
            throw "Size dimensions must be positive: $Text"
        }

        return [PSCustomObject]@{
            width = $width
            height = $height
            slug = "${width}x${height}"
        }
    }

    if ($trimmed -match "^[0-9]+$") {
        $size = [int]$trimmed
        if ($size -lt 1) {
            throw "Size dimensions must be positive: $Text"
        }

        return [PSCustomObject]@{
            width = $size
            height = $size
            slug = "${size}x${size}"
        }
    }

    throw "Size must be formatted like 128 or 123x128: $Text"
}

function New-Prompt {
    param(
        [Parameter(Mandatory = $true)]$WorkflowConfig,
        [Parameter(Mandatory = $true)]$CategoryConfig,
        [Parameter(Mandatory = $true)]$Asset,
        [Parameter(Mandatory = $true)][string]$SizeSummary
    )

    return "$($WorkflowConfig.style), $($Asset.subject). $($CategoryConfig.promptTail) Designed as an original public-safe game asset source for exact $SizeSummary exported variants. Keep the design clean, centered, high quality, no watermark."
}

function Invoke-SharpResize {
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][string]$Format,
        [Parameter(Mandatory = $true)][int]$Width,
        [Parameter(Mandatory = $true)][int]$Height,
        [Parameter(Mandatory = $true)][int]$Quality,
        [Parameter(Mandatory = $true)][int]$Effort
    )

    $outputDir = Split-Path -Parent $OutputPath
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

    $tempRoot = Join-Path $repoRoot ".tools/sharp-tmp"
    $tempDir = Join-Path $tempRoot ([Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

    $rootRelative = Get-RelativePathText -BasePath $repoRoot -Path $InputPath
    $sharpInput = "./$rootRelative"
    $tempRelative = Get-RelativePathText -BasePath $repoRoot -Path $tempDir
    $sharpOutput = "./$tempRelative"
    $arguments = @("--yes", "--package=sharp-cli", "--", "sharp", "-i", $sharpInput, "-o", $sharpOutput, "-f", $Format)
    if ($Format -eq "webp") {
        $arguments += @("-q", "$Quality", "--alphaQuality", "$Quality", "--effort", "$Effort", "--lossless")
    }
    elseif ($Format -eq "png") {
        $arguments += @("--compressionLevel", "9", "--effort", "$Effort")
    }

    $arguments += @("resize", "$Width", "$Height", "--fit", "cover", "--kernel", "nearest")

    try {
        & npx @arguments
        if ($LASTEXITCODE -ne 0) {
            throw "sharp-cli failed for $InputPath"
        }

        $generated = Get-ChildItem -LiteralPath $tempDir -Filter "*.$Format" -File | Select-Object -First 1
        if ($null -eq $generated) {
            throw "No $Format output was generated for $InputPath"
        }

        Move-Item -LiteralPath $generated.FullName -Destination $OutputPath -Force
    }
    finally {
        $tempFull = [System.IO.Path]::GetFullPath($tempDir)
        $tempRootFull = [System.IO.Path]::GetFullPath($tempRoot)
        if ($tempFull.StartsWith($tempRootFull, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $tempFull)) {
            Remove-Item -LiteralPath $tempFull -Recurse -Force
        }
    }
}

function Find-ExistingSource {
    param([Parameter(Mandatory = $true)][string]$SourcePrefix)

    $rawDir = Join-Path $repoRoot ("raw/generated/$TaskId")
    if (-not (Test-Path -LiteralPath $rawDir)) {
        return $null
    }

    $candidate = Get-ChildItem -LiteralPath $rawDir -Filter "$SourcePrefix*.png" -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $candidate) {
        return $null
    }

    return $candidate.FullName
}

function Get-LatestDownloadedSource {
    param([Parameter(Mandatory = $true)][string]$RawTaskId)

    $rawDir = Join-Path $repoRoot ("raw/generated/$RawTaskId")
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

    return [System.IO.Path]::GetFullPath((Join-Path $repoRoot ([string]$downloadedFiles[0])))
}

function Add-OrReplaceFeedPost {
    param(
        [Parameter(Mandatory = $true)]$Feed,
        [Parameter(Mandatory = $true)]$Post
    )

    $remaining = @($Feed.posts | Where-Object { $_.id -ne $Post.id })
    $Feed.posts = @($Post) + $remaining
}

function Publish-FeedPost {
    param([Parameter(Mandatory = $true)]$Post)

    $feedPath = Join-Path $repoRoot "public/home-feed.json"
    $feed = Get-Content -Raw -Encoding UTF8 -LiteralPath $feedPath | ConvertFrom-Json
    Add-OrReplaceFeedPost -Feed $feed -Post $Post
    Write-JsonFile -Path $feedPath -Value $feed
}

$catalogFull = Resolve-RepoPath -Path $CatalogPath
$catalog = Get-Content -Raw -Encoding UTF8 -LiteralPath $catalogFull | ConvertFrom-Json
$workflowNames = @($Workflow | ForEach-Object { $_ -split "," } | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
if ($workflowNames.Count -lt 1) {
    throw "At least one workflow is required."
}

$sizeSpecs = if ($Sizes.Count -gt 0) {
    @($Sizes | ForEach-Object { ConvertTo-SizeSpec -Text $_ })
}
else {
    @($Resolutions | Sort-Object -Unique | ForEach-Object { ConvertTo-SizeSpec -Text ([string]$_) })
}
$sizeSpecs = @($sizeSpecs | Sort-Object slug -Unique)
if ($sizeSpecs.Count -lt 1) {
    throw "At least one output size is required."
}
$sizeSummary = (($sizeSpecs | ForEach-Object { $_.slug }) -join " and ")

$results = New-Object System.Collections.Generic.List[object]
$posts = New-Object System.Collections.Generic.List[object]

foreach ($workflowName in $workflowNames) {
    $workflowConfig = Get-WorkflowConfig -WorkflowName $workflowName
    $effectiveSourceSize = if ($SourceSize -gt 0) { $SourceSize } else { [int]$workflowConfig.sourceSize }

    foreach ($category in $Categories) {
        $categoryConfig = Get-CategoryConfig -Catalog $catalog -CategorySlug $category
        $assets = @($categoryConfig.assets | Select-Object -First $MaxItemsPerPack)
        if ($assets.Count -ne $MaxItemsPerPack) {
            throw "Category '$category' has $($assets.Count) asset definition(s), expected $MaxItemsPerPack."
        }

        $categoryResults = New-Object System.Collections.Generic.List[object]
        $index = 0
        foreach ($asset in $assets) {
            $index++
            $indexText = "{0:D2}" -f $index
            $baseFileStem = "pixel-$($categoryConfig.singular)-$indexText-$($asset.name)"
            $sourcePrefix = "$TaskId-source-$($workflowConfig.slug)-$category-$indexText-$($asset.name)"
            $prompt = New-Prompt -WorkflowConfig $workflowConfig -CategoryConfig $categoryConfig -Asset $asset -SizeSummary $sizeSummary

            $targetPaths = @()
            foreach ($sizeSpec in $sizeSpecs) {
                $fileStem = "$baseFileStem-$($sizeSpec.slug)-$($workflowConfig.slug)"
                $publicPath = Join-Path $repoRoot ("public/assets/$($categoryConfig.assetFolder)/$TaskId/$($workflowConfig.slug)/$($sizeSpec.slug)/$category/$fileStem.png")
                $webpPath = Join-Path $repoRoot ("public/assets/feed-optimized/$TaskId/$($workflowConfig.slug)/$($sizeSpec.slug)/$category/$fileStem-feed.webp")
                $targetPaths += [PSCustomObject]@{
                    width = [int]$sizeSpec.width
                    height = [int]$sizeSpec.height
                    sizeSlug = [string]$sizeSpec.slug
                    fileStem = $fileStem
                    publicPath = $publicPath
                    webpPath = $webpPath
                }
            }

            $needsSource = $true
            if ($SkipExisting.IsPresent) {
                $missingTargets = @($targetPaths | Where-Object {
                    -not (Test-Path -LiteralPath $_.publicPath) -or -not (Test-Path -LiteralPath $_.webpPath)
                })
                $needsSource = ($missingTargets.Count -gt 0)
            }

            $sourcePath = $null
            $sourceStatus = "not-needed"
            $sourceError = $null

            if ($DryRun.IsPresent) {
                $sourceStatus = "dry-run"
            }
            elseif ($needsSource) {
                try {
                    $existingSource = Find-ExistingSource -SourcePrefix $sourcePrefix
                    if ($null -ne $existingSource) {
                        Write-Host "Reusing source [$workflowName][$category] $indexText $($asset.name)"
                        $sourcePath = $existingSource
                        $sourceStatus = "reused-source"
                    }
                    else {
                        Write-Host "Generating source [$workflowName][$category] $indexText $($asset.name)"
                        $runnerParams = @{
                            TaskId = $TaskId
                            Workflow = $workflowName
                            Prompt = $prompt
                            Width = $effectiveSourceSize
                            Height = $effectiveSourceSize
                            FilenamePrefix = $sourcePrefix
                            ComfyUrl = $ComfyUrl
                            PollSeconds = $PollSeconds
                            TimeoutSeconds = $TimeoutSeconds
                        }
                        $runnerOutput = & $runner @runnerParams 2>&1
                        if (-not $?) {
                            throw (($runnerOutput | Out-String).Trim())
                        }

                        $sourcePath = Get-LatestDownloadedSource -RawTaskId $TaskId
                        $sourceStatus = "generated-source"
                    }
                }
                catch {
                    $sourceStatus = "failed"
                    $sourceError = [string]$_
                    if (-not $ContinueOnError.IsPresent) {
                        throw
                    }
                    Write-Warning "Failed source [$workflowName][$category] $indexText $($asset.name): $sourceError"
                }
            }

            foreach ($target in $targetPaths) {
                $result = [PSCustomObject]@{
                    workflow = $workflowName
                    workflowSlug = $workflowConfig.slug
                    category = $category
                    name = $asset.name
                    prompt = $prompt
                    sourceSize = "${effectiveSourceSize}x${effectiveSourceSize}"
                    width = $target.width
                    height = $target.height
                    size = $target.sizeSlug
                    publicAsset = Get-RelativePathText -BasePath $repoRoot -Path $target.publicPath
                    feedAsset = Get-RelativePathText -BasePath (Join-Path $repoRoot "public") -Path $target.webpPath
                    status = "pending"
                    error = $null
                }

                if ($DryRun.IsPresent) {
                    $result.status = "dry-run"
                }
                elseif ($SkipExisting.IsPresent -and (Test-Path -LiteralPath $target.publicPath)) {
                    if (Test-Path -LiteralPath $target.webpPath) {
                        $result.status = "skipped-existing"
                    }
                    else {
                        try {
                            Write-Host "Optimizing existing [$workflowName][$($target.sizeSlug)][$category] $indexText $($asset.name)"
                            Invoke-SharpResize -InputPath $target.publicPath -OutputPath $target.webpPath -Format "webp" -Width $target.width -Height $target.height -Quality $Quality -Effort $Effort
                            $result.status = "optimized-existing"
                        }
                        catch {
                            $result.status = "failed"
                            $result.error = [string]$_
                            if (-not $ContinueOnError.IsPresent) {
                                throw
                            }
                            Write-Warning "Failed existing optimization [$workflowName][$($target.sizeSlug)][$category] $indexText $($asset.name): $($result.error)"
                        }
                    }
                }
                elseif ($sourceStatus -eq "failed") {
                    $result.status = "failed"
                    $result.error = $sourceError
                }
                else {
                    try {
                        if ([string]::IsNullOrWhiteSpace($sourcePath)) {
                            throw "No source image available for $($asset.name)."
                        }

                        Write-Host "Exporting [$workflowName][$($target.sizeSlug)][$category] $indexText $($asset.name)"
                        Invoke-SharpResize -InputPath $sourcePath -OutputPath $target.publicPath -Format "png" -Width $target.width -Height $target.height -Quality $Quality -Effort $Effort
                        Invoke-SharpResize -InputPath $target.publicPath -OutputPath $target.webpPath -Format "webp" -Width $target.width -Height $target.height -Quality $Quality -Effort $Effort
                        $result.status = "generated"
                    }
                    catch {
                        $result.status = "failed"
                        $result.error = [string]$_
                        if (-not $ContinueOnError.IsPresent) {
                            throw
                        }
                        Write-Warning "Failed export [$workflowName][$($target.sizeSlug)][$category] $indexText $($asset.name): $($result.error)"
                    }
                }

                $categoryResults.Add($result) | Out-Null
                $results.Add($result) | Out-Null
            }
        }

        if (-not $DryRun.IsPresent) {
            foreach ($sizeSpec in $sizeSpecs) {
                $packResults = @($categoryResults | Where-Object { $_.size -eq $sizeSpec.slug })
                $successful = @($packResults | Where-Object { $_.status -in @("generated", "skipped-existing", "optimized-existing") })
                $publicDir = Join-Path $repoRoot ("public/assets/$($categoryConfig.assetFolder)/$TaskId/$($workflowConfig.slug)/$($sizeSpec.slug)/$category")
                $feedDir = Join-Path $repoRoot ("public/assets/feed-optimized/$TaskId/$($workflowConfig.slug)/$($sizeSpec.slug)/$category")

                if (-not (Test-Path -LiteralPath $publicDir)) {
                    New-Item -ItemType Directory -Force -Path $publicDir | Out-Null
                }
                if (-not (Test-Path -LiteralPath $feedDir)) {
                    New-Item -ItemType Directory -Force -Path $feedDir | Out-Null
                }

                $manifestPath = Join-Path $publicDir "manifest.json"
                Write-JsonFile -Path $manifestPath -Value ([PSCustomObject]@{
                    schemaVersion = 1
                    generatedAt = (Get-Date).ToString("s")
                    taskId = $TaskId
                    packId = "$TaskId-$($workflowConfig.slug)-$($sizeSpec.slug)-$category"
                    workflow = $workflowName
                    workflowTitle = $workflowConfig.title
                    category = $category
                    size = $sizeSpec.slug
                    width = $sizeSpec.width
                    height = $sizeSpec.height
                    sourceSize = "${effectiveSourceSize}x${effectiveSourceSize}"
                    publicDir = Get-RelativePathText -BasePath $repoRoot -Path $publicDir
                    feedDir = Get-RelativePathText -BasePath $repoRoot -Path $feedDir
                    assets = $packResults
                })

                if ($successful.Count -eq $MaxItemsPerPack) {
                    $media = @($successful | Sort-Object publicAsset | ForEach-Object {
                        [PSCustomObject]@{
                            type = "image"
                            url = $_.feedAsset
                            alt = "$($sizeSpec.slug) $($workflowConfig.title) pixel art $($categoryConfig.singular) asset: $($_.name -replace '-', ' ')"
                        }
                    })
                    $post = [PSCustomObject]@{
                        id = "$TaskId-$($workflowConfig.slug)-$($sizeSpec.slug)-$category"
                        date = (Get-Date -Format "yyyy-MM-dd")
                        type = "gallery"
                        title = "$($workflowConfig.title) $($sizeSpec.slug) Pixel Art $($categoryConfig.title) Set 01"
                        text = "Nine original public-safe $($sizeSpec.slug) pixel art $($categoryConfig.title.ToLowerInvariant()) generated through the local ComfyUI $($workflowConfig.title) workflow and exported as exact game-ready PNG variants with lossless WebP feed previews."
                        media = $media
                        url = "https://github.com/Gameyang/GPT-GenImage2-2D-Game-Art-Resource-Test/tree/main/public/assets/$($categoryConfig.assetFolder)/$TaskId/$($workflowConfig.slug)/$($sizeSpec.slug)/$category"
                        linkLabel = $categoryConfig.linkLabel
                        tags = @($categoryConfig.feedTag, $sizeSpec.slug, $workflowConfig.title, "Pixel Art", "Non-commercial")
                    }

                    $posts.Add($post) | Out-Null
                    if (-not $NoFeedUpdate.IsPresent) {
                        Publish-FeedPost -Post $post
                        Write-Host "Published feed post: $($post.id)"
                    }
                }
                else {
                    Write-Warning "Pack not published because $($successful.Count)/$MaxItemsPerPack media are ready: $TaskId-$($workflowConfig.slug)-$($sizeSpec.slug)-$category"
                }
            }
        }
    }
}

if (-not $DryRun.IsPresent) {
    $batchManifestPath = Join-Path $repoRoot ("public/assets/feed-optimized/$TaskId/manifest.json")
    Write-JsonFile -Path $batchManifestPath -Value ([PSCustomObject]@{
        schemaVersion = 1
        generatedAt = (Get-Date).ToString("s")
        taskId = $TaskId
        workflows = $workflowNames
        categories = $Categories
        sizes = @($sizeSpecs | ForEach-Object { $_.slug })
        maxItemsPerPack = $MaxItemsPerPack
        feedUpdated = (-not $NoFeedUpdate.IsPresent)
        totals = [PSCustomObject]@{
            total = $results.Count
            generated = @($results | Where-Object { $_.status -eq "generated" }).Count
            skippedExisting = @($results | Where-Object { $_.status -eq "skipped-existing" }).Count
            optimizedExisting = @($results | Where-Object { $_.status -eq "optimized-existing" }).Count
            failed = @($results | Where-Object { $_.status -eq "failed" }).Count
        }
        results = $results.ToArray()
        posts = $posts.ToArray()
    })

    Write-Host "Batch manifest: $(Get-RelativePathText -BasePath $repoRoot -Path $batchManifestPath)"
}

Write-Host "Total: $($results.Count), generated: $(@($results | Where-Object { $_.status -eq 'generated' }).Count), optimized-existing: $(@($results | Where-Object { $_.status -eq 'optimized-existing' }).Count), skipped: $(@($results | Where-Object { $_.status -eq 'skipped-existing' }).Count), failed: $(@($results | Where-Object { $_.status -eq 'failed' }).Count), dry-run: $(@($results | Where-Object { $_.status -eq 'dry-run' }).Count)"
