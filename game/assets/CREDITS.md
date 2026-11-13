# Asset credits

Every third-party asset in `game/assets/`, its author, license and source. Update this file whenever a pack is added (see `docs/ASSETS.md`). CC-BY assets must also appear on the in-game credits screen, which reads `game/assets/art/credits.tres` (this file and the `License.txt` files do not ship in an exported build). `test_art_credits.gd` checks that every pack block in a `License.txt` under `game/assets/art/` has an entry there and a row here with its author and source, and, for CC BY, "CC BY 4.0".

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
| DawnBringer's 32-colour palette (DB32) | DawnBringer | None stated (a published list of 32 colours, credited as a courtesy) | https://lospec.com/palette-list/dawnbringer-32 | `art/palette/master_palette.png` and `master_palette.gpl` (entries 1-32) and the DB32 colours of `player_ramps.png` and `skin_ramps.png`, unmodified (tracked; license: `art/palette/License.txt`) |
| Terrain tiles (Zelda-like tilesets and sprites, `gfx/Overworld.png`: the beach, grass-on-sand, bush and seven ground tiles) | ArMM1998 | CC0 1.0 | https://opengameart.org/content/zelda-like-tilesets-and-sprites | `art/terrain/sand.png`, `dune.png`, `brush.png`, `plain.png` and their `_shore` sheets, modified: recoloured to the master palette, the baked water and foam keyed out, cut and put together by corner mask; its sand outline also shapes `art/sea/foam.png` and `art/decals/shade.png` (tracked copies; license: `art/terrain/License.txt`) |
| Sea texture (Scallywag - Water and Islands 1.0, `Water and Island tiles.png`: the 32x32 deep-water block at x 224, y 0) | Foozle, commissioned from Pixel Carvel | CC0 1.0 | https://foozlecc.itch.io/scallywag-water-islands | `art/sea/water.png`, modified: recoloured to four palette colours (tracked copy; license: `art/sea/License.txt`) |
| Shoreline foam (16x16 Shoreline Wave Animation Tiles, `cc0waveanimtiles16x16.png`: the 8 straight frames) | Eldiran | CC0 1.0 | https://opengameart.org/node/144858 | `art/sea/foam.png`, modified: only the white kept, wrapped round each sand shape and tinted (tracked copy; license: `art/sea/License.txt`) |
| Drop shadow (MetroCity Free Top Down Character Pack 1.0, `CharacterModel/Shadow.png`: its 12x7 ellipse) | JIK-A-4 | CC0 1.0 | https://jik-a-4.itch.io/metrocity-free-topdown-character-pack | `art/shadows/shadow_12x7.png`, cut out of the 32x32 frame, colour and alpha unchanged (tracked copy; the 8x4 and 6x3 shadows beside it are own work; license: `art/shadows/License.txt`) |
| Seagull (Tiny, Tiny Heroes - Animals, `animals/spritesheet.png`: the seagull, columns 8-15 of rows 15-17) | Kacper Woźniak (thkaspar) | CC BY 4.0 | https://thkaspar.itch.io/tth-animals | `art/creatures/seagull.png`, recoloured to the master palette (modified; tracked copy; license: `art/creatures/License.txt`) |
| Shark splash (DawnLike - 16x16 Universal Rogue-like tileset v1.81, `Objects/Effect0.png`: the crests of two water bursts) | DragonDePlatino; palette by DawnBringer | CC BY 4.0 | https://opengameart.org/content/dawnlike-16x16-universal-rogue-like-tileset-v181 | `art/creatures/reef_shark.png`, strike frames 2 and 3, recoloured with a black edge (modified; the fin and body beside it are own work in the pack's shark colours; license: `art/creatures/License.txt`) |
| Crab shape reference (Tiny Dungeon, `Tiles/tile_0110.png`) | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/tiny-dungeon | none copied: `art/creatures/land_crab.png` is own work drawn after its proportions (license: `art/creatures/License.txt`) |

## Art direction C packs (downloaded 2026-11-08)

Downloaded by hand with the owner's permission into git-ignored folders (`game/assets/oga/`, `game/assets/itch/`); each pack folder keeps its archive, a `License.txt` with the source page, the licence and the date read, and an `extracted/` folder. The `art-pass` change copies only the files it uses into `game/assets/art/<area>/` with their licence and adds a row to the Packs table above for each tracked copy, saying whether it was modified. The CC-BY packs must also be credited on the in-game credits screen.

| Pack | Author | License | Source | Local folder |
| --- | --- | --- | --- | --- |
| MetroCity Free Top Down Character Pack (1.0 and 2.0) | JIK-A-4 | CC0 1.0 | https://jik-a-4.itch.io/metrocity-free-topdown-character-pack | `itch/metrocity/` |
| Zelda-like tilesets and sprites | ArMM1998 | CC0 1.0 | https://opengameart.org/content/zelda-like-tilesets-and-sprites | `oga/zelda-like/` |
| Scallywag - Water and Islands (1.0) | Foozle, commissioned from Pixel Carvel | CC0 1.0 | https://foozlecc.itch.io/scallywag-water-islands | `itch/scallywag-water-islands/` |
| Scallywag - Ships (1.0) | Foozle, commissioned from Pixel Carvel | CC0 1.0 | https://foozlecc.itch.io/scallywag-ships | `itch/scallywag-ships/` |
| 16x16 Shoreline Wave Animation Tiles | Eldiran | CC0 1.0 | https://opengameart.org/node/144858 | `oga/eldiran-shoreline/` |
| DawnLike - 16x16 Universal Rogue-like tileset v1.81 | DragonDePlatino; palette by DawnBringer | CC BY 4.0 (the OpenGameArt licence field and the pack's own `README.txt`) | https://opengameart.org/content/dawnlike-16x16-universal-rogue-like-tileset-v181 | `oga/dawnlike/` |
| Tiny, Tiny Heroes - Animals | Kacper Woźniak (thkaspar) | CC BY 4.0 | https://thkaspar.itch.io/tth-animals | `itch/tth-animals/` |
| Kyrise's Free 16x16 RPG Icon Pack (v1.3) | © 2018 Kyrise | CC BY 4.0 | https://kyrise.itch.io/kyrises-free-16x16-rpg-icon-pack | `itch/kyrise-icons/` |
| Shikashi's Fantasy Icons Pack v2 | Matt Firth (shikashipx); based on game-icons.net designs | CC BY 4.0 (game-icons.net: CC BY 3.0) | https://shikashipx.itch.io/shikashis-fantasy-icons-pack | `itch/shikashi-icons/` |

## Fonts

| Font | Author | License | Source | Local file |
| --- | --- | --- | --- | --- |
| Press Start 2P | The Press Start 2P Project Authors (CodeMan38) | SIL OFL 1.1, Reserved Font Name "Press Start 2P" | https://github.com/google/fonts/tree/main/ofl/pressstart2p | `fonts/PressStart2P-Regular.ttf` (license: `fonts/PressStart2P-OFL.txt`) |
| Pixelify Sans | The Pixelify Sans Project Authors | SIL OFL 1.1 | https://github.com/google/fonts/tree/main/ofl/pixelifysans | `fonts/PixelifySans[wght].ttf` (license: `fonts/PixelifySans-OFL.txt`) |

## Not yet downloaded

Listed in `docs/ASSETS.md` but still to source (manual download, license checked per pack):

- Sea ambience, waves, wind and rain (freesound.org, CC0 filter; needs a login).
- Priority 2 content-pass art and music.
