# 20260528-gemini-1ysr-keyed-animation

## Input

- Local source reference: `raw/references/Gemini_Generated_Image_1ysr8x1ysr8x1ysr.png`
- Source image size: `252x252`
- Source pixel format: `Format32bppArgb`

## External Key Mapping

The animation was implemented from the Godot atlas mapping in:

`https://github.com/systemchester/Spritesheetweapon/blob/master/05-%E6%88%90%E5%93%81%E9%A1%B9%E7%9B%AE/AI%E5%83%8F%E7%B4%A0%E5%95%86K/ocad/ocad_spritesheet_generator.gd`

Important mapping behavior:

- Frame regions are keyed with `Rect2i(x, y, w, h)`.
- Animation definitions are arrays of those frame keys.
- Right-facing states are intended to be produced by horizontal flip in Godot, not separate atlas keys.

## Output Plan

- Keep the original source in `raw/references/`.
- Generate normalized transparent sheet, keyed frame PNGs, playback GIFs, and metadata into `experiments/20260528-gemini-1ysr-keyed-animation/`.
- Do not move this reference-derived material into `public/` unless publication rights are confirmed.
