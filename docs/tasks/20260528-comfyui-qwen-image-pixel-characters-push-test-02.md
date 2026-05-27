# 20260528-comfyui-qwen-image-pixel-characters-push-test-02

## Scope

- Generate one 4-image pixel character pack with local ComfyUI.
- Workflow: `qwen_image` using `workflow/qwen_image.json` only.
- Category: `characters`.
- Publishing mode: real-time commit/push after this ready pack.
- Storage mode: WebP-only public publishing; delete task-generated PNG intermediates after WebP validation.
- StopAt: 2026-05-28 02:00 KST, but stop earlier when the requested pack is complete.

## Expected Output

- Source PNGs generated: 4.
- Retained PNGs: 0.
- Optimized WebPs: 4.
- Feed posts: 1.
- Feed media: 4.

## Verification

- Passed: ComfyUI generated 4 Qwen Image character outputs.
- Passed: 4 optimized WebP files exist at 960x960 with nonzero sizes.
- Passed: project `public/home-feed.json` parses as JSON.
- Passed: feed post count is 1 and feed media count is 4.
- Passed: all feed media files exist under `public/assets/feed-optimized/20260528-comfyui-qwen-image-pixel-characters-push-test-02/`.
- Passed: task public PNG count is 0 and raw PNG count is 0 after cleanup.
- Passed: staged private/raw path check and staged task PNG check.

## Results

- Generated source PNGs: 4.
- Deleted public PNG intermediates: 4.
- Deleted raw PNG intermediates: 4.
- Retained PNGs: 0.
- Optimized WebPs: 4.
- Feed posts: 1.
- Feed media: 4.

## Follow-Ups

- None planned; this is the second requested real-time push test pack.
