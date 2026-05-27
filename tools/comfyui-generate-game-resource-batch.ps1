param(
    [string]$TaskId = "20260527-comfyui-marketplace-game-resource-batch-01",
    [ValidateSet("qwen_image", "pokemon", "hidream_o1")]
    [string[]]$Workflows = @("qwen_image", "pokemon", "hidream_o1"),
    [string[]]$Categories = @("characters", "monsters", "backgrounds", "items", "inventory-ui"),
    [string]$CatalogPath,
    [string]$ComfyUrl = "http://127.0.0.1:8188",
    [int]$TimeoutSeconds = 900,
    [int]$PollSeconds = 2,
    [int]$Quality = 82,
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
    throw "TaskId must use the repo task pattern, for example 20260527-comfyui-marketplace-game-resource-batch-01."
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
    param([Parameter(Mandatory = $true)][string]$Text)

    $slug = $Text.ToLowerInvariant() -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")
    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw "Could not convert text to slug: $Text"
    }

    return $slug
}

function Get-WorkflowConfig {
    param([Parameter(Mandatory = $true)][string]$Workflow)

    switch ($Workflow) {
        "qwen_image" {
            return [PSCustomObject]@{
                slug = "qwen-image"
                title = "Qwen Image"
                squareSize = 1024
                backgroundWidth = 1344
                backgroundHeight = 768
                style = "Premium pixel art marketplace asset, original non-branded game resource, crisp readable silhouette, limited palette, clean outline, polished 2D RPG and platformer production quality"
            }
        }
        "pokemon" {
            return [PSCustomObject]@{
                slug = "z-image"
                title = "Z-Image"
                squareSize = 512
                backgroundWidth = 768
                backgroundHeight = 512
                style = "Clean collectible-game pixel art asset, original non-branded design, bold readable forms, simple color grouping, charming proportions, polished marketplace preview quality"
            }
        }
        "hidream_o1" {
            return [PSCustomObject]@{
                slug = "hidream-o1"
                title = "HiDream O1"
                squareSize = 768
                backgroundWidth = 1024
                backgroundHeight = 576
                style = "High-resolution premium pixel art game resource, original non-branded marketplace asset, detailed but readable forms, refined lighting, crisp 2D production art quality"
            }
        }
        default {
            throw "Unknown workflow: $Workflow"
        }
    }
}

function Get-CategoryConfig {
    param([Parameter(Mandatory = $true)][string]$Category)

    switch ($Category) {
        "characters" {
            return [PSCustomObject]@{
                assetFolder = "characters"
                singular = "character"
                title = "Characters"
                feedTag = "Character"
                linkLabel = "View character PNG assets"
                promptTail = "Full body playable character concept, idle-ready pose, centered single character, transparent-friendly plain light background, no text, no UI frame."
                aspect = "square"
            }
        }
        "monsters" {
            return [PSCustomObject]@{
                assetFolder = "characters"
                singular = "monster"
                title = "Monsters"
                feedTag = "Monster"
                linkLabel = "View monster PNG assets"
                promptTail = "Single enemy creature concept, full body, centered pose, clear attack silhouette, transparent-friendly plain light background, no text, no UI frame."
                aspect = "square"
            }
        }
        "backgrounds" {
            return [PSCustomObject]@{
                assetFolder = "backgrounds"
                singular = "background"
                title = "Backgrounds"
                feedTag = "Background"
                linkLabel = "View background PNG assets"
                promptTail = "Wide side-view stage background for a 2D game, layered parallax-ready composition, clear foreground platform area, rich midground and background depth, no characters, no text, no UI."
                aspect = "wide"
            }
        }
        "items" {
            return [PSCustomObject]@{
                assetFolder = "items"
                singular = "item"
                title = "Items"
                feedTag = "Item"
                linkLabel = "View item PNG assets"
                promptTail = "Single inventory item icon object, centered, readable at small size, transparent-friendly plain light background, no text, no UI frame."
                aspect = "square"
            }
        }
        "inventory-ui" {
            return [PSCustomObject]@{
                assetFolder = "ui"
                singular = "inventory-ui"
                title = "Inventory UI"
                feedTag = "Inventory UI"
                linkLabel = "View inventory UI PNG assets"
                promptTail = "Complete inventory UI panel kit for a game, item grid slots, equipment slots, resource counters, polished interface mockup, no readable text, no logos, clean marketplace preview."
                aspect = "square"
            }
        }
        default {
            if ($script:CatalogCategories.ContainsKey($Category)) {
                return $script:CatalogCategories[$Category]
            }

            throw "Unknown category: $Category"
        }
    }
}

function Get-AssetDefinitions {
    return @{
        characters = @(
            [PSCustomObject]@{ name = "sunblade-knight"; subject = "heroic sunblade knight with bronze armor, red scarf, short sword, compact shield" },
            [PSCustomObject]@{ name = "moonlit-ranger"; subject = "moonlit forest ranger with green cloak, short bow, leather quiver, calm stance" },
            [PSCustomObject]@{ name = "ember-apprentice-mage"; subject = "ember apprentice mage with orange robe, tiny flame familiar, wooden staff" },
            [PSCustomObject]@{ name = "clockwork-tinkerer"; subject = "clockwork tinkerer engineer with brass goggles, tool belt, small backpack device" },
            [PSCustomObject]@{ name = "marsh-healer"; subject = "marsh healer druid with teal cloak, herb pouch, glowing leaf charm" },
            [PSCustomObject]@{ name = "frost-lancer"; subject = "frost lancer guard with icy spear, blue mantle, silver shoulder plates" },
            [PSCustomObject]@{ name = "storm-monk"; subject = "storm monk brawler with wrapped fists, navy sash, crackling charm beads" },
            [PSCustomObject]@{ name = "coral-corsair"; subject = "coral corsair sailor with curved cutlass, sea-green coat, shell trinkets" },
            [PSCustomObject]@{ name = "crystal-summoner"; subject = "crystal summoner with violet robes, floating prism focus, ornate boots" }
        )
        monsters = @(
            [PSCustomObject]@{ name = "mossy-slime"; subject = "mossy cave slime enemy with blue body, leaf cap, tiny glowing core" },
            [PSCustomObject]@{ name = "rustbone-sentry"; subject = "rustbone skeleton sentry with cracked shield, short sword, red eye glow" },
            [PSCustomObject]@{ name = "mushroom-stomper"; subject = "forest mushroom stomper enemy with stout legs, spotted cap, angry face" },
            [PSCustomObject]@{ name = "gearwing-drone"; subject = "gearwing scout drone enemy with brass body, lens eye, small propellers" },
            [PSCustomObject]@{ name = "ember-bat"; subject = "ember bat enemy with dark wings, orange flame edges, sharp ears" },
            [PSCustomObject]@{ name = "ice-imp-scout"; subject = "ice imp scout enemy with fur hood, tiny spear, pale blue claws" },
            [PSCustomObject]@{ name = "rune-stone-golem"; subject = "small rune stone golem enemy with glowing teal chest core and heavy fists" },
            [PSCustomObject]@{ name = "lantern-wisp"; subject = "swamp lantern wisp enemy with floating green flame, small metal lantern frame" },
            [PSCustomObject]@{ name = "shadow-bandit-runner"; subject = "shadow bandit runner enemy with hood, dagger, nimble crouched stance" }
        )
        backgrounds = @(
            [PSCustomObject]@{ name = "ancient-forest-ruins"; subject = "ancient forest ruins stage with mossy stone arches, tree roots, readable ground path" },
            [PSCustomObject]@{ name = "lava-forge-depths"; subject = "lava forge depths stage with glowing furnaces, chains, basalt platforms" },
            [PSCustomObject]@{ name = "sky-castle-approach"; subject = "sky castle approach stage with floating stone bridge, clouds, distant towers" },
            [PSCustomObject]@{ name = "neon-rain-alley"; subject = "neon rain alley stage with wet pavement, shop signs without readable text, cyber panels" },
            [PSCustomObject]@{ name = "ice-cavern-shrine"; subject = "ice cavern shrine stage with blue crystals, frozen steps, soft cold glow" },
            [PSCustomObject]@{ name = "desert-sunken-temple"; subject = "desert sunken temple stage with sandstone pillars, dunes, warm sunset haze" },
            [PSCustomObject]@{ name = "swamp-witch-hamlet"; subject = "swamp witch hamlet stage with crooked huts, lanterns, shallow water" },
            [PSCustomObject]@{ name = "underwater-ruins"; subject = "underwater ruins stage with coral, broken columns, shafts of blue light" },
            [PSCustomObject]@{ name = "cozy-town-night"; subject = "cozy town night stage with cobblestone street, warm windows, festival flags" }
        )
        items = @(
            [PSCustomObject]@{ name = "sunsteel-sword"; subject = "sunsteel short sword with gold guard, red grip, bright gem pommel" },
            [PSCustomObject]@{ name = "moonwood-bow"; subject = "moonwood bow with silver tips, green string, leaf-carved handle" },
            [PSCustomObject]@{ name = "ember-staff"; subject = "ember mage staff with small flame crystal, carved wooden shaft" },
            [PSCustomObject]@{ name = "guardian-shield"; subject = "round guardian shield with blue enamel, brass rim, simple crest icon" },
            [PSCustomObject]@{ name = "healing-potion-crate"; subject = "small healing potion crate with red bottles, corks, rope handle" },
            [PSCustomObject]@{ name = "arcane-key"; subject = "arcane key with violet crystal teeth, silver bow, tiny sparkle" },
            [PSCustomObject]@{ name = "mana-crystal-cache"; subject = "cluster of mana crystals in teal and purple with small stone base" },
            [PSCustomObject]@{ name = "dash-boots"; subject = "leather dash boots with wing charms, blue straps, dust trail hint" },
            [PSCustomObject]@{ name = "merchant-coin-stack"; subject = "stack of gold merchant coins with tiny pouch and two loose gems" }
        )
        "inventory-ui" = @(
            [PSCustomObject]@{ name = "adventurer-backpack-panel"; subject = "adventurer backpack inventory panel with leather grid slots and small equipment area" },
            [PSCustomObject]@{ name = "arcane-library-inventory"; subject = "arcane library inventory panel with violet frame, spellbook slot, gem counters" },
            [PSCustomObject]@{ name = "blacksmith-stash-screen"; subject = "blacksmith stash inventory screen with iron slot grid, weapon area, warm forge trim" },
            [PSCustomObject]@{ name = "alchemist-kit-panel"; subject = "alchemist kit inventory panel with potion slots, ingredient tray, glass bottle icons" },
            [PSCustomObject]@{ name = "neon-runner-loadout"; subject = "neon runner loadout inventory UI with dark panels, cyan slot highlights, equipment sockets" },
            [PSCustomObject]@{ name = "pirate-cargo-inventory"; subject = "pirate cargo inventory panel with wood planks, rope border, coin and map slots" },
            [PSCustomObject]@{ name = "forest-ranger-pouch"; subject = "forest ranger pouch inventory UI with green cloth frame, arrow slots, herb pockets" },
            [PSCustomObject]@{ name = "frost-armory-panel"; subject = "frost armory inventory panel with icy blue frame, armor slots, crystal resource counters" },
            [PSCustomObject]@{ name = "merchant-shop-grid"; subject = "merchant shop inventory grid with parchment panels, price coin placeholders, item shelves" }
        )
    }
}

function New-Prompt {
    param(
        [Parameter(Mandatory = $true)]$WorkflowConfig,
        [Parameter(Mandatory = $true)]$CategoryConfig,
        [Parameter(Mandatory = $true)]$Asset
    )

    return "$($WorkflowConfig.style), $($Asset.subject). $($CategoryConfig.promptTail) Keep the design public-safe, original, cohesive, high quality, no watermark."
}

function Invoke-SharpWebp {
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][string]$Aspect,
        [Parameter(Mandatory = $true)][int]$Quality,
        [Parameter(Mandatory = $true)][int]$Effort
    )

    $outputDir = Split-Path -Parent $OutputPath
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

    $rootRelative = Get-RelativePathText -BasePath $repoRoot -Path $InputPath
    $sharpInput = "./$rootRelative"
    $outputRelative = Get-RelativePathText -BasePath $repoRoot -Path $outputDir
    $sharpOutput = "./$outputRelative"
    $inputStem = [System.IO.Path]::GetFileNameWithoutExtension($InputPath)
    $expectedOutput = Join-Path $outputDir "$inputStem.webp"

    if ((Test-Path -LiteralPath $expectedOutput) -and ($expectedOutput -ne $OutputPath)) {
        Remove-Item -LiteralPath $expectedOutput -Force
    }

    $arguments = @("--yes", "--package=sharp-cli", "--", "sharp", "-i", $sharpInput, "-o", $sharpOutput, "-f", "webp", "-q", "$Quality", "--alphaQuality", "$Quality", "--effort", "$Effort")
    if ($Aspect -eq "wide") {
        $arguments += @("resize", "1280", "--withoutEnlargement")
    }
    else {
        $arguments += @("resize", "--height", "960", "--withoutEnlargement")
    }

    try {
        & npx @arguments
        if ($LASTEXITCODE -ne 0) {
            throw "sharp-cli failed for $InputPath"
        }

        if (-not (Test-Path -LiteralPath $expectedOutput)) {
            throw "No WebP output was generated for $InputPath"
        }

        Move-Item -LiteralPath $expectedOutput -Destination $OutputPath -Force
        if (-not (Test-Path -LiteralPath $OutputPath)) {
            throw "WebP output could not be moved to $OutputPath"
        }
    }
    finally {
        if (($expectedOutput -ne $OutputPath) -and (Test-Path -LiteralPath $expectedOutput)) {
            Remove-Item -LiteralPath $expectedOutput -Force
        }
    }
}

function Add-OrReplaceFeedPost {
    param(
        [Parameter(Mandatory = $true)]$Feed,
        [Parameter(Mandatory = $true)]$Post
    )

    $remaining = @($Feed.posts | Where-Object { $_.id -ne $Post.id })
    $Feed.posts = @($Post) + $remaining
}

$script:CatalogCategories = @{}
$definitions = Get-AssetDefinitions
if (-not [string]::IsNullOrWhiteSpace($CatalogPath)) {
    $catalogFull = if ([System.IO.Path]::IsPathRooted($CatalogPath)) {
        [System.IO.Path]::GetFullPath($CatalogPath)
    }
    else {
        [System.IO.Path]::GetFullPath((Join-Path $repoRoot $CatalogPath))
    }

    if (-not (Test-Path -LiteralPath $catalogFull)) {
        throw "CatalogPath not found: $CatalogPath"
    }

    $catalog = Get-Content -Raw -Encoding UTF8 -LiteralPath $catalogFull | ConvertFrom-Json
    foreach ($categoryDef in $catalog.categories) {
        $slug = [string]$categoryDef.slug
        if ([string]::IsNullOrWhiteSpace($slug)) {
            throw "Catalog category is missing slug."
        }

        $script:CatalogCategories[$slug] = [PSCustomObject]@{
            assetFolder = [string]$categoryDef.assetFolder
            singular = [string]$categoryDef.singular
            title = [string]$categoryDef.title
            feedTag = [string]$categoryDef.feedTag
            linkLabel = [string]$categoryDef.linkLabel
            promptTail = [string]$categoryDef.promptTail
            aspect = if ([string]::IsNullOrWhiteSpace([string]$categoryDef.aspect)) { "square" } else { [string]$categoryDef.aspect }
        }

        $definitions[$slug] = @($categoryDef.assets | ForEach-Object {
            [PSCustomObject]@{
                name = [string]$_.name
                subject = [string]$_.subject
            }
        })
    }
}
$results = New-Object System.Collections.Generic.List[object]
$posts = New-Object System.Collections.Generic.List[object]

foreach ($workflow in $Workflows) {
    $workflowConfig = Get-WorkflowConfig -Workflow $workflow
    foreach ($category in $Categories) {
        $categoryConfig = Get-CategoryConfig -Category $category
        $assets = @($definitions[$category] | Select-Object -First $MaxItemsPerPack)
        $packId = "$TaskId-$($workflowConfig.slug)-$category"
        $publicDir = Join-Path $repoRoot ("public/assets/$($categoryConfig.assetFolder)/$TaskId/$($workflowConfig.slug)/$category")
        $feedDir = Join-Path $repoRoot ("public/assets/feed-optimized/$TaskId/$($workflowConfig.slug)/$category")
        New-Item -ItemType Directory -Force -Path $publicDir | Out-Null
        New-Item -ItemType Directory -Force -Path $feedDir | Out-Null

        $media = New-Object System.Collections.Generic.List[object]
        $packResults = New-Object System.Collections.Generic.List[object]
        $index = 0
        foreach ($asset in $assets) {
            $index++
            $indexText = "{0:D2}" -f $index
            $fileStem = "pixel-$($categoryConfig.singular)-$indexText-$($asset.name)-$($workflowConfig.slug)"
            $publicPath = Join-Path $publicDir "$fileStem.png"
            $webpPath = Join-Path $feedDir "$fileStem-feed.webp"
            $prompt = New-Prompt -WorkflowConfig $workflowConfig -CategoryConfig $categoryConfig -Asset $asset

            $width = if ($categoryConfig.aspect -eq "wide") { $workflowConfig.backgroundWidth } else { $workflowConfig.squareSize }
            $height = if ($categoryConfig.aspect -eq "wide") { $workflowConfig.backgroundHeight } else { $workflowConfig.squareSize }

            $result = [PSCustomObject]@{
                workflow = $workflow
                category = $category
                name = $asset.name
                prompt = $prompt
                width = $width
                height = $height
                publicAsset = Get-RelativePathText -BasePath $repoRoot -Path $publicPath
                feedAsset = Get-RelativePathText -BasePath (Join-Path $repoRoot "public") -Path $webpPath
                status = "pending"
                error = $null
            }

            if ($DryRun.IsPresent) {
                $result.status = "dry-run"
                $packResults.Add($result) | Out-Null
                $results.Add($result) | Out-Null
                continue
            }

            if ($SkipExisting.IsPresent -and (Test-Path -LiteralPath $publicPath)) {
                if (Test-Path -LiteralPath $webpPath) {
                    $result.status = "skipped-existing"
                }
                else {
                    try {
                        Write-Host "Optimizing existing [$workflow][$category] $indexText $($asset.name)"
                        Invoke-SharpWebp -InputPath $publicPath -OutputPath $webpPath -Aspect $categoryConfig.aspect -Quality $Quality -Effort $Effort
                        $result.status = "optimized-existing"
                    }
                    catch {
                        $result.status = "failed"
                        $result.error = [string]$_
                        if (-not $ContinueOnError.IsPresent) {
                            throw
                        }
                        Write-Warning "Failed [$workflow][$category] $indexText $($asset.name): $($result.error)"
                    }
                }
            }
            else {
                try {
                    Write-Host "Generating [$workflow][$category] $indexText $($asset.name)"
                    $runnerParams = @{
                        TaskId = $packId
                        Workflow = $workflow
                        Prompt = $prompt
                        Width = $width
                        Height = $height
                        FilenamePrefix = $fileStem
                        ComfyUrl = $ComfyUrl
                        PollSeconds = $PollSeconds
                        TimeoutSeconds = $TimeoutSeconds
                    }
                    $runnerOutput = & $runner @runnerParams 2>&1
                    if (-not $?) {
                        throw (($runnerOutput | Out-String).Trim())
                    }

                    $rawDir = Join-Path $repoRoot ("raw/generated/$packId")
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
                    Copy-Item -LiteralPath $downloadedFull -Destination $publicPath -Force
                    Invoke-SharpWebp -InputPath $publicPath -OutputPath $webpPath -Aspect $categoryConfig.aspect -Quality $Quality -Effort $Effort
                    $result.status = "generated"
                }
                catch {
                    $result.status = "failed"
                    $result.error = [string]$_
                    if (-not $ContinueOnError.IsPresent) {
                        throw
                    }
                    Write-Warning "Failed [$workflow][$category] $indexText $($asset.name): $($result.error)"
                }
            }

            if ($result.status -in @("generated", "skipped-existing", "optimized-existing")) {
                $media.Add([PSCustomObject]@{
                    type = "image"
                    url = $result.feedAsset
                    alt = "$($workflowConfig.title) pixel art $($categoryConfig.singular) asset: $($asset.name -replace '-', ' ')"
                }) | Out-Null
            }

            $packResults.Add($result) | Out-Null
            $results.Add($result) | Out-Null
        }

        if (-not $DryRun.IsPresent) {
            $manifestPath = Join-Path $publicDir "manifest.json"
            Write-JsonFile -Path $manifestPath -Value ([PSCustomObject]@{
                schemaVersion = 1
                generatedAt = (Get-Date).ToString("s")
                taskId = $TaskId
                packId = $packId
                workflow = $workflow
                category = $category
                publicDir = Get-RelativePathText -BasePath $repoRoot -Path $publicDir
                feedDir = Get-RelativePathText -BasePath $repoRoot -Path $feedDir
                assets = $packResults.ToArray()
            })
        }

        if ($media.Count -gt 0) {
            $postId = $packId
            $post = [PSCustomObject]@{
                id = $postId
                date = (Get-Date -Format "yyyy-MM-dd")
                type = "gallery"
                title = "$($workflowConfig.title) Pixel Art $($categoryConfig.title) Set 01"
                text = "Nine original public-safe pixel art $($categoryConfig.title.ToLowerInvariant()) generated through the local ComfyUI $($workflowConfig.title) workflow for marketplace-style game resource ideation."
                media = $media.ToArray()
                url = "https://github.com/Gameyang/GPT-GenImage2-2D-Game-Art-Resource-Test/tree/main/public/assets/$($categoryConfig.assetFolder)/$TaskId/$($workflowConfig.slug)/$category"
                linkLabel = $categoryConfig.linkLabel
                tags = @($categoryConfig.feedTag, $workflowConfig.title, "Pixel Art", "Non-commercial")
            }
            $posts.Add($post) | Out-Null
        }
    }
}

if (-not $DryRun.IsPresent -and -not $NoFeedUpdate.IsPresent -and $posts.Count -gt 0) {
    $feedPath = Join-Path $repoRoot "public/home-feed.json"
    $feed = Get-Content -Raw -Encoding UTF8 -LiteralPath $feedPath | ConvertFrom-Json
    foreach ($post in $posts) {
        Add-OrReplaceFeedPost -Feed $feed -Post $post
    }
    Write-JsonFile -Path $feedPath -Value $feed
}

$batchManifestPath = Join-Path $repoRoot ("public/assets/feed-optimized/$TaskId/manifest.json")
Write-JsonFile -Path $batchManifestPath -Value ([PSCustomObject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    taskId = $TaskId
    workflows = $Workflows
    categories = $Categories
    maxItemsPerPack = $MaxItemsPerPack
    feedUpdated = (-not $DryRun.IsPresent -and -not $NoFeedUpdate.IsPresent -and $posts.Count -gt 0)
    totals = [PSCustomObject]@{
        total = $results.Count
        generated = @($results | Where-Object { $_.status -eq "generated" }).Count
        skippedExisting = @($results | Where-Object { $_.status -eq "skipped-existing" }).Count
        optimizedExisting = @($results | Where-Object { $_.status -eq "optimized-existing" }).Count
        failed = @($results | Where-Object { $_.status -eq "failed" }).Count
        dryRun = @($results | Where-Object { $_.status -eq "dry-run" }).Count
    }
    results = $results.ToArray()
    posts = $posts.ToArray()
})

Write-Host "Batch manifest: $(Get-RelativePathText -BasePath $repoRoot -Path $batchManifestPath)"
Write-Host "Total: $($results.Count), generated: $(@($results | Where-Object { $_.status -eq 'generated' }).Count), optimized-existing: $(@($results | Where-Object { $_.status -eq 'optimized-existing' }).Count), skipped: $(@($results | Where-Object { $_.status -eq 'skipped-existing' }).Count), failed: $(@($results | Where-Object { $_.status -eq 'failed' }).Count)"
