# Asset credits

Every third-party asset in `game/assets/`, its author, license and source. Update this file whenever a pack is added (see `docs/ASSETS.md`). CC-BY assets must also appear on the in-game credits screen.

Kenney packs are fetched by `python -I tools/fetch_assets.py` and are git-ignored (`game/assets/kenney/`); each pack folder keeps its own `License.txt`.

## Packs

| Pack | Author | License | Source | Local folder |
| --- | --- | --- | --- | --- |
| Roguelike Characters | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/roguelike-characters | `kenney/characters/roguelike-characters/` |
| Tiny Dungeon | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/tiny-dungeon | `kenney/characters/tiny-dungeon/` |
| Roguelike/RPG Pack | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/roguelike-rpg-pack | `kenney/tiles/roguelike-rpg-pack/` |
| Generic Items | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/generic-items | `kenney/items/generic-items/` |
| UI Pack | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/ui-pack | `kenney/ui/ui-pack/` |
| Pixel UI Pack | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/pixel-ui-pack | `kenney/ui/pixel-ui-pack/` |
| Interface Sounds | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/interface-sounds | `kenney/audio_sfx/interface-sounds/` |
| Impact Sounds | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/impact-sounds | `kenney/audio_sfx/impact-sounds/` |
| Particle Pack | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/particle-pack | `kenney/particles/particle-pack/` |
| UI 9-slices (Pixel UI Pack: `9-Slice/Ancient/tan`, `9-Slice/Colored/blue`, `blue_pressed`) | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/pixel-ui-pack | `art/ui/panel_tan.png`, `button_blue.png`, `button_blue_pressed.png` (tracked copies; license: `art/ui/License.txt`) |
| Player placeholder sprite (Tiny Dungeon, tile_0097, 16x16) | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/tiny-dungeon | `art/characters/player_placeholder.png` (tracked copy; license: `art/characters/License.txt`) |

## Fonts

| Font | Author | License | Source | Local file |
| --- | --- | --- | --- | --- |
| Press Start 2P | The Press Start 2P Project Authors (CodeMan38) | SIL OFL 1.1, Reserved Font Name "Press Start 2P" | https://github.com/google/fonts/tree/main/ofl/pressstart2p | `fonts/PressStart2P-Regular.ttf` (license: `fonts/PressStart2P-OFL.txt`) |
| Pixelify Sans | The Pixelify Sans Project Authors | SIL OFL 1.1 | https://github.com/google/fonts/tree/main/ofl/pixelifysans | `fonts/PixelifySans[wght].ttf` (license: `fonts/PixelifySans-OFL.txt`) |

## Not yet downloaded

Listed in `docs/ASSETS.md` but still to source (manual download, license checked per pack):

- Shark, crab, fish and bird sprites (OpenGameArt / itch.io): needed from Milestone B.
- Sea ambience, waves, wind and rain (freesound.org, CC0 filter; needs a login).
- Priority 2 content-pass art and music.
