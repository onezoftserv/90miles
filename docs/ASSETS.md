# 90 Millas — Free Assets

Every asset source is free for commercial use. Keep each pack's license file next to its files in `game/assets/<source>/`. The art direction is 16×16 tiles and 16×16 characters (decided 2026-11-05), top-down, Caribbean palette (sand, turquoise, mangrove green, rust).

`tools/fetch_assets.py` downloads the packs marked **auto**; the rest need a manual download because the site requires a login or a click.

## Priority 1 — needed for the first playable

| Asset | Source | License | Where it goes | How |
| --- | --- | --- | --- | --- |
| Top-down character bases | Kenney "Roguelike Characters" / "Tiny Dungeon" (both are 16×16 single-frame sprites; characters are 16×16, decided 2026-11-05; walk cycles need custom frames later) | CC0 | `assets/kenney/characters/` | auto |
| Beach, water, sand, rock tiles (16×16) | Kenney "Roguelike / RPG pack" | CC0 | `assets/kenney/tiles/` | auto |
| Shark, crab, fish, bird sprites | OpenGameArt "LPC Animals" / itch.io "Pixel Sea Creatures" (CC0 only) | CC0 / CC-BY | `assets/oga/creatures/` | manual, check license per pack |
| Items: rope, jug, coconut, knife, tarp, bottle | Kenney "Generic Items" (there is no Kenney "Roguelike Items" pack) | CC0 | `assets/kenney/items/` | auto |
| UI: panels, bars, buttons, cursor | Kenney "UI Pack" + "Pixel UI Pack" | CC0 | `assets/kenney/ui/` | auto |
| Pixel font (Spanish accents and ñ required) | Google Fonts "Press Start 2P" (Latin) or "Pixelify Sans" | OFL | `assets/fonts/` | auto |
| Sea ambience, waves, wind, rain | freesound.org (CC0 filter) / Kenney "Audio" packs | CC0 | `assets/audio/ambience/` | manual |
| UI and impact SFX | Kenney "Interface Sounds", "Impact Sounds" | CC0 | `assets/audio/sfx/` | auto |

## Priority 2 — content pass

| Asset | Source | License | Notes |
| --- | --- | --- | --- |
| Palms, mangroves, dunes, wrecks, boats | OpenGameArt (search "tropical tileset", "beach tiles", "boat sprite") | CC0 / CC-BY | Prefer CC0; attribute CC-BY in `CREDITS.md` |
| Lighthouse, hut, bunker, wreck interiors | Kenney "Roguelike Modern City" (for concrete), hand-pixel the rest | CC0 | The lighthouse will likely need custom art |
| Patrol boat, cutter, dinghy, skiff, raft | itch.io "Top-down Boats" (free tier) / hand-pixel | varies | Raft is simple enough to draw |
| Weather: rain, fog, lightning sprites/particles | Godot particles; Kenney "Particle Pack" for textures | CC0 | |
| Cuban son / salsa loops for the Músico and endings | freemusicarchive.org (CC-BY) or commission | CC-BY | Do not use any real recorded song |
| Portraits for NPCs (dialogue) | Hand-pixel from Kenney bases, or commission | — | 8 important NPCs + 8 minor |
| Voice: cloned Cuban voices | Chatterbox (MIT) with your own recordings | — | Record friends/family with written permission |
| Runtime TTS | Kokoro (Apache 2.0) | — | Spanish voices exist; test the accent |

## Not to use

- Mixamo, Quaternius and Poly Haven are 3D; skip them for this 2D game.
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

`game/assets/CREDITS.md` lists every pack, author, license and URL. Update it whenever a pack is added. CC-BY packs must be credited in the in-game credits screen too.
