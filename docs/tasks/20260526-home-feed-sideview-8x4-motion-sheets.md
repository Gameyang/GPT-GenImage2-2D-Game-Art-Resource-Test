# 20260526-home-feed-sideview-8x4-motion-sheets

## Scope

Publish the `20260525-sideview-8x4-motion-sheets` character motion results to the Weekly Project Home feed.

## Touched Files

- `public/home-feed.json`
- `public/assets/feed-optimized/20260526-home-feed-sideview-8x4-motion-sheets/`
- `docs/tasks/20260526-home-feed-sideview-8x4-motion-sheets.md`
- `D:/Gameyang/home/public/data/local-sources.json`

## Feed Media

- Converted four public playback GIFs from `public/assets/characters/20260525-sideview-8x4-motion-sheets/playback/` to animated WebP previews.
- Kept the WebP previews at the source playback size, `192x256`, for direct motion review.
- Left original PNG sheets and GIF playbacks out of `media.url`; they remain public source assets linked from the post.

## Home Feed

- Added post id `20260525-sideview-8x4-motion-sheets`.
- Used `type: "gif"` with four animated WebP media items.
- Confirmed the public source id is `gpt-genimage2-2d-game-art-resource-test`.

## Verification

- Done: ran project feed JSON/media path check with Node; `public/home-feed.json` parses and all 19 relative media paths exist.
- Done: ran `tools/optimize-home-feed-webp.ps1` against a temporary feed containing the four playback GIFs.
- Done: confirmed the optimized media manifest records four animated WebP previews, each `192x256` with 32 frames.
- Done: confirmed home `public/data/sources.json` parses and contains only public HTTP(S) URLs.
- Done: confirmed home `public/data/local-sources.json` parses and maps `gpt-genimage2-2d-game-art-resource-test` to sibling project `GPT-GenImage2-2D-Game-Art-Resource-Test`.
- Done: ran `node --check public/js/main.js` in the home repo.
- Done: started `scripts/local-home-server.mjs` and confirmed `/__local_projects/GPT-GenImage2-2D-Game-Art-Resource-Test/home-feed.json` and the first WebP media URL return HTTP 200.
- Done: rendered the local home feed in Chromium via Playwright and confirmed the new post loads four `192x256` WebP images.
