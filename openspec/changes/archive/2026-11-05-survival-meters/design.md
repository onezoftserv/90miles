# Design

## Context

`player-movement` left a `SurvivalMeters` node with energy only: `PlayerBody` spends it through `spend_energy`, and `downed` is a plain `PlayerBody` flag that `DragHandle` reads. There is no day cycle, weather, shade, crafting, inventory or networking yet, so every input the meters need from those systems has to be injectable. `game/resources/<folder>` accepts only registered content types (`ContentCatalog.unregistered_folders()` fails the validator otherwise). Static typing is enforced, and a typed array of a script's own class leaks at exit. See proposal.md for the numbers and the provisional decisions.

## Goals / Non-Goals

**Goals:** every spec scenario is a GUT test with exact numbers, stepped by hand with no scene tree timing; every rate lives in one data file; the energy API and the 178 existing tests keep passing; the HUD reads only the meters node, so it works the same on host and clients.

**Non-Goals:** replicating meters (coop-networking adds the synchronizer); items that drink, eat, poison or revive (crafting-inventory, through `EffectData`); running the clock and weather (weather-daynight); showing hallucinations; telling every player about an ally's death (the party system that detects it calls each player's meters); death screens and spectating (Milestone B).

## Decisions

### State in the component, rates in pure functions
`SurvivalMeters` (`Node`) keeps the six values, timed changes, states, the downed timer and the signals. `tick(delta, context)` applies one step: timed changes first, then rates, then thresholds and the downed timer. The rates come from static functions in `SurvivalRules` (`RefCounted`, pure: context + tuning in, per-second rates out), so the rules read in one short file and tests can also check a rate directly. Alternative: one large node script; rejected to keep each file small and the rules readable apart from the bookkeeping. Same split as `MovementModel`/`PlayerBody`.

### Inputs as a context object
`MeterContext` (`RefCounted`) carries what the world knows: `phase` (`DataEnums.DayPhase`), `midday` (10:00–16:00), `shaded`, `in_water`, `swimming`, `crafting`, `teammate_nearby` and `heat_factor` (1, or 2 in scorching calm). Direct sun is `phase == DAY and not shaded and not in_water`. Tests build it directly. In the game, `PlayerBody` builds it each physics frame on the host: water from the terrain, swimming from the movement state (SWIM or DIVE; FLOAT is in water but not swimming), shade from a new `TerrainQuery.is_shaded(cell)` (default false; `GridTerrain` gets a shaded set), company from other players in the `players` group within 5 tiles (80 px) that are not dead, and clock and weather from a `ClimateState` (`RefCounted` with `phase`, `midday`, `heat_factor`; default day, not midday, ×1). weather-daynight will drive that object; until then the playground sets it. `crafting` stays false until crafting-inventory sets it. Alternative: meters reading `WeatherManager` directly; rejected because the stub has no clock and tests would depend on an autoload.

### One tuning file, values only there
`SurvivalTuning` (`Resource`, `scripts/components/survival_tuning.gd`) exports every rate (per real second), threshold, factor and event amount with no meaningful script defaults. The numbers live once, in `game/resources/survival_tuning.tres`, and `SurvivalMeters.tuning` defaults to it (`preload`), so a bare `SurvivalMeters.new()` in tests uses the shipped values. The file sits at the top of the content root, not in a subfolder, because subfolders must be registered content types and tuning is not content; the smoke run still loads it. One test lists the spec numbers against the file, so retuning after the playtest fails loudly and points at the spec and §4. Alternatives: constants in code like `MovementModel` (rejected: the playtest is about to retune these, and the project wants tuning in data), or registering a `tuning` content type (rejected: that is a content-data spec change for one file).

### Plain properties and signals, ready for a synchronizer
Each meter is a float property (`thirst`, `hunger`, `heat`, `energy`, `morale`, `health`) whose setter clamps to 0–100 and emits `meter_changed(meter, value)` when the value changes; energy also keeps `energy_changed(value)`. States are bool properties with their own signals: `sunstroke` and `hallucinating` (`*_changed(active)`), `downed` (`downed_changed(is_downed)`) and `dead` (`died()`), plus `downed_time_left_s`. Only `tick` and the host-side methods derive states, so on a client a replicated value just updates the property and the HUD. The hunger energy cap is enforced by the host-side methods (`gain_energy`, `eat`, `sleep_night`, `tick`), not the setter, so replicated values arriving in any order are never clamped wrongly.

### Host-side methods for events
`drink(thirst)`, `eat(hunger)` (adds hunger, plus the meal's +10 energy when hunger > 0), `sleep_night()` (+50 energy), `damage(health)`, `add_over_time(meter, total, duration_s)` for seawater and poison, `morale_event(event)` for ally death, squall, fire, song and text (amounts in tuning), and `revive()` (30 health, only while downed). Item amounts (coconut 15, seawater +10 / −30 over 120 s, poison −20 over 30 s) are item data that crafting-inventory feeds into these methods through `EffectData` (`METER_ADD` with `duration_s`, `REVIVE`); the meters do not interpret `EffectData` in this change. Timed changes are `MeterOverTime` objects (meter, rate, time left) in an `Array[MeterOverTime]`, a separate class so no script types an array of itself.

### Thresholds and float crumbs
A value at or below 1e-6 counts as empty and snaps to 0, as `MovementModel` does for energy, so a hunger of 2e-15 never keeps the energy cap off. Sunstroke starts at heat ≥ 100 and ends below 60; hallucinating is morale < 20; health at 0 downs a co-op player (`solo == false`) for 90 s and kills a solo one at once. Dead meters stop ticking. `solo` is a property set by whoever spawns the players (false in the two-player playground).

### Downed moves to the meters; the body follows
`PlayerBody` connects `downed_changed` to its existing `set_downed`, so dragging and `DragHandle` work unchanged, and on `died` it stays down with the drag handle disabled. The body ticks the meters after movement, only when `multiplayer.is_server()` (true offline), and keeps ticking while downed so thirst still drains. Energy spending stays where it is.

### Solo is derived from the run, and fire is company
`PlayerBody` sets `meters.solo` on every host tick: true when no other player in the `players` group is alive (dead teammates do not count, downed ones do). A one-player run and the last survivor of a co-op run therefore die at 0 health instead of waiting 90 s for a revive nobody can give. `MeterContext.near_fire` stops the night drain like a teammate does; the body sets it when a node in the `lit_fires` group is within `company_radius_tiles`. Nothing adds itself to that group yet: crafting-inventory's fire will join it while lit, so the rule already works end to end (a test stands a `Node2D` in for the fire). Alternatives: `solo` set once by run setup (rejected: nothing sets it today, and it would miss the last-one-alive case), or exempting solo runs from the night drain (rejected: it removes the night's pressure instead of giving the player something to do about it).

### Last stand and free revive are hooks other systems set
Health reaching 0 goes through one place, in this order:
1. An unused free revive (`SurvivalMeters.free_revives`, an int the keepsake system sets to 1 for the Medalla's holder) stands the player at `revive_health` and counts down (`free_revive_used` signal).
2. Otherwise a co-op player is downed for `tuning.downed_s + downed_bonus_s`.
3. Otherwise a solo player gets a last stand (`last_stand`, `last_stand_changed`) of `tuning.solo_last_stand_s` (0) `+ downed_bonus_s`, or dies at once when that is 0.

`downed_bonus_s` is the Experiencia hook: endings-progression sets it from the player's level and boosts, and the meters never compute it. The last stand reuses `downed_time_left_s` and `revive()`, so a cup the player uses on themselves stands them up exactly like a teammate's cup. `PlayerBody` lies the body down during a last stand with its drag handle disabled.

Alternative: modelling the last stand as `downed` with a different timer. Rejected because "downed" means a teammate can drag or revive, and the HUD and body would have to ask "but is anyone there?" everywhere.

### Sunstroke slows through a speed factor
`MovementModel.step` gains a trailing `speed_factor: float = 1.0` that scales the player's own speed (walk, run, crouch, crawl, swim), not the water current or a drag. `SurvivalMeters.speed_factor()` returns 0.6 during sunstroke. The parameter is optional, so existing callers and tests are untouched.

### HUD: one widget, bound to one meters node
`scenes/ui/meters_hud.tscn` (`MetersHud`, a full-screen `Control` that ignores the mouse) holds six `MeterBar` rows (`scenes/ui/meter_bar.tscn`: a label and a flat-colored `ProgressBar`, 0–100) in the top-left corner, about 120×62 px with Press Start 2P at 8 px. Each row's meter, Spanish label and color are exported in the scene, so changing a label needs no code; localization keys wait for review item 45. `bind(meters)` reads the current values and follows `meter_changed` and `sunstroke_changed`; binding another node disconnects the old one. The sunstroke blur is a full-screen `ColorRect` with a small box-blur shader over the screen texture (works in the Compatibility renderer), shown only while the bound player has sunstroke. The movement playground gets a `CanvasLayer` with the HUD bound to its first local player, a shaded hut and a fixed midday climate so every meter can be watched by hand. `main.tscn` stays idle.

## Risks / Trade-offs

- [All numbers are provisional] → one `.tres`, one test listing them, and the spec, §4 and the file change together.
- [`PlayerBody`, `player.tscn`, `TerrainQuery` and `MovementModel` are player-movement files the coop-networking session may also touch] → only additive changes (an optional parameter, a default-false method, two signal connections); rebase on `main` before the PR.
- [The HUD layout has no owner (review item 23)] → a self-contained widget with no assumptions about the rest of the screen.
- [Clients clamping energy on replication order] → the cap lives in host-side methods only.
- [Shaders and fonts do not render headless] → headless tests check bar values and overlay visibility; one windowed run with a screenshot checks the look.
- [Thirst drain at 0 is now reachable: 2 health/s downs a player 50 s after thirst runs out] → called out in the proposal for the playtest.

## Open Questions

None that change this design; the provisional decisions and open questions are in proposal.md.
