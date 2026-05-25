# 20260525 Sprite Pivot Alignment

## Scope

Implement a local sprite-frame pivot alignment workflow for generated side-view animation frames. The tool follows the atlas-style approach used by common sprite packers: keep a stable logical canvas, compute visible alpha bounds, preserve trim offsets as metadata, and align each frame to a consistent pivot.

## Files Touched

- `tools/align-sprite-pivots.ps1`
- `tools/export-aligned-playback-gifs.ps1`
- `docs/tasks/20260525-sprite-pivot-alignment.md`
- `experiments/20260525-sprite-pivot-alignment/` after verification runs
- `public/assets/characters/sideview-pixel/animation/pivot-aligned/` after public asset runs

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
.\tools\align-sprite-pivots.ps1 -MaxPivotStepX 10 -MaxPivotStepY 8 -Smoothing 0.35 -OutputRoot experiments/20260525-sprite-pivot-alignment-smoothed
.\tools\export-aligned-playback-gifs.ps1
.\tools\align-sprite-pivots.ps1 -InputRoot public/assets/characters/sideview-pixel/animation/frames -OutputRoot public/assets/characters/sideview-pixel/animation/pivot-aligned
.\tools\export-aligned-playback-gifs.ps1 -MetadataPath public/assets/characters/sideview-pixel/animation/pivot-aligned/metadata.json -OutputDirectory public/assets/characters/sideview-pixel/animation/pivot-aligned/playback
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
- Updated `tools/align-sprite-pivots.ps1` to write BOM-free UTF-8 JSON metadata for Node-based verification.
- Re-ran pivot alignment directly into `public/assets/characters/sideview-pixel/animation/pivot-aligned/`.
- Generated 160 public aligned frame PNGs, 10 public aligned sheet PNGs, 10 public aligned playback GIFs, and public `metadata.json`.
- Confirmed public `metadata.json` parses with Node `JSON.parse`.
- Confirmed public sheet PNGs are `Format32bppArgb`.
- Confirmed public playback GIFs are readable as 16 frames each.
- Re-tested after playback review showed visible drift from smoothing. The original generated frames had large per-frame character position shifts, so the smoothed settings only corrected a few pixels per frame.
- Changed the default settings to strict pivot locking: `Smoothing 1`, `MaxPivotStepX 999`, and `MaxPivotStepY 999`.
- Re-generated `public/assets/characters/sideview-pixel/animation/pivot-aligned/` with strict pivot locking.
- Confirmed strict public output keeps computed raw pivot anchor spread at less than 1px on X and 0px on Y across all 10 character sets.

## Follow-ups

- If a runtime engine is selected later, add a small converter from `metadata.json` to that engine's preferred atlas schema.
- Attack frames with long weapons may still need per-character override rules if visual body center and attack silhouette center diverge too far.
