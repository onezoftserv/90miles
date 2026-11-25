# Proposal

## Why

The Fable review of 2026-11-22 (main 8c58c16) found that the HUD never says where the player is or what to do:
- **H1:** time is one word ("Mediodía"), with no day count and no time left before dark.
- **H2 and G4:** nothing on screen names the goal, the direction or the run's progress. The first frame of a run is dark and wordless.
- **H13 and G9:** Calor reads like an emptied meter. At sea, Calor sat at 100 for 46 s and the screen blurred with no word saying why.
- **H14:** "Sangrando" is a bare word, with no icon and no time left.

The owner took the review's recommended options on 2026-11-23:
- Priority 3, "Tell the player the goal, the time and the keys": the objective row, the clock and the hut note. The controls card belongs to the run-menu session.
- Decision 5 (a): the objective row and the hut note now, with the shipwreck intro as its own later change.
- Decision 7 (a): Calor gets its own thermometer row with an "Insolación" tag. The heat cap at sea belongs to island-pressure.

## What Changes

**Clock strip** (ui-shell "Clock strip", "HUD layout")
- The day phase window becomes one 228×14 px clock row at (152,4)–(380,18). It extends left into the empty band between the meters and the old phase tag.
- From left to right the row shows:
  - the day count, "Día 2";
  - a strip of the day from dawn to the next dawn, coloured by phase, with a sun-yellow marker at the time of day;
  - the time left before dark, in in-game hours beside a moon mark, or before dawn beside a sun mark at night;
  - the phase word.
- DAY's word splits into "Mañana", "Mediodía" and "Tarde", so the row never reads "Día 2 … Día".
- It reads the session's sky, which the host runs and every client follows.

**Objective row** (ui-shell "Objective row")
- A thin row under the clock, at (152,20)–(380,30), names the current goal in Cuban voice and updates as the party progresses. The goals, in order:
  - "Arma la balsa: 2/6 madera", counting each input the raft site still needs, input by input;
  - "Lleva to' pa' la balsa";
  - "Dale a la balsa: 40%";
  - by day, while a patrol boat is out, "Espera la noche pa' zarpar" (island-pressure's launch rule, owner 2026-11-23);
  - at night or in a squall, "Zarpa pa'l cayo";
  - at sea, "Aguanta hasta tierra".
- It reads only the level's synced raft site, the built raft and the local player's own inventory, so every peer shows its own player's view of the same goal.
- It never names or points at anything secret.
- It yields to an open sign note.

**Raft-site arrow** (ui-shell "Raft-site arrow"; "Inventory band and world marks")
- While the current island's raft site or raft is off screen, a small arrow on the screen's edge points at it.
- The arrow keeps out of the HUD windows, the horizon band and the bottom band.

**Hut note** (island-generation "The hut note")
- A new sign beside the sandbar's hut, read with the existing sign note. It states the goal in voice: Florida is to the north, you build a raft from wood, tubes and rope, and you set off at night or in a squall, because by day the patrol boat sees you.

**Calor row and Insolación** (survival-meters "HUD bars", "Sunstroke tag on the HUD")
- Calor leaves the middle of the meters and becomes the last row.
- Its bar is a thermometer: the empty track is tinted by zone (calm, warning, critical), with notches at the warning and critical steps.
- While the player has sunstroke, an "Insolación" status row, with a sun icon and a bar of the heat left to shed, names the blur.

**Sangrando row** (survival-meters "Bleeding tag on the HUD", "Bleeding time on every peer")
- "Sangrando" becomes a status row with a drop icon and a bar of the bleeding time left.
- The host's time left is synced as one plain meter property, so a client's and a spectator's bars are honest.

**Layout moves**
- The secret cay's needle moves from (308,20) to (384,20), under the weather window's place, because the objective row now holds y 20–30.
- Nothing else moves: the weather window, the sign note, the note label, the teammate list and the crossing strip all keep their places.

**Content**
- Items gain an optional short name for counts (content-data "Short names for counts"). Driftwood is "madera" and "wood", so the count fits the row.
- Islands gain an optional launch line, the objective's words for setting off. The sandbar's is "Zarpa pa'l cayo"; any other island uses the default line.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `ui-shell`:
  - "HUD layout" (the clock, the objective row and the needle's new place);
  - "Inventory band and world marks" (the edge arrow);
  - new "Clock strip", "Objective row" and "Raft-site arrow".
- `survival-meters`:
  - "HUD bars" (Calor last, as a thermometer);
  - "Bleeding tag on the HUD" (a status row with an icon and a time bar);
  - new "Sunstroke tag on the HUD" and "Bleeding time on every peer".
- `island-generation`: new "The hut note".
- `secret-cay`: "Needle on the carrier's HUD" (its new place).
- `content-data`: new "Short names for counts" and "Launch lines".

## Impact

**New scenes and scripts:**
- `game/scenes/ui/`: `clock_strip.*`, `objective_row.*`, `site_arrow.*` and `status_row.*`;
- `game/scripts/ui/`: `objective.gd` (pure: site, raft and inventory to a goal and its line) and `day_strip.gd` (pure: time to segments, marker and time left).

**Edited:**
- `run_hud.gd` and `.tscn` (a few lines each);
- `meters_hud.gd` and `.tscn`, `meter_bar.gd` (zone track and notches);
- `compass_needle.tscn` (new place);
- `survival_meters.gd` (`bleeding_left_s`) and `player.tscn` (one synchronizer entry);
- `hud_text.gd` and `.tres` (a new `objective_lines` and `clock_words` block);
- `item_data.gd` and `driftwood.tres`, `inner_tube.tres`, `rope.tres`;
- `island_layout_data.gd`, `sandbar.tres` (one cell, the sign, the launch line).

**Tests:**
- new 1-player tests;
- a host-plus-client check of the clock, the objective and the bleeding bar on a client (UDP 7800);
- updated `test_run_hud`, `test_hud_windows`, `test_compass_needle`, `test_player_state_sync` and `test_sign_note`.

**Out of scope:**
- the heat cap at sea (island-pressure);
- the controls card and the run menu (run-menu);
- the crossing HUD strip (crossing-gameplay #75, unchanged);
- hiding or wiring Energía and Ánimo (H13's other half);
- pulsing the sábila slot (H14's cure hint);
- "Cayo 1/3".

**Archive order:** hud-window-kit, damage-feedback, bleeding-and-sabila and art-mood-pass archive before this change. Its MODIFIED blocks are written on their text.
