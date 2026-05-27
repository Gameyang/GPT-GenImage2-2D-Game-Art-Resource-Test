# 20260527 ComfyUI Local Text2Image Test

## Scope

- Add a local ComfyUI API runner for registered text-to-image workflows.
- Normalize workflow overrides for prompt, size, seed, filename prefix, and optional input image.
- Add a VRAM safety step that frees ComfyUI memory when switching between workflow files.
- Run one local generation test and keep outputs in `raw/generated/`.

## Files touched

- `tools/comfyui-generate.ps1`
- `tools/comfyui-workflows.json`
- `prompts/20260527-comfyui-local-text2img-test.md`
- `docs/tasks/20260527-comfyui-local-text2img-test.md`

## Verification

- Passed: ComfyUI `/system_stats` responded at `http://127.0.0.1:8188` and reported CUDA device availability.
- Passed: dry-run override checks for `qwen_image`, `pokemon`, and `hidream_o1`.
- Passed: generated and downloaded `raw/generated/20260527-comfyui-local-text2img-test/20260527-comfyui-local-text2img-test-qwen_image_00002_.png`.
- Passed: downloaded PNG verified as `1024x1024`, `Format24bppRgb`.
- Passed: after a `qwen_image` run, `pokemon` dry-run reported workflow-switch VRAM free as `True`.

## Follow-ups

- Curate successful raw outputs into `public/assets/` only after manual visual review.
