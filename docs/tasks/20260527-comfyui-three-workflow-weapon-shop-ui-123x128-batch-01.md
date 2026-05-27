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
- Pending: dry-run script validation.
- Pending: generate 54 public PNG assets.
- Pending: generate 54 optimized WebP feed previews.
- Pending: parse `public/home-feed.json` and verify 6 task posts with 54 media entries.
- Pending: verify all feed media paths resolve under `public/`.
- Pending: verify PNG dimensions are exactly `123x128`.
- Pending: verify WebP dimensions are exactly `123x128`.
- Pending: verify home repo source JSON files parse.
- Pending: git commit and push.

## Follow-ups

- None yet.
