# 20260525 Home Feed WebP Optimized Assets

## Scope

Convert public home feed media to lighter WebP variants for the `home-feed-publisher` workflow. Keep source public assets and previous optimized JPG/PNG/GIF files intact, and update `public/home-feed.json` so the Weekly Project Home feed loads the WebP variants.

## Files Touched

- `tools/optimize-home-feed-webp.ps1`
- `public/home-feed.json`
- `public/assets/feed-optimized/20260525-home-feed-webp-optimized-assets/`
- `public/assets/feed-optimized/20260525-home-feed-optimized-assets/`
- `public/assets/backgrounds/20260525-sideview-platform-backgrounds/`
- `public/assets/characters/sideview-pixel/`
- `docs/tasks/20260525-home-feed-webp-optimized-assets.md`

## Approach

- Background feed previews are resized to max width 960px and exported as WebP.
- Character concept previews are resized to max height 640px and exported as WebP with alpha support.
- Animation playback previews are converted from GIF to animated WebP at max width 640px.
- Media entries with animation previews keep `type: "gif"` so the home UI animation filter still groups them with animated previews, while the URLs point to `.webp` files.
- `F:\Workspace\home\public\data\sources.json` remains unchanged because it points to the project feed endpoint, not individual media files.

## Verification

- Ran `.\tools\optimize-home-feed-webp.ps1`.
- Generated 15 WebP feed media files and `manifest.json` under `public/assets/feed-optimized/20260525-home-feed-webp-optimized-assets/`.
- Updated all 15 media URLs in `public/home-feed.json` to `.webp`.
- Reduced referenced feed media from 3,492,465 bytes to 636,542 bytes, saving 2,855,923 bytes / 81.77%.
- Confirmed all media URLs referenced by `public/home-feed.json` exist under `public/`.
- Removed 6 legacy character preview PNG files from `public/assets/feed-optimized/20260525-home-feed-optimized-assets/` after WebP feed URLs replaced them.
- Confirmed there are no remaining PNG files under `public/assets/feed-optimized/`.
- Removed the 11 old public post PNG source files that the previous deployed feed referenced directly: 5 background PNGs and 6 character concept PNGs.
- Updated post click-through URLs in `public/home-feed.json` to the WebP optimized asset folder instead of the old PNG source folders.
- Confirmed the four animation preview WebP files contain `ANIM` chunks and 4 `ANMF` frames each.
- Confirmed `public/home-feed.json` parses with Node `JSON.parse`.
- Confirmed `F:\Workspace\home\public\data\sources.json` parses successfully.
- Confirmed `F:\Workspace\home\public\js\main.js` passes `node --check`.

## Follow-ups

- If the home feed UI later supports responsive sources, keep WebP previews as the default and add optional full-resolution source URLs separately.
