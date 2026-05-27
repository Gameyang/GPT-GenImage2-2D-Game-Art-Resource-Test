# 20260528-comfyui-pixel-scene-feed-marathon-01

## Scope

- Run an unattended ComfyUI feed pipeline until before `2026-05-29 09:00 KST`.
- Source prompt files:
  - `prompts/20260527-pixel-art-imdb-top-100-scenes.md`
  - `prompts/20260527-fc-era-hd2d-pixel-scenes-prompts.md`
- Workflows:
  - `qwen_image` from `workflow/qwen_image.json`
  - `pokemon` from `workflow/포켓몬.json`
- Pack size: 4 images per feed gallery post.
- Workflow order: alternate by pack between `qwen_image` and `pokemon`.
- Source order: `imdb-top-100`, `fc-hd2d`, `fc-hd2d`, `imdb-top-100`, then repeat, so both workflows cover both prompt families over time.

## Confirmed Settings

- `stopAt`: `2026-05-29 09:00 KST`.
- `publishMode`: real-time feed update, validation, commit, and push after each ready pack.
- `followUpMode`: similar-only continuation packs if the base 200-image plan finishes before `stopAt`.
- `shutdownMode`: clean-stop after `stopAt`; no generator loop should remain running after the script exits.
- `storageMode`: WebP-only public publishing; delete task-generated PNG intermediates after WebP validation.
- `commitCadence`: each ready pack, with final validation before the last run-state push.

## Expected Base Output

- Source PNGs generated: 200.
- Retained PNGs: 0.
- Optimized WebPs: 200.
- Feed posts: 50.
- Feed media: 200.
- Follow-up continuation packs may add more posts/media in 4-image increments if time remains before `stopAt`.

## Task Artifacts

- Prompt notes: `prompts/20260528-comfyui-pixel-scene-feed-marathon-01.md`.
- Optimized feed media: `public/assets/feed-optimized/20260528-comfyui-pixel-scene-feed-marathon-01/`.
- Live run state: `public/assets/feed-optimized/20260528-comfyui-pixel-scene-feed-marathon-01/run-state.json`.
- Automation: `tools/comfyui-run-prompt-feed-loop.ps1`.

## Verification Plan

- Confirm ComfyUI queue and health before starting.
- For each ready pack:
  - Parse `public/home-feed.json`.
  - Verify the pack post exists with exactly 4 media entries.
  - Verify each media URL is project-relative `.webp`.
  - Verify each media file exists and has plausible WebP dimensions.
  - Reject staged `raw/`, `internal-notes/`, `.tools/`, `local-sources.json`, and task PNG paths before commit.
- At stop:
  - Count task posts and feed media.
  - Confirm all task feed media exists.
  - Confirm no task PNG files remain under the public feed media folder.

## Live Results

- Run started after user confirmation on `2026-05-28 KST`.
- Results are tracked incrementally in `run-state.json` and pack manifests.

## Follow-Ups

- If the run exits before `stopAt` because of a local ComfyUI or Git error, resume with `-SkipExisting` after fixing the external condition.
