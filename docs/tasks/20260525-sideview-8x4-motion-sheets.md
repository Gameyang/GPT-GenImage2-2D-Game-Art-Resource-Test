# 20260525-sideview-8x4-motion-sheets

## Scope

Create one `8 columns x 4 rows` side-view motion sheet for each of the four semi-realistic side-view characters.

## Touched Files

- `prompts/20260525-sideview-8x4-motion-sheets.md`
- `raw/generated/20260525-sideview-8x4-motion-sheets/`
- `public/assets/characters/20260525-sideview-8x4-motion-sheets/`

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

## Verification

- Done: generated source files copied to `raw/generated/20260525-sideview-8x4-motion-sheets/`.
- Done: public asset files copied to `public/assets/characters/20260525-sideview-8x4-motion-sheets/`.
- Done: final four public sheets are each `1536x1024`, `Format24bppRgb`, with no alpha channel.
- Done: final sheets divide cleanly into `8 columns x 4 rows`; expected cell size is `192x256`.

## Follow-ups

- Optional: slice each sheet into individual cells.
- Optional: remove backgrounds and create alpha-ready sprite sheets.
- Optional: manually clean frame alignment if these are used in a production animation pipeline.
