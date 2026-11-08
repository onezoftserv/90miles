# Design

## Shape

- `CreatureData` (existing) holds everything a creature does. `Creature` (`scenes/creatures/creature.gd`) is one generic node; its `brain` is `CreatureBrain.for_behavior(data.behavior)`, which loads `res://scripts/ai/<behavior in snake_case>.gd`. A new creature with an existing behavior is a new `.tres` and nothing else.
- `CreatureWorld` is what a brain may read or ask (players, lit fires, food pick-ups, the grids, the day phase, the rng) and the few things it may do (`strike`, `pinch`, `take_from_pickup`, `take_held`). It exists on the host only: a creature without a world does nothing, and `Creature.advance` returns on a client.
- `CreatureNav` builds the land grid and `water(margin)` grids from the island's `GridTerrain`, plus the land distance (Chebyshev) used for the shore margin and the beach groups. Path following is in the base brain, with a 0.5 s recompute cap.
- `CreatureSpawner` (a node under the session, host only) reads spawn rules: rules with no phases fire once (the offshore shark); phased rules fire when a phase begins and nothing of that rule is alive. Despawn phases remove creatures. A `FIRE_LIGHT`/`DISPERSE` counter means "half as many while a fire burns".
- Sync: the session sets `entity_spawner.spawn_function`; `CoopSession.spawn_creature(data, at)` spawns `{name, id, position}` and each peer builds the creature from the catalog. The synchronizer (position, facing, state) is added in code for session creatures only, so the crossing's visual shark has none.

## Decisions

- **Crossing timing (D1):** the creature shark keeps the crossing's instant pass; a pre-pass circle would break "Shark pass event" timing. The visual shark is a `Creature` with no world and a `lifetime_s` of the circle time.
- **Strike:** at the end of the circle the shark lunges to 1 tile from the swimmer (if that cell is open water outside the margin) and strikes in the same step. A dash at 3× speed was considered and dropped: it made the strike time depend on distance, and the spec fixes it at circle end.
- **Targeting:** a swimmer is targetable if they stand in an open cell of the shark's water grid (water, at least the margin from land). The shallows by the shore are therefore out of reach, and a swimmer who reaches them ends the hunt.
- **Stash (D2):** a food pick-up on the ground, taken through `CreatureWorld.take_from_pickup`, so containers can plug in later.
- **Held food (D3, confirmed):** `Inventory.held_food()` is the first FOOD slot; the world skips swimmers.
- **Fire (D4):** halving at night start and for the living crabs when a fire is lit. A crab never steps into a lit fire's radius and only moves outward from inside it. A stash whose adjacent cells are in the light is not a target.
- **Spawner timing:** the island is furnished before the session's peer is connected (in the network tests, and so on a client `is_server()` is still true then), so `CreatureSpawner.start()` defers its first spawn by a frame and then does nothing on a client.
- **Party scaling (D10):** `floor(count × 1.2^(players−1))` per beach for the crabs; anchored members (gulls) do not scale.
- **Tide (D9):** none exists, rules use `Tide.ANY`.
- **Run seed:** the spawner's rng uses a fixed seed (90) until a run seed reaches the island; circle times and positions are therefore the same each run.

## Reference games (ideas and structure only; nothing copied or translated)

**Reef shark: DCSS "shark frenzy"**
- `MONS_SHARK` and its blood frenzy are no longer in the cloned DCSS (only `skyshark.yaml` and `BAND_SKYSHARKS` in `mon-place.cc`). The idea comes from the archetype described in `docs/BESTIARY.md`, not from code.
- Borrowed from `mon-behv.cc`: `handle_behaviour`'s split into `BEH_WANDER` / `BEH_SEEK` / `BEH_FLEE` gives PATROL / CIRCLE-STRIKE / RETREAT-LEAVE. `behaviour_event` (`ME_ALERT`, `ME_DISTURB`, `ME_SCARE`) gives the single INVESTIGATE entry point that the noise bus can feed later.
- Borrowed from `mon-act.cc` (around l.4069): water-habitat monsters keep to deep water and do not step out of their habitat. This is the water grid with a shore margin, so "stay in the shallows" is a real counter.
- Borrowed from `dat/mons/*.yaml`: one data file per monster.
- Rejected: frenzy as a speed or damage buff. Here blood is a targeting gate (strike only if bleeding or tired); a buff would punish a lone wounded swimmer twice.

**Seagull: Brogue monkey (steal and flee)**
- Borrowed: `MA_HIT_STEAL_FLEE` (`Rogue.h`) and the steal on a hit (`Combat.c`, around l.423); `updateMonsterState` in `Monsters.c`, where a thief stays fleeing while it carries the item. The gull carries what it took and flees for a fixed 30 s.
- Rejected: the safety map (`Time.c` `updateSafetyMap`, a Dijkstra scan from the player): a flyer on a small sandbar only needs "away from the nest, then home". Also rejected: stealing a random pack item; the docs limit gulls to food on the ground or held.

**Land crab: Shattered Pixel Dungeon crab and thief**
- `Crab.java`: borrowed a weak, fast mob that is a nuisance; rejected its 15 HP (ours has 3).
- `Thief.java`: borrowed the steal then flee (`attackProc` → `steal` → `FLEEING`), with the stolen item held on the mob (dropped on death later, with combat).
- `Mob.java` states: borrowed the states as objects behind one interface, with a night (active) and dawn (despawn) switch in place of sleeping. `Fleeing.nowhereToRun` (a cornered fleer fights) is borrowed as the turn-aside in `_run`; a cornered crab keeps pinching.
- Rejected: the escape roll in `Fleeing.act`. A crab flees light by a fixed radius so tests are exact.

## Risks handled

- Typed arrays of the creature's own class leak at exit: the rig keeps `Array[Node2D]`.
- `Array[StringName].sort()` does not sort by text: `ContentCatalog.list_ids` already sorts by text and the spawner uses it.
- The solo pause freezes creatures: `Creature` uses the default process mode.
- The offline default: see "Spawner timing".
