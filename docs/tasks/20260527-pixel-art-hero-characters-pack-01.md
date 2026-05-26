# 20260527-pixel-art-hero-characters-pack-01

## Scope

Create the eighth 9-image high-quality pixel-art game asset set, focused on playable hero character concepts.

## Planned Files

- `prompts/20260527-pixel-art-hero-characters-pack-01.md`
- `raw/generated/20260527-pixel-art-hero-characters-pack-01/`
- `public/assets/characters/20260527-pixel-art-hero-characters-pack-01/`
- `public/assets/feed-optimized/20260527-pixel-art-hero-characters-pack-01/`
- `public/home-feed.json`
- `docs/tasks/20260527-pixel-art-hero-characters-pack-01.md`

## Generation Notes

- Generation path: built-in image generation tool.
- Transparency path: flat `#ff00ff` chroma-key background followed by local alpha extraction.
- Public feed media: lossless WebP previews generated from curated transparent PNGs.
- Raw generated source copies were kept under `raw/generated/20260527-pixel-art-hero-characters-pack-01/`, which is ignored by git per repository policy.

## Touched Files

- `prompts/20260527-pixel-art-hero-characters-pack-01.md`
- `public/assets/characters/20260527-pixel-art-hero-characters-pack-01/`
- `public/assets/feed-optimized/20260527-pixel-art-hero-characters-pack-01/`
- `public/home-feed.json`
- `docs/tasks/20260527-pixel-art-hero-characters-pack-01.md`

## Public Assets

- `pixel-hero-01-vanguard-knight.png`
- `pixel-hero-02-forest-ranger.png`
- `pixel-hero-03-arcane-mage.png`
- `pixel-hero-04-shadow-rogue.png`
- `pixel-hero-05-sun-cleric.png`
- `pixel-hero-06-clockwork-engineer.png`
- `pixel-hero-07-martial-monk.png`
- `pixel-hero-08-sea-corsair.png`
- `pixel-hero-09-crystal-lancer.png`

## Verification

- Done: generated 9 raw images with the built-in image generation tool.
- Done: removed chroma-key backgrounds into transparent PNGs.
- Done: visually checked local contact sheet at `raw/generated/20260527-pixel-art-hero-characters-pack-01/contact-sheet-alpha-check.png`.
- Done: validated all public PNGs are `1254x1254`, `Format32bppArgb`, with 4 transparent corners.
- Done: generated 9 feed WebP previews at `960x960`, `mode=RGBA`, lossless WebP.
- Done: feed WebP total size is 3,247,734 bytes, down 56.08% from the curated PNG total.
- Done: added post id `20260527-pixel-art-hero-characters-pack-01` to `public/home-feed.json`.
- Done: ran project feed JSON/media path check; `public/home-feed.json` parses and all 91 relative media paths exist.
- Done: verified `D:/Gameyang/home/public/data/sources.json` and `D:/Gameyang/home/public/data/local-sources.json` parse.
- Done: ran `node --check D:/Gameyang/home/public/js/main.js`.
- Done: committed and pushed to `origin/main` with commit `2f42fba`.
