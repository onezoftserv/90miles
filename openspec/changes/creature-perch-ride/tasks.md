# Tasks

Test-first: each task writes its GUT test before the code, and every test that involves players has exactly 1 player, offline, unless it is marked host-plus-client. Every group ends with `godot --headless --path game --import`, `godot --headless --path game -s res://tests/smoke.gd` and `godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gexit` passing with no `ERROR:` lines.

## 1. Run record, flags and sighting effects

- [x] 1.1 Add `game/scripts/run/run_record.gd` (flags, per-run creature counts, effect claims with NONE, ONCE_PER_RUN, ONCE_PER_DAY and ONCE_PER_READER) and `CoopSession.run_record`; `test_run_record.gd` covers each limit across days and a fresh record per session
- [x] 1.2 `EffectApplier` applies `SET_FLAG` and `CLEAR_FLAG` to the actor's session record and does nothing without a session; a 1-player test sets and clears `galleguito_a_bordo` through a body in a session
- [x] 1.3 Add `game/scripts/ai/sightings.gd` and the `CreatureWorld` fields (`crossing`, `record`, `day()`, `run_seed()`, `peer_of`); `test_sightings.gd`: the solo songbird scenario (+5, +0 the same day, +5 the next day), a flag set once, an island creature seen only within its sight radius, and the same body seen twice paying once
- [x] 1.4 Run the import, the smoke run and GUT; all pass with no `ERROR:` lines

## 2. Crossing creature roll

- [x] 2.1 Add `CrossingTuning.max_rolled_creatures` with 2 in `crossing_tuning.tres`; the existing tuning test reads it
- [x] 2.2 Add the fixture catalog `game/tests/fixtures/content/creatures/` (`galleguito_prueba`, `pajarito_prueba`, `pajaro_bobo_prueba`, BESTIARY numbers, seagull frames) and the static `CrossingCreatures.roll`; `test_crossing_creatures.gd`: family, band, phase and weather filters; chance 1.0 placed with 3 rolled at 0.99 capped to 2; `max_per_run` 1 across two rolls; island rules ignored; and the plan rolled from the same seed holds the same beats with and without the creature roll after it
- [x] 2.3 Add the `CrossingCreatures` node, `Creature.passing` and `is_passing()`, and the call in `GameShell._on_route_started` (host only, after `Crossing.launch`, with the island's chain family); a 1-player crossing-rig test places a chance-1.0 booby at the sea's north edge, the island spawner's `creatures()` leaves it out, and the booby is gone when the crossing ends
- [x] 2.4 Run the import, the smoke run and GUT; all pass with no `ERROR:` lines

## 3. Ambient machine (balsero-lore 7.1)

- [x] 3.1 Write `test_ambient.gd` (1 player) and then `game/scripts/ai/ambient.gd`. The test covers:
  - a songbird and a booby on a mid crossing both run `Ambient`, reach their stations and each pay +5 morale once that day;
  - the booby leaves when the weather turns to squall and the songbird stays to the end;
  - a stay time ends a visit;
  - health, inventory and vessel integrity never change;
  - an island ambient lingers at its spot.
- [x] 3.2 Run the import, the smoke run and GUT; all pass with no `ERROR:` lines

## 4. Perch ride (balsero-lore 7.2, 7.3)

- [x] 4.1 Append `CreatureData.Behavior.PERCH_RIDE` after `TRADE_OR_ROB`; `test_data_classes.gd` (or the creature content test) checks its index follows `TRADE_OR_ROB` and `CreatureBrain.for_behavior` finds `perch_ride.gd`
- [x] 4.2 Write `test_perch_ride.gd` (1 player unless noted) and then `game/scripts/ai/perch_ride.gd`. The test covers:
  - circling then landing;
  - +10 morale once and `galleguito_a_bordo` set once;
  - theft held-only and at most twice in 120 s, with the first roll at 60 s;
  - a solo shoo circles 5 s and re-lands, and a roll inside the hover is skipped;
  - waiting overhead while the player swims and re-landing on the climb;
  - speed, drift, plan and integrity unchanged;
  - the co-op pick, in a 3-rider session (3, 1 and 1 food) and on a tie decided by the run seed;
  - a shoo with another rider aboard hops to that head;
  - a dead rider makes it pick again.
- [x] 4.3 Add `CreatureBrain.interact_priority()` (base 1; perch ride −1) and use it in `Creature._ready`; a 1-player test ties down and climbs aboard with the galleguito perched, and an island gull still outranks the palm
- [x] 4.4 Add `CreatureWorld.carries_negator` and use it in `swoop_steal.gd` and `perch_ride.gd`; a 1-player test with a registered fixture feather: an island gull with the counter takes nothing, and the galleguito's roll takes nothing
- [x] 4.5 Add the final-crossing tests: a crossing out of a FINAL-family island places the galleguito with 1 player and with 4, even when 2 rolled creatures already filled the cap, and the 4-player run gives each player +10 once
- [x] 4.6 Run the import, the smoke run and GUT; all pass with no `ERROR:` lines

## 5. Perched on every peer

- [ ] 5.1 Add `Creature.perch_peer` to `attach_sync` (spawn and always), and in `CreatureLook` draw a perched creature at its rider's body: head lift from `BodyLook.head_y()`, sorted over the rider, facing the rider's `PlayerLook.facing`. A 1-player look test draws it on the solo player's head and turns it with them.
- [ ] 5.2 Write `test_perch_ride_net.gd` (host plus client, NetHarness). It checks:
  - a client rider sees the gull on its own player's head while walking;
  - a client's shoo from beside the host's player hops it to the client's head, and one from 6 tiles is refused;
  - a client that joins mid-crossing sees it on the host player's head;
  - a rejoined rider keeps it, and its +10 morale is not paid twice.
- [ ] 5.3 Add `game/tests/manual/perch_ride_run.gd` (host and client as two processes, the fixture catalog, FINAL family by hook); run a host and a client locally and record the `PERCHRUN` lines in the PR
- [ ] 5.4 Run the import, the smoke run, GUT and a 300-frame headless run of the game; all pass with no `ERROR:` lines (balsero-lore 7.4)

## 6. Docs and task lists

- [ ] 6.1 Tick `balsero-lore` tasks 7.1–7.4. In `TASKS.md`, note under content-batch-12 that the scripts are in, that `galleguito` needs a FINAL-family island to meet a real run, and that the rabihorcado, the pelican's theft, the whale's wake and the songbird's noise flee are waiting on fishing, a wake rule and the noise bus. Add a history line.
- [ ] 6.2 Verify `openspec validate creature-perch-ride --type change --strict` and `openspec validate --all` pass

## Workflow follow-up

- Archive this change after the PR merges; `balsero-lore` stays open until groups 6–9 ship.
- content-batch-12 adds the production `galleguito`, `pajarito` and `pajaro_bobo` `.tres` files, their art and the feather counter on `seagull.tres` with no script edit.
