# Design

## Context

See proposal.md, "Why".

- **Placement is crossing-gameplay's.**
  - `CrossingHazards` (z −30) draws the lane beats `shown_beats()` lists, each at `Crossing.beat_center`: its lane beside the vessel's lateral position, and its time to come measured up the sea from the deck's middle.
  - A rock is `rock_width_tiles` wide (2 today) and debris `debris_width_tiles` (1); the raft is `vessel_width_tiles` (4).
  - A child at z −19 draws each open leak at `Crossing.leak_position`.
  - Warnings are crossing-gameplay's too: a hazard shows at the sea's north edge `hazard_lead_s` (5 s) before it reaches the deck, and the HUD's line names a leak as it opens.
- **What art-mood-pass group 5 (#129) adds, which this change sits on:**
  - crests at z −38 and a wake at z −35;
  - flotsam drawn as loot through `CrossingHazards.piece_look`;
  - the pure rules in `CrossingArt`;
  - five sea pieces through `mood.py`.
- **Colours already taken on the sea:**
  - #ffffff is the fin's foam;
  - #cbdbfc and #9badb7 are the wake's and the flotsam ring's;
  - crests keep to the deep ramp and #4a85a8.
- **The contrast rule:** an actor's outline ring or mean colour reaches 3:1 on the grounds it is on (art-pass "Actors stand out from the ground"). On the deep, black reaches 3.34:1 and #222034 only 2.52:1.

## Goals / Non-Goals

**Goals:**
- Hazards whose silhouettes say "rock", "wreckage" and "leak" at a glance on deep water, each drawn exactly where and as wide as it hits.
- Frames from the plan clock, never by chance, so every peer agrees and the tests can read them.
- Art through the existing recipe, with its colour and outline checks.

**Non-Goals:**
- Changing any hazard's width, lane, time, damage, drain or warning lead.
- New hazard kinds.
- A sound for impacts.
- Flotsam's look (art-mood-pass D8).
- Island rocks.

## Decisions

### D1. Each hazard is as wide as its lane (owner QH1, recommended answer)
- **The rule.**
  - A rock's outlined body is `rock_width_tiles` × 16 px wide (32 px), and debris's `debris_width_tiles` × 16 px (16 px).
  - Each is centred on `beat_center`.
  - Its collar may reach 2 px a side past the body (`ArtTuning.hazard_collar_px`).
  - "At raft width" is read as "at the raft's own pixel scale": what the riders see is exactly what hits.
- **A test pins it.** It reads the tuning's widths and the art's opaque bounds, so a tuning change that widens a rock fails until the art is redrawn.
- **Rejected:**
  - (b) Drawing a rock 4 tiles wide, like the raft, over a 2-tile hit lane. Riders would steer away from water that is safe.
  - (c) Widening the rock's hit lane to 4 tiles in data. That is a balance change to crossing-gameplay, not drawing.

### D2. A rock head with a surf collar
- **`sea/rock.png`,** one 32×16 frame:
  - a low, wide wet rock head lit from the upper left, in #595652, #847e87 and #9badb7 highlights, with a #45283c crack, outlined in black;
  - its bottom row is the waterline, straight and cut, so it sits in the water instead of on it.
- **`sea/rock_surf.png`,** 3 frames of 36×6:
  - a broken ring of foam in #cbdbfc and #9badb7;
  - drawn over the rock's bottom rows, centred on its waterline, so the surf wraps its base;
  - the dashes swell outward over the three frames.
- **Frames** come from the plan clock and the beat's index, at `ArtTuning.hazard_fps`.

### D3. Debris as a jagged cluster
- **`sea/debris.png`,** one 16×10 frame:
  - a splintered board (#8f563b, lit #c08a5a) crossed by a buckled strip of tin (#847e87, #9badb7) with one bent nail, outlined in black;
  - a jagged top edge, unlike the flotsam plank's clean board, so wreckage that cuts never reads as a plank to grab.
- **`sea/debris_surf.png`,** 2 frames of 18×4, the same foam colours.

### D4. A leak's jet
- **`fx/leak_spurt.png`,** 3 frames of 9×12:
  - a black and #222034 crack at the bottom;
  - a jet of #cbdbfc with a #639bff core that rises 1 px a frame and falls back;
  - drawn bottom-centre on `leak_position` by today's z −19 child, so it sits over the planks and under the riders.
- The frame steps on the plan clock, offset by the leak's index, so two leaks never pulse together.

### D5. Data, the recipe and the rules
- **Textures.** `crossing.tscn` names the five textures on `Hazards`: `rock_texture`, `rock_surf_texture`, `debris_texture`, `debris_surf_texture` and `spurt_texture`. `check.py` requires each tracked PNG to be named by a scene or resource.
- **Numbers.** `ArtTuning` gains `hazard_fps` and `hazard_collar_px`.
- **Pure rules in `CrossingArt`:**
  - `hazard_frame(index, frames, elapsed_s)`;
  - `hazard_look(crossing, beat)`: the texture, its top left, its collar's frame and top left;
  - `spurt_look(crossing, leak_index)`.

  `CrossingHazards._draw` and `_draw_spurts` only consume them, as `piece_look` does.
- **The recipe.** `mood_fx.json` gains the five pieces:
  - the bodies with `"outline": "#000000"`;
  - the surfs and the jet with their colour sets, never #ffffff.

### Reference games
- **Shattered Pixel Dungeon:**
  - *Borrowed:* `effects/Ripple.java` grows and fades a ring where a character steps in water, and `effects/Splash.java` bursts a few pixels of one colour. They are the model for the surf collar's swelling frames and the jet's rise and fall.
  - *Borrowed:* `levels/traps/Trap.java` gives each trap kind its own colour and shape (`color`, `shape`) so it reads at a glance. Each hazard here has its own silhouette: a wide mound, a jagged cluster, an upright jet.
  - *Rejected:* SPD's particle emitters (`GameScene.emitter()`), which roll each particle at random. Frames come from the plan clock so every peer draws the same.
- **Brogue CE:**
  - *Borrowed:* `TM_VISUALLY_DISTINCT` (`Rogue.h`, used in `Globals.c`'s tile catalogue) marks terrain that must stand out from its background. Here that is a fixed 3:1 rule on the deep ground, checked by the tests.
  - *Rejected:* Brogue's run-time colour adjustment of such tiles. Our palette is fixed and the art is checked offline.
- **DCSS:**
  - *Borrowed:* `_pack_shoal_waves` (`tilecell.cc`) lays a wave overlay on water cells beside land or a wall. That is the foam collar where the sea meets a rock.
  - *Rejected:* `tile_apply_animations` (`tileview.cc`) picking a random water flavour each turn, for the same reason as SPD's emitters.
- **Don't Starve Together** (wiki pages "Sea Stack", "Leak", which redirects to "Floating Platform", and "Waves"; `docs/REFERENCE_DST.md` "Sea stacks", "Boat health and leaks"):
  - *Borrowed:* the roles. A sea stack is a fixed rock a boat collides with, and a leak is a damage state of the boat.
  - None of the three pages describes how these look. So nothing visual is borrowed, and the art is our own.
  - *Rejected:* the yellow paint some stacks carry near Moon Quay, a landmark marker that has no use here.

## Owner decisions

- **QH1. How wide is a rock drawn?** The review asked for rocks and debris "at raft width with a foam collar".
  - (a) *Recommended:* each at its own lane's width (rock 2 tiles, debris 1) at the raft's pixel scale, so what is seen is what hits (D1).
  - (b) A rock drawn 4 tiles wide like the raft over its 2-tile hit lane.
  - (c) The rock's hit lane widened to 4 tiles in data, a balance change.

  The spec is written for (a). (b) or (c) changes the spec's width rule, and (c) changes crossing-gameplay's tuning.

## Risks / Trade-offs

- **[The width depends on the tuning]** If crossing-gameplay retunes a width, the art no longer matches. → D1's test fails on any mismatch, so the art is redrawn with the retune.
- **[Collar over the rock's base]** The surf hides the rock's bottom rows. → The body's outline ring is measured above the collar, and the 3:1 test reads both.
- **[Debris against flotsam]** Debris could still be mistaken for a plank. → It has a jagged edge and a tin strip, and the plank has a clean board. The 1-player test checks the two use different art.
- **[Busy water]** Crests, wake, flotsam and hazards share the sea. → The hazards are the only dark, outlined masses on it, and crests stay in the deep ramp.

## Migration Plan

Art only. Rebuild with `python -I tools/art/mood.py`, then import twice. Roll back by reverting the commit: no save, network message or tuning depends on these pixels.
