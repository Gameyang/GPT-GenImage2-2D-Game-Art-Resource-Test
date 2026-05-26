# 20260525-sideview-8x4-motion-sheets

## Scope

Create one `8 columns x 4 rows` side-view motion sheet for each of the four semi-realistic side-view characters.

## Touched Files

- `prompts/20260525-sideview-8x4-motion-sheets.md`
- `raw/generated/20260525-sideview-8x4-motion-sheets/`
- `public/assets/characters/20260525-sideview-8x4-motion-sheets/`
- `tools/export-motion-sheet-playbacks.ps1`

## Asset Plan

- `sheet-sideview-8x4-motion-01-vanguard-swordswoman-v2.png`
- `sheet-sideview-8x4-motion-02-desert-ranger-archer.png`
- `sheet-sideview-8x4-motion-03-arcane-herbalist-mage.png`
- `sheet-sideview-8x4-motion-04-clockwork-shield-engineer.png`

Note: the first swordswoman sheet was regenerated as `v2` because the first generated image was `1774x887`, which does not divide cleanly into an `8x4` grid.

## Motion Rows

- Row 1: idle, 8 frames
- Row 2: run, 8 frames
- Row 3: attack, 8 frames
- Row 4: jump, 8 frames

## Motion Export

- Added `tools/export-motion-sheet-playbacks.ps1` for folder-level export from `8 columns x 4 rows` motion sheets.
- The tool slices each valid sheet into temporary fixed-cell PNG frames.
- The tool estimates each RGB cell background from corner samples, measures the character foreground bbox, and computes a `BottomCenter` pivot.
- The tool aligns `idle`, `run`, and `attack` frames to a stable foot pivot; `jump` frames keep vertical motion while stabilizing horizontal pivot drift.
- The tool exports one 32-frame playback GIF per valid sheet under `playback/`.
- By default, temporary frame PNGs are deleted after GIF export to avoid keeping intermediate work files.
- Use `-KeepFrames` only when frame-level debugging is needed.
- The tool writes `metadata.json` with source sheet paths, cell sizes, row actions, playback paths, measured bboxes, raw pivots, corrected pivots, draw offsets, and skipped sheets.
- The original non-v2 swordswoman sheet is retained as a source artifact but skipped during playback export because its dimensions do not divide cleanly into `8x4`.

## Verification

- Done: generated source files copied to `raw/generated/20260525-sideview-8x4-motion-sheets/`.
- Done: public asset files copied to `public/assets/characters/20260525-sideview-8x4-motion-sheets/`.
- Done: final four public sheets are each `1536x1024`, `Format24bppRgb`, with no alpha channel.
- Done: final sheets divide cleanly into `8 columns x 4 rows`; expected cell size is `192x256`.
- Done: ran `.\tools\export-motion-sheet-playbacks.ps1`.
- Done: generated temporary fixed-cell frame PNGs for GIF export, then deleted `public/assets/characters/20260525-sideview-8x4-motion-sheets/frames/`.
- Done: generated four playback GIFs under `public/assets/characters/20260525-sideview-8x4-motion-sheets/playback/`.
- Done: confirmed each playback GIF is `192x256` and contains 32 frames.
- Done: confirmed `metadata.json` parses and records four processed sheets plus one skipped non-divisible sheet.
- Done: confirmed `metadata.json` records `keepFrames: false` and does not point at retained frame PNG outputs.
- Done: confirmed pivot alignment is enabled with `BottomCenter` mode and background distance threshold `42`.
- Done: confirmed corrected pivot spread is `0px` on X/Y for all `idle`, `run`, and `attack` rows.
- Done: confirmed `jump` rows have corrected X spread `0px`; mage and engineer retain vertical motion after median filtering.

## Follow-ups

- Optional: remove backgrounds and create alpha-ready sprite sheets.
- Optional: manually clean frame alignment if these are used in a production animation pipeline.
- Optional: export separate per-action GIFs for idle, run, attack, and jump if row-level review is needed.
