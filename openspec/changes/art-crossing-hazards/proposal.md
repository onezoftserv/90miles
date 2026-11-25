# Proposal

## Why

The crossing's rocks, debris and leak spurts are still crossing-gameplay's kitbashed placeholders in `CrossingHazards`:
- a rock is a grey polygon on a 75% white box;
- debris is a brown rectangle on another white box;
- a leak is a few rectangles of blue.

Art waves 2, 3 and 5 gave the crossing's sea crests, a wake and flotsam that reads as loot (art-mood-pass C35). The hazards are now the plainest thing on the water, and the white boxes are the only white near the raft besides the shark's foam.

The review's crossing item asked to "draw rocks and debris at raft width with a foam collar". On 2026-11-24 the owner chose "Own change after group 5" for it, with the leak spurts too.

## What Changes

The art is drawing only. Each hazard's hit width, lane, timing, warning lead and drain are crossing-gameplay's, and none of them changes.

- **Rocks.**
  - A hand-drawn rock head, a dark wet stone outlined in black, drawn exactly as wide as the lane it hits: `rock_width_tiles` × 16 px, 32 px today. What the riders see is what hits the raft, at the raft's own pixel scale.
  - A 3-frame surf collar at its waterline in the wake's foam colours, pulsing on the plan clock.
- **Debris.**
  - A hand-drawn cluster of wreckage, a splintered board and a twisted sheet of tin, outlined in black, as wide as its lane: `debris_width_tiles` × 16 px, 16 px today.
  - A 2-frame surf collar.
- **Leak spurts.** A 3-frame jet of water rising from a dark crack, drawn where each open leak is, over the deck and under the riders (z −19, as today).
- **Readable on deep water.**
  - Every hazard's outline ring and its collar reach 3:1 against the deep ground, the actors' rule.
  - No hazard uses #ffffff, which stays the shark fin's foam.
  - Each kind has its own silhouette: a wide dark mound, a jagged low cluster, an upright jet.
- **New art** is own work, drawn as hand sources in `tools/art/fixes/mood/`. The existing recipe, `tools/art/mood.py`, checks it and writes it to `game/assets/art/sea/` and `game/assets/art/fx/`.
- **The look reads only synced state:**
  - the beats `CrossingHazards.shown_beats()` lists;
  - the leaks `shown_leaks()` lists;
  - the plan clock.

  So a host, a client and a late joiner draw the same frames. A solo crossing looks the same.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `art-pass`: new requirements "Crossing rocks and debris look", "Crossing leak look" and "Crossing hazard frames and drawing only".

## Impact

- **Code:** `game/scenes/crossing/crossing_hazards.gd`.
  - `_draw_rock`, `_draw_debris` and `_draw_spurts` become texture draws.
  - Its lists and z stay as they are.
  - `CrossingArt` (`game/scripts/art/crossing_art.gd`) gains the pure frame and placement rules the tests read.
- **Data:**
  - `game/scenes/crossing/crossing.tscn` names the new textures on `Hazards`;
  - `game/resources/art_tuning.tres` gains the hazards' frame rate and collar reach.
- **Art tools:** `tools/art/mood_fx.json` gains the pieces; `tools/art/test_mood.py`'s tracked list grows.
- **New tracked art:**
  - `game/assets/art/sea/rock.png`, `rock_surf.png`, `debris.png`, `debris_surf.png`;
  - `game/assets/art/fx/leak_spurt.png`;
  - their own-work licence blocks.
- **Tests:** `test_crossing_art.gd`, with a 1-player crossing; `test_draw_order.gd`; `test_mood.py`.
- **Order:** builds after art-mood-pass group 5 (#129), which this change's `CrossingHazards` and `CrossingArt` edits sit on.
- **Not changed:**
  - crossing-gameplay's specs and tuning;
  - the HUD's warning lines;
  - flotsam's look, which is art-mood-pass D8.
