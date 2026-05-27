# 20260527 ComfyUI Expanded Pixel Resource Batch 02

## Scope

- Generate 20 additional 2D pixel game resource categories through local ComfyUI.
- Run each category through `qwen_image`, `pokemon`, and `hidream_o1`.
- Create 9 public PNG assets and 9 optimized WebP feed previews per workflow/category pack.
- Update `public/home-feed.json` with gallery posts for successful packs.
- Verify the existing home feed source registration in the available home repo.

## Files touched

- `tools/comfyui-generate-game-resource-batch.ps1`
- `tools/comfyui-resource-catalog-02.json`
- `prompts/20260527-comfyui-expanded-pixel-resource-batch-02.md`
- `docs/tasks/20260527-comfyui-expanded-pixel-resource-batch-02.md`
- `public/assets/`
- `public/home-feed.json`

## Verification

- Passed: dry-run selected exactly 20 catalog categories across 3 workflows for 60 workflow/category packs.
- Passed: generated 540 public PNG assets with 0 failed final results.
- Passed: created 540 optimized WebP feed previews; Qwen missing-preview retries optimized existing PNGs without regenerating images.
- Passed: `public/home-feed.json` parses, has 60 task gallery posts, has 540 task media entries, all task media are `.webp`, and all task media paths resolve.
- Passed: image dimension sanity check found 180 at 1024x1024, 180 at 512x512, and 180 at 768x768.
- Passed: selected-category manifest check found 60 pack manifests and 0 manifests outside the selected 20 categories.
- Passed: available home repo at `D:\Gameyang\home` has a registered public source for this project, and both source JSON files parse.
- Passed: git commit and push completed from this worktree.
