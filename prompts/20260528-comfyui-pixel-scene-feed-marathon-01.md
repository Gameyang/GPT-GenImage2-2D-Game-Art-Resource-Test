# 20260528-comfyui-pixel-scene-feed-marathon-01

## Settings

- Use `prompts/20260527-pixel-art-imdb-top-100-scenes.md` and `prompts/20260527-fc-era-hd2d-pixel-scenes-prompts.md` as source prompt sets.
- Generate 4-image gallery packs.
- Alternate workflows by pack:
  - `qwen_image` (`workflow/qwen_image.json`)
  - `pokemon` (`workflow/포켓몬.json`)
- Publish optimized WebP feed media only.
- Delete task-generated PNG intermediates after WebP validation.
- Continue until before `2026-05-29 09:00 KST`.

## Pack Ordering

The automation uses this 4-pack source pattern while workflows alternate every pack:

1. `qwen_image` with `imdb-top-100`
2. `pokemon` with `fc-hd2d`
3. `qwen_image` with `fc-hd2d`
4. `pokemon` with `imdb-top-100`

This pattern repeats, giving both workflows coverage across both prompt families.

## Public-Safety Constraints

- No exact actor likeness.
- No exact movie frame recreation.
- No exact game screenshot, franchise, mascot, character, HUD, title screen, logo, or trademarked symbol.
- No readable text, letters, numbers, watermark, or brand marks.
- No private references or unpublished source material.

## Base Scope

- 100 IMDb-inspired cinematic pixel scene prompts.
- 100 FC-era HD-2D-inspired game scene prompts.
- 200 base generated images.
- 50 base feed posts.
- Follow-up continuation packs reuse the same prompt families as alternate compositions only if time remains before `stopAt`.
