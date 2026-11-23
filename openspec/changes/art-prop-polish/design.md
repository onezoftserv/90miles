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
  - The 48 tiles are declared in `decal_tiles.tres`.
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
