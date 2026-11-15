# Proposal

## Why

The owner played on 2026-11-14 and said "it's hard to notice when you are getting damage". Today a hit changes only the number and fill of the Salud bar in the top-left corner. The bar pulses only at 25 or less, so a shark's 25-point bite at full health and a crab's 5-point pinch go by unseen, and nothing shows on the body, so a teammate's hits are invisible too.

## What Changes

**Telling a hit from a drain (every peer, nothing sent)**
- Each peer watches the health it already has for every body: the host its own simulation, a client what the host replicates. A loss that comes at once is a **hit**: a shark's strike or bite (25), a crab's pinch (5), any later creature or item that takes health in one go. A loss spread over time is a **drain**: thirst at 0 (2/s), drowning in the crossing (10/s), manzanillo (−50 over 60 s).
- The test is the rate of the loss, not the size of one update, so a client that misses half a second of sync while drowning does not read it as a crab.
- The first value a peer sees for a body, a rise (revive, healing), a body that is dead, and a rebind to another body never cue.
- No synced property, RPC or simulation code is added. Everything here is drawing and HUD, and the art/sim invariance run is extended with a crab pinch to prove it.

**On the body, seen by every peer (owner decision Q1, recommended A)**
- On a hit the player's sprite flashes white for one frame, then blinks for 0.6 s: the hurt blink of *A Link to the Past* and GBA-era games.
- Drains show nothing on the body. The teammate's name tag and health strip already show while health is not full.

**On the local screen (Q2, recommended A)**
- A red flash at the screen edges, scaled by the size of the hit, with a floor so the smallest hit (a crab's 5 of 100) is still plain to see. It fires at most three times a second.
- The Salud bar shows the lost chunk in pale red, holds it for a moment, then drains it down to the new value (DCSS's changed-bar colour, the GBA HP bar draining). The bar shakes by 1 px on a hit.
- The cue follows the meters panel: your own body, or the teammate you watch while dead (dead-spectate).

**Floating numbers (Q3, recommended A: none).** The bar's chunk carries the size of the hit, as the GBA games do.

**Drains (Q4, recommended A)**: the softer cue. The chunk ticks down on the Salud bar and the bar's frame glows a dim red while the drain lasts. There is no blink, edge flash or shake.

**Included unless the owner objects**
- **Reduce flashes:** a "Reducir destellos" checkbox in Ajustes, off by default and kept per install. With it on, the blink becomes a steady red tint, and the edge flash and shake are gone; the bar's chunk stays.
- **No knockback:** it would move a body the host simulates. If a shake is wanted (Q2 B), it is a camera-only 2 px shake on big hits.
- **Sound hook:** a hit asks `AudioManager.play_sfx` for `hurt_hit` or `hurt_big`, and a drain's start asks for `hurt_drain`. The call does nothing until sounds exist.

**Solo:** all of it works with one player, offline. A 1-player test covers a crab pinch and thirst at 0.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `survival-meters`: ADDED "Hits and drains are told apart" and "Hurt cue on the body".
- `ui-shell`: ADDED "Hit flash at the screen edges", "Lost health shows on the bar" and "Drain glow on the health bar". MODIFIED "Settings" adds the reduce-flashes checkbox.

## Impact

- New scripts:
  - `game/scripts/ui/hurt_watch.gd` (`HurtWatch`), the pure classifier, with `hurt_blink.gd` (`HurtBlink`) and `hurt_cues.gd` (`HurtCues`: the reduce-flashes flag and the shared tuning);
  - `game/scripts/ui/hurt_cue_tuning.gd` (`HurtCueTuning`), with its data in `game/resources/hurt_cue_tuning.tres`;
  - `game/scenes/ui/hurt_overlay.gd`, the screen edge.
- `game/scenes/art/player_look.gd` and `player_look.gdshader`: the blink and the white flash, through a uniform after the water-line cut.
- `game/scenes/ui/meter_bar.gd` and `.tscn`: the lost chunk and the shake.
- `game/scenes/ui/meters_hud.gd` and `.tscn`: the edge overlay, the drain glow and the binding. These edits are kept narrow, because a HUD restyle is in review.
- `game/scripts/ui/game_settings.gd` and `game/scenes/shell/settings_screen.gd` and `.tscn`: the reduce-flashes checkbox.
- `game/scripts/autoload/audio_manager.gd`: one no-op `play_sfx(id)` method. No new autoload.
- Tests:
  - new unit tests;
  - a solo test;
  - host-plus-client tests;
  - a crab pinch inside `test_art_sim_invariance.gd`;
  - `tests/manual/damage_feedback_run.gd`, two processes on UDP 7793.
- Not touched: `player.tscn`'s synchronizer, `survival_meters.gd`, `crossing.gd`, `creature_world.gd`, networking and saves.
