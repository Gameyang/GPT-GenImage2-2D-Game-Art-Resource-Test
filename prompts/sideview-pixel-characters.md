# Side-View Pixel Character Concepts

## Goal

2D 픽셀 아트 사이드뷰 캐릭터 원화 10종을 만들고, 이후 sprite sheet animation으로 확장하기 쉬운 기준 이미지를 확보합니다.

## Shared Constraints

- Full-body 2D pixel-art side-view character
- Facing right
- Neutral idle-ready standing pose
- One character only
- Clear limb separation for later idle, walk, run, attack, hit, death animation
- Feet aligned to a flat baseline
- Readable 64x96 sprite proportions, shown as enlarged concept art
- Limited palette, hard pixel edges
- No sprite sheet, no multiple poses, no text, no watermark
- Flat chroma-key background for local transparency processing

## Character Set

1. Adventurer Swordsman
2. Desert Scout Archer
3. Forest Herbalist Mage
4. Mechanical Tinkerer Engineer
5. Armored Shield Guard
6. Nimble Rogue Thief
7. Fire Apprentice Caster
8. Ice Lancer Knight
9. Village Blacksmith Brawler
10. Sea Courier Runner

## Notes

- Generated source images are stored in `raw/generated/sideview-pixel-characters/`.
- Public transparent PNGs are stored in `public/assets/characters/sideview-pixel/`.

## Animation Sheet Pass 01

Created one 4x4 animation sheet for each character.

- Row 1: idle
- Row 2: move / walk
- Row 3: jump
- Row 4: attack

Each row has 4 frames. The sheets are intended as first-pass generated animation tests, not final engine-ready sprites.

Animation sheet source images are stored in `raw/generated/sideview-pixel-animation-sheets/`.
Public transparent animation sheets are stored in `public/assets/characters/sideview-pixel/animation/`.
