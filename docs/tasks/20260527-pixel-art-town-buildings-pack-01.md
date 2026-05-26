# 20260527-pixel-art-town-buildings-pack-01

## Scope

Create the fifth 9-image high-quality pixel-art game asset set, focused on town and shop building exteriors.

## Planned Files

- `prompts/20260527-pixel-art-town-buildings-pack-01.md`
- `raw/generated/20260527-pixel-art-town-buildings-pack-01/`
- `public/assets/buildings/20260527-pixel-art-town-buildings-pack-01/`
- `public/assets/feed-optimized/20260527-pixel-art-town-buildings-pack-01/`
- `public/home-feed.json`
- `docs/tasks/20260527-pixel-art-town-buildings-pack-01.md`

## Generation Notes

- Generation path: built-in image generation tool.
- Transparency path: flat `#ff00ff` chroma-key background followed by local alpha extraction.
- Public feed media: lossless WebP previews generated from curated transparent PNGs.
- Raw generated source copies were kept under `raw/generated/20260527-pixel-art-town-buildings-pack-01/`, which is ignored by git per repository policy.

## Touched Files

- `prompts/20260527-pixel-art-town-buildings-pack-01.md`
- `public/assets/buildings/20260527-pixel-art-town-buildings-pack-01/`
- `public/assets/feed-optimized/20260527-pixel-art-town-buildings-pack-01/`
- `public/home-feed.json`
- `docs/tasks/20260527-pixel-art-town-buildings-pack-01.md`

## Public Assets

- `pixel-building-01-blacksmith-shop.png`
- `pixel-building-02-alchemist-cottage.png`
- `pixel-building-03-cozy-inn.png`
- `pixel-building-04-adventurer-guild-hall.png`
- `pixel-building-05-magic-bookshop.png`
- `pixel-building-06-market-stall.png`
- `pixel-building-07-fisher-hut.png`
- `pixel-building-08-clockwork-workshop.png`
- `pixel-building-09-windmill-farmhouse.png`

## Verification

- Done: generated 9 raw images with the built-in image generation tool.
- Done: removed chroma-key backgrounds into transparent PNGs.
- Done: visually checked local contact sheet at `raw/generated/20260527-pixel-art-town-buildings-pack-01/contact-sheet-alpha-check.png`.
- Done: validated all public PNGs are `1254x1254`, `Format32bppArgb`, with 4 transparent corners.
- Done: generated 9 feed WebP previews at `960x960`, `mode=RGBA`, lossless WebP.
- Done: feed WebP total size is 6,693,440 bytes, down 56.56% from the curated PNG total.
- Done: added post id `20260527-pixel-art-town-buildings-pack-01` to `public/home-feed.json`.
- Done: ran project feed JSON/media path check; `public/home-feed.json` parses and all 64 relative media paths exist.
- Done: verified `D:/Gameyang/home/public/data/sources.json` and `D:/Gameyang/home/public/data/local-sources.json` parse.
- Done: ran `node --check D:/Gameyang/home/public/js/main.js`.
- Pending: commit and push.
