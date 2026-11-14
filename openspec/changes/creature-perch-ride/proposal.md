# Proposal

## Why

`balsero-lore` specified the *galleguito* (a laughing gull that rides a player's head on the final crossing), the `ambient` birds and a guarantee that chance-1.0 crossing creatures are always placed. None of it can run: nothing reads a creature's CROSSING spawn rules, nothing applies `sighting_effects`, `SET_FLAG` and the once-per-run and once-per-day limits do nothing, and neither `ambient.gd` nor `PERCH_RIDE` exists. This change builds `balsero-lore` task group 7 (7.1–7.4), so content-batch-12 can add the birds as data only.

## What Changes

- **Crossing creature roll.** When a crossing launches, the host reads every creature's CROSSING spawn rules against the departing island's chain family, the distance band, the day phase and the weather.
  - A chance-1.0 rule is always placed, respecting `max_per_run`.
  - The other rules are rolled, and at most `CrossingTuning.max_rolled_creatures` (2) of them are placed.
  - The placed creatures come through the session's entity spawner, so clients and late joiners see them.
  - They ride along with the vessel, are passing creatures (the island ignores them) and leave every screen when the crossing ends.
  - The threat plan's beats (squall, shark pass, rock) are unchanged and are rolled first.
- **Sighting effects.** Each player who sees a creature gets its `sighting_effects`: every living rider of its crossing, or on an island a player within its sight radius.
  - `ONCE_PER_RUN` and `ONCE_PER_DAY` hold per player. They are keyed by the player, not the peer, so a rejoin never pays twice.
  - `METER_ADD` goes through `EffectApplier`. `SET_FLAG` sets a run flag the host keeps until the run ends.
- **Run record.** A host-only `RunRecord` on the session holds the run's flags, `max_per_run` counts and effect-limit marks. It is new every run.
- **`ambient.gd`** (songbird, booby, sperm whale, pelican): it arrives at its station, stays and leaves.
  - It leaves when a FLEE counter's condition holds (the booby in a squall), its stay time ends or its crossing ends.
  - It never attacks, steals or touches the vessel.
- **`CreatureData.Behavior.PERCH_RIDE`**, appended after `TRADE_OR_ROB`, and **`perch_ride.gd`**:
  - It circles, then lands on the rider holding the most food (ties broken by the run seed) and turns with them.
  - A shoo makes it hop to another head; with nobody else aboard it circles for 5 s and lands again.
  - It waits overhead while its rider is in the water.
  - From 60 s after landing, every 60 s while it is perched, it rolls 50% to take one held food item. It never leaves after a theft.
  - It never changes speed, drift, threats or the outcome.
- **Perched on every peer.** The creature syncs which rider it sits on, as a spawn property, and every peer draws it on that rider's head facing their way. It follows a rejoined rider.
  - Its shoo prompt ranks below the crossing's tie-down, climb and pull points, so a gull on your head never hides the lash in a squall.
- **Carried-item immunity.** An `ITEM_CARRIED` → `NEGATE` counter (the *Pluma de galleguito*) stops `swoop_steal` and `perch_ride` from robbing the holder.
- **Tests.** Every behavior has a 1-player, offline GUT test built on fixture creatures in `game/tests/fixtures/content/`. Host-plus-client tests cover the perched gull on the rider's head for a client and a late joiner, and a client's shoo. A manual harness runs a host and a client as two processes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `creatures-ai`: added "Crossing creature roll", "Crossing creatures leave with the crossing", "Sighting effects", "Ambient visits", "Perch ride details", "Perched creature never hides the rescue points", "Perched creature on every peer" and "Carried-item immunity". They complement `balsero-lore`'s "Perch ride", "Final gull" and "Crossing spawn rules", which this change implements but does not restate.

## Impact

- **New code:**
  - `game/scripts/ai/ambient.gd` and `game/scripts/ai/perch_ride.gd`.
  - `game/scripts/crossing/crossing_creatures.gd`: the roll, a crossing-side `CreatureWorld`, and cleanup at the end of the crossing.
  - `game/scripts/run/run_record.gd` and `game/scripts/ai/sightings.gd`.
- **Edited code:**
  - `creature_data.gd`: append `PERCH_RIDE`.
  - `creature.gd`: the rider sync, a passing flag and the shoo priority from the brain.
  - `creature_look.gd`: draw on the rider's head.
  - `creature_world.gd`: the crossing, the run record and the carried-item check.
  - `swoop_steal.gd`: the carried-item check.
  - `effect_applier.gd`: `SET_FLAG` and `CLEAR_FLAG`.
  - `crossing_tuning.gd` and `.tres`: `max_rolled_creatures`.
  - `coop_session.gd`: one `run_record` variable.
  - `game_shell.gd`: one call that rolls the crossing's creatures with the island's chain family.
- **`crossing.gd` and the plan are left alone:**
  - `vessel-car-board` edits the crossing scene, so the roll lives beside it.
  - No new `CrossingBeat.Kind` is added, so plan and snapshot serialisation do not change.
- **Not in this change:**
  - The production creature files (`galleguito`, `pajarito`, `pajaro_bobo`, `rabihorcado`), their art, and the feather counter on `seagull.tres` (content-batch-12, tasks 9.1–9.3).
  - The rabihorcado and the pelican's catch theft, which need fishing.
  - The sperm whale's −10 wake and the songbird's noise flee, which needs a noise bus. The data can name them; the machine ignores them for now.
  - The gull's dialogue lines (`beat_galleguito`; `DialogueService` is a stub).
  - Its walk up the beach on arrival.
- **No real run meets the galleguito yet.** No island has the FINAL chain family, so the gull is exercised through tests and a manual harness hook until the final chain exists (recorded in `TASKS.md`).
- Solo stays first-class: the gull's only shoo alternative is its own circle, the pick is the solo player, and morale is per player.
