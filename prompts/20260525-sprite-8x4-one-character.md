# 20260525 Sprite 8x4 One Character

## Goal

Generate a one-character side-view pixel-art sprite sheet using an 8 columns x 4 rows layout, then test pivot alignment from the generated frames.

## Reference Notes

- `prompts/b9c62d16-289b-4f7f-a3e7-0deb6f478d99_medium.webp`: 4x4 character sheet reference for style and row actions.
- `prompts/538f7cc1-5f27-4ec5-aa0d-2a9120163c78_medium.webp`: multi-row side-view sprite sheet reference for denser per-action frame counts.

## Final Generation Prompt

```text
Use case: stylized-concept
Asset type: 2D game character sprite sheet, side-view pixel art
Primary request: Create a clean production sprite sheet for one fantasy adventurer swordsman character, exactly 8 columns x 4 rows, exactly 32 isolated frames. The canvas should be wide 2:1.
Critical layout rule: every frame must stay fully inside its own invisible cell with large empty gutters between cells. No sword, slash effect, boot, hair, hand, cape, or pixel may cross into the neighboring cell. Leave at least 24 pixels of flat green empty space between each frame and every cell boundary.
Rows from top to bottom: idle, walk/run, jump, sword attack. Do not draw labels, row names, numbers, grid lines, or any text.
Subject: same character in every frame, side-view facing right, young blond adventurer swordsman in a blue tunic/outfit, brown boots, leather gloves, small short sword. Keep identity, outfit, scale, palette, and facing direction consistent across all cells.
Animation requirements: idle row has 8 subtle breathing/stance frames; walk/run row has 8 loop frames with alternating legs; jump row has 8 frames with crouch, takeoff, airborne pose, descent, and landing; attack row has 8 sword slash frames, but the sword and slash effect must remain inside each frame cell with generous blank space around it.
Style/medium: crisp readable 2D pixel art game asset, clean silhouette, nearest-neighbor pixel feel, no painterly blur.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for removal; no shadows, no floor plane, no checkerboard, no grid.
Constraints: exactly 8 columns and exactly 4 rows; one complete character per cell; no overlapping cells; no clipped body parts; no fragments at cell edges; no text; no watermark; do not use #00ff00 in the character or effects.
```

## Outputs

- Raw generated source: `raw/generated/20260525-sprite-8x4-one-character/source-8x4-generated-v2.png`
- Public alpha source: `public/assets/characters/sideview-pixel/animation/20260525-sprite-8x4-one-character/source-8x4-alpha.png`
- Public fixed-cell frames: `public/assets/characters/sideview-pixel/animation/20260525-sprite-8x4-one-character/cells/frames/animation-sheet-01-adventurer-swordsman/`
- Public pivot-aligned sheet: `public/assets/characters/sideview-pixel/animation/20260525-sprite-8x4-one-character/pivot-aligned/sheets/animation-sheet-01-adventurer-swordsman.png`
- Public playback GIF: `public/assets/characters/sideview-pixel/animation/20260525-sprite-8x4-one-character/pivot-aligned/playback/playback-01-adventurer-swordsman.gif`
