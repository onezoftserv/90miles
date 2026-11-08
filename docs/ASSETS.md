# 90 Millas — Free Assets

Every asset source is free for commercial use and for redistribution of the raw files in this public repository. Downloaded packs are git-ignored (`game/assets/kenney/`, `game/assets/oga/`, `game/assets/itch/`) and keep their own license file next to them. Only the files the game actually uses are copied into tracked folders under `game/assets/art/<area>/`, each with its `License.txt`, and no tracked scene, resource, GDScript or shader under `game/` may refer to a git-ignored folder (`CREDITS.md` and the pipeline tools in `tools/` name those folders on purpose).

`tools/fetch_assets.py` downloads the packs marked **auto**; the rest need a manual download because the site requires a login or a click. The `art-pass` change teaches the script every pack below, printing the page and target folder for those it cannot fetch.

## Art direction (decided 2026-11-08)

Direction C, **"GBA tropic"**: a bright *A Link to the Past* / Pokémon look with saturated colours, 1 px dark outlines and 2–3 tone shading, in a 3/4 view. Tiles are 16×16. Players are about 16×28 figures (chibi, about 2 heads tall) in 32×32 frames, anchored bottom-centre on a one-tile (16 px) footprint, with the head about one tile into the row above; collision stays a small circle at the feet. This replaces the 2026-11-05 decision of 16×16 characters on Kenney bases. Pieces no pack has (the climbable palm with coconuts and gull nests, the raft and its damage states, coconut, inner tube, plastic jug, tarp and other island item icons, the Cuban cast's extra poses such as crouch, swim, downed, drag and carry, mangroves, sea grapes, a thatched bohío and palm-frond lean-to, portraits) are made by editing and kitbashing the CC0 and CC-BY pack pieces by hand to one shared master palette, rough first and refinable. The first pass is the OpenSpec change `art-pass`.

## Downloaded art packs (2026-11-08, with the owner's permission)

| Pack | Author | License | Folder | Used for | Measured |
| --- | --- | --- | --- | --- | --- |
| MetroCity Free Top Down Character Pack 1.0 and 2.0 | JIK-A-4 | CC0 | `itch/metrocity/` | players (and later NPCs) | 32×32 frames; one body in 6 skin tones; a 6-frame cycle in 4 facings (left = mirrored right) that bobs 1 px (side view lifts 2–3 px); hair, outfit (4–12 colours) and suit layers on the same grid; a 12×7 shadow; figure about 14×29 with a light skin-and-grey edge, not a dark outline |
| Zelda-like tilesets and sprites | ArMM1998 | CC0 | `oga/zelda-like/` | land tiles, logs, rocks, props | 16×16 tiles (`Overworld.png` 40×36); grass and sand edges onto water as a 2×2 island and a 3×3 pond, with their own water strip and foam rim (13 of 16 corner tiles: no islet, no diagonals); baked half-transparent prop shadows; hero 16×32 cells, figure about 15×20 |
| Scallywag – Water and Islands | Foozle / Pixel Carvel | CC0 | `itch/scallywag-water-islands/` | sea texture, palm fronds, floating debris | 16 px grid, straight-down view, 3-frame deep water, foam rims |
| Scallywag – Ships | Foozle / Pixel Carvel | CC0 | `itch/scallywag-ships/` | later: wreck and route-map references | 720×672 sheet |
| 16×16 Shoreline Wave Animation Tiles | Eldiran | CC0 | `oga/eldiran-shoreline/` | animated foam on shores | 4-colour template (plus black label text), a mid-tile shoreline: 8-frame edge and 8-frame curve (16×33, two tiles) |
| DawnLike 16×16 Universal Rogue-like tileset v1.81 | DragonDePlatino, palette by DawnBringer | CC BY 4.0 | `oga/dawnlike/` | shark and fin, items (rope, dagger, glasses, fruit), later creatures | 16×16, 2 frames per creature, DawnBringer's 16-colour palette (DB16; none of its colours is in DB32, so it is remapped like the other packs); no crab |
| Tiny, Tiny Heroes – Animals | Kacper Woźniak (thkaspar) | CC BY 4.0 | `itch/tth-animals/` | the seagull (later the galleguito, snakes) | 16×16; gull in 3 facings, 4 standing and 4 flying frames |
| Kyrise's Free 16x16 RPG Icon Pack v1.3 | Kyrise | CC BY 4.0 | `itch/kyrise-icons/` | item icons (wood, cup, bottles, fish, fruit) | 350 icons at 16×16, black outlines, 111 colours |
| Shikashi's Fantasy Icons Pack v2 | Matt Firth (shikashipx); game-icons.net bases | CC BY 4.0 (game-icons.net CC BY 3.0) | `itch/shikashi-icons/` | later: HUD meter and status icons after a palette reduction | 245 icons at 32×32, 1,237 colours |

The installed Kenney packs (all CC0) may fill gaps, but their flat or outline-free styles must pass the same palette and outline rules. DawnLike's own README asks users to hide its "Platino" sprite somewhere in the game; that is a request, not a licence term.

## Style guide

- **Palette:** one master palette, at most 64 colours: DawnBringer's 32 plus the tropical, sea and skin ramps the packs need (`game/assets/art/palette/master_palette.png`). Every world image uses only its colours, fully opaque or fully transparent; only drop shadows and shade decals (`shadows/`, `decals/`) use partial alpha. Pack art, DawnLike included, is remapped to it (baked half-transparent shadows removed) and fixed by hand.
- **Outlines:** a closed 1 px outline in one of the palette's darkest colours on every character, creature, item and structure frame, added by the pipeline's rim step (which recolours a piece's own edge ring, or grows one where there is none); none on terrain, water, foam, shadows or decals.
- **Characters:** 32×32 frames on one fixed feet line (the bottom edge of the standing frame's lowest opaque row) 4 px below the body position, so the walk keeps its bob; down, up and side facings (side mirrored); a head anchor per pose for the name tag, speech bubble, HUD marks and, later, the gull perch. Clothing in a key ramp that a palette swap recolours per player; skin and hair in their own reserved ramps.
- **Frame budget:** at most 6 unique frames per actor or structure animation and facing, at most 4 per creature animation, at most 48 per character, at most 12 fps; holds repeat frames. Terrain, sea and foam overlays (the 8-frame shoreline) are exempt.
- **Terrain:** corner-matched land tiles with a transparent water side and no water or foam of their own; one foam line per shore, drawn on the land side.
- **Creatures:** side-on frames mirrored by facing; animations named after the behaviour states (`circle`, `swoop`, `pinch`…), with `move` and `idle` as fallbacks.
- **Items:** 16×16 icons with the item inside the 14×14 box one pixel in from the edge, one silhouette per item, raised 3 px on the ground (5 px for an item under 8 px tall) over a small shadow.
- **Readability:** on land the dark outline carries the contrast (every outline colour reaches 3:1 against sand, dune and brush); on water, swimmers and the shark fin reach 3:1 against shallows and deep water with their outline ring or their mean colour. Every actor and item has a drop shadow except swimmers and the shark fin, which are cut at the water line.

## Priority 1 — needed for the first playable

| Asset | Source | License | Where it goes | How |
| --- | --- | --- | --- | --- |
| Players (and later NPC bases) | MetroCity (32×32 frames); crouch, swim, downed and dead poses hand-edited from it | CC0 | `assets/art/characters/` | manual download, copied when used |
| Beach, dune, brush, rock tiles (16×16) | ArMM1998 Zelda-like set, recoloured, its water strip and foam rim keyed out; islet and diagonal tiles hand-made | CC0 | `assets/art/terrain/` | manual download, copied when used |
| Sea and shoreline | Scallywag water (texture), Eldiran shoreline (foam) | CC0 | `assets/art/sea/` | manual download, copied when used |
| Shark, crab, gull sprites | DawnLike (shark, fin), hand-made crab, Tiny, Tiny Heroes gull | CC BY 4.0 / own | `assets/art/creatures/` | manual download, copied when used |
| Items: rope, jug, coconut, knife, tarp, cup, driftwood, dry grass, inner tube, binoculars, nails, mirror, aloe, lighter | Kyrise and DawnLike icons, hand-made for the rest | CC BY 4.0 / own | `assets/art/items/` | manual download, copied when used |
| Palm, lean-to, workbench, fire, rain catcher, sign post, raft | Hand-made, kitbashed from Scallywag fronds and logs and Zelda-like props | CC0 / own | `assets/art/structures/` | — |
| UI: panels, bars, buttons, cursor | Kenney "Pixel UI Pack" (tracked 9-slices in `assets/art/ui/`) | CC0 | `assets/kenney/ui/` | auto |
| Pixel font (Spanish accents and ñ required) | Google Fonts "Press Start 2P" (Latin) or "Pixelify Sans" | OFL | `assets/fonts/` | auto |
| Sea ambience, waves, wind, rain | freesound.org (CC0 filter) / Kenney "Audio" packs | CC0 | `assets/audio/ambience/` | manual |
| UI and impact SFX | Kenney "Interface Sounds", "Impact Sounds" | CC0 | `assets/audio/sfx/` | auto |

## Priority 2 — content pass

| Asset | Source | License | Notes |
| --- | --- | --- | --- |
| Mangroves, sea grapes, dunes, reef and coral, cliffs, casuarina, wrecks | Hand-made from the Zelda-like and Scallywag pieces | CC0 / own | The first art pass gives these terrains a plain tile; full edge sets come later |
| Lighthouse, bohío, bunker, wreck interiors | Zelda-like `Inner.png` and `cave.png` for interiors, hand-pixel the rest at the 28 px people scale | CC0 / own | The Zelda-like houses were drawn for a 22 px hero, so doors need resizing |
| Patrol boat, cutter, dinghy, skiff, more rafts | Hand-pixel; Scallywag Ships as a reference only (straight-down, ship scale) | CC0 / own | The raft and its damage states come first, in `art-pass` |
| Almendrón: a 1950s American car seen from above, no make, badge or logo, with four drums lashed under it and a welded propeller; it is a vessel (`Vessel.CAR`), drawn as a car at sea | Hand-pixel (no free pack has it); boat sprites as a base | — | Rare vessel (about 1 run in 4 sees the route); the sprite is the joke. Never copy a real model's grille or badge |
| Surfboard with a sail, with a rider; a board is a vessel (`Vessel.BOARD`), one per rider | Hand-pixel | — | No maker's logo on the board |
| Laughing gull perched on a player's head (4–8 frames: circle, land, turn with the player, lift off, hop down, walk), plus the songbird, booby and frigatebird for the ambient birds | Tiny, Tiny Heroes gull as the base, then hand-pixel the perch frames | CC BY 4.0 / own | Sits on each pose's head anchor (decided with the character height, 2026-11-08) |
| Piling with an official board, the raft-for-sale sign, marked and unmarked washed-up rafts, the raft that fills a living room | Hand-pixel | — | The painted mark is a plain stripe, not a real agency's marking or logo |
| Weather: rain, fog, lightning sprites/particles | Godot particles; Kenney "Particle Pack" for textures, palette-snapped | CC0 | |
| HUD meter and status icons | Shikashi's icons reduced to the palette, or hand-made | CC BY 4.0 / own | Credit Matt Firth (shikashipx) and game-icons.net if used |
| Cuban son / salsa loops for the Músico and endings | freemusicarchive.org (CC-BY) or commission | CC-BY | Do not use any real recorded song |
| Portraits for NPCs (dialogue) | Drafted, then cleaned by hand to the master palette, or commissioned | — | 8 important NPCs + 8 minor; no real people |
| Voice: cloned Cuban voices | Chatterbox (MIT) with your own recordings | — | Record friends/family with written permission |
| Runtime TTS | Kokoro (Apache 2.0) | — | Spanish voices exist; test the accent |

## Not to use

- Mixamo, Quaternius and Poly Haven are 3D; skip them for this 2D game.
- Kenney "Generic Items" and "UI Pack" in the world: they are flat vector art at 20–110 px and clash with 16×16 pixel art.
- Art from the reference games (Shattered Pixel Dungeon, Brogue CE, DCSS): ideas only.
- Any sprite of a real brand, flag of a real political party, or real person's likeness.
- Any music under a Non-Commercial or No-Derivatives license.

## Sources

- Kenney: https://kenney.nl/assets (all CC0; "Kenney Game Assets All-in-1" bundles everything, free)
- OpenGameArt: https://opengameart.org (filter by CC0)
- itch.io: https://itch.io/game-assets/free/tag-pixel-art (check each license)
- Google Fonts: https://fonts.google.com
- Freesound: https://freesound.org (filter license = CC0)
- Free Music Archive: https://freemusicarchive.org

## Credits file

`game/assets/CREDITS.md` lists every pack, author, license and URL. Update it whenever a pack is added. CC-BY packs must be credited in the in-game credits screen too, each line with the source page and the licence's address (`https://creativecommons.org/licenses/by/4.0/`), because `CREDITS.md` and the `License.txt` files do not ship in an exported build (DawnLike: DragonDePlatino and DawnBringer; Tiny, Tiny Heroes – Animals: Kacper Woźniak; Kyrise; Shikashi: Matt Firth and game-icons.net, once used). CC BY 4.0 forbids DRM that restricts the licensed files; the raw files stay available in this repository.
