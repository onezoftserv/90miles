# Proposal

## Why

The owner played on 2026-11-14 and reported two problems.

**Hits are hard to see.** The owner said "it's hard to notice when you are getting damage". Today a hit changes only the number and fill of the Salud bar in the top-left corner. The bar pulses only at 25 or less, so two hits go by unseen:
- a shark's 25-point bite at full health;
- a crab's 5-point pinch.

Nothing shows on the body either, so a teammate's hits are invisible too.

**Uses are hard to read.** The owner also said "it's hard to know what happens when you use coconuts or sabila". The owner widened this change to cover uses ("Both"). Today nothing confirms a use:
- `request_use` drops the host's result;
- `hud_text.tres` has no success line;
- item descriptions are never shown;
- a use that does nothing, such as sábila when nothing needs curing, still spends the item.

## What Changes

### Part 1: hits and drains

**Telling a hit from a drain (every peer, nothing sent)**
- Each peer watches the meters it already has for every body: the host its own simulation, a client what the host replicates.
- A **hit** is health lost at once. Today that is a shark's strike or bite (25) or a crab's pinch (5). Any later creature or item that takes health in one go counts too.
- A **drain** is health lost over time: thirst at 0 (2/s), drowning in the crossing (10/s), manzanillo (−50 over 60 s).
- The test is the loss against the body's recent steady change, not the size of one update. So a client that misses half a second of sync while drowning does not read it as a crab.
- These never cue:
  - the first value a peer sees for a body;
  - a dead body;
  - a rebind to another body.
- No synced property, RPC or simulation code is added for this. The art/sim invariance run is extended with a crab pinch to prove it.

**On the body, seen by every peer (Q1, recommended A):** on a hit the sprite is drawn white for one frame, then blinks for 0.6 s. This is the hurt blink of *A Link to the Past* and GBA-era games. Drains show nothing on the body; the name tag and health strip already show while health is not full.

**On the local screen (Q2, recommended A)**
- A red flash at the screen edges, scaled by the size of the hit. A floor keeps the smallest hit (a crab's 5 of 100) plain to see. It fires at most three times a second.
- The Salud bar shows the lost chunk in pale red, holds it, then drains it down. This borrows DCSS's changed-bar colour and the GBA HP bar draining. The bar shakes by 1 px on a hit.
- The cue follows the meters panel: your own body, or the teammate you watch while dead.

**Drains (Q4, recommended A):** the chunk ticks down and the Salud bar's frame glows dim red while the drain lasts. There is no blink, edge flash or shake.

### Part 2: item uses

**After a use: change floats (Q7)**
- When a meter jumps at once, every peer floats the change over that body for about 1 s, in the meter's colour, stacked:
  - "+15 Sed" and "+5 Hambre" after a coconut;
  - "+N Sed" for a drink at the lagoon;
  - "+30 Salud" on a revive.
- A status that clears floats "Sin sangrado" or "Sin quemadura".
- This is the hit cue's watch run the other way, from the same replicated state, so a teammate sees your coconut too.
- Slow regains do not float.

**Hits float too (Q3, recommended A):** "−25" in red over the hurt body, from the same system. Without floats for uses we had recommended none; with them, a hit's number is consistent and plain.

**The changed bar:** a bar whose meter jumped shows its gained slice in a light tint of its colour and flashes once, for about 1 s. This is DCSS's `colour_bar` gain slice; a loss shows the pale red slice from Part 1.

**Before a use: an effect line (Q5, recommended A)**
- The row just above the selected item's line reads what the use the button would send does, built from that use's own effect data and the rules the host applies:
  - "Sed +15 · Hambre +5 · Energía +10" (the coconut is a meal);
  - "Cura sangrado y quemadura" (sábila);
  - "Salud −50 en 60 s" (manzanillo).
- The text cannot drift from the effects. Kinds the host does not apply yet, such as `APPLY_STATUS`, are left out.
- A refusal still replaces the row for 2 s.

**Refusing a use that would do nothing (Q6, recommended A)**
- A use is refused, with a reason and with nothing spent, when no effect would change anything for whoever it goes on: every meter it raises is already full, every status it cures is absent, and it has no other effect.
- The lines are Cuban and live in `hud_text.tres`:
  - "No tienes sed."
  - "No 'tás sangrando."
  - "A Papo no le hace falta."
- The HUD checks first, and the host refuses too. This follows DCSS's `can_quaff` and Brogue's "not hungry enough" check in `eat()`.

### Included unless the owner objects
- **Reduce flashes:** a "Reducir destellos" checkbox in Ajustes, off by default and kept per install. With it on:
  - the blink becomes a steady red tint;
  - the edge flash, the bar flash and the shake are gone;
  - floats, slices and the glow stay.
- **No knockback:** it would move a body the host simulates. If a shake is wanted (Q2 B), it is a camera-only 2 px shake on big hits.
- **Sound hook:** `AudioManager.play_sfx` is called with `hurt_hit`, `hurt_big`, `hurt_drain` or `use_done`. It does nothing until sounds exist.
- **Out of scope:** sábila's own gameplay (a bleeding drain, treating teammates, a sunburn source). A separate session fixes it, and this change edits no effect.

**Solo:** all of it works with one player, offline. The 1-player tests cover:
- a crab pinch;
- thirst at 0;
- drinking a coconut;
- sábila refused with nothing to cure.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `survival-meters`: ADDED requirements:
  - "Hits and drains are told apart"
  - "Jumps and cures are told apart"
  - "Hurt cue on the body"
  - "Change floats over the body"
- `ui-shell`: ADDED requirements:
  - "Hit flash at the screen edges"
  - "Changes show on the bars"
  - "Drain glow on the health bar"

  MODIFIED "Settings" adds the reduce-flashes checkbox.
- `inventory-hud`: ADDED "Effect line" and "Uses that would do nothing".
- `crafting-inventory`: ADDED "A use that changes nothing is refused".

## Impact

**New scripts**
- `game/scripts/ui/meter_watch.gd` (`MeterWatch`): the pure classifier for hits, drains, jumps and cures.
- `hurt_blink.gd` (`HurtBlink`).
- `hurt_cues.gd` (`HurtCues`): the reduce-flashes flag and the shared tuning.
- `hurt_cue_tuning.gd` (`HurtCueTuning`), with its data in `game/resources/hurt_cue_tuning.tres`.
- `effect_line.gd` (`EffectLine`): the effect text built from `ItemUseData`.
- `game/scenes/ui/hurt_overlay.gd`: the screen edge.
- `game/scenes/ui/change_floats.gd`: floats anchored to the head, as name tags are.

**Edited scenes and scripts**
- `game/scenes/art/player_look.gd` and `.gdshader`: the blink.
- `game/scenes/ui/meter_bar.gd` and `.tscn`: the change slice, the shake and the glow.
- `game/scenes/ui/meters_hud.gd` and `.tscn`: the overlay.
- `game/scenes/ui/run_hud.gd` and `.tscn`: one `ChangeFloats` node beside `Marks`.
- `game/scenes/ui/inventory_strip.gd`: the effect line in the notice row, and the new refusal.
- `game/scripts/crafting/item_user.gd`: a `NOTHING_TO_DO` reason in `check`, shared by the host and the HUD. This is the one simulation edit, and it is a rule: a refused use spends nothing.
- `game/scripts/ui/hud_text.gd` and `game/resources/hud_text.tres`: meter and status words for floats and the effect line, and the refusal lines.
- `game/scripts/ui/game_settings.gd` and the settings screen.
- `game/scripts/autoload/audio_manager.gd`: one no-op method. No new autoload.

**Tests**
- Unit tests.
- Solo tests.
- Host-plus-client tests.
- A crab pinch inside `test_art_sim_invariance.gd`.
- `tests/manual/damage_feedback_run.gd`: two processes on UDP 7793.

**Not touched:**
- `player.tscn`'s synchronizer;
- `survival_meters.gd`;
- `effect_applier.gd` and every item's effects;
- `crossing.gd` and `creature_world.gd`;
- networking and saves.
