# Repository Guidelines

## Project Structure & Module Organization

This repository is a lightweight static site and asset lab for GPT GenImage2 2D game art tests.

- `public/` contains files safe to publish through GitHub Pages: `index.html`, `css/style.css`, `js/main.js`, JSON data, and public assets.
- `public/assets/characters/` stores publishable character previews.
- `public/data/test-pages.json` drives the homepage test page feed, while `work-feed.json` stores automated work posts.
- `prompts/` records prompt experiments.
- `raw/generated/` keeps source generated images before public curation.
- `raw/references/` and `internal-notes/` are private working material and should not be treated as public output.
- `scripts/` contains automation, including the Codex turn-ended publishing hook.

## Build, Test, and Development Commands

There is no package manager setup or build step.

Start a local static server from the repository root:

```sh
cd /Users/yang.jin/workspace/GPT-GenImage2-2D-Game-Art-Resource-Test
python3 -m http.server 8000 --directory public
```

Open `http://localhost:8000` in a browser to view the homepage. Stop the server with `Ctrl-C`. If port `8000` is busy, use another port, for example `python3 -m http.server 8010 --directory public`.

Run the feed publisher in dry-run mode before relying on hook output:

```sh
node scripts/publish-work-result.js --dry-run
```

Use `--force --dry-run` only when checking post formatting for changes that would normally be below the publishing threshold.

## Coding Style & Naming Conventions

Use two-space indentation for HTML, CSS, JSON, and JavaScript, matching the existing files. Keep JavaScript browser-native and dependency-free. Prefer `const`, small helper functions, and clear DOM selectors. Use kebab-case for file and directory names, CSS classes, JSON IDs, and generated asset names, for example `character-sideview-01-adventurer-swordsman.png`.

## Testing Guidelines

No automated test framework is configured. Validate changes manually by serving `public/`, checking the browser console, and confirming `test-pages.json` entries resolve to real assets. For script changes, run the Node command above and inspect the JSON-shaped result. Keep JSON files valid arrays or objects as expected by `public/js/main.js`.

## Commit & Pull Request Guidelines

Recent commits use short imperative messages such as `Add initial project structure and files for 2D Game Art Resource Test`. Follow that style: start with a verb, keep the subject concise, and mention the affected area when useful.

Pull requests should describe the purpose, list changed public assets or data files, note manual verification steps, and include screenshots for visible `public/` UI changes.

## Security & Configuration Tips

Keep private references, evaluation notes, and unpublished sources outside `public/`. The publisher already hides `internal-notes/` and `raw/references/`; do not bypass that separation when adding scripts or data.
