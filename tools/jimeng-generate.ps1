param(
    [Parameter(Mandatory = $true)][string]$TaskId,
    [string]$Prompt,
    [string]$PromptPath,
    [string]$SubmitId,
    [ValidateSet("21:9", "16:9", "3:2", "4:3", "1:1", "3:4", "2:3", "9:16")]
    [string]$Ratio = "1:1",
    [ValidateSet("", "1k", "2k", "4k")]
    [string]$ResolutionType = "2k",
    [ValidateSet("", "3.0", "3.1", "4.0", "4.1", "4.5", "4.6", "5.0")]
    [string]$ModelVersion = "",
    [int]$PollSeconds = 0,
    [string]$OutputRoot = "raw/generated",
    [string]$DreaminaPath = "",
    [switch]$NoQueryAfterSubmit,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

    $json = $Value | ConvertTo-Json -Depth 30
    Write-TextFile -Path $Path -Text $json
}

function Resolve-DreaminaPath {
    param([string]$RequestedPath)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        if (Test-Path -LiteralPath $RequestedPath) {
            return [System.IO.Path]::GetFullPath($RequestedPath)
        }

        $requestedCommand = Get-Command $RequestedPath -ErrorAction SilentlyContinue
        if ($null -ne $requestedCommand) {
            return $requestedCommand.Source
        }

        throw "DreaminaPath not found: $RequestedPath"
    }

    $localPath = Join-Path (Get-Location).Path ".tools/dreamina/dreamina.exe"
    if (Test-Path -LiteralPath $localPath) {
        return $localPath
    }

    $pathCommand = Get-Command "dreamina" -ErrorAction SilentlyContinue
    if ($null -ne $pathCommand) {
        return $pathCommand.Source
    }

    throw "Dreamina CLI was not found. Run .\tools\install-dreamina-cli.ps1, or install the official CLI and make dreamina available on PATH."
}

function Invoke-Dreamina {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $output = & $Executable @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output | Out-String).Trim()

    if ($exitCode -ne 0) {
        throw "dreamina exited with code $exitCode.`n$text"
    }

    return $text
}

function ConvertFrom-JsonIfPossible {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    try {
        return $Text | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return $null
    }
}

function Find-PropertyValue {
    param(
        $Value,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [string]) {
        return $null
    }

    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            if ([string]::Equals([string]$key, $Name, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $Value[$key]
            }
        }
        foreach ($key in $Value.Keys) {
            $found = Find-PropertyValue -Value $Value[$key] -Name $Name
            if ($null -ne $found) {
                return $found
            }
        }
        return $null
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        foreach ($item in $Value) {
            $found = Find-PropertyValue -Value $item -Name $Name
            if ($null -ne $found) {
                return $found
            }
        }
        return $null
    }

    foreach ($property in $Value.PSObject.Properties) {
        if ([string]::Equals($property.Name, $Name, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $property.Value
        }
    }

    foreach ($property in $Value.PSObject.Properties) {
        $found = Find-PropertyValue -Value $property.Value -Name $Name
        if ($null -ne $found) {
            return $found
        }
    }

    return $null
}

function Format-CommandLine {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $parts = @($Executable) + $Arguments
    return ($parts | ForEach-Object {
        if ($_ -match "\s") {
            '"' + ($_ -replace '"', '\"') + '"'
        }
        else {
            $_
        }
    }) -join " "
}

if ($TaskId -notmatch "^[0-9]{8}-[a-z0-9][a-z0-9-]*$") {
    throw "TaskId must use the repo task pattern, for example 20260526-sideview-character-test."
}

if ($PollSeconds -lt 0) {
    throw "PollSeconds must be 0 or greater."
}

if (-not [string]::IsNullOrWhiteSpace($SubmitId) -and (-not [string]::IsNullOrWhiteSpace($Prompt) -or -not [string]::IsNullOrWhiteSpace($PromptPath))) {
    throw "Use SubmitId for query mode, or Prompt/PromptPath for generation mode, not both."
}

if ([string]::IsNullOrWhiteSpace($SubmitId) -and [string]::IsNullOrWhiteSpace($Prompt) -and [string]::IsNullOrWhiteSpace($PromptPath)) {
    throw "Provide Prompt, PromptPath, or SubmitId."
}

if (-not [string]::IsNullOrWhiteSpace($Prompt) -and -not [string]::IsNullOrWhiteSpace($PromptPath)) {
    throw "Provide either Prompt or PromptPath, not both."
}

if (-not [string]::IsNullOrWhiteSpace($PromptPath)) {
    if (-not (Test-Path -LiteralPath $PromptPath)) {
        throw "PromptPath not found: $PromptPath"
    }
    $Prompt = (Get-Content -Raw -LiteralPath $PromptPath).Trim()
}

if (-not [string]::IsNullOrWhiteSpace($ModelVersion) -and $ModelVersion -in @("3.0", "3.1") -and $ResolutionType -eq "4k") {
    throw "Dreamina text2image models 3.0/3.1 support resolution_type 1k or 2k, not 4k."
}

if (-not [string]::IsNullOrWhiteSpace($ModelVersion) -and $ModelVersion -notin @("3.0", "3.1") -and $ResolutionType -eq "1k") {
    throw "Dreamina text2image models 4.0 and later support resolution_type 2k or 4k, not 1k."
}

$dreamina = Resolve-DreaminaPath -RequestedPath $DreaminaPath
$rootForRelative = (Get-Location).Path
$outputFull = [System.IO.Path]::GetFullPath((Join-Path $OutputRoot $TaskId))
New-Item -ItemType Directory -Force -Path $outputFull | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$mode = if ([string]::IsNullOrWhiteSpace($SubmitId)) { "text2image" } else { "query_result" }

if ($mode -eq "text2image") {
    $arguments = @("text2image", "--prompt=$Prompt", "--ratio=$Ratio")
    if (-not [string]::IsNullOrWhiteSpace($ResolutionType)) {
        $arguments += "--resolution_type=$ResolutionType"
    }
    if (-not [string]::IsNullOrWhiteSpace($ModelVersion)) {
        $arguments += "--model_version=$ModelVersion"
    }
    if ($PollSeconds -gt 0) {
        $arguments += "--poll=$PollSeconds"
    }
}
else {
    $arguments = @("query_result", "--submit_id=$SubmitId", "--download_dir=$outputFull")
}

$commandLine = Format-CommandLine -Executable $dreamina -Arguments $arguments
$metadataPath = Join-Path $outputFull ("dreamina-" + $mode + "-" + $timestamp + "-command.json")

$metadata = [PSCustomObject]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString("s")
    tool = "tools/jimeng-generate.ps1"
    mode = $mode
    taskId = $TaskId
    outputRoot = (Get-RelativePathText -BasePath $rootForRelative -Path $outputFull)
    dreaminaPath = $dreamina
    command = $commandLine
    settings = [PSCustomObject]@{
        ratio = $Ratio
        resolutionType = $ResolutionType
        modelVersion = $ModelVersion
        pollSeconds = $PollSeconds
    }
    prompt = $Prompt
    submitId = $SubmitId
}

Write-JsonFile -Path $metadataPath -Value $metadata

if ($DryRun.IsPresent) {
    Write-Host "Dry run only. Command metadata written:"
    Write-Host (Get-RelativePathText -BasePath $rootForRelative -Path $metadataPath)
    Write-Host $commandLine
    exit 0
}

if ($mode -eq "text2image") {
    Write-Host "Submitting Dreamina text2image task. This can consume credits."
}
else {
    Write-Host "Querying Dreamina task and downloading ready media."
}

$responseText = Invoke-Dreamina -Executable $dreamina -Arguments $arguments
$responsePath = Join-Path $outputFull ("dreamina-" + $mode + "-" + $timestamp + "-response.txt")
Write-TextFile -Path $responsePath -Text $responseText

$parsed = ConvertFrom-JsonIfPossible -Text $responseText
if ($null -ne $parsed) {
    $jsonResponsePath = Join-Path $outputFull ("dreamina-" + $mode + "-" + $timestamp + "-response.json")
    Write-JsonFile -Path $jsonResponsePath -Value $parsed
}

$resolvedSubmitId = if ($mode -eq "text2image") { Find-PropertyValue -Value $parsed -Name "submit_id" } else { $SubmitId }
$genStatus = Find-PropertyValue -Value $parsed -Name "gen_status"

if ($null -ne $resolvedSubmitId) {
    Write-TextFile -Path (Join-Path $outputFull "submit-id.txt") -Text ([string]$resolvedSubmitId)
}

if ($mode -eq "text2image" -and $null -ne $resolvedSubmitId -and -not $NoQueryAfterSubmit.IsPresent) {
    $queryArguments = @("query_result", "--submit_id=$resolvedSubmitId", "--download_dir=$outputFull")
    $queryResponseText = Invoke-Dreamina -Executable $dreamina -Arguments $queryArguments
    $queryResponsePath = Join-Path $outputFull ("dreamina-query_result-" + $timestamp + "-response.txt")
    Write-TextFile -Path $queryResponsePath -Text $queryResponseText

    $queryParsed = ConvertFrom-JsonIfPossible -Text $queryResponseText
    if ($null -ne $queryParsed) {
        Write-JsonFile -Path (Join-Path $outputFull ("dreamina-query_result-" + $timestamp + "-response.json")) -Value $queryParsed
        $genStatus = Find-PropertyValue -Value $queryParsed -Name "gen_status"
    }
}

Write-Host "Output: $(Get-RelativePathText -BasePath $rootForRelative -Path $outputFull)"
if ($null -ne $resolvedSubmitId) {
    Write-Host "Submit ID: $resolvedSubmitId"
}
if ($null -ne $genStatus) {
    Write-Host "Generation status: $genStatus"
}

