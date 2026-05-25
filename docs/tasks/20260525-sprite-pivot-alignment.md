# 20260525 Sprite Pivot Alignment

## Scope

Implement a local sprite-frame pivot alignment workflow for generated side-view animation frames. The tool follows the atlas-style approach used by common sprite packers: keep a stable logical canvas, compute visible alpha bounds, preserve trim offsets as metadata, and align each frame to a consistent pivot.

## Files Touched

- `tools/align-sprite-pivots.ps1`
- `tools/export-aligned-playback-gifs.ps1`
- `docs/tasks/20260525-sprite-pivot-alignment.md`
- `experiments/20260525-sprite-pivot-alignment/` after verification runs

## Algorithm

- Read transparent PNG frames from `public/assets/characters/sideview-pixel/animation/frames/`.
- Compute each frame's alpha bounding box using `AlphaThreshold`.
- Choose a raw pivot:
  - `BottomCenter`: lower-body alpha center on X and alpha bounds bottom on Y.
  - `Center`: alpha bounding-box center.
  - `Centroid`: alpha-weighted visual center.
- Smooth each motion sequence against the previous frame's pivot, clamping large X/Y jumps.
- Build a common logical cell per character so all frames share a stable target pivot.
- Export aligned frames, a 4-column PNG atlas sheet, playback GIFs, and JSON metadata containing `sourceSize`, `spriteSourceSize`, `rawPivot`, `smoothedPivot`, and `targetPivot`.

## Usage

```powershell
.\tools\align-sprite-pivots.ps1
```

Useful overrides:

```powershell
.\tools\align-sprite-pivots.ps1 -PivotMode Center -OutputRoot experiments/20260525-sprite-pivot-alignment-center
.\tools\align-sprite-pivots.ps1 -MaxPivotStepX 6 -MaxPivotStepY 4 -Smoothing 0.25
.\tools\export-aligned-playback-gifs.ps1
```

## Verification

- Ran `.\tools\align-sprite-pivots.ps1` against `public/assets/characters/sideview-pixel/animation/frames/`.
- Generated 160 aligned frame PNGs in `experiments/20260525-sprite-pivot-alignment/frames/`.
- Generated 10 aligned 4-column sheet PNGs in `experiments/20260525-sprite-pivot-alignment/sheets/`.
- Ran `.\tools\export-aligned-playback-gifs.ps1`.
- Generated 10 aligned playback GIFs in `experiments/20260525-sprite-pivot-alignment/playback/`.
- Generated `experiments/20260525-sprite-pivot-alignment/metadata.json`.
- Confirmed generated sheet PNGs are `Format32bppArgb` and keep alpha.
- Confirmed each character metadata entry has 16 frames, a common cell size, and a target pivot.
- Confirmed each playback GIF is readable as 16 frames.

## Follow-ups

- If a runtime engine is selected later, add a small converter from `metadata.json` to that engine's preferred atlas schema.
- Attack frames with long weapons may still need per-character override rules if visual body center and attack silhouette center diverge too far.
