# Side-View Platform Background Concepts

## Goal

Task 2로 2D 횡스크롤 플랫포머/액션 게임에 사용할 수 있는 긴 2.5D 픽셀 아트 배경 스테이지 5종을 만듭니다. `prompts/sideview-pixel-characters.md`의 캐릭터 스타일과 함께 쓰기 쉽도록 제한 팔레트, 하드 픽셀 에지, 확대된 sprite-era concept art 질감을 유지합니다.

## Shared Constraints

- Large horizontal 2D pixel-art side-scrolling platform background
- 2.5D side-view stage depth with foreground, midground, and distant parallax layers
- Clear left-to-right traversal path across the lower third
- One complete background image per stage, not a tile sheet
- Original classic 1990s arcade fantasy action-platformer mood
- Limited palette, hard pixel edges, deliberate dithering
- Readable walkable platform silhouettes
- No characters, monsters, UI, text, logo, watermark, sprite sheet, or repeated asset grid
- Do not recreate or copy an existing game screen or franchise artwork

## Stage Set

1. Ancient Dungeon Causeway
2. Overgrown Temple Approach
3. Lava Forge Undercroft
4. Coastal Cavern Dock
5. Sky Castle Battlement

## Prompt Notes

Each prompt used this base structure:

```text
Use case: stylized-concept
Asset type: project-bound 2D game background resource, wide horizontal side-scrolling platform stage backdrop
Primary request: Create one original large horizontal 2.5D pixel-art fantasy <stage> background for a side-scrolling platform game. Match prompts/sideview-pixel-characters.md: limited palette, hard pixel edges, readable enlarged sprite-era concept art, no text, no watermark.
Composition: 3:1 panoramic side-view game camera, clear left-to-right traversal path with raised ledges/platforms, 2.5D layered depth. One complete stage background image, not a tileset.
Style: original classic 1990s arcade fantasy action-platformer pixel art feel, crisp pixel clusters, controlled dithering. Do not recreate or copy any existing game screen or franchise artwork.
Avoid: characters, monsters, UI, health bars, text, logos, modern painterly blur, photorealism, isometric top-down view, sprite sheet layout, repeated asset grid.
```

## Output

- Generated source images: `raw/generated/20260525-sideview-platform-backgrounds/`
- Public background images: `public/assets/backgrounds/20260525-sideview-platform-backgrounds/`
