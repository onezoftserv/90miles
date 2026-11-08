# Proposal

## Why

Milestone B (`TASKS.md` §4) needs the first live threats. The creature data classes exist but nothing reads them, and the crossing's shark is a scripted dice roll. This change builds the reef shark, the land crab and the seagull as data plus three state machines, and puts a reef shark behind the crossing's shark pass.

## What Changes

- Three creature files: `game/resources/creatures/{reef_shark,land_crab,seagull}.tres`.
- A generic creature scene (`game/scenes/creatures/creature.tscn`), run by the host and synced through the session's entity spawner.
- Three state machines in `game/scripts/ai/` (`patrol_circle_strike`, `night_thief`, `swoop_steal`), picked by the data's behavior name.
- Land and water `AStarGrid2D`s built from the island terrain (`CreatureNav`), with the shark's 2-tile shore margin.
- A host spawner (`CreatureSpawner`) that reads spawn rules on the sandbar: crabs at night, gulls at their palms, one offshore shark.
- `CreatureThreats`, a `CrossingThreats` resolver that replaces the scripted shark with a reef shark creature. The crossing's numbers and tests are unchanged.
- Small append-only data fields: `CreatureData.keep_off_shore_tiles`, `CreatureSpawnRuleData.per_beach` and `anchor`, `IslandLayoutData.nest_palms` (checked as palm indices), and `Inventory.held_food()`.
- Capability: `creatures-ai`, ADDED requirements only. No existing requirement is modified.
- Docs: `docs/ISLANDS.md` §1 "Threats" names the offshore shark; `docs/BESTIARY.md` "Seagulls" defines held food; `TASKS.md` §4.

Out of scope: moray eel, barracuda, man o' war, mosquitoes, crocodile, boa, bosses; the noise and blood event bus; frigatebird, galleguito, guardacostas; combat (so no killing creatures, crab meat or gull egg raids and no nest pecks); sealed containers; spear and raw-fish shark counters. Creature health and loot are data only until a combat change exists.

## Solo

Every behavior is tested with exactly 1 player, offline: a lone swimmer is circled, struck only when bleeding or tired, and escapes to the shallows; a lone player guards a stash with one fire; a lone player keeps food from a gull by shooing. A solo player is their own host, so creatures run with no network.

## Confirmed by the owner (2026-11-08)

1. **Gull theft (D3, option A).** "Held food" is the inventory's first FOOD slot while the player is on land (not swimming), `Inventory.held_food()`. A gull swoops, takes one, flees and is back at its perch 30 s later. `docs/BESTIARY.md` "Seagulls" says so.
2. **Sandbar shark (D6).** One reef shark offshore around the sandbar (deep and shallow water, at least 2 tiles from shore), circling swimmers and striking only a bleeding swimmer or one below 20 energy. `docs/ISLANDS.md` §1 "Threats" names this change. Turning it off later is data only (spawn chance 0).

## Provisional decisions

Not yet confirmed by the owner. Each is data or a named constant.

- **D1** The crossing shark keeps the crossing's instant pass (strike or ram at the beat), then circles visually for its circle time.
- **D2** A stash is a food pick-up on the ground (no containers exist). Sealed containers come with a later crafting change.
- **D4** Fire halving: half the crabs spawn (rounded down) when a fire is lit at night start; half the living crabs leave when one is lit mid-night. Light radius is the company radius, 5 tiles.
- **D5** A beach is a 4-connected group of at least 8 beach cells; 6 crabs per beach.
- **D7** A shoo is an interact on the gull within 2 tiles.
- **D8** The shark's domains are deep and shallow water; its 2-tile margin removes the water next to land.
- **D9** No tide exists, so all rules use `Tide.ANY`.
- **D10** Party scaling compounds the creature's `party_rate_mult_per_extra_player` (1.2) and floors: 6, 7, 8, 10 crabs for 1–4 players. The shark and the gulls do not scale.
- **(P)** Shark health 60, patrol 2 tiles/s, circle ×1.5, retreat away at base speed, a lunge at the end of the circle, leave 2 s, ignore 20 s, hearing 8 tiles. Crab health 3, speed 5, pinch every 1 s adjacent, flee 10 s after a steal, 10% bleeding left out. Gull health 2, speed 6, sight 8 tiles, shoo reach 2 tiles. Nest palms are indices 4 and 5 (the two farthest from the hut). Offshore shark spawns within 10 tiles of land.
