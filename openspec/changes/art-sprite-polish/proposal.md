# Proposal

## Why

Wave 3 of the art and HUD review of 2026-11-14 (`docs/art-pass/review-2026-11-14/DESIGN_PASS.md`, section 2.3 and section 3 "Wave 3: sprites", plus PR1 from section 2.4). The characters and creatures read as cut-outs on the new rounded coast:

- A swimmer is cut by one dead-straight white bar the body's width, and the two swim frames are the same above the line, so the swimmer is a frozen floating head (SP2, SP3).
- During the crossing's shark pass the fin sits on the raft's planks (SP1).
- A rider thrown in on the deck's north side is drawn over the planks with a white stripe across them (SP5).
- The shark is a fin on a straight foam bar over a dark slab, with side frames only, so it slides sideways when it heads north or south (SP4).
- The crab fills its cell edge to edge with a one-frame idle (SP8). The gull's wings end in straight walls on the cell edge, and its swoop lifts only 8 px (SP10). Downed and dead are the idle frame turned 90°, eyes stacked, with the standing shadow poking out (SP9).
- Scrub is cover, but the bush is a ground tile under the player: crouched in a bush reads as crouched on sand with a closed-eye mark (PR1).

The owner accepted every recommended option on 2026-11-14 and approved queuing this wave on 2026-11-15. Q6 (a): a small animated ripple ring round the swimmer, SPD style, reversing the earlier straight-cut decision (archived art-pass D19). Q7 (a) (the shark south of the raft) has since been overtaken by crossing-gameplay's shark tell; see design.md "Owner decisions".

## What Changes

Art only. No synced value, layout, terrain kind or simulation number changes. Smallest first:

- **Swim bob and ripple ring (C19, C20; SP3, SP2).** The two swim frames come from walk frames 1 and 3 (`poses.py` `SWIM_FROM`), which gives a 1 px bob from the source art. A new `Look/SwimRing` sprite, 2–3 frames of a dashed light oval of about 18–20×5 px, drawn by a small recipe, shows round a swimming or floating body. The player shader cuts the frame hard at the water line instead of a white row and a fade.
- **A smaller, livelier crab (C25; SP8).** About 12–13 px wide, one big claw, feet on the cell's bottom row, idle 0, 1, 0, 2 at 4–5 fps, a 4-frame scuttle at no more than 12 fps. It keeps its dark red shell.
- **Gull flight frames (C25; SP10).** Flight frames in 24×16 cells with bent M wings that never touch the frame edge, played for swoop, flee and return; the flying lift rises from 8 to 15 px (archived art-pass D16).
- **A lying pose (C25; SP9).** Downed, dragged and dead come from a new pose rule: the body turned to lie along the ground, the head kept upright so the eyes sit side by side, and a 22–24×5 lying shadow. Every look part follows, with no hand pixels per part.
- **Bush in front (C8; PR1).** A `Look/BushFront` sprite draws the Brush layer's exact tile at the body's cell, variant included, over the body sprite, so a crouched player shows the bush in front of them up to the chin. It builds after art-terrain-polish's scrub variants (C10).
- **Shark redraw and facings (C24; SP4).** A redrawn fin and tapered body, a broken foam dash instead of a solid bar, and `_up` / `_down` (edge-on fin) variants of patrol, circle and move. Every frame's drawn half-width stays at most 15 px.
- **The fin stays off the deck (SP1, drawing only).** crossing-gameplay already moves the shark: its fin circles 1 tile off the side the pass names for 5 s, with a shoo point that follows it. This change adds no crossing delta and no drawn drift. It guarantees the drawn fin never covers an intact deck or board, and tests that on crossing-gameplay's placement.
- **Swimmer behind the deck (C22; SP5).** A swimmer north of a drawn deck's top edge, within its span, is drawn just under the deck (Look z −21), so only the head shows above the planks. Riders aboard, swimmers beside or south of the deck and island swimmers are unchanged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `art-pass`:
  - "Swimmers at the water line": the hard cut, the ripple ring and the swim bob replace the 1 px white ripple row and the fade.
  - "Crossing look": a swimmer north of the deck is drawn under it.
  - New requirements: "Cover over a crouched body", "The fin stays off the deck", "The shark reads from every side", "Crab frames", "Gull flight frames" and "Lying pose".

## Impact

- Art tools (`tools/art/`):
  - `poses.py`: `SWIM_FROM` and the lying rule; `test_poses.py`.
  - A new `fx.py` recipe (png.py only) and `test_fx.py` for the swim ring.
  - `creature_sheets.json`, the hand sources `fixes/creatures/reef_shark.png`, `land_crab.png` and a new `seagull_flight.png`, and `test_creatures.py`.
- Rebuilt art: every player part sheet under `game/assets/art/characters/` (swim and lying cells), `game/assets/art/creatures/` (shark, crab, gull sheets and their `_frames.tres`), a new `game/assets/art/fx/swim_ring.png` with its `.tres` and licence block, and the lying ellipse in `game/assets/art/shadows/`.
- Game scripts and scenes: `scenes/art/player_look.gd`, `.tscn` and `.gdshader`; `scripts/art/player_pose.gd`; `scenes/art/shadow.gd` (a LYING size appended to the enum); `game/assets/art/creatures/creature_art.tres` (the gull's `air_lift_px`).
- Tests: `test_player_art.gd`, `test_look_composer.gd`, `test_palette_swap.gd`, `test_creature_art.gd`, `test_drop_shadow.gd`, `test_draw_order.gd`, `test_crossing_art.gd` and new crossing fin and swimmer tests. `test_art_sim_invariance`, the frame budget and the contrast tests stay green.
- No crossing, creature, networking, HUD or layout file changes.
- Left out of this queue (the design pass's other wave 3 items): C23 vessels (waterline wobble, the raft's 3/4 redraw, the car and the board), SP11 (crouch lean, run dust) and SP12 (the occlusion outline under the hut roof), and C21's move of the shark's spawn south.
