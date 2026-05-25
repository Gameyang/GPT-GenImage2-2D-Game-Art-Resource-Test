# 20260525 Sprite 8x4 One Character

## Scope

Create a one-character 8x4 side-view pixel sprite sheet test, remove the chroma-key background, slice it into 32 frames, and generate pivot-aligned playback under the public animation folder.

## Files Touched

- `prompts/20260525-sprite-8x4-one-character.md`
- `raw/generated/20260525-sprite-8x4-one-character/`
- `public/assets/characters/sideview-pixel/animation/20260525-sprite-8x4-one-character/`
- `tools/remove-chroma-key.ps1`
- `docs/tasks/20260525-sprite-8x4-one-character.md`

## Approach

- Generated a new 8 columns x 4 rows sprite sheet for one adventurer swordsman.
- Kept the raw generated PNGs under `raw/generated/20260525-sprite-8x4-one-character/`.
- Added `tools/remove-chroma-key.ps1` to convert the flat `#00ff00` generated background into PNG alpha without requiring Python.
- Used `tools/slice-sprite-sheet-cells.ps1` with `-Columns 8 -Rows 4` to cut 32 fixed-cell frames.
- Used `tools/align-sprite-pivots.ps1` with `-Columns 8 -AlphaThreshold 32 -PreserveVerticalActions jump`.
- Exported playback with `tools/export-aligned-playback-gifs.ps1` at 85ms per frame.

## Verification

- Final alpha source is 1774x887.
- Fixed slicing produced 32 frames at 222x222.
- Pivot-aligned output produced one 8x4 sheet and one 32-frame playback GIF.
- Final alpha source has transparent corners.
- Pivot-aligned cell size is 266x177.
- Anchor spread from `pivot-aligned/metadata.json`:
  - `idle`: X spread 0.693px, Y spread 0px
  - `move`: X spread 0.921px, Y spread 0px
  - `jump`: X spread 0.898px, Y spread 37px
  - `attack`: X spread 0.856px, Y spread 0px
- Visually inspected `pivot-aligned/sheets/animation-sheet-01-adventurer-swordsman.png` and `pivot-aligned/playback/playback-01-adventurer-swordsman.gif`.

## Follow-ups

- If the v2 playback is visually acceptable, use the same stricter 8x4 generation prompt for additional characters.
- If jump height should be encoded inside the sprite frames, generate another pass with a stronger row-specific vertical arc requirement before pivot alignment.
