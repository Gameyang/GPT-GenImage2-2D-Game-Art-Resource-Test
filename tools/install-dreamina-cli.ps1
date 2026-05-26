param(
    [string]$InstallDir = ".tools/dreamina",
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

if (-not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
    throw "This project installer currently downloads the Windows Dreamina CLI. On macOS/Linux, use the official installer: curl -fsSL https://jimeng.jianying.com/cli | bash"
}

if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne [System.Runtime.InteropServices.Architecture]::X64) {
    throw "Only Windows x64 is supported by this installer."
}

$downloadBase = "https://lf3-static.bytednsdoc.com/obj/eden-cn/psj_hupthlyk/ljhwZthlaukjlkulzlp"
$binaryUrl = "$downloadBase/dreamina_cli_beta/dreamina_cli_windows_amd64.exe"
$skillUrl = "$downloadBase/dreamina_cli_beta/SKILL.md"
$versionUrl = "$downloadBase/version.json"

$installFull = [System.IO.Path]::GetFullPath($InstallDir)
$binaryPath = Join-Path $installFull "dreamina.exe"
$skillPath = Join-Path $installFull "SKILL.md"
$versionPath = Join-Path $installFull "version.json"

New-Item -ItemType Directory -Force -Path $installFull | Out-Null

if ((Test-Path -LiteralPath $binaryPath) -and -not $Force.IsPresent) {
    Write-Host "Dreamina CLI already exists: $binaryPath"
    Write-Host "Use -Force to download it again."
}
else {
    $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("dreamina-cli-" + [Guid]::NewGuid().ToString("N") + ".exe")
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $binaryUrl -OutFile $tempPath -TimeoutSec 120
        Move-Item -Force -LiteralPath $tempPath -Destination $binaryPath
    }
    finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -Force -LiteralPath $tempPath
        }
    }

    Write-Host "Downloaded Dreamina CLI: $binaryPath"
}

Invoke-WebRequest -UseBasicParsing -Uri $skillUrl -OutFile $skillPath -TimeoutSec 60
Invoke-WebRequest -UseBasicParsing -Uri $versionUrl -OutFile $versionPath -TimeoutSec 60

Write-Host "Installed official CLI references:"
Write-Host "Skill: $skillPath"
Write-Host "Version metadata: $versionPath"
Write-Host ""
Write-Host "Next steps:"
Write-Host ".\.tools\dreamina\dreamina.exe login"
Write-Host ".\tools\jimeng-generate.ps1 -TaskId 20260526-test -Prompt ""a side-view pixel art swordsman"" -DryRun"

