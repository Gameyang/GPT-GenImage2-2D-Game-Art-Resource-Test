# 20260526-jimeng-cli-integration

## Scope

Add a project-local Dreamina/Jimeng CLI setup and generation workflow for raw 2D game art source assets.

## Touched Files

- `.gitignore`
- `tools/install-dreamina-cli.ps1`
- `tools/jimeng-generate.ps1`
- `prompts/20260526-jimeng-cli-integration.md`
- `docs/tasks/20260526-jimeng-cli-integration.md`

## Implementation Notes

- The official Jimeng installer at `https://jimeng.jianying.com/cli` installs a `dreamina` CLI entrypoint.
- `tools/install-dreamina-cli.ps1` downloads the official Windows x64 binary into `.tools/dreamina/`.
- The downloaded metadata reports Dreamina CLI version `1.4.3`, release date `2026-05-07`.
- `.tools/` is ignored because the CLI binary and local metadata are machine-local install artifacts.
- `tools/jimeng-generate.ps1` resolves `.tools/dreamina/dreamina.exe` first, then falls back to `dreamina` on PATH.
- Raw generation outputs default to `raw/generated/<task-id>/`.

## Verification

- Done: ran `tools/install-dreamina-cli.ps1`.
- Done: downloaded the official Windows x64 CLI to `.tools/dreamina/dreamina.exe`.
- Done: confirmed `.tools/dreamina/dreamina.exe -h` works.
- Done: confirmed `.tools/dreamina/dreamina.exe text2image -h` lists supported model, ratio, and resolution values.
- Done: ran `tools/jimeng-generate.ps1` in `-DryRun` mode.
- Done: confirmed dry-run command metadata is written under `raw/generated/20260526-jimeng-cli-integration/`.
- Not run: real login or generation, because those require user account authorization and may consume credits.

## Follow-ups

- After login, run a small single-image text-to-image task and record the `submit_id` in the relevant task log.
- Curate reviewed outputs into `public/assets/characters/<task-id>/` or `public/assets/backgrounds/<task-id>/`.
