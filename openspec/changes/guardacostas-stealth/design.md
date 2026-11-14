# Design

## Context

See proposal.md "Why" for the motivation and the owner decisions. This section covers only what exists in the code today (main at 9cb339a) and limits the approach.

**The data model is ready, but nothing reads it.**
- `PatrolData` (`game/scripts/data/patrol_data.gd`) holds these fields: route period, horizon warning, spot time, cone angle, range, sweep speed, searchlight phases, water radius, the smoke distances (night 2, day 6) and the noise minimum (8). It also holds the chase, squad and capture fields for `guardacostas-capture`.
- `CreatureData` has the `PATROL` tag, the `PATROL_ROUTE` behavior, `patrol: PatrolData` and `party_extra_count_every_n_players`. The spawner does not read that last field yet.
- `EffectData.Kind` has `NOISE`, `SMOKE` and `ALERT_PATROL`, and `EffectApplier` skips them with a "not built yet" warning.
- `ModifierData` has `PATROL_SPOT_TIME` and `NOISE_RADIUS`, and `PoiData` has `noise_multiplier`.
- `WeatherData` has `disabled_senses` and `patrols_in_port`. `squall.tres` sets `patrols_in_port`, and there is no fog file.

**The creature pipeline.**
- `CreatureSpawner` spawns rules that have no phases once, at setup, on the host. That is the offshore shark today.
- `CreatureBrain.for_behavior` loads `game/scripts/ai/<behavior>.gd`.
- `Creature` sends `position`, `facing` and `state_id` every 0.1 s through a `MultiplayerSynchronizer`, with spawn properties, so a late joiner gets them.
- `sandbar_island.gd` gives creatures to every layout except an off-graph one (the secret cay).
- The spawner's `world.rng` is seeded with the constant 90.

**Stealth today.**
- `MovementModel.step` sets `HIDDEN` for a crouch on `SCRUB` or `MANGROVE` (`TerrainQuery.is_brush`), and `SUBMERGED` for a dive of up to 5 s (`DIVE_MAX_S`).
- `PlayerNet` sends `net_stealth`.
- `BodyMarks` draws the closed-eye mark for `HIDDEN` on every peer.
- `GridTerrain.shaded` holds exactly the layout's shade-glyph cells, which `IslandLayout` also lists as `hut_cells`: the sandbar's hut (12 cells) and the coast cay's observation post (15 cells). Nothing else is shaded.

**Time and party.**
- `DayClock`: a day is 720 s; dawn runs 0–60 s, day 60–360 s, dusk 360–420 s and night 420–720 s, so night is 300 s.
- `DifficultyScaling.extra_patrols = floor(players / 2)`.
- No Experiencia level or skill exists yet (`GameState` is a stub).

**Fire and the bus.**
- `Fire` joins the `lit_fires` group while lit.
- `CreatureWorld.lit_fires()` reads that group.
- `structure-state-sync` (PR #42, not merged) gives `fire.gd` a `lit` setter and `attach_sync`.
- No world event bus exists, although creatures-ai "Noise and smell" calls for one.

### The geometry, measured

Measured with a throwaway script over the two layouts in `game/resources/islands/`. "Sea" means deep or shallow water joined to the map edge, so the coast cay's brackish lagoon is not sea.

| | Sandbar (80×72, 991 land) | Coast cay (88×64, 1,021 land) |
| --- | --- | --- |
| Farthest land from the sea | 5.7 tiles | 6.3 tiles |
| Land more than 2 / 3 / 6 tiles from the sea | 617 / 413 / 0 | 632 / 436 / 2 |
| Hull + 4 tiles: perimeter, every vertex on deep water | 179 tiles, yes | 191 tiles, yes |
| Land within 10 tiles of that loop | 702 (70%) | 715 (70%) |
| Raft site lit from that loop | no (inside the C's bay) | yes |
| Roofed cells lit from that loop | 12 of 12 (all hidden anyway) | 15 of 15 |
| Windward pass only (lane 4–6 tiles east of the east-most land) | 78–122 cells: the C's tips | 107–157 cells, all rock on the point |

## Goals / Non-Goals

**Goals:**
- A patrol that a lone offline player can learn, hide from and survive, built entirely from data on the creature pipeline.
- Every detection decision is made on the host from state the host already owns. Clients only draw.
- Pure helpers (the loop, the cone, the meter, the trigger rules) that GUT can test with no scene, no physics and no network.
- One seam (`patrol_alerted`) that `guardacostas-capture` hooks without reopening this code.

**Non-Goals:**
- Line of sight or occlusion for the light.
- Per-tick random rolls.
- A fog weather file, Stealth skill levels or Experiencia state. This change reads them through seams that give 0 today.
- The crossing, the jet ski, patrols on mid and far chains, and blood events.

## Decisions

### 1. The slice ends at the alert

Detection and response are separate systems with separate content. The response needs soldiers, Rodríguez's dialogue, the persuasion check and the previous-island restart. The alert is the boundary:
- every spot, smoke alert and noise alert ends in one `Creature.patrol_alerted(cause: StringName, position: Vector2)` signal on the host;
- `guardacostas-capture` connects to it and replaces the alert's ending with a chase or a landing.

*Alternatives:* shipping the squad's search without capture (owner decision 1b) leaves soldiers that cannot do anything; one change for everything (1c) is about three times the size and blocks on `la_captura`.

### 2. The boat is a creature

`patrol_boat.tres` is a `CreatureData` with behavior `PATROL_ROUTE`. Its brain is `game/scripts/ai/patrol_route.gd`. Its pure helpers live in a new folder, `game/scripts/stealth/`:
- `patrol_loop.gd`: the hull, its offset and the pose at a time;
- `searchlight.gd`: the sweep and the cone test;
- `spot_meter.gd`;
- `patrol_triggers.gd`: the smoke, noise and water rules;
- `hidden_rules.gd`: what hides a body.

The spawner, the entity spawner's replication, late join, the off-graph exclusion and the content check all come for free.

The spawner changes in two small ways.
- It honors `party_extra_count_every_n_players`: plus `floor(party / n)`, so a solo player gets plus 0.
- It hands a rule's members their index and count, so the brain can offset their loops.

The patrol rule's `party_rate_mult_per_extra_player` is 1.0, so the generic ×1.2 rate does not also apply. The second-boat roll is `count` (1, 2) on the coast rule. Because `world.rng` is seeded with a constant, the roll would come out the same in every run. The patrol roll therefore draws from a stream seeded from the run seed and the island id. It runs on the host only, so no peer needs to agree.

*Alternatives:*
- a `PatrolManager` autoload, rejected: no new autoloads without a spec change, and it would duplicate the creature sync;
- one node per island, rejected: it repeats the spawner's work.

### 3. The loop is the island's convex hull, pushed out

1. Take the convex hull of the land cell centres (monotone chain, over the island's integer cells).
2. Push each vertex out by `route_offshore_tiles` (4) along the average of its two edge normals.
3. Sample the polygon every half tile. A sample that is not deep water pushes the whole polygon one more tile, at most 4 times. If it still fails, the island gets no patrol and a warning is logged; a test proves that both islands pass at 4.
4. The lap starts at the polygon's most easterly point (on a tie, the most northerly) and runs clockwise as drawn: north along the east side first.

The pose at time `t` into the lap is the point at arc length `perimeter × t / lap_s`. Speed is therefore `perimeter / lap_s`: 1.79 tiles/s on the sandbar and 1.91 tiles/s on the coast cay.

The loop's phases, with `period = route_period_s + 10 × experiencia`:

| Phase | Time | What happens |
| --- | --- | --- |
| HORIZON | [0, 20) | the warning |
| LAP | [20, 120) | the boat is in sight |
| AWAY | [120, period) | the boat is out of sight |

Boat `k` of `n` runs its clock `k × period / n` behind boat 0. An alert pauses the boat's clock (Alert, "The lap waits for the alert").

A hull is used because it is one closed convex path for any island shape, a handmade C or a generated reef. It runs at a uniform speed, is cheap and is a pure function of the layout. It is the same on every peer (decision 10).

The sandbar's bay sits inside the hull, so its raft site is never lit. That is a fair refuge on island 1. The coast cay's raft site is lit, which gives island 2 more teeth.

*Alternatives:*
- the windward pass in the current spec text (owner decision 3b): it lights 8–12% of the islands, so the light is scenery;
- a water A* ring that follows the coast: it enters the sandbar's bay, its length varies sharply with shape, and the generator's islands would each need it checked;
- handmade waypoints per layout: the generator would have to produce them.

### 4. The searchlight is host geometry, not an `Area2D`

The beam's centre aims at the island's centroid (the mean of the land cell centres) and swings ±60° from that line as a triangle wave. Its angular speed is 30°/s, so a full swing takes 8 s. Its phase is the boat's time in sight, so it is reproducible.

A player at `p` is lit when both hold:
- `|p − boat| ≤ range` (10 tiles);
- `|wrap(angle(p − boat) − beam)| ≤ width / 2` (30°).

It is tested on the host each physics tick, and only at night (`searchlight_phases` = [NIGHT]), when the weather does not disable `SIGHT`.

`docs/GAME_DESIGN.md` §17 says "light cones with Area2D". Pure geometry is used instead because:
- it needs no physics frame, collision layers or shapes;
- it gives the same answer in a headless test as in play;
- it is a few lines.

The doc line is updated after the owner confirms. Terrain does not block the light: the island is flat, and seen from a boat, cover is modelled by the hidden states, which the player can read and the HUD already shows.

*Alternative:* Brogue's and SPD's field-of-view requirement for noticing, rejected for the same reason.

### 5. A spot meter, not dice

The reference games roll per turn: Brogue rolls 25% to notice and 97% to keep tracking, and DCSS rolls perception against stealth. This game runs in real time with up to four players, and the tests must be exact. Each player therefore has one meter, in seconds, on the host:
- It gains `fill_per_s` (1) per second while lit by any cone and not hidden.
- Otherwise it loses `drain_per_s` (0.5) per second, never going below 0.
- At `spot_time_s + stealth bonus` the player is spotted, by the boat whose cone lit them on that tick (the nearest, if several did), and the meter resets.

The drain is what makes the sweep fair. The middle of the arc is lit for exactly 2 s per swing, so with a reset on leaving the light a still player would be caught or not by rounding error. With the drain, a still player in the open is caught within two swings, and one who steps out within 2 s is not. Threshold checks use the same tolerance as `MovementModel` (1e-6).

The meter lives on `PlayerBody` (host-owned) and is sent as `PlayerNet.net_spot`, as a fraction from 0 to 1. A dead or dropped player's meter is cleared.

### 6. Hidden states are computed where the stealth state already is

`MovementModel.step` takes one more input, `roofed: bool`. `PlayerBody` passes it from `terrain.is_shaded(cell)` (the roofed cells).

The rules, in `hidden_rules.gd` and called from the model:

| Ground | Stealth state |
| --- | --- |
| a roofed cell | HIDDEN in any posture |
| mangrove | HIDDEN in any posture |
| scrub | HIDDEN only while crouching |
| a dive | SUBMERGED, as now |

Because the model is pure and its inputs are replicated, a client predicts the same state the host computes. The closed-eye mark appears in the hut with no HUD change.

Fog is not a stealth state. A weather whose `disabled_senses` contains `SIGHT` turns the searchlight and the water trigger off. Nobody's body changes, so the HUD does not mark every player in fog.

A cell counts as roofed if it is a shaded cell. Today those are exactly the hut and the post. A later tarp shelter that shades cells would also hide its occupants, which fits "under a roof". A placed fire, bench or rain catcher shades nothing.

*Alternatives:*
- a separate `Stealth` component that overrides the movement step's state on the host only, rejected: the client's prediction would disagree for one round trip and the mark would flicker;
- a new `roof_glyphs` field, rejected: it would be a second list of the same cells.

### 7. Trigger rules

The rules live in `patrol_triggers.gd`. A boat checks them only while it is in sight: in its LAP phase or an alert.

- **Distance to the sea:** computed once per island. It is the Euclidean distance from each land cell to the nearest sea cell, where sea is deep or shallow water flood-filled from the grid edge (the lagoon is excluded).
- **Smoke:** checked once per second.
  - At night: a lit fire within `smoke_shore_tiles_night` (2) of the sea, and not on a roofed cell.
  - By day: within `smoke_shore_tiles_day` (6).
  - Dawn and dusk use the night rule (the dark side wins).
  - A fire that has alerted a boat is remembered for the rest of that lap.
- **Noise:** the boat hears a bus `noise` event when its radius is at least `noise_alert_min_radius_tiles` (8) and the boat is within that radius of the source.

  Straight-line distance is used on purpose. DCSS floods noise through the map and Brogue walks a Dijkstra map, but between a beach and a boat there is only open water, so a flood fill would cost a grid walk per event and change nothing.
- **Water:** a player whose movement is `SWIM` or `FLOAT`, within `water_spot_radius_tiles` (6) of the boat and with sight not disabled, is spotted at once. `DIVE` is excluded.

### 8. The world event bus is a session node

`WorldEvents` (`game/scripts/world/world_events.gd`) is a `Node` added as a child of the `CoopSession`. It acts only on the host, and `CreatureWorld.events` points at it.

Its API:
- `make_noise(position, radius_tiles, source)` applies the place's noise multiplier, then emits `noise_made(position, radius_tiles, source)`.
- `smoke_rose(position, fire)` is emitted from `Fire.light()` on the host.
- `smoke_sources()` returns the lit fires.

No handmade island has POIs yet, so the noise multiplier reads 1. The seam is `CreatureWorld.noise_multiplier_at(cell)`, which POIs fill later. The maker's `NOISE_RADIUS` modifiers are a seam that gives ×1 today.

`EffectApplier` routes `NOISE` (from `radius_tiles`, at the actor) and `SMOKE` to the bus. `ALERT_PATROL` stays unbuilt and belongs to `guardacostas-capture`.

*Alternatives:*
- an autoload, rejected: CLAUDE.md, and an autoload would outlive the session it belongs to;
- global groups and signals, rejected: hard to scope to one session, and so hard to test in `NetHarness` with two sessions in one process.

### 9. The alert

The brain's states are append-only, because `state_id` is synced: `AWAY`, `HORIZON`, `LAP`, `ALERT_LOCK` and `ALERT_SEARCH`.

**Entering an alert.** A spot, a water spot, smoke or noise puts the boat into an alert:
- it stops, and its clock pauses;
- `alert_serial` goes up by 1, so every peer shows the next alert line;
- `patrol_alerted` is emitted.

What it does next depends on the cause:
- **A spot (sight or water):** `ALERT_LOCK` on that player. The beam aims at the locked player each tick while they are not hidden and within `searchlight_range_tiles`. Otherwise the boat goes to `ALERT_SEARCH`, aimed at the last known position.
- **Smoke or noise:** `ALERT_SEARCH`, aimed at the source.

**Searching.** In `ALERT_SEARCH` the beam swings ±`alert_sweep_deg` (30°) round the aim. The meter rules apply, so another spot goes back to `ALERT_LOCK` on that player. After `alert_s` (20 s) with nobody locked, `alert_serial` goes up again for the give-up line, and the boat goes back to `LAP`.

**By day** there is no beam: the boat simply waits out `alert_s`.

**A squall** (`patrols_in_port`) ends any alert and sends the boat to `AWAY` at once. The clock restarts at HORIZON when the squall ends.

The lines are `PatrolData.alert_lines_es` and `alert_lines_en` for the start of an alert, and `give_up_lines_es` and `give_up_lines_en` for its end. A line is picked by `alert_serial mod count`, so every peer shows the same line with no extra message.

Draft lines, in formal Spanish because the official voice is the joke, all for the owner's voice pass:
- "¡Atención! Tropas Guardafronteras. Permanezcan donde están."
- "Ciudadano, se encuentra en zona de vigilancia. No se mueva."
- give-up: "Sector sin novedad. Continuamos el recorrido."

### 10. Network: send the clock and the aim, derive the rest

`Creature.attach_sync` adds three properties, with spawn and always-replicate, when the creature has patrol data:
- `route_t`, the boat's seconds into its loop;
- `beam`, the beam's centre angle;
- `alert_serial`.

On a client:
- in HORIZON, LAP and AWAY, `PatrolLoop` gives the boat's pose and beam from `route_t`, advanced by the client's own `delta` between syncs and snapped to the host's value at each sync;
- in the alert states, the boat stands at its synced `position` and the beam uses the synced `beam`.

A mid-lap joiner gets `route_t`, `beam`, `state_id` and `position` in the spawn packet, so its first drawn frame is right. Meters ride on `PlayerNet` (`net_spot`).

The host decides every spot from its own movement step, which uses the host's terrain and the host's reading of the intent. A client that sends crouch while standing on sand is still visible.

*Alternative:* syncing position and beam only, with interpolation. It is simpler, but the client's beam would lag a sweep at 30°/s by up to 3° per sync and need easing. Deriving the beam from the clock is exact and costs one float.

### 11. Drawing and cues: client-side, never in the simulation

**The patrol look** is a scene beside `creature_look.gd`, used on every peer, the host included. It draws:
- a placeholder hull until the art pass makes the boat;
- a `PointLight2D` with a generated 60°, 10-tile cone texture, rotated to the beam.

A light under the night `CanvasModulate` brightens the sand it covers, which reads as a searchlight. A flat polygon drawn above the tint was rejected because it would look pasted on. art-pass's test that drawing never changes the simulation is extended to the patrol look.

**The horizon light** is drawn by the HUD on the band where the squall line sits:
- a 3×2 px light at night, or a grey 5×2 hull by day;
- it shows during HORIZON, placed along the band by the entry point's bearing from the viewing player's camera and clamped to the band.

**The open eye** is drawn by `BodyMarks` beside the closed eye:
- a 7×5 open eye whose iris fills with `net_spot`;
- it shows while `net_spot > 0` and the player is not HIDDEN, because the closed eye wins.

All of its text is in `hud_text.tres`. A speech bubble (`speech_bubble.tscn`) over the boat shows the alert or give-up line for 3 s.

### 12. Data

New `PatrolData` fields, with their defaults in `patrol_boat.tres`:
- `route_lap_s` (100);
- `route_offshore_tiles` (4);
- `searchlight_arc_deg` (120): the range of the beam's centre;
- `spot_fill_per_s` (1) and `spot_drain_per_s` (0.5);
- `alert_s` (20) and `alert_sweep_deg` (30);
- `alert_lines_es`, `alert_lines_en`, `give_up_lines_es` and `give_up_lines_en`.

Existing fields keep their meaning: `route_period_s` 180, `horizon_warning_s` 20, `spot_time_s` 2, `searchlight_cone_deg` 60, `searchlight_range_tiles` 10, `searchlight_sweep_deg_s` 30, `searchlight_phases` [NIGHT], `water_spot_radius_tiles` 6, and the smoke and noise fields.

`patrol_boat.tres` has:
- category HUMAN, tags [PATROL], domains [DEEP], behavior PATROL_ROUTE, health 0;
- senses [SIGHT, HEARING, SMOKE];
- `party_rate_mult_per_extra_player` 1.0 and `party_extra_count_every_n_players` 2;
- two spawn rules: SANDBAR with count (1, 1), and COAST with count (1, 2).

The content validator checks that a PATROL-tagged creature has a patrol part with:
- a lap shorter than its period minus its warning;
- a cone of 1–180°;
- a positive range and drain;
- at least one alert line and one give-up line in each language.

Fixtures: `tests/fixtures/weather/fog_test.tres` (`disabled_senses` [SIGHT]), a noise item, and a tiny island for fast pose tests.

### 13. Solo

Nothing waits for a second peer. One offline player is the server (`multiplayer.is_server()` is true), so the spawner, the brain, the meter, the bus and the triggers all run on that one machine. The count is the base count, because `floor(1 / 2) = 0`. Every way to survive works alone (proposal.md "Solo"). The full-night test drives a solo body by its input actions only, like `test_inventory_hud_solo_run.gd`.

## Reference games (ideas and structure only; nothing copied or translated)

Brogue CE is under `reference/BrogueCE/src/brogue/`. SPD is under `reference/shattered-pixel-dungeon/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/`. DCSS is under `reference/crawl/crawl-ref/source/`. Line numbers are approximate. Every function named below was found by grep on 2026-11-14.

### Brogue CE (the main stealth reference)

- **Borrowed: one stealth number with readable stacking modifiers** (`Time.c` `currentStealthRange`, ~695). Brogue starts at 14, halves it in darkness (`Light.c` `playerInDarkness`, ~283) and again in shadow, and floors it. Our spot time is the same idea turned around: one number, 2 s, which the Stealth skill raises (+1 s a level, capped). Our hidden states are the "invisible" case: the meter does not fill at all.
- **Borrowed: a lost hunter heads for the last seen place, then returns to its rounds** (`Monsters.c` `updateMonsterState`, ~1711, with `wanderToward`, ~1701, and `lastSeenPlayerAt`). This became `ALERT_SEARCH` aimed at the last known position, then back to the lap.
- **Borrowed: noise as one event with a radius that alerts what is in range** (`Items.c` `aggravateMonsters`, ~3362). *Rejected:* its Dijkstra distance (open water, decision 7) and its rule that sends hearers to the player's position instead of the noise. A noise alert aims at the source, so a decoy works later.
- **Borrowed: show the player their own state.** Brogue shows the sidebar "Stealth range" and the `]` map overlay (`IO.c`, ~4695 and ~1452), and colours the player sprite by light. Ours are the closed-eye and open-eye marks.
- **Borrowed: hiding by submersion** (`Monsters.c` `monsterHiddenBySubmersion`, ~179). Brogue applies it to monsters. We apply it to the diving player, as built.
- **Rejected: per-turn dice** (`awareOfTarget`, ~1651: 25% to notice inside range, 97% to keep tracking). They assume discrete turns, and tests need exact outcomes. They were converted to the meter (decision 5).
- **Rejected: the scent map** (`awarenessDistance`, ~1623). A boat does not track by scent, and the last known position plus a timer is enough.
- **Rejected: field of view as a requirement for noticing.** The island is flat seen from the sea (decision 4).

### Shattered Pixel Dungeon

- **Borrowed: facing cones that change the chance of being noticed.** The vault guards (`actors/mobs/Mob.java` `StealthGameplayWandering.detectionChance`, ~1612) notice inside a 75° cone, more weakly inside 150°, and almost never behind. Our searchlight is the same shape made exact: inside the cone the meter fills, outside it does not.
- **Borrowed: fixed loops for guards.** `setupStealthGameplayWanderPositions` (~1595) makes guards walk set positions, which gives a loop the player can learn.
- **Borrowed: a "noticed" tell before the hunt.** SPD shows "!" through `showAlert`, "?" through `showLost` in `Hunting` (~1358) and `Investigating` (~1449), and `showInvestigate` (~1643). These became the open-eye mark while the meter fills and the loudhailer lines at the start and end of an alert.
- **Borrowed: noise sends the hearer to a place, not to the player** (`beckon`, ~1176). A smoke or noise alert searches the source, and only a real spot locks.
- **Borrowed: tall grass blocks sight** (`levels/Terrain.java`: `HIGH_GRASS` is `LOS_BLOCKING`, ~103). This supports "crouch in brush" as a hard hide, not a softer chance.
- **Rejected: SmokeScreen hiding everyone** (`levels/Level.java` `updateFieldOfView`, ~1347). In 90 Millas smoke gives you away. Only fog hides, and it does so by turning the light off.
- **Rejected: `AlarmTrap` beckoning every mob on the level.** Too blunt for a beach.

### DCSS

- **Borrowed: perception against stealth, shown to the player as a chance** (`shout.cc` `check_awaken`, ~265; `describe.cc` `_monster_notice_chance`, ~6356; `output.cc` `stealth_pips`, ~2101). We show progress (the eye filling) rather than a percentage, because the outcome is a timer, not a roll.
- **Borrowed: a monster that loses you keeps a memory, then gives up** (`mon-behv.cc` `foe_memory`, ~733; `handle_behaviour` resets it on a failed arrival roll, ~685). Our alert's 20 s search is that memory. It is one fixed time, not memory by intelligence, because there is only one crew.
- **Borrowed: noise near the player alerts, and noise far away only disturbs** (`shout.cc` `_monster_apply_noise`, ~43; `behaviour_event` `ME_DISTURB` and `ME_ALERT`, `mon-behv.cc`, ~1072). Smoke and noise alerts aim at their source, not at a player.
- **Borrowed, for later: entering water is the loud part** (`player.cc` `_enter_water`: `noisy(8)` for a splash, `noisy(4)` for a swimmer, ~682–694). This is the source of owner decision 6c's splash (4).
- **Rejected: noise propagation through a grid with per-terrain attenuation** (`noise_grid::propagate_noise`, ~958; `BASE_NOISE_ATTENUATION_MILLIS` 850 in `noise.h`). Nothing stands between a beach and a boat.
- **Rejected: stealth from character stats** (`player.cc` `player_stealth`, ~3607). There are no builds here, only situation and one skill.

### Don't Starve Together (proprietary; dontstarve.wiki.gg only)

- **Borrowed: warn before you hurt.** On *Darkness*, the attack comes 5–10 s after full darkness, after a spoken line and a sound. On *Hound/DST*, warning growls grow louder before a wave. These are the source of the 20 s horizon light, the open eye filling before the spot, and the loudhailer starting each alert.
- **Considered for later: warnings that shrink.** On *Hound/DST* the warning goes from 120 s to 30 s as the days pass. It is not in this slice: the horizon warning is data, so a later chain can shorten it.
- **Borrowed: a visible give-up.** *Guides/Mob Killing Guide* describes territorial mobs that chase briefly and go home; no timers are given [unverified]. The alert's 20 s search, the give-up line and the return to the lap follow it.
- **Partly borrowed: hiding does not shake a mob that already has you.** On *Bush Hat/DST*, mobs already targeting the player keep tracking them, and moving ends the disguise. We let hiding break a lock (owner decision 2a) because the solo player needs a way out until capture exists. Option 2c is the strict Bush Hat rule, and option 7c is the "moving ends it" rule.
- **Rejected for now: full-moon light** (*Moon Cycle/DST*). Brighter nights would let patrols see farther. There are no moon phases yet.
- **Rejected: random wildfires** (*Wildfires*, about 20% per 45 s try, in summer). Our smoke comes only from fires the players make.

## Risks / Trade-offs

- **[The hull loop lights 70% of each island.]** That is much harder than the current windward wording. → It is owner decision 3. The sandbar's bay and raft site stay dark, its scrub band is everywhere, and the lap and offset are data, so a playtest can soften it without code.
- **[Every day fire is seen.]** No land is more than 6.3 tiles from the sea, so day fires on islands 1 and 2 always alert a boat in sight. → It is owner decision 5, with the measurement shown. Until capture exists, an alert has no lasting cost. Fires matter at night, and night has the 2-tile rule.
- **[Spot meter edge cases at 60 Hz.]** → Meter arithmetic uses the model's 1e-6 tolerance, and the tests step whole seconds, as `test_movement_model.gd` does.
- **[Files shared with in-flight changes.]** PR #42 (`fire.gd`, `coop_session.gd`) and `net-platform-seam` (`net_manager.gd`, `game_shell.gd`; not touched here) are in flight. → The build rebases on main after #42 merges (task 0.2). This change only adds lines to `fire.gd` (`smoke_rose` in `light()`) and `coop_session.gd` (adding the bus child).
- **[The second-boat roll's seed.]** → It uses a stream from the run seed and the island id (decision 2), so it varies by run. It is host-only, so no peer must agree.
- **[The placeholder hull and cone may read badly at night.]** → A hand check of the night tint is in the two-process run (task 9.2), and the boat's art waits for the art pass.
- **[Bigger party, more boats.]** Four players on the coast cay with a second boat roll get four boats, so a boat starts a lap every 45 s. → This follows coop-networking's rule (+1 per 2 players). The host-plus-client test covers two players (two boats on the sandbar), and the four-boat schedule is a pure test.

## Migration Plan

Nothing to migrate. All new data has defaults, and islands without a patrol rule are unchanged. To roll back, revert the change; `patrol_boat.tres` is the only content file.

## Open Questions

- The loudhailer lines and the English translations wait for the owner's voice pass, which cannot change the specs.
- The boat's sprite waits for the art pass (docs/ASSETS.md "Patrol boat, cutter, dinghy, skiff": hand-pixel).
