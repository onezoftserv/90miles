# Design

## Context

See proposal.md for why. The review behind this change, with root causes, measurements and artboards, is `docs/art-pass/review-2026-11-14/DESIGN_PASS.md`:
- section 2.4, findings PR2 to PR8;
- section 3, changes C15 to C18;
- section 5, artboards A6, A19 and A22;
- section 6, Q12 and Q15.

The before captures the tasks compare against are in `docs/art-pass/review-2026-11-14/before/`.

How the props are drawn today:
- **Structures** are built by `tools/art/structures.py` from `structure_sheets.json`, the read-only packs and the hand sources in `tools/art/fixes/structures/`. They are rimmed by the rim step and checked by `check.py`.
- **`StructureArtData`** (`structure_art.tres`) maps each kind to its frames, shadow size and offsets. `island_sign` draws `sign_post.png` for every sign.
- **`ShelterArtData`** (`shelter_art.tres`) names a shelter scene per layout id, with its origin on the hut's back edge (archived art-pass D18). The sandbar and the hidden cay get `lean_to.tscn`. The coast cay is not listed, so its post keeps only its shade.
- **Shade decals.** `TerrainView._build_decals` lays the shade of shaded cells as a corner set from `decals/shade.png`, and a foot shade under each palm.
- **Decor.** `DecorView` draws each decor cell as a flat square of its layout's `decor_colors` (secret-cay "He left minutes ago"). It never switches on an id, so new decor is a data edit.
- **Item icons** are built by `tools/art/items.py` from `item_icons.json`.
- **Palms.** `palm.gd` draws one `palm.png`, with coconut overlays and a nest overlay at `nest_point` (0, −34).
- **Outlines.** `art_tuning.tres` `outline_colors` holds four colours: #000000, #222034, #45283c and #323c39. The rim step takes the nearest one, or the one a recipe forces. `look_parts.json` and `item_icons.json` force #000000. Structures take the nearest, which gives plum or green-grey.

Constraints:
- Art never changes the simulation. No shelter, garita, decor piece or sign look gets collision, occlusion or a synced value.
- The master palette, 1 px outlines and nearest filtering apply. Every hand pixel goes through `tools/art/` with `png.py`, never Pillow, and the packs stay read-only.
- Other changes own these requirements:
  - art-terrain-polish MODIFIES "Tide pools and contact shade", so this change does not touch it; the hut shade lives in "Lean-to over the hut".
  - coast-cay-reshape re-authors the coast cay round the post but keeps the post's cells (rows 38–40, columns 63–67), its signs and its shade.

## Goals / Non-Goals

**Goals:**
- Fix PR2, PR3, PR4 and PR6 to PR8 in the recipes, the hand sources and the art data.
- Pin each fix with a test that fails today.
- Keep every peer's drawing identical.

**Non-Goals:**
- The vessels' waterline and redraws (C23), the crouch lean (SP11), the occlusion outline (SP12).
- The shimmer's glint, the needle and the chest art. These are the other half of TASKS.md's secret-cay art item; only the decor cells are here.
- Reaching the hidden cay in a real run (secret-cay's open items).
- Unifying the outline colour of every family (Q15 (b)).
- Legible words painted in the art. The slogans' text stays in the signs, Spanish first, so nothing in a sprite needs translating.

## Decisions

### D1. The outline rule, written down and checked (C18, PR8, Q15 (a))
- **The rule.** Characters, creatures, item icons and pick-ups are outlined in #000000. It is the only outline colour that reaches 3:1 against deep water, where swimmers, the fin and floating pick-ups are seen. Structures (palms, the lean-to, the garita, the fire, the catcher, the bench, signs, the raft, decor) are outlined in the palette's three dark tones, #222034, #45283c and #323c39, whichever the rim step finds nearest. Their dark tones keep them a step back from the actors.
- **Where it is written.** `docs/ASSETS.md`'s "Outlines" line, and a `family_outline` field per recipe kind in the tool docs.
- **The check.** A `tools/art/check.py` rule reads which family each tracked sheet belongs to from its folder: `players/`, `creatures/`, `items/` and the new `decor/` actors are black; `structures/` uses the dark tones. It fails with the file and the pixel.
- **If today's art breaks the rule** (a creature that the rim gave a plum edge), the build stops and records it. A redraw is not silently folded into this group.
- **Rejected:** one outline colour for everything (Q15 (b)). Black on structures makes the scenery as loud as the actors.

### D2. Five icons that read (C18, PR6)
- **Which.** `nails`, `tarp`, `crab_cooked`, `hutia_cooked` and `iguana_cooked`, redrawn as hand sources in `tools/art/fixes/items/`. They stay 16×16, inside the 14×14 box.
- **The cause.** A part under 3 px thick becomes solid outline once rimmed.
- **The rules** (a test on the made icons):
  - every opaque part is at least 3 px thick, so it keeps fill pixels;
  - outline pixels are at most half of the icon's opaque pixels;
  - no two icons share a silhouette (the existing test).
- **The looks:**
  - nails: three nails on a slant with heads;
  - tarp: a folded blue sheet with a grommet;
  - cooked crab: a browned shell with legs folded, not a bow;
  - hutía and iguana: a body on a spit or leaf, with the animal's shape kept.
- **Kept:** the dry-grass sheaf (K71).

### D3. The rain catcher's tarp funnel (C18, PR8)
- A hand-drawn tarp funnel in the tarp's blue, tied over the barrel's rim, is added as a layer in every rain-catcher frame (`rain_catcher.png`, `catcher_tops.png`).
- The water showing while it holds a cup stays visible through the funnel's mouth (art-pass "Camp structures").
- The frame size does not change.

### D4. Palm looks by hash (C18, PR7)
- **Looks.** 2 or 3 palm looks: today's palm plus 1 or 2 redrawn trunks and crowns. Each has its own coconut overlays and nest overlay, so that `nest_point` and the coconut points keep their heights. Only the lean of the trunk and the frond pattern change. Whether a look may be a mirror is owner question QP1.
- **The pick.** `TerrainArt.cell_hash(layout id, cell) >> 1` modulo the look count, the same per-cell seed the terrain uses. It is deterministic on every peer and calls no random number generator.
- **The foot shade** is centred under the trunk base of every look.
- **What stays:**
  - `StructureArtData` `nest_point` (0, −34) for every look;
  - the perch point a gull lands on;
  - the trunk base on the palm's position;
  - every palm test.
  A new test perches a gull on a nest palm of each look.
- **Rejected:** a random lean per palm at run time (not seeded), and changing the nest height (it moves the perch, which is simulation-adjacent).

### D5. The lean-to as a frond shelter (C17, PR2)
- **Frame.** Same 64×48 frame and the same anchor on the hut's back edge (D18), so `test_lean_to.gd`'s anchor and sort tests keep passing.
- **Redraw.** The three hand sources (`lean_to_frame.png`, `lean_to_roof.png`, `lean_to_eave.png`) are redrawn:
  - a ragged eave whose frond tips hang 2–4 px;
  - a slight sag in the ridge;
  - closed top corners, so no transparent step shows a bush behind;
  - the upper-left light (K36).
- **Post contact shadows.** A small ellipse at each post foot, as a `Shadow` child of the lean-to scene in the darkest colour at the shadow alpha.
- **The hut's shade.**
  - The shaded cells keep their corner-set decal, all 12 of them on the sandbar.
  - A shelter's shaded cells take a shade variant that is full strength on its north edge, under the roof line, and fades south. Today's decal fades its north edge at the posts, which puts the darkest shade furthest from the roof.
  - The variant is a second row of the shade decal sheet, built by the same `terrain.py` shade step with a north-weighted ramp.
  - `TerrainView` picks it for shaded cells of a layout that `ShelterArtData` names.
- **Rejected:** moving the shaded cells north under the roof. They are simulation (shade), and the review kept all 12.

### D6. The hidden cay's scenery (C16, PR4)
- **Data.** A new `DecorArtData` resource (`decor_art.tres`) maps a decor id to a look: a texture or frames, a kind (upright or flat), an optional terrain override and an optional foot. It is keyed by (decor id, terrain), so the same post can show a dry foot on sand and a waterline foot in the shallows.
- **Drawing.**
  - `DecorView` keeps drawing flat pieces itself, as decals over the ground.
  - It adds upright pieces as Sprite2D children of a y-sorted `DecorPieces` node, so they sort with players and palms (art-pass "Draw order by foot position").
  - A decor id with no entry still draws its `decor_colors` square, so a new decor kind stays a data edit.
- **The pieces** (artboard A22):
  - embers from the fire's ash frame, flat;
  - a cigar stub with a 2-frame smoke wisp, upright, at most 4 unique frames and 12 fps;
  - the drag mark as furrows in the sand ramp, flat, continuous across its cells;
  - a post with a ripple foot in the shallows, upright;
  - a cut rope end floating, flat;
  - Platino on the chest's ledge, upright.
- **Platino.** It is cut from DawnLike's `Characters/Reptile0.png` by a `tools/art/` recipe with the pack's CC BY 4.0 credit in `CREDITS.md` and the credits data. DawnLike's README asks users to hide it somewhere (`docs/ASSETS.md`), and the chest's ledge is that place.
- **The tone stays.** Nothing reads as a grave, a marker, a stake, an empty raft or a memorial (secret-cay "He left minutes ago").
- **Tests:**
  - `test_he_left_minutes_ago` keeps reading `decor_colors`;
  - a new test checks each decor id draws its piece and an unknown id its square;
  - `test_art_tracked` checks the new files' licences.

### D7. The garita and the sign looks (C15, PR3, Q12 (a))
- **The garita.** A new `garita.tscn` shelter is named for `coast_cay` in `shelter_art.tres`. Its origin is on the post block's back edge, as the lean-to's is on the hut's (D18). Everything on the post's cells (the nails, the mirror, the signs, a player) draws in front of it, and only what is north of the block goes behind its roof.
- **Its look** (artboard A6), about 80×48, own work kitbashed from the packs' concrete and tin:
  - low broken concrete walls on the back and sides, with no front wall;
  - two posts and a sagging rusted tin edge;
  - a dark window hole;
  - a faded red band where a formal slogan was painted, with no legible letters.
- **Solid.** It has no collision, occlusion or navigation, and the post's cells stay walkable as today.
- **The sign looks.** `IslandSignData` gains `@export var look: StringName = &""`, and `StructureArtData` a `sign_looks: Dictionary[StringName, Texture2D]`. `island_sign.gd` draws the sign's look, or `sign_post.png` when the look is empty or unknown, so an old layout and a new look are both data. The looks:
  - `radio`: a dead radio on a crate (sign r);
  - `sticks`: two crossed sticks in a sand mound (sign x);
  - `slogan`: a concrete fragment with a red band (the two wall slogans).
  The garita itself has no radio on the sill, because sign r is the radio.
- **Order.** It builds after coast-cay-reshape merges, because that change re-authors the rock round the post. The post's cells are kept, so the garita's anchor does not move. The shade decal round the post stays art-terrain-polish's.
- **Rejected:**
  - keeping only the shade (Q12 (b));
  - a closed building with a door, which would need collision and changes the cay;
  - legible slogan text in the sprite.

### D8. Order and seams
1. D1, the outline rule: docs and a check.
2. D2, five icons.
3. D3, the tarp funnel.
4. D4, palm looks (after the owner answers QP1).
5. D5, the lean-to. It touches `TerrainView._build_decals`, which art-terrain-polish's C14 also edits, so it rebases on C14.
6. D6, the hidden cay's scenery.
7. D7, the garita and sign looks, after coast-cay-reshape.

Seams with other changes:
- **art-terrain-polish** owns "Tide pools and contact shade" and C14's decal edits. D5 adds a shade variant and leaves the decal list alone.
- **coast-cay-reshape** keeps the post's cells and the four signs' cells. D7 reads them from the layout, never as numbers.
- **art-sprite-polish** C8 draws the bush in front of a crouched body. It does not touch structures.
- **The test-folders session** may move tests. Follow its layout.

## Reference games

Ideas and structure only, never code, data or text.

**Shattered Pixel Dungeon**
- *Borrowed for D5 and D7:* `scenes/GameScene.java` adds `DungeonWallsTilemap` (`tiles/DungeonWallsTilemap.java`) after the mobs, so a wall's raised face draws over an actor behind it. The roof of a shelter on its back edge is that face for one structure.
- *Borrowed for D6:* `tiles/CustomTilemap.java` gives a room its own hand-drawn scenery layer over the terrain, kept apart from the tile rules. `DecorArtData` is that layer as data.
- *Borrowed for D4:* `tiles/DungeonTerrainTilemap.java` picks a tile's alternate visual through `DungeonTileSheet.getVisualWithAlts` from the cell's fixed `tileVariance`. A palm's look comes from its cell's seed the same way.
- *Noted for D5:* `sprites/ItemSprite.java` sizes a shadow from the sprite.

**DCSS**
- *Borrowed for D4:* `tile_init_flavour` (`tileview.cc`) fixes a per-cell flavour once, so the same cell always looks the same.
- *Borrowed for D1:* `tile::add_rim` (`rltiles/tool/tile.cc`) gives every tile one rim colour, by tile kind. Our rule is a rim colour per family, written down.

**Brogue CE**
- *Borrowed for D6:* `drawManacles` (`Monsters.c`) lays manacle decorations round a captive, so the scenery tells what happened there without a word. The embers, the stub and the drag mark do that for the man who left minutes ago.

**ALttP and Pokémon** (general knowledge of how they look; nothing copied)
- *Borrowed:* huts and ruins drawn as a roof and walls the player walks in front of; ragged thatch eaves; items drawn thick enough to read at 16 px.

**Don't Starve Together** (dontstarve.wiki.gg, through `docs/REFERENCE_DST.md`)
- *Borrowed for D6:* "Set pieces" ([Set Piece/DST](https://dontstarve.wiki.gg/wiki/Set_Piece/DST)). The "failed survivor" scenes lie with their gear and are never traps; the hidden cay's camp is that kind of scene, a boon with a story.
- *Borrowed for D7:* "Lore in fragments" ([Ancient Mural](https://dontstarve.wiki.gg/wiki/Ancient_Mural)). One panel is worn past reading, which is the garita's faded slogan band: the words are in the signs, and the wall only shows that there were words.
- *Rejected for D7:* "Building placement" ([Structures](https://dontstarve.wiki.gg/wiki/Structures)) with claimed radii. The garita is a fixed part of a handmade layout, not a placed structure.
- `docs/REFERENCE_DST.md` has no section on icons, outlines or palm looks, so nothing is borrowed from DST for D1 to D4.

## Owner decisions

**Accepted on 2026-11-14 (the review's section 6):**
- **Q12 (a):** an open, ruined garita over the post's shaded patch (D7).
- **Q15 (a):** today's outline rule written down (D1), not one colour for everything.

**2026-11-15:** the owner said "Yes, write it" to this change.

**New, for the owner (through the coordinator), recommended first:**
- **QP1. Palm looks: redraws or a mirror?** A mirrored palm leans the other way, but its crown is then lit from the upper right, against every other sprite's upper-left light (K36).
  - (a) *Recommended:* 1 or 2 redrawn palms, each lit from the upper left, so 2–3 looks in all. More hand pixels: a trunk, a crown, three coconut overlays and a nest overlay per look.
  - (b) Today's palm, its mirror and one redraw. It is cheaper, but the mirrored crown's light is wrong.

## Risks / Trade-offs

- **[The outline check finds old art off the rule]** → The build stops and records it. A fix is its own task, not hidden in D1.
- **[Palm looks multiply overlays]** → Each look carries its own coconut and nest overlays, built by the same recipe. The structure-art frame-size range test covers them.
- **[The garita covers the post's back row]** → Only the roof covers the row north of the block. The post's cells draw in front, which a solo test pins.
- **[DawnLike's credit]** → Platino adds DawnLike pixels to the tracked art. `test_art_tracked` and the credits test require the pack's licence block and credit line.
- **[The shade variant and art-terrain-polish's decal edits]** → D5 rebases on C14 and adds a sheet row, so neither change's tile counts collide. The tile-set test names both.

## Migration Plan

Art and art data only. Rebuild with `python -I tools/art/structures.py`, `items.py`, `terrain.py` (the shade row) and the decor step, each with `--packs C:/Users/liann/src/90miles/game/assets`, then re-import. Old layouts keep working: a sign with no `look` draws the board, and a decor id with no art draws its square. To roll back, revert the commit. No save, network message or layout cell depends on these pixels.

## Build notes

Measured values and departures are recorded here as the tasks ship.

**Gate (0.1, 2026-11-22).** The coordinating session's "continue in your order" after C7, C8, the mood pass and C6 is the go. Branched from main 8c58c16.

**Group 1, the outline rule: stopped at 1.2, asked as QO1.** A survey of today's tracked art against D1 found non-black edges on actors:
- `creatures/reef_shark.png`: 213 edge pixels in #222034 and #323c39, the fin's rim among them.
- `creatures/seagull.png`: 53. `seagull_flight.png`: 13.
- The player hair parts (`characters/parts/hair_0`, `hair_2` to `hair_7`) carry dark-tone edges that form the top of the head once composed.
- Every item icon is already all black, and every structure uses only the dark tones.

As the task says, nothing was redrawn. The question went to the coordinating session with three options: re-rim to black (recommended), keep today's practice, or exempt these files. Group 1 resumes on the answer.

**Group 3, the rain catcher's tarp (D3).**
- **Test first.** `test_the_rain_catcher_wears_a_tarp_funnel_whose_mouth_shows_the_water` (test_structure_looks.gd, one player offline) failed on today's sheet: no #5b6ee1 or #3f3f74 over the rim, the mouth #45283c, the water #639bff.
- **The art.** A new hand layer, `tools/art/fixes/structures/catcher_funnel.png`: 2 frames of 16×12 laid at (0, 2) over each frame's barrel and top.
  - The tarp in the tarp icon's blues (#639bff lit, #5b6ee1, #3f3f74 where it dips into the mouth).
  - Outlined in #222034, flaring a pixel past the rim.
  - Tied with a #d9a066 cord with two #8f563b knots, its corners hanging below the cord.
  - The mouth is #222034 when empty. At one cup it shows water in #5fcde4 with a #cbdbfc glint and a #639bff edge, so the water stays distinct from the tarp's own blue.
- **The build.** The catcher's recipe gains the layer. The sheet stays 32×24 (2 frames of 16×24); every other structure sheet rebuilt byte-identical; `check.py` is clean.
- Image: `docs/art-pass/prop-polish/rain_catcher_before_after_x8.png`.
