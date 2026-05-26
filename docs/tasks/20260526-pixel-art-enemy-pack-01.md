# 20260526-pixel-art-enemy-pack-01

## Scope

Create the second 9-image high-quality pixel-art game asset set, this time focused on small enemy character concepts.

## Planned Files

- `prompts/20260526-pixel-art-enemy-pack-01.md`
- `raw/generated/20260526-pixel-art-enemy-pack-01/`
- `public/assets/characters/20260526-pixel-art-enemy-pack-01/`
- `public/assets/feed-optimized/20260526-pixel-art-enemy-pack-01/`
- `public/home-feed.json`
- `docs/tasks/20260526-pixel-art-enemy-pack-01.md`

## Generation Notes

- Generation path: built-in image generation tool.
- Transparency path: flat `#ff00ff` chroma-key background followed by local alpha extraction.
- Public feed media: lossless WebP previews generated from curated transparent PNGs.
- Raw generated source copies were kept under `raw/generated/20260526-pixel-art-enemy-pack-01/`, which is ignored by git per repository policy.

## Touched Files

- `prompts/20260526-pixel-art-enemy-pack-01.md`
- `public/assets/characters/20260526-pixel-art-enemy-pack-01/`
- `public/assets/feed-optimized/20260526-pixel-art-enemy-pack-01/`
- `public/home-feed.json`
- `docs/tasks/20260526-pixel-art-enemy-pack-01.md`

## Public Assets

- `pixel-enemy-01-cave-slime.png`
- `pixel-enemy-02-rusty-skeleton-guard.png`
- `pixel-enemy-03-forest-mushroom-stomper.png`
- `pixel-enemy-04-clockwork-scout-drone.png`
- `pixel-enemy-05-ember-bat.png`
- `pixel-enemy-06-ice-goblin-spearman.png`
- `pixel-enemy-07-stone-mini-golem.png`
- `pixel-enemy-08-swamp-lantern-wisp.png`
- `pixel-enemy-09-bandit-knife-runner.png`

## Verification

- Done: generated 9 raw images with the built-in image generation tool.
- Done: removed chroma-key backgrounds into transparent PNGs.
- Done: visually checked local contact sheet at `raw/generated/20260526-pixel-art-enemy-pack-01/contact-sheet-alpha-check.png`.
- Done: validated all public PNGs are `1254x1254`, `Format32bppArgb`, with 4 transparent corners.
- Done: generated 9 feed WebP previews at `960x960`, `mode=RGBA`, lossless WebP.
- Done: feed WebP total size is 2,836,160 bytes, down 56.5% from the curated PNG total.
- Done: added post id `20260526-pixel-art-enemy-pack-01` to `public/home-feed.json`.
- Done: ran project feed JSON/media path check; `public/home-feed.json` parses and all 37 relative media paths exist.
- Done: verified `D:/Gameyang/home/public/data/sources.json` and `D:/Gameyang/home/public/data/local-sources.json` parse.
- Done: ran `node --check D:/Gameyang/home/public/js/main.js`.
- Done: committed and pushed to `origin/main` with commit `a2fae38`.
