# 20260525 Sprite Pivot Reference One Character

## Scope

Use the two sample WebP images added under `prompts/` as reference for a better sprite alignment test. The reference style keeps sprites inside stable cells, holds grounded poses on a consistent baseline, preserves jump height changes, and allows intentional attack motion.

## Files Touched

- `tools/align-sprite-pivots.ps1`
- `tools/slice-sprite-sheet-cells.ps1`
- `experiments/20260525-grid-cell-pivot-test/`
- `experiments/20260525-sprite-pivot-reference-one-character/`
- `docs/tasks/20260525-sprite-pivot-reference-one-character.md`

## Approach

- Added `tools/slice-sprite-sheet-cells.ps1` to test the pure fixed-cell interpretation from the original 4x4 sheet.
- Generated a fixed-cell baseline test from `public/assets/characters/sideview-pixel/animation/animation-sheet-01-adventurer-swordsman.png`.
- Added single-folder input support to `tools/align-sprite-pivots.ps1`.
- Added action-preservation controls:
  - `PreserveVerticalActions`: keeps per-frame vertical offsets for actions like `jump`.
  - `PreserveHorizontalActions`: keeps per-frame horizontal offsets for actions like `attack`.
- Generated a one-character reference alignment test using:

```powershell
.\tools\align-sprite-pivots.ps1 `
  -InputRoot public/assets/characters/sideview-pixel/animation/frames/animation-sheet-01-adventurer-swordsman `
  -OutputRoot experiments/20260525-sprite-pivot-reference-one-character `
  -PreserveVerticalActions jump `
  -PreserveHorizontalActions attack

.\tools\export-aligned-playback-gifs.ps1 `
  -MetadataPath experiments/20260525-sprite-pivot-reference-one-character/metadata.json `
  -OutputDirectory experiments/20260525-sprite-pivot-reference-one-character/playback
```

## Verification

- Fixed-cell test generated 16 frames at 314x314, one 1256x1256 sheet, one 16-frame playback GIF, and metadata.
- Reference one-character test generated 16 frames, one 1400x1120 sheet, one 350x280 16-frame playback GIF, and metadata.
- Confirmed `experiments/20260525-sprite-pivot-reference-one-character/metadata.json` parses with Node `JSON.parse`.
- Confirmed idle and move anchors stay within 1px X spread and 0px Y spread.
- Confirmed jump keeps a 53px vertical arc.
- Confirmed attack keeps a 62px horizontal action offset while remaining on the grounded Y baseline.

## Follow-ups

- Review `experiments/20260525-sprite-pivot-reference-one-character/playback/playback-01-adventurer-swordsman.gif`.
- If this one-character test is visually acceptable, apply the same action-preservation settings to all 10 characters under a new public output folder.
