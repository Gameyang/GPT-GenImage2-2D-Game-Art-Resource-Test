# 20260527 ComfyUI Local Text2Image Test

## Goal

Validate local Docker ComfyUI text-to-image generation with one game-resource-oriented prompt.

## Test Prompt

Pixel art game resource, single fantasy adventurer inventory item, enchanted bronze compass with a tiny blue crystal core, clean readable silhouette, centered object, transparent-friendly plain light background, crisp pixel edges, 2D RPG item icon style, no text, no watermark, no UI frame.

## Workflow Notes

- Runner target: `tools/comfyui-generate.ps1`
- Workflow registry: `tools/comfyui-workflows.json`
- First generation candidate: `workflow/qwen_image.json`
- Output policy: keep test results under `raw/generated/20260527-comfyui-local-text2img-test/`
