# Repository Guidelines

## Project Structure & Module Organization

This repository is an asset-only lab for GPT GenImage2 2D game art tests.

- `public/assets/` stores curated image resources that are safe to publish or copy into another project.
- `public/assets/characters/` stores publishable character concepts, animation sheets, cut frames, and playback GIFs.
- `public/assets/backgrounds/` stores publishable background and stage images.
- `prompts/` records prompt experiments.
- `raw/generated/` keeps source generated images before public curation.
- `raw/references/` and `internal-notes/` are private working material and should not be treated as public output.
- `docs/tasks/` is the task log area for planned or completed work.

## Task Isolation Workflow

Manage each requested work item as a separate task. Use a stable task id such as `20260525-sideview-pixel-characters` and record scope, touched files, verification, and follow-ups in `docs/tasks/<task-id>.md`.

Keep task artifacts grouped by the same id:

- Prompt notes: `prompts/<task-id>.md`
- Raw generated sources: `raw/generated/<task-id>/`
- Public assets: `public/assets/<category>/<task-id>/`
- Experiments: `experiments/<task-id>/`

Do not mix unrelated task changes in one edit, commit, or PR. Shared asset folders such as `public/assets/characters/`, `public/assets/backgrounds/`, and `raw/generated/` may be edited by multiple tasks, so update them narrowly and note the reason in the task log.

## Build, Test, and Development Commands

There is no package manager setup, build step, homepage, or feed publisher in this repository. Validate assets by checking file paths, image dimensions, and alpha channels where relevant.

## Coding Style & Naming Conventions

Use kebab-case for file and directory names and generated asset names, for example `character-sideview-01-adventurer-swordsman.png`.

## Testing Guidelines

No automated test framework is configured. Validate changes manually by confirming referenced assets exist, image dimensions are plausible for the asset type, and transparent PNGs have valid alpha where transparency is expected.

## Commit & Pull Request Guidelines

Recent commits use short imperative messages such as `Add initial project structure and files for 2D Game Art Resource Test`. Follow that style: start with a verb, keep the subject concise, and mention the affected area when useful.

Pull requests should describe the purpose, list changed public assets or raw generated sources, and note manual verification steps.

## Security & Configuration Tips

Keep private references, evaluation notes, and unpublished sources outside `public/`. Do not move `internal-notes/` or `raw/references/` content into public asset folders.
