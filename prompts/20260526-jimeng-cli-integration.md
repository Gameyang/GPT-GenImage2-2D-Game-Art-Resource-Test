# 20260526-jimeng-cli-integration

## Purpose

Project-local notes for using the official Dreamina/Jimeng CLI to generate raw 2D game art sources.

## One-time Setup

```powershell
.\tools\install-dreamina-cli.ps1
.\.tools\dreamina\dreamina.exe login
```

The CLI uses OAuth device login. Complete the verification code in the browser window or URL printed by the CLI.

## Generate Text-to-Image

```powershell
.\tools\jimeng-generate.ps1 `
  -TaskId 20260526-sample-jimeng-character `
  -Prompt "side-view 2D game character concept, clean silhouette, transparent-friendly background, animation-ready costume details" `
  -Ratio 1:1 `
  -ResolutionType 2k `
  -ModelVersion 5.0 `
  -PollSeconds 60
```

Outputs are written to:

```text
raw/generated/<task-id>/
```

Curate successful outputs manually into:

```text
public/assets/characters/<task-id>/
public/assets/backgrounds/<task-id>/
```

## Query Existing Submit ID

```powershell
.\tools\jimeng-generate.ps1 `
  -TaskId 20260526-sample-jimeng-character `
  -SubmitId <submit-id>
```

## Notes

- The official CLI command is `dreamina`; this repository keeps the wrapper named `jimeng-generate.ps1` because the requested workflow is Jimeng/即梦.
- Generation commands can consume account credits.
- Keep raw downloads in `raw/generated/` until the asset is reviewed and curated.

