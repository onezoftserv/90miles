# Proposal

## Why

The guardacostas are the threat the whole game is named for, and nothing of them exists yet. The data model has a `PatrolData` part and the creatures-ai spec promises a world event bus, but no patrol boat, searchlight, spot rule or bus is built. `TASKS.md` §6 opens Milestone D with "`guardacostas-stealth`: patrol loop, searchlight cone, hidden states, smoke/noise bus". The main spec `openspec/specs/guardacostas-stealth/spec.md` has ten requirements, from the patrol loop to capture on the final crossing. That is too much for one buildable change, so this change scopes the first slice: **detection**. A second change, `guardacostas-capture`, covers the response: chase, the shore squad, capture, freeing a captive, `la_captura` and the restart on the previous island.

## What Changes

- **A patrol boat as data.** `game/resources/creatures/patrol_boat.tres` (`CreatureData`, tag PATROL, behavior PATROL_ROUTE, a `PatrolData` part) runs on one new generic brain, `game/scripts/ai/patrol_route.gd`. A second patrol kind is a new file, not a script edit.
- **The loop.** Each boat circles the island on a loop through deep water, 4 tiles outside the island's convex hull. Each 3-minute period has a 20 s horizon warning, a 100 s lap that starts and ends at the windward (east) end, and 60 s out of sight (owner decision 3). Experiencia adds 10 s per level to the time out of sight, and there is no Experiencia state yet. In a squall (`patrols_in_port`) no boat comes into sight.
- **The searchlight.** It is on at night only. It is a 60° cone, 10 tiles long, sweeping 30°/s back and forth over a 120° arc that faces the island (owner decision 4). The host tests it as plain geometry (angle and distance). It is not an `Area2D`, and it is not blocked by terrain: cover comes from the hidden states.
- **A spot meter per player, held by the host.** It fills 1 s per second while the player is lit and not hidden, and drains 0.5 s per second otherwise. At 2 s the player is spotted. The +1 s per Stealth level (up to +3) is read through the existing `PATROL_SPOT_TIME` modifier, which gives 0 until skills exist.
- **Hidden states.** Brush (scrub) hides a crouching player. Mangrove and roofed cells (the sandbar's hut, the coast cay's observation post) hide a player in any posture (owner decision 7). A dive hides the player for up to 5 s, as built. Weather that disables sight (fog) turns every searchlight off and stops sight spotting, and fog is tested with a fixture because no fog weather exists yet. The stealth state, and so the hidden mark, follows these rules on every peer.
- **Triggers.**
  - Smoke: while a boat is in sight, a lit fire within 2 tiles of the sea at night (never one on a roofed cell), or any lit fire within 6 tiles of the sea by day, raises an alert. Each fire alerts once per lap.
  - Noise: a boat in sight hears a noise of radius 8 tiles or more when it is within that radius.
  - Water: a swimmer who is not diving and is within 6 tiles of a boat in sight is spotted at once.
- **The world event bus** (creatures-ai "Noise and smell"). It is a node owned by the session on the host, not an autoload. It carries `noise(pos, radius)` and `smoke(pos)`, and lists the lit fires. Noise comes from data, through `EffectData` NOISE (owner decision 6). Blood comes later, with the creatures that need it.
- **The alert, which is all that spotting does in this slice** (owner decision 2):
  1. The boat stops, and its loudhailer calls out in formal Spanish.
  2. The light locks on the spotted player and follows them while they stay visible within 10 tiles.
  3. Hiding or getting out of range breaks the lock. The light then sweeps the last known position for 20 s, and the boat goes back to its loop.
  4. A new spot restarts the 20 s.
  5. Each alert emits `patrol_alerted(cause, position)` for `guardacostas-capture` to hook.
- **Every peer draws it.** The host runs the boats, the meters and every check. Each boat sends its loop clock and its beam's aim. Between syncs every peer advances them the same way, so a client's cone matches the host's. A late joiner gets both at once.
- **Cues** (owner decision 9):
  - a light on the HUD horizon band (a grey hull by day) for the 20 s before each lap;
  - an open-eye mark over any player whose spot meter is filling, drawn by the HUD on every peer like the hidden mark;
  - loudhailer lines in a speech bubble over the boat.

  The lines are drafts in `PatrolData` and wait for the owner's voice pass.
- **How many boats.** The sandbar counts as coast for patrols. It gets one boat, and the coast cay gets one or two (50% for a second). Each 2 living, connected players add one (`DifficultyScaling.extra_patrols`). The boats on one island are spread evenly round the loop in time. The secret cay gets none (owner decision 8).

## Solo

Solo is first class. One offline player is the host and runs every check on their own machine, so nothing waits for a second peer. The patrol count for one player is the base count. Every rule a solo player meets has a solo way through:
- crouch in the scrub or stand in the hut while the light passes;
- dive when a boat comes close;
- light the night fire inland or in the hut, or put it out while the horizon light shows;
- if spotted, break the lock by hiding and wait out the 20 s.

The tests run one offline player through a whole sandbar night: hiding through every lap with a fire in the hut and never spotted, then spotted on the open beach, hiding, and the boat giving up. Nothing in this slice needs a teammate.

## Owner decisions (recommended option first)

Not yet answered. The numbers in the What Changes list and in the specs follow the recommended options.

1. **The slice boundary.**
   a. *Recommended:* detection only. This change builds the patrol loop, searchlight, hidden states, spot meter, smoke, noise and water triggers, the noise and smoke bus, and an alert that ends with the boat giving up. A second change, `guardacostas-capture`, takes chase, the shore squad, capture, freeing a captive, `la_captura`, the restart on the previous island, and capture on the final crossing.
   b. Detection plus the shore squad's landing and search (the fire, then the last known position, then a random walk), but no capture. Capture and its outcomes go in the second change.
   c. All ten requirements in one change. It needs Rodríguez's `la_captura` scene, the persuasion check and the previous-island restart, so it is about three times the size.
2. **What being spotted does in this slice.**
   a. *Recommended:* an alert. The boat stops and its loudhailer calls out. The light locks on the spotted player and follows them while they stay visible within 10 tiles. Hiding (brush, a roof, a dive) or getting out of range breaks the lock. The light then sweeps the last known position for 20 s, and the boat goes back to its loop. A new spot restarts the 20 s. Nothing else happens until the capture change, which hooks the end of the alert.
   b. As (a), plus a stand-in cost so being spotted hurts now: −10 morale for the spotted player. The capture change removes it.
   c. As (a), but hiding does not break a lock. This is Don't Starve Together's Bush Hat rule: once the light is locked, it follows the player until they get out of range.
3. **The loop's shape.**
   a. *Recommended:* a loop round the whole island, 4 tiles outside its convex hull. That is 180 tiles of deep water on the sandbar and 195 on the coast cay, so the boat moves at 1.8–1.95 tiles/s. Each 3-minute period is a 20 s horizon light, then a 100 s lap that starts and ends at the windward (east) end, then 60 s out of sight. In one lap the sweeping light falls on 68% of the sandbar's land and 60% of the coast cay's. It never reaches the sandbar's raft site, which sits inside the bay, but it does reach the coast cay's. This matches BESTIARY's "a fixed loop around coast-chain islands".
   b. A pass along the windward (east) side only, as the spec reads now. The light then reaches only 8–12% of the sandbar (the tips of its C) and only the coast cay's rocky point, where the observation post hides you anyway. The lee side is a refuge, so the patrol is mostly scenery.
   c. Circling without stopping: one lap per 3 minutes at about 1 tile/s, never out of sight. There is no horizon light; the warning is the boat rounding the point.
4. **The cone, its sweep and the spot timing.**
   The percentages below come from a simulation of one 100 s lap on each island. They give the share of the land where a player standing still and not hidden gets spotted.

   a. *Recommended:* the spec's cone (60°, 10 tiles, 30°/s), sweeping back and forth over a 120° arc that faces the island, so a full sweep takes 8 s. A spot meter fills 1 s per second in the light and drains 0.5 s per second out of it. At 2 s the player is spotted, plus 1 s per Stealth level up to +3, and no skills exist yet. A still player in the open is caught on 45% of the sandbar's land and 34% of the coast cay's. While the boat is stopped for an alert, they are caught within two sweeps. A player who gets out of the light within 2 s is never caught.
   b. A strict reset with a slower sweep: the player must be lit for 2 s in a row, and the count resets when the light moves off. The sweep slows to 20°/s. A still player is caught on 48% of the sandbar's land and 36% of the coast cay's. The slower beam is easier to step out of.
   c. As (a), but over a 180° arc, so a full sweep takes 12 s. Each spot on the beach is lit less often: 31% and 20%. Gentler.
   d. As (a), but over a 90° arc: 58% and 42%. Harsher. A 140 s lap does about as much (62% and 51%), but it leaves only 20 s out of sight.
5. **Smoke.**
   a. *Recommended:* the spec's rule. While a boat is in sight, a smoke alert is raised by a lit fire within 2 tiles of the sea at night, or by any lit fire within 6 tiles of the sea by day. Each fire alerts once per lap, and a fire on a roofed cell (the hut, the post) never alerts at night. Measured on both islands: no land cell is more than 6.3 tiles from the sea, so every day fire is seen. At night 62% of the sandbar's land is safe for a fire, the hut included. The 20 s of horizon light is the time to put a fire out.
   b. BESTIARY's wording, "2 tiles from cover": at night a fire is seen unless brush, rock or a roof is within 2 tiles of it. By day, as in (a).
   c. As (a), but by day a fire is seen only within 3 tiles of the sea, so an inland day fire is safe. About 40% of the sandbar is more than 3 tiles inland.
6. **Noise sources in v1.**
   a. *Recommended:* noise comes from data only: an `EffectData` NOISE on an item, a route or a set piece, such as the conch's 15, the almendrón's 25 and the wall's 20 as each ships. It is scaled by the POI where it is made (a cave doubles it). A boat in sight hears a noise of radius 8 or more when it is within that radius of the source. Nothing in the game makes such a noise yet, so for now only fires and swimmers alert the patrol in play. The tests use fixtures.
   b. Also make building at a site a radius-8 noise while the hold runs (hammering and tying), so building the raft near a passing boat alerts it.
   c. Also put quiet everyday noise on the bus now, for sharks and birds later: running (3), a splash into water (4) and a gull taking off (6). All of it is below the patrol's 8.
7. **Hidden states: brush, mangrove and roofs.**
   a. *Recommended:* brush hides a player only while they crouch, as built. Mangrove hides a player standing or crouching, as BESTIARY and ISLANDS say ("stand in mangroves"). "Inside a structure" means a roofed cell the island marks (the sandbar's hut, the coast cay's post), in any posture. A placed fire or bench is not a roof.
   b. The spec as written: brush and mangrove both need a crouch, and roofed cells hide a player in any posture.
   c. As (a), but brush hides a player only while they crouch and stand still. Moving in brush shows you (the Bush Hat rule).
8. **How many boats, and where.**
   a. *Recommended:* the sandbar counts as coast for patrols, since its family is SANDBAR and layouts have no distance band. It gets one boat. The coast cay gets one or two (a 50% chance of a second). Each 2 living, connected players add one. The boats on one island are spread evenly round the loop in time. The secret cay gets none. Patrols on mid chains, far chains and the final crossing wait until those exist.
   b. One boat on each island in this slice, plus party scaling.
   c. One or two boats on both islands.
9. **Cues.**
   a. *Recommended:* three cues:
      - a small light on the HUD horizon band (a grey hull by day) for the 20 s before each lap;
      - an open-eye mark over any player whose spot meter is filling, drawn by the HUD on every peer like the hidden mark;
      - a loudhailer line in a speech bubble over the boat when an alert starts and when it gives up.
   b. The horizon light and the loudhailer only. With no open-eye mark, the 2 s comes without a warning.
   c. No HUD cues: only the boat and its light in the world.
10. **Hiding at sea and on a raft.**
    a. *Recommended:* not in this slice. The crossing's searchlight beat (cut the sail to go dark, or reach fog or the reef line) comes with the cutter boss in Milestone D. On islands, a swimmer can hide only by diving (5 s) and is spotted at once within 6 tiles of a boat in sight. The beached raft is open ground.
    b. Add the crossing's searchlight beat now, with the alert only. Riders crouching on the deck are hidden, and a rider lit for 2 s raises an alert.
    c. On islands, crouching in the shallows beside the beached raft hides you, with the raft as cover.

## Provisional numbers

All of these are data in `patrol_boat.tres` (`PatrolData`):
- Loop timing: a period of 180 s, made of a 20 s horizon warning, a 100 s lap and the rest out of sight; the loop 4 tiles outside the hull.
- Searchlight: night only, 60°, 10 tiles, 30°/s, over a 120° arc.
- Spot meter: spotted at 2 s, fills 1 s per second, drains 0.5 s per second.
- Triggers: water 6 tiles; smoke 2 tiles at night and 6 tiles by day; noise radius 8 or more.
- Alert: 20 s, with a ±30° sweep round the last known position.
- Boats: one on the sandbar, one or two on the coast cay, plus one per 2 players.

The loudhailer lines are drafts for the owner's voice pass. They stay in formal Spanish, because the official voice is the joke.

## Not in this change

The following come later, each in its own change:
- in `guardacostas-capture`: chase, the shore squad, capture, freeing a captive, `la_captura` with Rodríguez, the persuasion check, the restart on the previous island, and capture on the final crossing. That change will modify this change's Alert, whose ending it replaces. It will also modify the main spec's "Chase and shore squad", which says that being spotted starts a chase; until then the two read side by side;
- with the mid and far chains and the final crossing: patrols there ("Fade with distance");
- with the cutter boss: the crossing's searchlight beat;
- with their own changes: the jet ski, the patrol dinghy and logbook set pieces, the Stealth skill, Ex-militar's quieter steps, El Chino's slower spotting, Tania's loop prediction, and a fog weather file;
- with the creatures that need it: blood on the bus;
- with the art: the boat's sprite (until then it is a placeholder hull).

## Impact

- **Data classes:** `patrol_data.gd` gains these fields: lap time, hull offset, sweep arc, spot drain rate, alert time, lost-sweep half-angle, the second-boat chance, and the loudhailer lines (Spanish and English). `creature_counter_data.gd` and `effect_data.gd` are unchanged, because NOISE and SMOKE are already effect kinds. No new data class.
- **Content:** `game/resources/creatures/patrol_boat.tres`. Test fixtures: a fog weather, a noise item and a tiny island.
- **Code:**
  - New files:
    - `game/scripts/ai/patrol_route.gd`, the brain;
    - `game/scripts/stealth/`: `patrol_loop.gd` (hull, offset and the pose at a time), `searchlight.gd` (sweep and cone test), `spot_meter.gd`, `patrol_triggers.gd` (the smoke, noise and water rules) and `hidden_rules.gd`;
    - `game/scripts/world/world_events.gd`, the bus.
  - Changed files:
    - `movement_model.gd` takes the roofed cell and mangrove;
    - `player.gd` passes the roofed cell;
    - `player_net.gd` carries the spot meter;
    - `fire.gd` raises smoke;
    - `effect_applier.gd` routes NOISE and SMOKE to the bus;
    - `creature.gd` syncs the patrol's clock and aim;
    - `creature_spawner.gd` adds the extra-boat roll and phase spreading;
    - `body_marks.gd` draws the open-eye mark;
    - the horizon band gets the patrol light;
    - `creature_look.gd` gets a patrol look, which draws the cone above the night tint.
- **Specs:**
  - `guardacostas-stealth`: MODIFIED Patrol route, Searchlight, Hidden states and Triggers; ADDED Alert, Patrols on every peer, Patrol cues and Patrol data.
  - `creatures-ai`: MODIFIED Noise and smell (the bus).
  - `player-movement`: MODIFIED Walk, run, crouch (mangrove and roofed cells).
- **Sequencing:**
  - Rebase on `structure-state-sync` (PR #42) before building. It gives `fire.gd` a `lit` setter and `attach_sync`, and both changes touch `fire.gd` and `coop_session.gd`.
  - Rebase on `creature-perch-ride` (PR #46) as well. It adds synced fields to `creature.gd`, one line to `creature_spawner.gd` and a process priority to `creature_look.gd`, and this change edits all three. Its note says `CoopSession.spawn_creature` re-reads a creature's data from the catalog by id, so this change's test patrols are fixture files in the catalog, not copies made in code.
  - `net-platform-seam` touches `net_manager.gd` and `game_shell.gd`, which this change does not.
  - None of the open changes' deltas modifies a requirement this change modifies.
  - `vessel-car-board` (PR #48) adds no noise. Its almendrón's alert chance stays `RouteData.patrol_alert_chance`, which the capture change reads.
- **Docs, after the owner confirms:**
  - `docs/BESTIARY.md` patrol entry: the loop, arc, meter and alert;
  - `docs/GAME_DESIGN.md` §17: "Light cones with Area2D" becomes host geometry;
  - `docs/ISLANDS.md` mangrove line, if decision 7a stands;
  - `docs/CONTENT_MANIFEST.md`: tick `patrol_boat`;
  - `TASKS.md`.
