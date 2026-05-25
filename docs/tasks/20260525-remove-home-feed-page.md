# 20260525 Remove Home Feed Page

## Scope

Remove the home/feed page runtime from this repository and keep the project focused on generated image resources. The feed UI will be implemented in a separate project.

## Files Touched

- Removed `public/index.html`
- Removed `public/css/`
- Removed `public/js/`
- Removed `public/data/`
- Removed `scripts/codex-turn-ended-hook.sh`
- Removed `scripts/publish-work-result.js`
- Removed `start-local-server.command`
- Removed `start-local-server.bat`
- Removed `docs/tasks/20260525-feed-usability-improvements.md`
- Updated `README.md`
- Updated `AGENTS.md`
- Removed `public/README.md`
- Removed `public/assets/.gitkeep`
- Updated prompt/task notes that referenced the old feed data

## Verification

- Confirmed `public/` now contains `assets/` and asset files only.
- Confirmed `public/assets/` contains 195 image files.
- Searched documentation and prompt notes for old page/feed file references.

## Follow-ups

- Build the new home/feed UI in the separate project and consume image resources from `public/assets/`.
