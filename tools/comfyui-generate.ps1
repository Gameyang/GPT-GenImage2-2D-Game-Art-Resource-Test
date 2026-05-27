param(
    [Parameter(Mandatory = $true)][string]$TaskId,
    [Parameter(Mandatory = $true)][string]$Workflow,
    [string]$Prompt,
    [string]$PromptPath,
    [int]$Width = 0,
    [int]$Height = 0,
    [long]$Seed = -1,
    [string]$InputImage,
    [string]$FilenamePrefix,
    [string]$OutputRoot = "raw/generated",
    [string]$ComfyUrl = "http://127.0.0.1:8188",
    [string]$RegistryPath = "tools/comfyui-workflows.json",
    [int]$PollSeconds = 2,
    [int]$TimeoutSeconds = 900,
    [switch]$ForceFreeBeforeRun,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptDir ".."))
$comfyBase = $ComfyUrl.TrimEnd("/")

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

function Get-JsonProperty {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Name,
        [bool]$Required = $true
    )

    if ($null -eq $Value) {
        if ($Required) {
            throw "Missing JSON object while reading property '$Name'."
        }
        return $null
    }

    $property = $Value.PSObject.Properties[$Name]
    if ($null -eq $property) {
        if ($Required) {
            throw "Missing JSON property '$Name'."
        }
        return $null
    }

    return $property.Value
}

function Set-NodeInput {
    param(
        [Parameter(Mandatory = $true)]$PromptObject,
        [Parameter(Mandatory = $true)][string]$Node,
        [Parameter(Mandatory = $true)][string]$InputName,
        [Parameter(Mandatory = $true)]$Value
    )

    $nodeObject = Get-JsonProperty -Value $PromptObject -Name $Node
    $inputs = Get-JsonProperty -Value $nodeObject -Name "inputs"
    $property = $inputs.PSObject.Properties[$InputName]
    if ($null -eq $property) {
        Add-Member -InputObject $inputs -MemberType NoteProperty -Name $InputName -Value $Value
    }
    else {
        $property.Value = $Value
    }
}

function Remove-PromptNode {
    param(
        [Parameter(Mandatory = $true)]$PromptObject,
        [Parameter(Mandatory = $true)][string]$Node
    )

    $property = $PromptObject.PSObject.Properties[$Node]
    if ($null -ne $property) {
        $PromptObject.PSObject.Properties.Remove($Node)
    }
}

function Get-NodeInput {
    param(
        [Parameter(Mandatory = $true)]$PromptObject,
        [Parameter(Mandatory = $true)][string]$Node,
        [Parameter(Mandatory = $true)][string]$InputName
    )

    $nodeObject = Get-JsonProperty -Value $PromptObject -Name $Node
    $inputs = Get-JsonProperty -Value $nodeObject -Name "inputs"
    return Get-JsonProperty -Value $inputs -Name $InputName
}

function New-ComfySeed {
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $bytes = New-Object byte[] 8
        $rng.GetBytes($bytes)
        $value = [BitConverter]::ToUInt64($bytes, 0)
        return [long]($value % 9007199254740991)
    }
    finally {
        $rng.Dispose()
    }
}

function Invoke-ComfyGet {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$TimeoutSec = 30
    )

    return Invoke-RestMethod -Uri ($comfyBase + $Path) -Method Get -TimeoutSec $TimeoutSec
}

function Invoke-ComfyPost {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Body,
        [int]$TimeoutSec = 30
    )

    $json = $Body | ConvertTo-Json -Depth 100 -Compress
    return Invoke-RestMethod -Uri ($comfyBase + $Path) -Method Post -ContentType "application/json" -Body $json -TimeoutSec $TimeoutSec
}

function Upload-ComfyImage {
    param([Parameter(Mandatory = $true)][string]$Path)

    Add-Type -AssemblyName System.Net.Http
    $client = [System.Net.Http.HttpClient]::new()
    $form = [System.Net.Http.MultipartFormDataContent]::new()
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $fileContent = [System.Net.Http.StreamContent]::new($stream)
        $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/octet-stream")
        $form.Add($fileContent, "image", [System.IO.Path]::GetFileName($Path))
        $form.Add([System.Net.Http.StringContent]::new("input"), "type")
        $form.Add([System.Net.Http.StringContent]::new("true"), "overwrite")

        $response = $client.PostAsync(($comfyBase + "/upload/image"), $form).GetAwaiter().GetResult()
        $responseText = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if (-not $response.IsSuccessStatusCode) {
            throw "ComfyUI image upload failed with status $([int]$response.StatusCode): $responseText"
        }

        return $responseText | ConvertFrom-Json
    }
    finally {
        $stream.Dispose()
        $form.Dispose()
        $client.Dispose()
    }
}

function Get-WorkflowHash {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-WorkflowEntry {
    param(
        [Parameter(Mandatory = $true)]$Registry,
        [Parameter(Mandatory = $true)][string]$RequestedWorkflow
    )

    $requestedFull = $null
    if ([System.IO.Path]::IsPathRooted($RequestedWorkflow) -or $RequestedWorkflow -match "[\\/]" -or $RequestedWorkflow.EndsWith(".json")) {
        $requestedFull = Resolve-RepoPath -Path $RequestedWorkflow
    }

    foreach ($entry in $Registry.workflows) {
        if ([string]::Equals($entry.name, $RequestedWorkflow, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $entry
        }

        $entryFull = Resolve-RepoPath -Path $entry.path
        if ($null -ne $requestedFull -and [string]::Equals($entryFull, $requestedFull, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $entry
        }

        if ([string]::Equals((Split-Path -Leaf $entry.path), $RequestedWorkflow, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $entry
        }
    }

    throw "Workflow is not registered in ${RegistryPath}: $RequestedWorkflow"
}

function Get-HistoryItem {
    param(
        [Parameter(Mandatory = $true)]$History,
        [Parameter(Mandatory = $true)][string]$PromptId
    )

    return Get-JsonProperty -Value $History -Name $PromptId -Required $false
}

function Wait-ComfyPrompt {
    param(
        [Parameter(Mandatory = $true)][string]$PromptId,
        [Parameter(Mandatory = $true)][int]$PollIntervalSeconds,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        $history = Invoke-ComfyGet -Path ("/history/" + [Uri]::EscapeDataString($PromptId)) -TimeoutSec 30
        $item = Get-HistoryItem -History $history -PromptId $PromptId
        if ($null -ne $item) {
            $status = Get-JsonProperty -Value $item -Name "status" -Required $false
            if ($null -ne $status) {
                $statusString = Get-JsonProperty -Value $status -Name "status_str" -Required $false
                $completed = Get-JsonProperty -Value $status -Name "completed" -Required $false
                if ($statusString -match "error|failed") {
                    throw "ComfyUI prompt failed: $($status | ConvertTo-Json -Depth 20 -Compress)"
                }
                if ($completed -eq $true) {
                    return $item
                }
            }

            $outputs = Get-JsonProperty -Value $item -Name "outputs" -Required $false
            if ($null -ne $outputs) {
                return $item
            }
        }

        Start-Sleep -Seconds $PollIntervalSeconds
    }

    throw "Timed out waiting for ComfyUI prompt $PromptId after $TimeoutSeconds seconds."
}

function Get-HistoryImages {
    param([Parameter(Mandatory = $true)]$HistoryItem)

    $images = @()
    $outputs = Get-JsonProperty -Value $HistoryItem -Name "outputs"
    foreach ($outputProperty in $outputs.PSObject.Properties) {
        $nodeImages = Get-JsonProperty -Value $outputProperty.Value -Name "images" -Required $false
        if ($null -eq $nodeImages) {
            continue
        }

        foreach ($image in $nodeImages) {
            $images += $image
        }
    }

    return $images
}

function Download-ComfyImage {
    param(
        [Parameter(Mandatory = $true)]$Image,
        [Parameter(Mandatory = $true)][string]$OutputDirectory
    )

    $filename = [string](Get-JsonProperty -Value $Image -Name "filename")
    $subfolder = [string](Get-JsonProperty -Value $Image -Name "subfolder" -Required $false)
    $type = [string](Get-JsonProperty -Value $Image -Name "type" -Required $false)
    if ([string]::IsNullOrWhiteSpace($type)) {
        $type = "output"
    }

    $query = "?filename=$([Uri]::EscapeDataString($filename))&subfolder=$([Uri]::EscapeDataString($subfolder))&type=$([Uri]::EscapeDataString($type))"
    $localPath = Join-Path $OutputDirectory ([System.IO.Path]::GetFileName($filename))
    Invoke-WebRequest -Uri ($comfyBase + "/view" + $query) -OutFile $localPath -UseBasicParsing | Out-Null
    return $localPath
}

if ($TaskId -notmatch "^[0-9]{8}-[a-z0-9][a-z0-9-]*$") {
    throw "TaskId must use the repo task pattern, for example 20260527-comfyui-local-text2img-test."
}

if ($PollSeconds -lt 1) {
    throw "PollSeconds must be 1 or greater."
}

if ($TimeoutSeconds -lt $PollSeconds) {
    throw "TimeoutSeconds must be greater than or equal to PollSeconds."
}

if (-not [string]::IsNullOrWhiteSpace($Prompt) -and -not [string]::IsNullOrWhiteSpace($PromptPath)) {
    throw "Provide either Prompt or PromptPath, not both."
}

if ([string]::IsNullOrWhiteSpace($Prompt) -and [string]::IsNullOrWhiteSpace($PromptPath)) {
    throw "Provide Prompt or PromptPath."
}

if (($Width -gt 0 -and $Height -le 0) -or ($Height -gt 0 -and $Width -le 0)) {
    throw "Provide both Width and Height, or neither."
}

if ($Width -lt 0 -or $Height -lt 0) {
    throw "Width and Height must be positive values when provided."
}

if ($Seed -lt -1) {
    throw "Seed must be -1 for random, or 0 and above."
}

if (-not [string]::IsNullOrWhiteSpace($PromptPath)) {
    $promptFull = Resolve-RepoPath -Path $PromptPath
    $Prompt = (Get-Content -Raw -Encoding UTF8 -LiteralPath $promptFull).Trim()
}

$registryFull = Resolve-RepoPath -Path $RegistryPath
$registry = Get-Content -Raw -Encoding UTF8 -LiteralPath $registryFull | ConvertFrom-Json
$workflowEntry = Get-WorkflowEntry -Registry $registry -RequestedWorkflow $Workflow
$workflowName = [string](Get-JsonProperty -Value $workflowEntry -Name "name")
$workflowPathSetting = [string](Get-JsonProperty -Value $workflowEntry -Name "path")
$promptMap = Get-JsonProperty -Value $workflowEntry -Name "prompt"
$sizeMap = Get-JsonProperty -Value $workflowEntry -Name "size" -Required $false
$seedMap = Get-JsonProperty -Value $workflowEntry -Name "seed"
$filenamePrefixMap = Get-JsonProperty -Value $workflowEntry -Name "filenamePrefix"
$inputImageMap = Get-JsonProperty -Value $workflowEntry -Name "inputImage" -Required $false

$workflowFull = Resolve-RepoPath -Path $workflowPathSetting
$workflowRelative = Get-RelativePathText -BasePath $repoRoot -Path $workflowFull
$workflowHash = Get-WorkflowHash -Path $workflowFull
$workflowPrompt = Get-Content -Raw -Encoding UTF8 -LiteralPath $workflowFull | ConvertFrom-Json

$resolvedSeed = if ($Seed -eq -1) { New-ComfySeed } else { $Seed }
$resolvedPrefix = if ([string]::IsNullOrWhiteSpace($FilenamePrefix)) {
    "$TaskId-$workflowName"
}
else {
    $FilenamePrefix
}

Set-NodeInput -PromptObject $workflowPrompt -Node $promptMap.node -InputName $promptMap.input -Value $Prompt
Set-NodeInput -PromptObject $workflowPrompt -Node $seedMap.node -InputName $seedMap.input -Value $resolvedSeed
Set-NodeInput -PromptObject $workflowPrompt -Node $filenamePrefixMap.node -InputName $filenamePrefixMap.input -Value $resolvedPrefix

if ($Width -gt 0 -and $Height -gt 0) {
    if ($null -eq $sizeMap) {
        throw "Workflow '$workflowName' does not define size overrides."
    }
    Set-NodeInput -PromptObject $workflowPrompt -Node $sizeMap.node -InputName $sizeMap.widthInput -Value $Width
    Set-NodeInput -PromptObject $workflowPrompt -Node $sizeMap.node -InputName $sizeMap.heightInput -Value $Height
}

$uploadedImageName = $null
$inputImageFull = $null
if (-not [string]::IsNullOrWhiteSpace($InputImage)) {
    if ($null -eq $inputImageMap) {
        throw "Workflow '$workflowName' does not support InputImage."
    }

    $inputImageFull = Resolve-RepoPath -Path $InputImage
}
elseif ($null -ne $inputImageMap) {
    Set-NodeInput -PromptObject $workflowPrompt -Node $inputImageMap.switchNode -InputName $inputImageMap.switchInput -Value $inputImageMap.disabledValue
}

if ($workflowName -eq "hidream_o1" -and $null -eq $inputImageFull) {
    Set-NodeInput -PromptObject $workflowPrompt -Node "110" -InputName "text" -Value $Prompt
    Set-NodeInput -PromptObject $workflowPrompt -Node "108" -InputName "positive" -Value ([object[]]@("110", 0))
    Set-NodeInput -PromptObject $workflowPrompt -Node "108" -InputName "negative" -Value ([object[]]@("188", 0))
    Set-NodeInput -PromptObject $workflowPrompt -Node "108" -InputName "latent_image" -Value ([object[]]@("156", 0))

    foreach ($nodeToRemove in @(
        "104",
        "152",
        "153",
        "154",
        "155",
        "157",
        "171",
        "172",
        "176",
        "177",
        "213",
        "218",
        "219",
        "221",
        "175:164",
        "175:165",
        "175:166",
        "175:167",
        "175:170",
        "175:198",
        "175:201",
        "175:202"
    )) {
        Remove-PromptNode -PromptObject $workflowPrompt -Node $nodeToRemove
    }
}

$statePath = Join-Path $repoRoot ".tools/comfyui-runner-state.json"
$previousState = if (Test-Path -LiteralPath $statePath) {
    Get-Content -Raw -Encoding UTF8 -LiteralPath $statePath | ConvertFrom-Json
}
else {
    $null
}

$shouldFree = $ForceFreeBeforeRun.IsPresent
if ($null -ne $previousState) {
    $previousHash = Get-JsonProperty -Value $previousState -Name "workflowHash" -Required $false
    if (-not [string]::IsNullOrWhiteSpace($previousHash) -and -not [string]::Equals($previousHash, $workflowHash, [System.StringComparison]::OrdinalIgnoreCase)) {
        $shouldFree = $true
    }
}

$systemStats = Invoke-ComfyGet -Path "/system_stats" -TimeoutSec 10

if ($DryRun.IsPresent) {
    Write-Host "Dry run only. No prompt submitted."
    Write-Host "ComfyUI: $comfyBase"
    Write-Host "Workflow: $workflowName ($workflowRelative)"
    Write-Host "Seed: $resolvedSeed"
    Write-Host "Filename prefix: $resolvedPrefix"
    if ($Width -gt 0 -and $Height -gt 0) {
        Write-Host "Size override: ${Width}x${Height}"
    }
    else {
        Write-Host "Size override: unchanged"
    }
    if ($null -ne $inputImageFull) {
        Write-Host "Input image: $(Get-RelativePathText -BasePath $repoRoot -Path $inputImageFull)"
    }
    Write-Host "Would free VRAM before run: $shouldFree"
    exit 0
}

if ($shouldFree) {
    Write-Host "Freeing ComfyUI VRAM before workflow switch."
    Invoke-ComfyPost -Path "/free" -Body ([PSCustomObject]@{
        unload_models = $true
        free_memory = $true
    }) -TimeoutSec 30 | Out-Null
}

if ($null -ne $inputImageFull) {
    $upload = Upload-ComfyImage -Path $inputImageFull
    $uploadedImageName = [string]$upload.name
    $uploadedSubfolder = [string](Get-JsonProperty -Value $upload -Name "subfolder" -Required $false)
    if (-not [string]::IsNullOrWhiteSpace($uploadedSubfolder)) {
        $uploadedImageName = ($uploadedSubfolder.TrimEnd("/") + "/" + $uploadedImageName)
    }
    Set-NodeInput -PromptObject $workflowPrompt -Node $inputImageMap.node -InputName $inputImageMap.input -Value $uploadedImageName
    Set-NodeInput -PromptObject $workflowPrompt -Node $inputImageMap.switchNode -InputName $inputImageMap.switchInput -Value $inputImageMap.enabledValue
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputFull = Resolve-RepoPath -Path (Join-Path $OutputRoot $TaskId) -MustExist $false
New-Item -ItemType Directory -Force -Path $outputFull | Out-Null

$submittedWorkflowPath = Join-Path $outputFull ("comfyui-submitted-workflow-" + $timestamp + ".json")
Write-JsonFile -Path $submittedWorkflowPath -Value $workflowPrompt

$clientId = [Guid]::NewGuid().ToString()
$submitBody = [PSCustomObject]@{
    prompt = $workflowPrompt
    client_id = $clientId
}

Write-Host "Submitting ComfyUI prompt to $comfyBase."
$submitResponse = Invoke-ComfyPost -Path "/prompt" -Body $submitBody -TimeoutSec 60
$promptId = [string](Get-JsonProperty -Value $submitResponse -Name "prompt_id")
Write-Host "Prompt ID: $promptId"

$historyItem = Wait-ComfyPrompt -PromptId $promptId -PollIntervalSeconds $PollSeconds -TimeoutSeconds $TimeoutSeconds
$images = @(Get-HistoryImages -HistoryItem $historyItem)
if ($images.Count -eq 0) {
    throw "ComfyUI completed prompt $promptId but did not return any images."
}

$downloadedFiles = @()
foreach ($image in $images) {
    $downloadedFiles += Download-ComfyImage -Image $image -OutputDirectory $outputFull
}

$metadataPath = Join-Path $outputFull ("comfyui-generation-" + $timestamp + "-metadata.json")
$metadata = [PSCustomObject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    tool = "tools/comfyui-generate.ps1"
    taskId = $TaskId
    comfyUrl = $comfyBase
    workflow = [PSCustomObject]@{
        name = $workflowName
        path = $workflowRelative
        hash = $workflowHash
    }
    promptId = $promptId
    clientId = $clientId
    vramFreeCalled = $shouldFree
    overrides = [PSCustomObject]@{
        prompt = $Prompt
        width = if ($Width -gt 0) { $Width } else { $null }
        height = if ($Height -gt 0) { $Height } else { $null }
        seed = $resolvedSeed
        filenamePrefix = $resolvedPrefix
        inputImage = if ($null -ne $inputImageFull) { Get-RelativePathText -BasePath $repoRoot -Path $inputImageFull } else { $null }
        uploadedImageName = $uploadedImageName
    }
    outputRoot = Get-RelativePathText -BasePath $repoRoot -Path $outputFull
    submittedWorkflow = Get-RelativePathText -BasePath $repoRoot -Path $submittedWorkflowPath
    downloadedFiles = @($downloadedFiles | ForEach-Object { Get-RelativePathText -BasePath $repoRoot -Path $_ })
    systemStats = $systemStats
}
Write-JsonFile -Path $metadataPath -Value $metadata

$state = [PSCustomObject]@{
    schemaVersion = 1
    updatedAt = (Get-Date).ToString("s")
    comfyUrl = $comfyBase
    workflowName = $workflowName
    workflowPath = $workflowRelative
    workflowHash = $workflowHash
    promptId = $promptId
}
Write-JsonFile -Path $statePath -Value $state

Write-Host "Output: $(Get-RelativePathText -BasePath $repoRoot -Path $outputFull)"
foreach ($file in $downloadedFiles) {
    Write-Host "Downloaded: $(Get-RelativePathText -BasePath $repoRoot -Path $file)"
}
Write-Host "Metadata: $(Get-RelativePathText -BasePath $repoRoot -Path $metadataPath)"
