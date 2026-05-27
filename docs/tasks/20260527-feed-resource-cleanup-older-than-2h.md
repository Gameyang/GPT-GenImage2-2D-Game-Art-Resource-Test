# 20260527-feed-resource-cleanup-older-than-2h

## Scope

- Cleaned intermediate resources in `public/assets/` and `raw/generated/`.
- Used `public/home-feed.json` as the source of truth for resources that must be retained.
- Cutoff: files with `CreationTime` older than 2 hours at cleanup time.
- Protected all feed-referenced media and excluded `raw/references/`.

## Results

- Feed media references checked: 874.
- Missing feed media before deletion: 0.
- Deleted files: 3,222.
- Deleted bytes: 1,255,894,837.
- Removed empty directories: 278.
- Remaining old unreferenced candidates after cleanup: 0.

## Verification

- Parsed `public/home-feed.json` successfully.
- Verified all relative feed media paths exist under `public/`.
- Re-ran old-unreferenced candidate scan for `public/assets/` and `raw/generated/`; result was 0.

## Follow-ups

- No commit was made by this cleanup task.
