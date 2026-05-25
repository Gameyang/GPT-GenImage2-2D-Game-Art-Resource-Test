# 20260525 Home Feed Optimized Assets

## Scope

Create lighter public image variants for media referenced by `public/home-feed.json`, keeping the original publishable assets untouched. This follows the home feed publisher workflow: only public-safe assets are exposed, and feed media URLs remain relative to the static project feed.

## Files Touched

- `tools/optimize-home-feed-images.ps1`
- `public/assets/feed-optimized/20260525-home-feed-optimized-assets/`
- `public/home-feed.json`
- `docs/tasks/20260525-home-feed-optimized-assets.md`

## Approach

- Background feed images are resized to a maximum width of 1280px and exported as JPEG previews at quality 82.
- Transparent character concept images are resized to a maximum height of 768px and kept as PNG previews to preserve alpha.
- Existing playback GIFs are kept unchanged because they are already relatively small and animated GIF re-encoding is not available in this repository tooling.
- Original public source assets remain in their existing folders.

## Verification

- Ran `.\tools\optimize-home-feed-images.ps1`.
- Generated 11 optimized feed images and `manifest.json` under `public/assets/feed-optimized/20260525-home-feed-optimized-assets/`.
- Reduced the feed image media referenced by `public/home-feed.json` from 15,157,014 bytes to 2,217,066 bytes, saving 12,939,948 bytes / 85.37%.
- Updated `public/home-feed.json` image media URLs to point at optimized variants.
- Confirmed all media URLs referenced by `public/home-feed.json` exist under `public/`.
- Confirmed optimized backgrounds are `Format24bppRgb` JPEGs at max width 1280px.
- Confirmed optimized character previews are `Format32bppArgb` PNGs at 512x768 with alpha preserved.
- Confirmed `F:\Workspace\home\public\data\sources.json` parses successfully.
- Confirmed `F:\Workspace\home\public\js\main.js` passes `node --check`.

## Follow-ups

- If the public home UI later supports responsive sources, add optional full-resolution URLs beside the optimized preview URLs.
