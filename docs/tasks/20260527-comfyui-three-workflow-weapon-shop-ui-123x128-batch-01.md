# 20260527 ComfyUI Three Workflow Weapon and Shop UI 123x128 Batch 01

## Scope

- Generate 9 weapon assets and 9 game shop UI assets from each of the three local ComfyUI workflows.
- Workflows: `qwen_image`, `pokemon`, `hidream_o1`.
- Publish exact `123x128` public PNG variants.
- Create optimized WebP feed previews for each public PNG.
- Add six gallery posts to `public/home-feed.json`.
- Keep raw ComfyUI sources under `raw/generated/` and do not stage them for publication.

## Files touched

- `tools/comfyui-generate-resolution-game-resource-batch.ps1`
- `tools/comfyui-resolution-resource-catalog.json`
- `prompts/20260527-comfyui-three-workflow-weapon-shop-ui-123x128-batch-01.md`
- `docs/tasks/20260527-comfyui-three-workflow-weapon-shop-ui-123x128-batch-01.md`
- `public/home-feed.json`
- `public/assets/equipment/20260527-comfyui-three-workflow-weapon-shop-ui-123x128-batch-01/`
- `public/assets/ui/20260527-comfyui-three-workflow-weapon-shop-ui-123x128-batch-01/`
- `public/assets/feed-optimized/20260527-comfyui-three-workflow-weapon-shop-ui-123x128-batch-01/`

## Verification

- Passed: ComfyUI health and empty queue check.
- Passed: dry-run script validation, 54 planned outputs.
- Passed: generated 54 public PNG assets.
- Passed: generated 54 optimized WebP feed previews.
- Passed: parsed `public/home-feed.json` and verified 6 task posts with 54 media entries.
- Passed: verified all feed media paths resolve under `public/` and point to `.webp` files.
- Passed: verified PNG dimensions are exactly `123x128`.
- Passed: verified WebP dimensions are exactly `123x128`.
- Passed: confirmed `D:\Gameyang\home` worktree is clean for home feed source registration context.
- Passed: real-time git pushes completed as feed sets finished:
  - `dbe9200` published `qwen_image` and `pokemon` / Z-Image weapon and shop UI feed sets.
  - `6e8bf64` published `hidream_o1` weapon feed set.
  - Final task-close commit publishes the `hidream_o1` shop UI feed set.

## Follow-ups

- Raw ComfyUI sources remain under `raw/generated/20260527-comfyui-three-workflow-weapon-shop-ui-123x128-batch-01/` and were intentionally not staged.
