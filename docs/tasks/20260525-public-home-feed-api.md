# 20260525 Public Home Feed API

## Scope

Expose this public asset lab to the separate `Gameyang/home` social feed by adding a static project feed JSON and GitHub Pages deployment workflow. The home repository consumes this feed as a visual social source.

## Files Touched

- `public/home-feed.json`
- `.github/workflows/deploy.yml`
- `README.md`
- `docs/tasks/20260525-public-home-feed-api.md`

## Verification

- Confirm `public/home-feed.json` is valid JSON.
- Confirm all media paths referenced by `public/home-feed.json` exist under `public/assets/`.
- Confirm `.github/workflows/deploy.yml` is present for GitHub Pages deployment from `public/`.

## Follow-ups

- Change the GitHub repository visibility to public in GitHub settings before relying on the public feed URL.
- Enable GitHub Pages with GitHub Actions for this repository if it is not already enabled.
