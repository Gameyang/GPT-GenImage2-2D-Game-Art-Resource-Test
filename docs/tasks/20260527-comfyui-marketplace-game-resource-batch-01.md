# 20260527 ComfyUI Marketplace Game Resource Batch 01

## Scope

- Generate marketplace-style pixel art game resource packs through local ComfyUI.
- Create 9-image packs for characters, monsters, backgrounds, items, and inventory UI.
- Run packs across `qwen_image`, `pokemon`, and `hidream_o1` workflows when the local ComfyUI model setup supports them.
- Publish successful generated assets under `public/assets/` and optimized WebP previews under `public/assets/feed-optimized/`.
- Update `public/home-feed.json` with gallery posts for successful packs.

## Files touched

- `tools/comfyui-generate-game-resource-batch.ps1`
- `prompts/20260527-comfyui-marketplace-game-resource-batch-01.md`
- `docs/tasks/20260527-comfyui-marketplace-game-resource-batch-01.md`
- `public/home-feed.json`
- `public/assets/`

## Verification

- Passed: dry-run batch manifest for one qwen item.
- Passed: generated 135 public PNG assets across 3 workflows, 5 categories, 9 images each.
- Passed: generated 135 optimized WebP feed previews.
- Passed: `public/home-feed.json` parses and includes 15 new gallery posts with 135 media entries.
- Passed: all feed media paths resolve under `public/`.
- Passed: PNG dimensions match expected workflow/category sizes: 1024 square qwen assets, 512 square Z-Image assets, 768 square HiDream assets, and wide background variants.
- Passed: `D:\Gameyang\home` public and local source JSON parse; this project was already registered there.
- Passed: git commit and push.

## Follow-ups

- `F:\Workspace\home` is not present in this environment. The available home repo is `D:\Gameyang\home`, and it already points at this project's GitHub Pages feed.
- HiDream O1 text-to-image API payload needed prompt-refine/reference-image pruning before batch generation would submit successfully.
