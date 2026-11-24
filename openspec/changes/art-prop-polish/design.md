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

**Group 1 resumed on QO1 (a), "Re-rim to black" (owner, 2026-11-22).**
- **Tests first.** They failed before the rule existed.
  - **The rule, in Python and GDScript.** In `test_check.py` and `test_art_checks.gd`, on three new fixtures: a creature sheet with a #45283c edge fails, naming the file, the pixel and "black"; the same edge under `structures/` passes; an item icon rimmed in #222034 fails. A unit test checks the split itself: black for actors, the dark tones for structures, nothing for terrain.
  - **The recipe.** `test_creatures.py` gains two tests: a sheet's `"outline"` rims every cell edge in that one colour, and an outline off the outline set is refused. A third test requires every shipped creature sheet to be rimmed in black.
  - **The gate.** `test_art_tracked.gd` reads each sheet's family. It failed on `reef_shark` (213 edge pixels), `seagull` (53) and `seagull_flight` (13).
  - **The 1-player test** (`test_look_composer.gd`): a solo player's look, as the run composes it, has only black edge pixels. The existing composition test now checks black too, for 2 bodies × 8 hairs.
- **The rule.** `check.py` (`family_outline`, `family_rule`) and `ArtChecks` (`family_outline`, `family_rule`) take the family from the folder right under `art/`.
  - `characters/`, `creatures/`, `items/` and `decor/` are actors, outlined in the outline set's darkest colour, black.
  - `structures/` takes the other three colours.
  - A failure names its rule: "not black (actors are outlined in black)" or "not a dark tone".
  - The rule is written into `docs/ASSETS.md`'s Outlines line, with one line per tool in the docs of `creatures.py`, `items.py`, `structures.py` and `compose.py`.
- **The re-rim.** `creatures.py` gains a sheet-level `"outline"`: the rim recolours each cell's edge ring to that one colour. Every sheet in `creature_sheets.json` now has `"rim": true` and `"outline": "#000000"`. The shark and both gull sheets changed, and `land_crab.png` rebuilt byte-identical, its edge being black already. No hand source was redrawn.
- **The hair parts are unchanged.** The survey above was wrong that their dark-tone edges reach the composed head. Each part has dark-tone edge pixels: hair_0 384, hair_2 296, hair_3 176, hair_4 140, hair_5 130, hair_6 545, hair_7 330, and hair_1 none. They are all where the part lies over the body (`compose.py`'s `over` keeps those). Composed with either body and the outfit, every hair has 0 non-black edge pixels, which the 1-player test and the 2 × 8 composition test confirm. Re-rimming the part files would only blacken the line between hair and face inside the figure.
- **Checks.** `check.py` reports 0 problems with the family rule on the tracked art, and the Python art tests pass.
- Image: `docs/art-pass/prop-polish/outline_black_before_after_x4.png`. Each sheet is shown before, then after, over deep water #306082: the shark, `seagull` and `seagull_flight`.

**Group 3, the rain catcher's tarp (D3).**
- **Test first.** `test_the_rain_catcher_wears_a_tarp_funnel_whose_mouth_shows_the_water` (test_structure_looks.gd, one player offline) failed on today's sheet: no #5b6ee1 or #3f3f74 over the rim, the mouth #45283c, the water #639bff.
- **The art.** A new hand layer, `tools/art/fixes/structures/catcher_funnel.png`: 2 frames of 16×12 laid at (0, 2) over each frame's barrel and top.
  - The tarp in the tarp icon's blues (#639bff lit, #5b6ee1, #3f3f74 where it dips into the mouth).
  - Outlined in #222034, flaring a pixel past the rim.
  - Tied with a #d9a066 cord with two #8f563b knots, its corners hanging below the cord.
  - The mouth is #222034 when empty. At one cup it shows water in #5fcde4 with a #cbdbfc glint and a #639bff edge, so the water stays distinct from the tarp's own blue.
- **The build.** The catcher's recipe gains the layer. The sheet stays 32×24 (2 frames of 16×24); every other structure sheet rebuilt byte-identical; `check.py` is clean.
- Image: `docs/art-pass/prop-polish/rain_catcher_before_after_x8.png`.

**Group 2, five icons that read (D2).**
- **Tests first.** The rule is outline pixels at most half of the icon's opaque pixels, checked on the five in `test_items.py`, in `test_item_icons.gd`, and in a new 1-player test in `test_coast_cay_solo.gd`: the post's nails show the redrawn icon on the ground and in the strip once picked up. On today's icons it failed for nails (76 of 114), crab (39 of 72) and iguana (31 of 47). Tarp (29%) and hutía (45%) already passed but did not read as D2 describes.
- **The new hand sources**, drawn as fill maps inside the 12×12 centre with a 4-neighbour #000000 ring, so the box and the closed outline hold:
  - **nails:** three nails lying parallel at 45°, heads at the upper left, a one-pixel #222034 seam between the shanks, 32% outline;
  - **tarp:** a sheet folded in three layers with a grey grommet, 27%;
  - **crab_cooked:** an orange shell with folded claws and leg nubs, 32%;
  - **hutia_cooked:** a browned body with ears and feet on a pale spit that sticks out both sides, 34%;
  - **iguana_cooked:** a browned iguana, legs splayed and tail curled, on a pointed leaf, 29%.
- Two nails drafts were rejected on the captures: an upright fan and a block of upright nails with T-heads. They passed the rule but read as a vase and a grate.
- **Checks.** `items.py` rebuilt every icon. Only the five changed; `dry_grass` is byte-identical. No two icons share a silhouette.
- **Noted, not redrawn.** Thirteen other icons are over the half rule too, mostly thin tools: crab_raw, fins, fishing_line, flint_steel, guao, lobster, lure, military_belt, pliers, snare, spear, sunglasses and uva_caleta_unripe (16 with today's nails, crab and iguana). D2 covers only the five, so the test names them alone.
- **Images.**
  - `docs/art-pass/prop-polish/icons_before_after_x8.png`: before on top, after below.
  - `docs/art-pass/prop-polish/strip_five_x3.png`: the strip holding the five, from `capture_inventory_hud.tscn -- --only=icons --scale=3`, a step added for this task. The three cooked foods show dimmed there by the HUD kit's own slot dimming.

**Group 4, palm looks (D4, owner QP1 (a)).**
- **Tests first.** They failed on today's single palm:
  - in `test_structure_art.gd`, the pick (`StructureArt.palm_look`) is the cell's hash and gives the same look twice;
  - every look keeps today's trunk base (rows 44 to 47 pixel for pixel, the foot centred on the palm's position), with the crown under the nest point and under each coconut's middle;
  - the foot shade is centred under each look;
  - every look is lit from the upper left, and no look is another's mirror.

  The 1-player tests:
  - `test_structure_looks.gd`: the sandbar, built twice for one offline player, draws the same look per palm both times, more than one look in all, each look its cell's;
  - `test_creature_art.gd`: a solo player's perched gull stands on the nest point of a nest palm drawn in each look.
- **Three looks.**
  - Look 0 is today's palm.
  - Look 1, `palm_bowed.png`: a trunk that bows 3 px to the left under a drooping fan of six fronds.
  - Look 2, `palm_upright.png`: a trunk that bows 3 px to the right under upright fronds, with two front fronds hanging behind the coconuts.

  Each is a hand-drawn trunk and crown (`tools/art/fixes/structures/palm_trunk_*.png`, `palm_crown_*.png`). Each frond is lit on its top in #99e550, #6abe30 through the middle and #4b692f underneath, with a serrated #323c39 underside. A frond reaching right shows less lit top. The bark uses today's colours and rings, lit on the left. The four base rows are today's, so the foot and its shade read the same.
- **Departures.**
  - **The bits of the hash.** The pick is `(TerrainArt.cell_hash(layout id, cell) >> 8) % 3`, not `>> 1`. From bit 1, five of the sandbar's six palms took the same look (2, 1, 2, 2, 2, 2), and with two looks every coast cay palm would. From bit 8, the sandbar draws [2, 0, 1, 1, 1, 2], the coast cay [2, 0, 0, 2, 1] (coast-cay-reshape keeps its palm cells, so this holds after it) and the hidden cay [1, 0, 2]. Starting from another bit than the terrain's also keeps a palm's look from following its ground tile's pick. It is one constant, `StructureArt.PALM_LOOK_SHIFT`.
  - **Shared overlays.** Every look keeps its crown hub under (16, 14), so the looks share today's coconut and nest overlays instead of each carrying its own. Their heights hold by construction, and the tests check that the crown is under each overlay point. `StructureArtData.palm_looks` lists the redrawn frames; look 0 stays `palm`, so a palm on no island draws today's palm.
  - **Where the pick is made.** It is made in `StructureLook`, the palm's art node, not in `palm.gd`, which is the host's climb script. The look picks once, from its island's layout id and the palm's cell, and keeps it.
- **Checks.**
  - `structures.py` built the two new sheets, and every other structure sheet rebuilt byte-identical.
  - `check.py` is clean on the art and the fixes, and the Python art tests pass.
  - The windowed solo run `art_pass_run.gd --mode=solo --only=palms` (a step added for task 4.3) passed 15 of 15: every palm draws its cell's look, and two gulls perch over the nest point of the bowed look.
- **Images:**
  - `docs/art-pass/prop-polish/sandbar_palms_before_after_x3.png`: before, left, from the 2026-11-14 review with its older sand; after, right, from `capture_terrain.tscn`, the same rect.
  - `docs/art-pass/prop-polish/two_palms_col_before_after_x6.png`: `before/two_palms_col_x3.png` (×6 in fact), which shows palms 1 and 3 at (23, 31) and (23, 36), beside the same rect now: today's palm above the bowed look.
  - `docs/art-pass/prop-polish/palm_looks_x6.png`: the three looks, bare and with 3 coconuts and the nest.
  - `docs/art-pass/prop-polish/sandbar_palms_solo.png`: the solo run's view of the grove.

**Group 5, the lean-to (D5).**
- **Tests first.** They failed on today's lean-to and shade.
  - **The frame** (`test_lean_to.gd`):
    - **A closed roof.** Every column with a pixel in the top 16 rows is opaque from its top through those rows, and the tops differ by no more than the 2 px ridge sag. Today's stepped corners start 10 rows lower.
    - **A ragged eave.** Between the posts, each column's lowest thatch pixel (the lowest that is not a dark tone) hangs 2 to 4 px below the eave line, in at least three separate tips. Today's eave varied by 1 px.
    - **Post shadows.** A `DropShadow` under each post's foot, drawn behind the lean-to.
  - **The pick** (`test_terrain_view.gd`). On the sandbar and the hidden cay, every shaded cell takes the hut shade of its depth band, and its tile is declared. The coast cay keeps today's corner set; its test is unchanged.
  - **The tool** (`test_terrain.py`). The sheet grows by three corner sets. Each band's full tile is highest on its north row, a column never darkens going south from 58 down to the last band's last row, and a bad ramp is refused.
  - **The 1-player test** (`test_lean_to.gd`, one solo shell). On the sandbar all 12 hut cells have a hut-shade decal. Each is highest on its north row, and walked down each hut column the shade never darkens going south, darkest on the hut's north edge.
- **The art.** The three hand sources are redrawn by a helper; the structure rim adds the outline.
  - `lean_to_roof.png`: a closed thatch slab, 62 px wide. Four courses of hanging frond strands, the upper course over the lower, lighter above and darker toward the eave, with fresh green fronds along the ridge. The ridge sags 1 px over its middle third, and the two top corners are rounded by 1 px.
  - `lean_to_eave.png`: frond tips hanging 2 to 4 px at uneven spacing between the posts.
  - `lean_to_frame.png`: the posts, and the back wall in the dark tones #45283c and #222034 down to the ground between the posts. It stays a 64×48 frame on the same anchor.
- **Post shadows.** `lean_to.tscn` gains `ShadowWest` and `ShadowEast` (`shadow.tscn`, MEDIUM, `show_behind_parent`) at (±25, −1). The root stays a Sprite2D.
- **The hut shade.**
  - `terrain.py`'s shade step takes `"hut": {"north": 58, "south": 18, "bands": 3}` and adds one corner set per depth band after the spot row (rows 5 to 16), with a ramp from 58 on the hut's north edge to 18 at 48 px.
  - `TerrainView.hut_shade_tile` picks a band by depth from the hut's north edge, and a mask that counts the cell north of any shaded cell as shaded, for the shaded cells of a layout `ShelterArtData` names.
  - The 45 hut tiles with art are declared in `decal_tiles.tres`. Mask 0 covers nothing and is not declared. `test_terrain_tile_sets.gd` re-pins `shade.png` from 19 tiles to 64.
- **Departures.**
  - **Three bands, not one row.** D5 says "a second row" of the shade sheet. A single ramped tile restarts its ramp in every hut row and draws stripes, so the ramp spans the hut's depth in three bands. `shade.png` grows from 64×80 to 64×272.
  - **Straight sides.** The hut shade takes the mask's straight quadrants, not the sand outline. The outline's wobble made a column's shade rise and fall along the hut's sides. A hut is a rectangle under a rectangular roof.
  - **The back wall reaches the ground.** Today rows 38 to 47 between the posts were open sand, which would put a lit strip right above the full-strength shade. The wall now meets the hut's north edge.
  - **Ahead of C14.** Task 5.2 asks to rebase on art-terrain-polish's C14 decal edits. C14 isn't built yet (it waits for crossing-gameplay #70 and #75), so this lands first, and C14 rebases on it. Both edit `TerrainView._build_decals`: the hut pick is in the shaded-cell loop, and C14 drops the raft's wide shade at the end.
- **Checks.**
  - `terrain.py` rebuilt only `decals/shade.png`. `structures.py` rebuilt only `lean_to.png`.
  - `check.py` is clean on the art and the fixes.
  - The windowed solo run `art_pass_run.gd --mode=solo --only=hut` (a step added for task 5.3) passed 16 of 16: the player in the back row on the shade and in front of the lean-to, and the tarp beside them.
- **Images:**
  - `docs/art-pass/prop-polish/hut_before_after_x4.png`: `before/sandbar_day_hut_crop4.png` and the same rect, (752, 192), 144×128.
  - `docs/art-pass/prop-polish/hut_before_after_x6.png`: `before/hut_c3.png`, which is really at ×6, and the same rect, (767, 162), 110×120.
  - `docs/art-pass/prop-polish/lean_to_sprite_before_after_x4.png`: `before/s_lean_to.png` and the new sprite.
  - `docs/art-pass/prop-polish/hut_solo.png`: the solo player in the hut.

  The after shots are of the island scene alone (`capture_terrain.tscn`), so the pick-ups and the bench are missing.

**Group 6, the hidden cay's scenery (D6).**
- **Tests first.** The tests were written before any of the code, but first run after it: they could not parse without `DecorArtData`.
  - **`test_decor_art.gd`**, new, 8 tests:
    - each decor id of `cayo_sin_norte.tres` draws its piece and no colour square;
    - upright pieces are children of the y-sorted `DecorPieces`, standing on their cell's centre at the actors' z;
    - the post in the shallows has its ripple foot, and a post on sand has none;
    - an id with no look draws its colour square;
    - the stub's wisp has at most 4 unique frames at 12 fps or less;
    - the drag mark covers its five sand cells and draws nothing in the shallows.
  - **The 1-player test:** the hidden cay, reached by one offline player, shows every piece and no colour square, and Platino stands beside the chest. A player south of the post draws over it, and one north of it behind it. The player's drop shadow draws over the flat pieces.
  - **The embers test**, added after the capture: most of the embers' pixels show clear of the palm crown beside them, whichever look the palm draws. It failed at offset 0, where 0 to 10 of 66 pixels showed.
- **The data.**
  - `DecorLook` holds one look: decor id, terrain (-1 for any), upright, texture or frames, foot, pair, offset.
  - `DecorArtData` (`structures/decor_art.tres`) holds the looks. `look_for(id, terrain)` prefers the cell's terrain over any.
  - A look with nothing to draw draws nothing, which is how the drag mark ends at the water. No look at all keeps the colour square.
- **`DecorView`.**
  - It draws flat pieces at z -9: over the terrain's decals (-10), under every drop shadow (-1).
  - Upright pieces are children of a y-sorted `DecorPieces` at the actors' z, and `DecorView` itself is y-sorted.
  - `piece_for(entry)` gives each cell's decision (flat, upright, square or none) for the tests, since GUT runs headless.
- **The pieces.**
  - **Embers:** the fire's out frame from `structures/fire.png`, flat, drawn 6 px up on its cell's north edge. The palm at (22, 17) spreads its crown over the cell's south half, and no layout cell moved.
  - **Cigar stub:** `fx/decor_cigar.png`, 2 frames of 16x16 at 3 fps. The stub with its ember, and a 1 px wisp swaying.
  - **Drag mark:** `decals/decor_drag.png`, 32x16. One trough down a slope of one row per two cells, as the run lies. A cell whose west neighbour is drag mark draws the east half, so the three pairs join up. In the shallows it draws nothing.
  - **Post:** `structures/decor_post.png`, 16x24, rimmed in the dark tones: a stake with a cut rope loop. In the shallows its foot is `fx/post_ripple.png`, 12x5.
  - **Cut line:** `decals/decor_rope.png`, the frayed end floating.
  - **Platino:** `creatures/platino.png`, cut from DawnLike `Characters/Reptile0.png` at (48, 192) by `creatures.py`. Its seven DB16 colours are mapped to the master palette, and it is rimmed in black. It is one still frame (the layout calls it a figurine).
- **Departures.**
  - **Folders.** No `decor/` folder. D1 says decor takes the dark tones in one line and is an actor in the next.
    - The post, a structure, is in `structures/`, in the dark tones.
    - Platino, a creature sprite, is in `creatures/`, in black.
    - The stub and wisp, the ripple, the rope end and the drag mark are thin. A rim would turn them to solid outline, so they live in `fx/` and `decals/`, which have no outline rule.
  - **Sources.** Those four are hand sources in `tools/art/fixes/terrain/`, copied and checked by `terrain.py`'s existing "copies".
  - **Capture.** It uses `art_pass_run.gd --only=hidden` (a step added here, travelling with `travel_to` as `--only=cay` does), not `secret_cay_playground.tscn`, which cannot save an image. `capture_terrain.tscn` gains the hidden cay for the before and after.
- **Licences and credits.**
  - `creatures/License.txt`: the DawnLike block names `platino.png`.
  - `CREDITS.md` gains Platino's row. The in-game credits already carry DawnLike's CC BY 4.0 line (for the knife).
  - Own-work blocks are added in `structures/`, `fx/`, `decals/` and the two fixes folders.
- **Checks.**
  - `terrain.py`, `structures.py` and `creatures.py` built only the six new files; everything else rebuilt byte-identical.
  - `check.py` is clean on the art and the fixes.
  - The windowed solo run `--only=hidden` passed 14 of 14.
- **Images:**
  - `docs/art-pass/prop-polish/hidden_cay_decor_before_after_x4.png`: `before/secret_cay_decor.png` and the same rect, (176, 16), 272x336.
  - `docs/art-pass/prop-polish/hidden_cay_scenery_x6.png`: the drag mark, the post and the rope end.
  - `docs/art-pass/prop-polish/hidden_cay_solo.png`: the solo player's view.

**Group 7, the garita and the sign looks (D7, owner Q12 (a)).** Built after coast-cay-reshape merged (#101): this branch merges main at a8239b4.
- **Tests first.** They failed for the right reasons: no shelter for the cay, no `hut_shade`, no `sign_texture`.
  - `test_lean_to.gd`: `test_the_coast_cay_shaded_cells_get_no_lean_to` became `test_the_coast_cays_post_gets_the_garita_on_its_back_edge`.
    - It is centred on the post, 80x48, on the back edge, with its roof over the row north of the post.
    - Nothing in it collides, occludes or navigates.
    - A still solo player set on each post cell stays there after a step, so every post cell is as walkable as without it.
    - The post keeps today's shade.
  - `test_structure_art.gd`: a sign with no look, or an unknown one, draws `sign_post.png`; a look draws its texture, on the sign node too.
  - **The 1-player test** (`test_coast_cay_solo.gd`, one shell):
    - the player on the post's back row, and the nails, the mirror and the radio, draw in front of the garita;
    - one tile north of the post, its roof draws over the player;
    - the four signs show their looks, and E opens and closes each one's note with its line.
    - The two wall slogans are read from the side that makes them the candidate. From the south, the nails and the mirror are nearer.
- **The data.**
  - `IslandSignData.look` and `IslandSign.look`, set by the island from the layout.
  - `StructureArtData.sign_looks` and `sign_texture(look)`, which falls back to the board.
  - `StructureLook` draws a sign's look.
  - `shelter_art.tres` names `garita.tscn` for `coast_cay`. The coast cay's four signs take `radio`, `slogan`, `slogan` and `sticks`.
- **Hut shade, now its own flag.** `ShelterArtData.hut_shade` (the sandbar and the hidden cay) now decides which layouts take group 5's hut shade, not the presence of a shelter. D7 keeps the post's own shade, and the garita made the coast cay a sheltered layout.
- **The art** (hand sources in `tools/art/fixes/structures/`, rimmed in the dark tones by `structures.py`):
  - `garita.png`, 80x48: an open-front concrete booth under a rusted, corrugated tin roof that sags at the front, on two pipe posts. The back wall is low and broken, with a dark window hole and a faded red band with no letters. The side walls are broken lower on the right, over a cracked floor. There is no radio on a sill: sign r is the radio.
  - `sign_radio.png`: a dead radio on a crate.
  - `sign_sticks.png`: two crossed sticks in a sand mound.
  - `sign_slogan.png`: a concrete fragment with the red band.
  - `garita.tscn` gets two small post shadows, drawn behind it.
- **Departure.** The captures come from `art_pass_run.gd --only=post`, a step added here.
- **Checks.**
  - `structures.py` built only the four new files.
  - The windowed solo run `--only=post` passed 15 of 15, including the player on the back row drawn in front of the garita.
- **Images:**
  - `docs/art-pass/prop-polish/post_before_after_x4.png`: `before/cay_day_observation_post_crop4.png` and the same world rect now, (927, 560), 224x160, from the solo view. The rock round it is coast-cay-reshape's.
  - `docs/art-pass/prop-polish/cay_post_x3.png`: the solo view, to set beside `before/cay_day_observation_post_x3.png` and `before/cay_day_rocky_point.png`.
  - `docs/art-pass/prop-polish/garita_back_row_x6.png`: the player on the back row, in front of the garita.


**Group 8, integration (2026-11-23).** Built from main 041e711, with all seven groups merged: group 1 (#105), 2 (#103), 3 (#102), 4 (#104), 5 (#106), 6 (#107) and 7 (#109).
- **The rebuild (8.1).** Every recipe tool was run into a scratch folder from the read-only packs and the tracked hand sources. `terrain.py`, `structures.py`, `creatures.py`, `items.py`, `compose.py`, `fx.py`, `mood.py` and `ui.py` built 156 files, and each one `cmp`s equal to the tracked file. The 23 sheets this change touched are among them.
  - Seven tracked files have no recipe and were not rebuilt: the three palette strips, the three drop shadows and `fx/dive_ripple.png`, all from art-pass. This change does not touch them.
- **The sheets this change ships**, with their measured sizes:

  | Sheet | Size | Group |
  |---|---|---|
  | `creatures/reef_shark.png`, `seagull.png`, `seagull_flight.png` | 160×16, 128×48, 96×48 | 1, re-rimmed in black |
  | `items/nails.png`, `tarp.png`, `crab_cooked.png`, `hutia_cooked.png`, `iguana_cooked.png` | 16×16 each | 2 |
  | `structures/rain_catcher.png` | 32×24 (2 frames of 16×24) | 3 |
  | `structures/palm_bowed.png`, `palm_upright.png` | 32×48 each | 4 |
  | `structures/lean_to.png` | 64×48 | 5 |
  | `decals/shade.png` | 64×272 (from 64×80) | 5 |
  | `structures/decor_post.png` | 16×24 | 6 |
  | `fx/decor_cigar.png`, `fx/post_ripple.png` | 32×16 (2 frames), 12×5 | 6 |
  | `decals/decor_drag.png`, `decals/decor_rope.png` | 32×16, 16×16 | 6 |
  | `creatures/platino.png` | 16×16 | 6 |
  | `structures/garita.png` | 80×48 | 7 |
  | `structures/sign_radio.png`, `sign_sticks.png`, `sign_slogan.png` | 16×16 each | 7 |

- **Looks and placements**, in layout cells:
  - **Palms**, by look (0 today's, 1 bowed, 2 upright), read from `StructureArt.palm_look` on this build:
    - the sandbar: (26, 28) 2, (23, 31) 0, (27, 34) 1, (23, 36) 1, (26, 39) 1, (24, 42) 2;
    - the coast cay: (28, 19) 2, (51, 21) 0, (38, 24) 0, (11, 35) 2, (18, 40) 1;
    - the hidden cay: (19, 11) 1, (27, 12) 0, (22, 17) 2.
  - **The lean-to** stands on the back edge of the hut block, centred on it: the sandbar's 12 shaded cells (x 49 to 52, y 14 to 16) and the hidden cay's 8 (x 21 to 24, y 12 to 13). Those are the two layouts in `ShelterArtData.hut_shade`.
  - **The garita** stands on the back edge of the coast cay's 15 post cells (x 63 to 67, y 38 to 40), centred on them. The post keeps its corner-set shade.
  - **The coast cay's signs:** the radio at (65, 39) and the slogans at (64, 38) and (66, 38), all on the post, and the sticks at (44, 18).
  - **The hidden cay's scenery:**
    - the embers at (22, 14), drawn 6 px up;
    - the cigar stub at (23, 14);
    - the drag mark down (19, 15), (20, 15), (17, 16), (18, 16) and (16, 17), drawing nothing at (15, 17) in the shallows;
    - the post at (14, 17) on its ripple;
    - the cut line at (14, 18);
    - Platino at (24, 4), beside the chest at (23, 3).
- **Checks (8.1).**
  - `check.py`: 0 problems on `game/assets/art` and on `tools/art/fixes`.
  - The Python art tests: 255 OK.
  - Import twice: the second is clean. Smoke: 10 frames, 0 problems.
  - GUT: 2,739 of 2,739 pass in 293 scripts, in 332 s locally, under CI's 600 s step.
- **TASKS.md (8.2)** records the change as built. The archive waits for the owner to see the captures in play.
