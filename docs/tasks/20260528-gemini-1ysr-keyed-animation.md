# 20260528-gemini-1ysr-keyed-animation

## Scope

- Turn `raw/references/Gemini_Generated_Image_1ysr8x1ysr8x1ysr.png` into keyed animation outputs.
- Use the Godot atlas key/animation mapping from `systemchester/Spritesheetweapon`.
- Keep generated PNG/GIF outputs in `experiments/` because the input is a raw reference and should not be treated as a public curated asset yet.

## Source Key File

- GitHub directory: `https://github.com/systemchester/Spritesheetweapon/tree/master/05-%E6%88%90%E5%93%81%E9%A1%B9%E7%9B%AE`
- Key mapping used: `05-成品项目/AI像素商K/ocad/ocad_spritesheet_generator.gd`
- Image import sidecar checked: `05-成品项目/AI像素商K/18n/Gemini_Generated_Image_1ysr8x1ysr8x1ysr.png.import`

## Touched Files

- `tools/export-ocad-keyed-animation.ps1`
- `prompts/20260528-gemini-1ysr-keyed-animation.md`
- `docs/tasks/20260528-gemini-1ysr-keyed-animation.md`
- `experiments/20260528-gemini-1ysr-keyed-animation/` local generated output

## Animation Keys

- Exported 60 keyed atlas regions.
- Exported 16 animation GIFs: `attractL`, `climb`, `defence`, `die`, `idleL`, `idledown`, `idleup`, `item`, `jump`, `runL`, `rundown`, `runup`, `sitdown`, `walkL`, `walkdown`, `walkup`.
- The original Godot implementation mirrors left-facing states with `AnimatedSprite2D.flip_h` instead of duplicating right-facing atlas regions.

## Verification

- Done: confirmed source image is `252x252`, `Format32bppArgb`.
- Done: found matching GitHub source image and `.png.import` sidecar.
- Done: found `ocad_spritesheet_generator.gd` with `Rect2i` atlas regions and animation key arrays.
- Done: ran `.\tools\export-ocad-keyed-animation.ps1`.
- Done: generated `60` keyed frame PNGs under `experiments/20260528-gemini-1ysr-keyed-animation/frames/`.
- Done: generated `16` playback GIFs under `experiments/20260528-gemini-1ysr-keyed-animation/playback/`.
- Done: generated normalized transparent source sheet at `experiments/20260528-gemini-1ysr-keyed-animation/sheets/gemini-1ysr-ocad-keyed-transparent.png`.
- Done: confirmed `metadata.json` parses and records `60` frames plus `16` animations.
- Done: confirmed GIF frame counts and dimensions match their keyed region definitions.

## Follow-ups

- If publication rights are confirmed, promote selected outputs from `experiments/` into `public/assets/characters/20260528-gemini-1ysr-keyed-animation/`.
- Optional: add mirrored right-facing GIF previews for `idleL`, `runL`, `walkL`, and `attractL`.
