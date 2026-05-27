# 20260527 ComfyUI Weapon and Shop UI Resolution Batch 01

## Scope

- Generate 9 weapon assets and 9 game shop UI assets using local ComfyUI.
- Publish exact `64x64` and `128x128` public PNG variants.
- Create optimized WebP feed previews for each public PNG.
- Add four gallery posts to `public/home-feed.json`.
- Keep raw ComfyUI sources under `raw/generated/` and do not stage them for publication.

## Files touched

- `tools/comfyui-resolution-resource-catalog.json`
- `tools/comfyui-generate-resolution-game-resource-batch.ps1`
- `prompts/20260527-comfyui-weapon-shop-ui-resolution-batch-01.md`
- `docs/tasks/20260527-comfyui-weapon-shop-ui-resolution-batch-01.md`
- `public/home-feed.json`
- `public/assets/equipment/20260527-comfyui-weapon-shop-ui-resolution-batch-01/`
- `public/assets/ui/20260527-comfyui-weapon-shop-ui-resolution-batch-01/`
- `public/assets/feed-optimized/20260527-comfyui-weapon-shop-ui-resolution-batch-01/`

## Verification

- Passed: ComfyUI health and empty queue check.
- Passed: dry-run script validation reported 36 target assets.
- Passed: generated 36 public PNG assets.
- Passed: generated 36 optimized WebP feed previews.
- Passed: `public/home-feed.json` parses and includes 4 task gallery posts with 36 media entries.
- Passed: all feed media paths resolve under `public/` and use `.webp`.
- Passed: PNG dimensions are exactly 18 files at `64x64` and 18 files at `128x128`.
- Passed: WebP dimensions are exactly 18 files at `64x64` and 18 files at `128x128`.
- Passed: `D:\Gameyang\home` public and local source JSON files parse, and this project is registered there.
- Passed: git commit and push.

## Follow-ups

- `F:\Workspace\home` is not present in this environment. The available home repo is `D:\Gameyang\home`.
- Raw generated ComfyUI source files remain under `raw/generated/20260527-comfyui-weapon-shop-ui-resolution-batch-01/` and are intentionally not staged.
