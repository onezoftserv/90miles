# Design

## Context

See proposal.md for why. The review that found these problems, with root causes, measurements and before captures, is `docs/art-pass/review-2026-11-14/DESIGN_PASS.md` (it lands with art-coast-pass): section 2.3 (SP1–SP5, SP8–SP10), section 2.4 (PR1), section 3 "Wave 3: sprites" (C8, C19–C22, C24, C25) and section 5 (artboards A8–A10, A20, A21). Captures named "AR/…" below are in the review's scratchpad folder, `C:/Users/liann/AppData/Local/Temp/claude/3e391225d1d53c33/033b02a6-abc6-4589-bc32-d2c7f6771443/scratchpad/art_review/`; task 0.2 copies the ones this change compares against into the repo, because that folder is temporary.

How the sprites are made and drawn today:
- **Players.** `tools/art/compose.py` builds one 320×128 sheet per look part (11 parts in `look_parts.json`) on the frame layout of `poses.py`. Every made cell (crouch, swim, downed, dead) is a pure pixel remap of a walk cell, so applying a rule per layer and compositing equals compositing and applying it (`test_each_rule_per_layer_then_composited_equals_the_rule_on_the_composite`). `PlayerLook` (`scenes/art/player_look.gd`, children Shadow, Sprite, Ripple) picks the pose through `PlayerPose` (`scripts/art/player_pose.gd`). While swimming, `player_look.gdshader` turns the frame's own row at the water line to foam white and fades the next 4 rows through `art_common.gdshaderinc` (`art_on_ripple`, `art_water_alpha`), which `waterline.gdshader` shares for the shark and the deck.
- **Creatures.** `tools/art/creatures.py` builds each sheet in `creature_sheets.json` from pack rects and hand sources in `tools/art/fixes/creatures/`. The `_frames.tres` files name the animations. `CreatureLook` (`scenes/creatures/creature_look.gd`) centres the frame on the creature, places its feet by `CreatureArtEntry` (`foot_px`, `air_lift_px`, `water_line_px`) and cuts water creatures with `waterline.gdshader`. The shark sheet is 160×16 (five 32×16 side cells), the crab 96×16 (six 16×16 cells, every frame 16 px wide), the gull 128×48 (16×16 cells, idle and move per facing).
- **Crossing.** `crossing.tscn`: Sea at z −40, Deck and Boards at z −20, riders at z 0. Today `CreatureThreats` shows the shark at `deck_center() + SHARK_OFFSET_PX` (16, 0), inside the 64×32 deck.

What is changing beside this change: crossing-gameplay (branch `claude/crossing-gameplay-53b440`, owner-approved, not merged) gives the shark a 5 s tell. `CreatureThreats.warn` spawns it 1 tile off the side the pass names and keeps it there until the strike; a `RescuePoint` kind SHOO follows the fin; at the strike the shark moves beside its victim or the hit deck (its tasks 7.2). It also adds `CrossingHazards` at z −30. art-terrain-polish adds scrub variants (C10) and darker shallows (C7).

Constraints:
- Art never changes the simulation: no art node writes a synced value, and no synced property is added (`test_art_sim_invariance`).
- Only `tools/art/` recipes and hand overlays, written with `png.py`, never Pillow. The packs stay read-only. Master palette only, 1 px outlines, nearest filtering.
- Frame budget: at most 4 unique frames per creature animation, at most 12 fps, at most 48 unique 32×32 frames per character (art-pass "Frame budget").

## Goals / Non-Goals

**Goals:**
- Fix each sprite at its source (the recipe, the pose rule, the hand source), so every look part and every peer follows.
- Pin each fix with a test that fails on today's art.
- Keep the shoo point, the bite reach and every other host rule exactly where crossing-gameplay puts them.

**Non-Goals:**
- C23 vessels (waterline wobble, the raft's 3/4 redraw, the car's fins and drums, the wider board).
- SP11 (crouch lean, run dust) and SP12 (the occlusion outline for a player under the hut roof).
- C21's move of the shark's spawn south of the deck, and C21's drawn `idle_drift_px` (see D3).
- Bush fronts for creatures. Only players hide in scrub.
- The night crab's visibility, which is lighting (art-mood-pass).

## Decisions

### Crossing draw order (shared with art-mood-pass)

| z | What | Owner |
|---|---|---|
| −40 | Sea | today |
| −38 | Crests | art-mood-pass |
| −35 | Wake | art-mood-pass |
| −30 | `CrossingHazards` (rocks, debris, flotsam, leaks) | crossing-gameplay |
| −21 | A swimmer north of a drawn deck (D2) | this change |
| −20 | Deck, Boards | today |
| 0 | Riders, swimmers elsewhere and the fin, y-sorted | today |

### D1. Swim bob and ripple ring (C19, C20; SP3, SP2)
- **The bob.** `SWIM_FROM` goes from (1, 4) to (1, 3). Walk frames 1 and 4 are both high-step frames, so today the two swim cells are the same above the line. Frames 1 and 3 differ by a 1 px bob above the line, from the source art, with no new pixels. The swim head anchor (−16 for the balsero, `BALSERO_ANCHORS`) is re-measured and must not change; if it does, the build stops and records why.
- **The ring.** `game/assets/art/fx/swim_ring.png`: 3 frames of about 20×5, a dashed oval in #ffffff and #cbdbfc, each frame shifting the dashes along the oval. It is drawn by a new recipe, `tools/art/fx.py` with `fx.json` (png.py only, colours through `palette.nearest`), with an own-work block in `game/assets/art/fx/License.txt`. `swim_ring.tres` plays it at 4 fps.
- **The node.** `Look/SwimRing`, an AnimatedSprite2D after Shadow and before Sprite, centred on the feet line where the cut lies. `PlayerPose.shows_swim_ring(pose)` is true for SWIM and FLOAT only. The dive ring (`Look/Ripple`) is unchanged.
- **The cut.** `player_look.gdshader` drops the foam row and the fade: rows above the line are opaque, rows at and below it are clear. `art_common.gdshaderinc` is untouched, so the shark and the deck keep their cut. Any bend of the line uses the node-local y passed from `vertex()`, never UV (`test_the_water_line_cuts_on_a_node_local_y_never_on_uv`). The hurt blink keeps working on the cut frame; the ring is the water's, so it does not blink.
- **Contrast.** "Actors stand out from the ground" counts a swimmer's ripple. The swimmer contrast test (`test_swimmers_stand_out_on_shallows_and_deep`) counts the ring's pixels instead of the white row, on today's shallows and on art-terrain-polish C7's darker shallows if that has landed.
- **Budget.** 24 + 2 (dive) + 3 (ring) stays under the 48-frame budget (`test_the_composed_look_keeps_the_frame_budget_with_the_ripple`).
- **Rejected:** DCSS's submerged split (`tilebuf.h` `SubmergedTileBuffer`, used by `tiledgnbuf.h`), which is today's straight cut with a translucent lower half: it reads as a box. Also rejected: keeping the cut and only shortening or tinting the white row (Q6 (b)).

### D2. A swimmer north of the deck goes under it (C22; SP5)
- `PlayerLook.step` sets Look's `z_index` to −21 when all three hold, and back to 0 otherwise:
  1. the pose is wet (SWIM or FLOAT);
  2. the body rides a running crossing with a drawn deck or board (not sunk);
  3. its position is north of that deck's or board's top edge, within its x span widened by the sprite's half-width.
- Why: swimmers are drawn 12 px lower than their feet (`SWIM_DROP_PX`), so a swimmer just north of the top edge is drawn over the deck's top rows. Under the deck, only the head shows above the planks.
- **Rejected:** a rect mask that clips the swimmer to the water. It needs the deck's drawn shape per integrity frame and breaks the moment the raft art changes.
- Riders aboard, a swimmer beside the deck (`crossing_rig.gd` `put_beside_deck`, east) or south of it, and every island swimmer keep z 0. `test_the_crossing_sea_and_deck_lie_under_its_riders` keeps its rider and gains the north swimmer.

### D3. The fin stays off the deck, drawing only (SP1)
- **No crossing delta.** crossing-gameplay already puts the fin 1 tile off the named side during the tell and moves it at the strike. The shark's synced position stays the only place it is drawn, so the SHOO point, which follows that position, stays on the fin.
- **No drawn drift.** The design pass's `idle_drift_px` (an ellipse of up to 10 px drawn round a still shark) would move the drawn fin off the SHOO point and off the bite reach the host uses. It is dropped. At most the circle animation bobs the fin 1 px in place.
- **The art side of the guarantee.** Today's frames are opaque from x 1 to 31 and y 0 to 12 of their 32×16 cells. With `foot_px` 9 that is about x −15..+15 and y −7..+5 round the position. A fin held 1 tile (16 px) off the deck's edge then clears it by 1 px. D4's redraw keeps every frame's drawn half-width at most 15 px, so the guarantee survives the redraw.
- **The test.** On crossing-gameplay's merged placement, for a solo raft crossing and a solo board crossing, the fin's drawn box, measured from the frame's non-clear texels and `CreatureLook`'s placement (not hard-coded), lies outside every intact deck or board rect from the warning to the retreat, and inside `sea_rect()`.
- **The seam.** If crossing-gameplay's strike still uses `deck_center() + SHARK_OFFSET_PX`, the test fails at the strike. The fix belongs in crossing-gameplay's placement (1 tile off the hit side's edge), not in the art. This is sent to the coordinator.
- **Never** lower the fin's z or clip it to the water: either hides almost all of its 66 fin texels (review SP1).

### D4. Shark redraw and facings (C24; SP4)
- **The hand source** `tools/art/fixes/creatures/reef_shark.png` is redrawn:
  - the fin keeps its shape and its 3:1 contrast on shallows and deep;
  - the water-line row (row 9, recoloured to foam at run time by `waterline.gdshader`) holds only the fin's base and 1–2 broken dashes in #222034, not a 17–27 px solid run;
  - rows 10–12 become a tapered spindle, not rectangles.
- **Facings.** The sheet gains rows for `patrol_up`, `patrol_down`, `circle_up`, `circle_down`, `move_up` and `move_down`: an edge-on fin with a short dash. The side frames become `_side`. Facing variants are picked by art-pass "Facing variants for creatures" with no script change. `strike` and `idle` stay single.
- **Budget.** At most 4 unique frames per animation; every frame's drawn half-width at most 15 px (D3).
- **Borrowed:** SPD `PiranhaSprite`: a water creature with no shadow (`link` sets `renderShadow = false`) and a ripple at the end of its attack (`onComplete` calls `GameScene.ripple`). We keep the strike's foam dash as that ripple.

### D5. Bush in front of a body in scrub (C8; PR1)
- `Look/BushFront`, a Sprite2D after Sprite. While the body's cell (`PlayerBody.cell()`) holds a Brush tile and the pose shows the body on land, it shows that exact tile: the source, atlas coordinates and alternative are read from the island `TerrainView`'s Brush layer, so a scrub variant or a fitted shore bush (art-terrain-polish C10, art-coast-pass C1) comes along. Off scrub, swimming or diving, it is hidden.
- It is placed at the cell, not on the body, so the bush does not walk with the player. It shows only the tile's rows that hold the bush's front (about rows 4–14, measured on the sheet), so the body's head stays clear when crouched: covered to about the chin crouched, to mid-thigh standing (artboard A21).
- It sorts inside the body's subtree, so a palm or a player one cell south still draws over it.
- Every peer draws it from the body's drawn position. The hidden state and its closed-eye mark (`BodyMarks`, HUD layer) are unchanged.
- **Rejected:** y-sorted scrub sprites. They amend the layer rule D15 and break `test_terrain_view.gd`'s layer tests and `test_draw_order.gd`'s ground test (the review's P4 verifier).
- **Order.** It builds after art-terrain-polish C10, so its copy test covers a variant tile.

### D6. A smaller, livelier crab (C25; SP8)
- `land_crab.png` is redrawn about 12–13 px wide, asymmetric (one big claw), its feet on row 15, keeping the dark red shell. Lighter orange lowers its contrast by day and by night.
- `idle` plays frames 0, 1, 0, 2 at 4–5 fps; `move` 4 frames at no more than 12 fps; `steal` and `pinch` keep their raised claws. The sheet grows as needed; side-on frames are still mirrored facing left, so the big claw swaps sides, which reads fine on a crab.
- **Borrowed:** SPD `CrabSprite`: an idle of frames 0, 1, 0, 2 at 5 fps and a 4-frame run. Its 15 fps run is over our 12 fps cap.

### D7. Gull flight frames (C25; SP10)
- A hand source `tools/art/fixes/creatures/seagull_flight.png`, kitbashed from the Tiny Tiny Heroes gull already in the sheet (credit unchanged): flight frames in 24×16 cells with bent M wings and no opaque pixel in a frame's outer column. 32×16 is the fallback if the wings need it.
- The frames file gains `swoop_*`, `flee_*` and `return_*` facings sharing those frames; `idle_*` and `move_*` keep the 16×16 cells. `CreatureLook` centres any frame width, so no script changes.
- The flying lift (`creature_art.tres` gull `air_lift_px`) goes from 8 to 15 px, within the review's 14–16. This amends archived art-pass D16. The shadow stays on the ground.

### D8. A lying pose (C25; SP9)
- A new pose rule `LIE` in `poses.py` replaces `TURN_DOWN` for downed, the downed breath frame and dead. It is still a pure pixel remap, so every look part follows and the per-layer invariant holds:
  - the rows from the neck down turn to lie along the ground, as today;
  - the head block is moved, not turned, so the face stays upright with the eyes side by side (a stated cheat: lying bodies in ALttP and Pokémon show an upright face);
  - the figure is about 26×12, its feet line and anchor unchanged;
  - the breath frame keeps its chest lift, and dead keeps no breathing frame.
- **Shadow.** `DropShadow.Size` gains LYING, appended (existing ints keep their meaning), a 23×5 ellipse drawn by `fx.py` in the darkest colour at MetroCity's alpha. `PlayerLook` uses it for the lying poses.
- **Rejected:** a hand "lying cell" kind. It needs hand pixels for each of the 11 look parts and for every future part, and it breaks "a new part needs no hand pose".

## Reference games

Ideas and structure only, never code, data or text.

**Shattered Pixel Dungeon**
- *Borrowed for D1:* `effects/Ripple.java`, a short ring effect a sprite spawns on water (`CharSprite.java` calls `GameScene.ripple`). Our ring is that effect held while swimming.
- *Borrowed for D4:* `sprites/PiranhaSprite.java`, a water creature with no shadow and a ripple on its bite.
- *Borrowed for D5:* `scenes/GameScene.java` adds the walls tilemap after the mobs group, so overhangs draw over actors. Our bush front is that overhang for one cell.
- *Borrowed for D6:* `sprites/CrabSprite.java`'s idle of frames 0, 1, 0, 2.

**DCSS**
- *Rejected for D1:* `SubmergedTileBuffer` (`tilebuf.h`, used by `tiledgnbuf.h`), a straight split with a translucent lower half.

**Brogue CE**
- Draws glyphs, not sprites; nothing applies.

**ALttP and Pokémon** (general knowledge of how they look; nothing copied)
- *Borrowed:* swimmers drawn as a head over a small ring; a knocked-out body lying with an upright face; bushes drawn over a body that stands in them; birds with M-shaped wings in flight.

**Don't Starve Together** (dontstarve.wiki.gg, `docs/REFERENCE_DST.md`)
- *Borrowed for D5:* "Hiding as a bush" ([Bush Hat/DST](https://dontstarve.wiki.gg/wiki/Bush_Hat/DST)). A hidden player reads as the bush they hide in. *Rejected:* replacing the body with a bush sprite. Teammates must still see a crouched body and its mark.
- *Rejected for D1:* "Falling overboard" ([Drowning](https://dontstarve.wiki.gg/wiki/Drowning)). DST players do not swim, so there is no swimmer look to borrow.
- *Nothing for D7:* "Birds landing and scattering" ([Birds](https://dontstarve.wiki.gg/wiki/Birds)) covers when birds land and flee, not how flight is drawn.
- *Borrowed for D8, as an aim only:* "Ghost form and haunting" ([Death/DST](https://dontstarve.wiki.gg/wiki/Death/DST)). Death reads at a glance as a different silhouette (a ghost, a skeleton). *Rejected:* the ghost itself. Our downed body stays a body teammates revive.
- *Nothing for D4 and D6:* the DST notes on the rock fish and the crabs cover behaviour, not drawing.

## Owner decisions

Accepted on 2026-11-14 (all recommended): Q6 (a), the ripple ring. Q7 (a), the shark just south of the raft, is overtaken by crossing-gameplay.

**Answered on 2026-11-15:** the owner chose "Accept all recommended" for QS1 and QL1, so QS1 (a) and QL1 (a) hold: crossing-gameplay's east or west side wins, and the lying pose is made by the pose rule (D8).

**The questions as they were asked, recommended first:**
- **QS1. Where the shark shows at the raft.** On 2026-11-14 Q7 (a) put it just south of the raft, drawn in front of the riders. crossing-gameplay's later approved Q4 (a) has the fin circle 1 tile off the east or west side its pass names, with a shoo hold on it.
  - (a) *Recommended:* crossing-gameplay's side wins. This change only guarantees the fin is never drawn over an intact deck (D3).
  - (b) South at the strike only: a crossing delta in crossing-gameplay that moves the shark south of the deck when it strikes, keeping the side for the tell.

- **QL1. How the lying pose is made.** The design canvas (artboard A20) showed a hand-drawn, foreshortened lying body with arms. D8 makes it with a pose rule instead, so every look part follows with no hand pixels.
  - (a) *Recommended:* the pose rule (D8), with the face upright. If the windowed capture (task 4.3) still reads as a turned standing frame, the build stops and asks again.
  - (b) A hand-drawn lying cell as on the canvas. This needs hand pixels for each of the 11 look parts and for every future part.

**Seam for crossing-gameplay (not an owner question):** its strike placement "beside the hit deck" must leave the fin's drawn box clear of the deck: 1 tile off the hit side's edge, not `deck_center() + SHARK_OFFSET_PX`.

## Risks / Trade-offs

- **[The hard cut is plainer than the white row]** The ring carries the water line instead. The swimmer contrast test counts the ring, so a swimmer that stops reading fails the build.
- **[The lying remap may still read as a turned standing frame]** The capture decides. A hand cell is the fallback, and it is a larger change recorded in the build notes.
- **[crossing-gameplay changes after this is written]** Group 0 re-reads its merged code. D3 and D2 cite its placement and its z −30, nothing else.
- **[Wider gull cells]** A 24 px frame still centres on the gull, so its sort position and shadow do not move.
- **[Re-shot images]** `docs/art-pass/looks_swim.png`, `looks_downed.png` and `crossing.png` change and are re-shot.

## Migration Plan

Art only. Rebuild with `python -I tools/art/compose.py --packs C:/Users/liann/src/90miles/game/assets`, `python -I tools/art/creatures.py --packs C:/Users/liann/src/90miles/game/assets` and `python -I tools/art/fx.py` (it reads only the master palette), then import twice. To roll back, revert the commit: no save, network message or layout depends on these pixels.

## Build notes

Measured values and departures are recorded here as the tasks ship.

**Gate (0.1, 0.2), 2026-11-15.** art-coast-pass merged into main and the coordinator said go. `player_look.gd`, `player_pose.gd` and `creature_look.gd` are as this design describes. The ten before captures are tracked in `docs/art-pass/review-2026-11-14/before/`.

**Group 1, swim bob and ring (D1).**
- `SWIM_FROM` is (1, 3). Rebuilding the parts changed only column 9 (the second swim cell) of each of the 11 part sheets. On `body_man` the head's top row moves 1 px between the two swim cells in every facing, and 81–98 px differ above the water row. The swim head anchor is still −16. The GDScript mirror of the rules (`tests/helpers/pose_rules.gd`, which `test_look_parts.gd` checks the made sheets against) follows: swim from walk frames 1 and 3.
- `tools/art/fx.py` and `fx.json` draw `fx/swim_ring.png`: 3 frames of 20×5, a dashed 1 px oval (2 px drawn, 1 left out, moving 1 px a frame, so the loop is seamless), #ffffff below the middle row and #cbdbfc above it. Two runs give the same bytes. `swim_ring.tres` plays it at 4 fps; the fx licence has its own-work block.
- `Look/SwimRing` sits between Shadow and Sprite, at x −10 and y = the water line − 2 from the body, so its middle row lies on the cut. `PlayerLook._ready` places it from the same `BodyArt` numbers as the shader's `water_line_y` (4). `PlayerPose.shows_swim_ring` is true for SWIM and FLOAT only.
- `player_look.gdshader` cuts hard (`art_local_y < water_line_y`) and has no foam colour; `art_common.gdshaderinc` and `waterline.gdshader` are unchanged, so the shark and the deck keep their fade.
- The frame budget counts the ring: 24 + 2 + 3 stays under 48. `test_swimmers_stand_out_on_shallows_and_deep` scores the body above the line, as before, and passes; the ring is not asked to reach 3:1 on its own (white on today's shallows is about 1.8:1).
- Capture: `docs/art-pass/sprite-polish/swim_ring_before_after_x3.png` (`capture_looks.tscn`'s `looks_swim.png`, the four slots in the sea; before above, after below). Each swimmer is a head and shoulders over a dashed white oval at the line, where before a flat white bar ran across the body over faded lower rows. `docs/art-pass/looks_swim.png` itself is re-shot in task 8.2.

**Group 2, the crab (D6).**
- `tools/art/fixes/creatures/land_crab.png` is redrawn as 10 cells of 16×16 (the sheet is now 160×16 in `creature_sheets.json`): idle, idle with the big claw open, idle with the eyes and the small claw shifted; three scuttle frames (legs out, body dipped 1 px, legs in); the big claw raised open and snapping; both claws raised, twice. It was drawn by a one-off png.py helper (fills, then a 1 px #000000 outline on every clear pixel 4-adjacent to a fill), kept in the coordinating session's notes folder as `art-waves-2-5/sprite_crab.py`.
- Every frame is 12 px wide (x 2–13), feet ending on row 15, so `foot_px` 5 is unchanged; one big claw on the right with an orange #df7126 tip, a small one on the left; the shell stays #ac3232 lit with #d95763 and shaded with #663931.
- `land_crab_frames.tres`: `idle` cells 0, 1, 0, 2 at 5 fps (SPD `CrabSprite`'s order); `move` cells 0, 3, 4, 5 at 10 fps; `pinch` 6, 7 at 6 fps; `steal` 8, 9 at 4 fps. Every animation keeps at most 4 unique frames; mirrored facing left as before.
- The outline contrast check and `tools/art/test_creatures.py` pass.
- Capture: a new manual scene, `tests/manual/capture_creatures.tscn` (windowed only), sets a player, four crabs (standing, scuttling, pinching, stealing) and a swooping gull on the sandbar's beach, at x6, by day and at night. `docs/art-pass/sprite-polish/crab_before_after_x6.png` stacks the review's `cr_lineup_day_crop6.png` (before) over the new day and night views. The crab reads smaller than the player and lopsided; at night it is a dark red shape with its black outline (its night visibility is lighting, art-mood-pass).

**Group 3, gull flight (D7).**
- `tools/art/fixes/creatures/seagull_flight.png` (96×48, 24×16 cells) is kitbashed from the made gull sheet by a one-off png.py helper (`art-waves-2-5/sprite_gull.py` in the coordinating session's notes folder): the four flying frames of each facing (columns 4–7 of `seagull.png`). The front and back facings (rows down and up), whose wing tips touched the cell walls, get each wing-root column (x 4 and x 11) drawn three times, so the span grows 2 px a side, and are centred: their pixels now run x 2–21. The side facing is only centred (x 4–19). The wings-up frame keeps its M shape. No pixel was drawn by hand.
- It is a second sheet in `creature_sheets.json` (`seagull_flight`, no rim: the made gull is already rimmed), credited with the Tiny, Tiny Heroes gull in both licence files.
- `seagull_frames.tres` gains `swoop_*`, `flee_*` and `return_*` for side, down and up, each the four flight cells of its facing at 10 fps (3 unique frames: cells 0 and 2 are the same wings-level frame). `idle_*` and `move_*` keep the 16×16 cells. `CreatureLook` centres any width, so no script changed.
- The gull's `air_lift_px` is 15 (archived art-pass D16 had 8). The shadow stays where a standing gull's would be. `test_a_flying_gulls_shadow_stays_on_the_ground_15_px_below_its_sprite` (renamed) now also asserts the swoop plays `swoop_*`.
- **A spec scenario this changes.** art-pass "Facing variants for creatures" said the shipped gull, with only `idle_*` and `move_*`, plays `move_up` when it swoops north, and `test_creature_anim.gd` pinned it. It now plays `swoop_up`, so this change MODIFIES that requirement (its text copied from main, the scenario updated; no open change touches it), and the test keeps the fallback on a fixture with only `move_*` frames.
- Capture: `capture_creatures.tscn`. `docs/art-pass/sprite-polish/gull_flight_before_after.png` stacks the review's `cr_gull_swoop_down_crop8.png` (before, x8) over the new swoop (x6): the wings spread past where the cell wall cut them, and the gull flies higher over its shadow.

**Group 4, the lying pose (D8, QL1 (a)).**
- `poses.py` `LIE`, for downed, its breath frame (with `CHEST_LIFT`) and dead: rows 20–31 turn clockwise and drop 8 px as `TURN_DOWN` did (body columns 1–11); rows 0–17, the head and its neck row, move by (5, 13) unturned, starting on the column after the body; rows 18–19 (the shoulders' top) are left out. The figure is about 28×15, wider than tall, and its lowest row is still 30, so the feet line and `foot` anchor do not move. The GDScript mirror (`tests/helpers/pose_rules.gd`) follows.
- Three departures from this design's first sketch, each found on the capture:
  - **The neck row goes with the head.** With the head block ending at row 16, the eye row became the head's bottom edge, and the rim turned it into outline: the face showed no eyes. Taking the neck row along makes the neck the outlined chin.
  - **Rows 18–19 are left out.** `hair_2` and `hair_6` hang strands at rows 17–19 beside the shoulders; turned with the body they became a stray vertical line beside the moved head. Leaving those rows out (the same rule for every layer, so the per-layer invariant holds) drops the strands and lets the head meet the shirt.
  - **The chest lift moves to columns 7–11**, the lying shirt, since columns 12–14 now hold the head.
- **The old hand fixes in the lying cells are replaced.** The body overlays (`tools/art/fixes/body_man.png` and `body_woman.png`) held, for the turned layout, a bent upper arm in both downed cells (archived art-pass review fix, 2026-11-13: "downed reads as hurt") and shut eyes in the dead cell. On the lying layout those pixels fell on the head. They are cleared; the dead cell gets shut eyes on the upright face (the whites and iris to skin, a black line across each eye, the open lid above to skin: 10 hand pixels per body). Downed and dead now differ by open or shut eyes and the breath frame. The bent arm is not redrawn: the arms now lie along the torso's edges, and a bent arm by the head would need its own hand pixels on both bodies (a follow-up if the owner wants downed to read as more hurt than dead).
- Head anchors re-measured on the composite: downed and dead are −14 (−13 on the turned frame); `BALSERO_ANCHORS` in `test_look_composer.gd` records them. Walk, crouch, swim and dive are unchanged.
- **Shadow.** `fx.py` gains a `shadow` kind and `fx.json` the piece `shadows/shadow_23x5.png`: a filled ellipse by pixel centre in #000000 at alpha 78 (MetroCity's), mirrored left to right and filling its box. `DropShadow.Size.LYING` is appended (3; the others keep 0–2) with its texture in `shadow.tscn`; `PlayerPose.lies` picks it for downed, dragged and dead, and the 12×7 otherwise. The shadows licence names it. art-terrain-polish C14 will append its WIDE size after LYING.
- Capture: `docs/art-pass/sprite-polish/lying_pose_before_after_x3.png` (`capture_looks.tscn`'s `looks_downed.png`, the four slots, downed above and dead below; before on top, after under it). It no longer reads as a turned standing frame: the body lies along the ground, the face is upright with the eyes side by side, open when downed and shut when dead.

**Bush in front (group 5, C8; D5).**
- `Look/BushFront` (a Sprite2D after `Sprite`, region on, nearest filter) shows the Brush layer's exact tile at the body's cell: `PlayerLook.bush_tile` holds its [source, atlas, alternative], the texture is that source's sheet, and the region is the tile's rows 4–14 (`BUSH_FRONT_TOP` 4, `BUSH_FRONT_ROWS` 11). It is placed at the cell's top left plus 4 px, so moving inside the cell leaves the bush where it is. It shows while the pose draws the body on land (`PlayerPose.shows_body` and no water line): standing, crouched, crawling, downed or dead in scrub, never swimming or diving.
- The Brush layer is found once, by walking up from the body to a node with an island beside it (a `TerrainView`, or a child whose `Terrain` is one), so the host's and the client's branches in one test process each find their own island.
- **Departure:** the cell is the Brush layer's own cell under the body's drawn position (`brush.local_to_map(brush.to_local(body.global_position))`), not `body.cell()`. On an island at the origin, as in the game, the two are the same; the capture tool offsets its island inside a viewport, where `body.cell()` would name another cell.
- The sandbar has no whole inland scrub cell; its inland bushes are lone bushes on the brush's row-4 islet picks (the variants there), so the 1-player test uses one of those and a fitted shore bush. The secret cay's row-5 picks come along the same way (the tile is copied, whatever row it is on).
- Tests (`test_bush_front.gd`, written first; they failed to parse before the node existed): solo, crouched on a lone bush and standing on a shore bush, the front copies the layer's tile, its sheet, its front rows, sits at the cell and is drawn after the sprite; off scrub, swimming and diving it is hidden; a palm south of the player draws over the bush front, which draws over the body (`DrawOrder`); host and client show the same tile at the same place for the client's player. `test_art_sim_invariance`, `test_draw_order`, `test_hidden_solo`, `test_player_art` and `test_terrain_view` stay green.
- Capture: `docs/art-pass/sprite-polish/bush_front_after_x3.png` (`capture_looks.tscn`'s new `looks_scrub.png`: two players crouched behind their bushes and one standing behind a shore bush; before: `docs/art-pass/review-2026-11-14/before/scrub_three.png`). The capture tool draws its bodies beside the island rather than in its y-sorted world, so it picks scrub cells away from the lean-to.

**Group 6, the shark redraw, facings and the fin off the deck (D3, D4; C24, SP4, SP1).** Built after crossing-gameplay merged (#70, #75), from main f8a6c75.
- **Group 0 re-read.** Since this design was written, crossing-gameplay has changed two things that matter here:
  - its strike already lands 1 tile off the hit side's edge (`Crossing.strike_spot`), so 6.3's seam is closed;
  - a warned fin circles 4 px round its spot, also 1 tile off the edge (`CreatureThreats.CIRCLE_RADIUS_PX`), so the drawn shark moves 4 px toward the deck.
- **Tests first.** They failed for the right reasons:
  - `test_creature_art.gd`:
    - **facing rows:** `patrol`, `circle` and `move` come as `_side`, `_up` and `_down`, and the bare names are gone. Each animation has at most 4 unique frames. The up and down fins are narrower above the line than the side fin;
    - **the water line:** no side or strike frame's line row holds a run longer than the fin's base (row 8) plus a 3 px dash. Today's frames ran 15 to 27 px;
    - **the width:** every frame draws within 12 px of its centre, down to the last faded row. Today's frames reached 15 px;
    - the new-creature test now expects `patrol_down`;
    - **the 1-player test:** the solo sandbar's shark heading mostly north plays `patrol_up`; turned east it plays `patrol_side` unmirrored, and turned west mirrored.
  - `test_crossing_art.gd`, two 1-player tests:
    - a solo raft crossing with an east shark pass;
    - a solo board crossing (the `test_board` fixture).

    Each steps the crossing, the shark and its look from the warning to the retreat. The fin's drawn box is the frame's non-clear texels down to the last faded row, mirrored as the sprite is, at the sprite's place. It never overlaps an intact deck or board and stays in `sea_rect()`. Today it overlapped the deck by 3 px at the warning.
  - The two-peer crossing test expects `patrol_down`. `art_pass_run.gd`'s offshore-shark check reads any `patrol`, `circle` or `move` facing.
- **The width, measured.** The spot is 16 px off the edge and the circle reaches 4 px toward it, so a drawn pixel may sit at most 12 px from the shark's centre, in columns 4 to 27 of the 32×16 cell. That is narrower than D3's and D4's 15 px, which predate the circle. Every frame keeps to it, so the fin's box at the circle's nearest point just touches the deck's edge and never overlaps it.
- **The redraw.** The hand source `tools/art/fixes/creatures/reef_shark.png` is redrawn by a helper as fills; the sheet's black rim outlines them. The sheet grows from 160×16 to 160×48:
  - **Row 0 (side, nose east):** two swim frames, then the three strike frames.
    - The dorsal fin is lit on its left (#cbdbfc, #9badb7) and shaded toward its leading edge (#847e87), on rows 2 to 7. Its base, row 8, is black, as today's was. The black base keeps the fin's edge ring at 3.34:1 on the deep; with a lit base row the edge-on fins read only 2.43:1.
    - On the line, row 9, the fin's 10 px base and two dashes of 2 to 3 px, which `waterline.gdshader` turns to foam, instead of a 15 px bar.
    - Under the line, rows 10 to 12 hold a tapered spindle from the forked tail at column 4 to the nose at 27. The second frame flicks the tail and moves the dashes.
    - **Strike:** the fin rises a row and throws 4×3 droplets, which keep a white core inside the rim, then sinks.
  - **Row 1 (up, heading north):** an edge-on fin with a 5 px base in the shade colours, a dash each side, and the tail fork under the water.
  - **Row 2 (down, heading south):** the same fin lit, with the snout under the water.
  - `reef_shark_frames.tres`:
    - `patrol`, `circle` and `move` each have `_side`, `_up` and `_down`, two frames at 4 fps;
    - `idle` and `strike` stay single;
    - 9 unique frames in all.
- **Checks.**
  - `creatures.py` rebuilt only `reef_shark.png`. The crab, the gulls and Platino rebuilt byte-identical.
  - `check.py`: 0 problems on the art and the fixes. Every frame keeps 3:1 on the shallows and the deep (3.34:1 on the deep at worst).
  - The four crossing-shark test files stay green.
- **Noted, not changed.** A passing crossing shark never changes its synced `facing` (new creatures face down, and `CreatureThreats` only moves it), so it always draws `patrol_down`, the edge-on fin. Turning it to show its side would be a crossing-gameplay change (setting the facing along its circle), not art.
- **Captures,** off-screen, per the owner's 2026-11-23 rule:
  - `capture_creatures.tscn` gains `sharks_day.png`: four sharks on the sandbar's water heading north, west, east and south;
  - `capture_crossing.tscn` gains a shark pass from the east, with `crossing_shark_tell.png` and `crossing_shark_strike.png`.
- **Images:**
  - `docs/art-pass/sprite-polish/shark_facings_before_after_x5.png`: `before/cr_water_day_crop5.png` left, and the four facings now right.
  - `docs/art-pass/sprite-polish/crossing_fin_before_after_x6.png`: from `before/crossing_shark.png` at the top, the fin over the deck; below it, the fin waiting a tile off the hull during the tell, then after the strike.
