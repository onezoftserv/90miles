# Design

## Context

- **Creatures today:**
  - `Creature` (`game/scenes/creatures/creature.gd`) is a generic scene with a `CreatureBrain` that `CreatureBrain.for_behavior` picks by the snake-case behavior name.
  - Brains tick on the host only. `attach_sync` replicates `position`, `facing` and `state_id` at 10 Hz as spawn properties.
  - `CreatureWorld` is everything a brain may read or do.
  - `CreatureSpawner` reads ISLAND rules only and skips every CROSSING rule (`_matches`).
- **The crossing today** (`game/scenes/crossing/crossing.gd`):
  - It knows nothing of creatures except `CreatureThreats`, which spawns a passing reef shark (a `lifetime_s` creature) for a shark beat.
  - `Crossing.launch` rolls a `CrossingPlan` (squall, shark pass, rock) with the shell's `_crossing_rng`.
  - It does not know the departing island's chain family: the shell does (`island.layout.chain_family`).
  - `vessel-car-board` is editing the crossing scene in parallel.
- **Effects and run state:**
  - `CreatureData.sighting_effects` exists but nothing applies it.
  - `EffectApplier` handles `METER_ADD`, `CURE_STATUS`, `REVIVE`, `GIVE_ITEM`, `TAKE_ITEM` and `START_ROUTE`, and ignores `limit`.
  - `GameState` is a stub. There are no run flags and no per-run creature counts.
  - The session is created per run and freed by `GameShell._end_run`. It already carries `world_state["run_seed"]`.
- **Players:**
  - A player's facing is drawn, not simulated. `PlayerLook.facing` (`Facing`) is observed from the drawn position on each peer.
  - "Held" food is `Inventory.held_food()`, the first FOOD slot, on land (`swoop_steal`, owner-confirmed 2026-11-08).
- **Interaction:** `InteractionPicker` picks the highest priority in reach (1 tile), then the nearest. `creature.tscn` gives creatures priority 1, and the crossing's `RescuePoint`s have 0.
- **The galleguito's rule** names the FINAL chain family. No island in `game/resources/islands/` has it yet (the sandbar is SANDBAR and the coast cay is COAST).

## Goals / Non-Goals

**Goals:**
- `ambient.gd` and `perch_ride.gd` work from data alone: content-batch-12 adds `galleguito`, `pajarito` and `pajaro_bobo` as `.tres` files with no script edit.
- The crossing places creatures from their CROSSING rules, deterministically from the shell's RNG after the plan, with no new beat kind and no change to plan or snapshot serialisation.
- A perched gull looks attached on every screen, the late joiner's included, and never costs a rider a tie-down or a climb.

**Non-Goals:**
- The production creature files and their art, and the feather counter on `seagull.tres` (content-batch-12, tasks 9.1–9.3).
- Fishing, so neither the rabihorcado nor the pelican's catch theft. The sperm whale's wake damage and the songbird's flee at noise are named in data but ignored by the machine until a wake rule and a noise bus exist.
- `max_per_run` on island spawns (the island spawner is unchanged).
- Dialogue (`PLAY_DIALOGUE` stays an `EffectApplier` "not built yet" skip).
- The gull's walk up the beach on arrival.

## Decisions

**D1. Reference games: ideas borrowed and rejected.** Ideas only; no code, data or text copied.

- **Following and perching.**
  - *Borrowed, SPD* `actors/mobs/npcs/DirectableAlly.java` (`followHero`, `Wandering`): with nothing else to do, an ally heads for the hero. Our gull's resting state is "on its rider". *Rejected:* SPD's directing commands; a shoo is the only order.
  - *Borrowed, Brogue CE* `Monsters.c` `moveAlly` and the `MB_FOLLOWER` branch of `monstersTurn`: a follower returns to its leader when it is too far, otherwise it mills about (`monsterMillAbout`). An ambient bird keeps station beside the vessel and returns to it.
  - *Rejected, Brogue:* the scent-following and the blink toward a distant leader. The crossing is one small screen.
- **Attached creatures.**
  - No reference game has a rider. The nearest are Brogue `MA_ENTER_SUMMONS` (a summoner carried inside a minion, `summonMinions` and `killCreature`) and DCSS tentacle chains (`mon-tentacle.cc`).
  - *Borrowed:* the attachment is a link to the carrier, not a position. We sync which rider it sits on and let each peer draw it on that body.
- **Shoo and return.**
  - *Borrowed, DCSS* `mon-act.cc` `_handle_battiness`: after acting, a bat flutters to a random spot and resumes after a short time. Our solo shoo circles for 5 s and lands again.
  - *Borrowed, DCSS* `shout.cc` `issue_orders` and `_set_allies_withdraw`: "go away" is a timed state that ends by itself.
  - *Rejected, Brogue* `allyFlees`: a health-based flee. Our gull has no health.
- **Harmless creatures and first sighting.**
  - *Borrowed, DCSS* `player-notices.cc` `seen_monster` and `MF_SEEN`: a once-ever "seen" mark per monster. Ours is per creature per player, with the effect's own once-per-run or once-per-day limit kept by the host.
  - *Borrowed:* DCSS `dat/mons/butterfly.yaml` and `mons_class_is_firewood` mark a harmless class by data, not by its own code. An `ambient` creature is harmless by its machine.
  - *Rejected:* SPD `Hero.checkVisibleMobs` and Brogue `playerTurnEnded` interrupt the player on a new sighting. Ours is real time and never stops play.
- **Thieves.**
  - *Rejected:* SPD `Thief.steal` (`Belongings.randomUnequipped`), Brogue `specialHit` with `MA_HIT_STEAL_FLEE`, and DCSS `monster::steal_item_from_player` (weighted by value) all take from the whole pack and then flee or blink.
  - *Borrowed:* our gull takes only the held FOOD slot (the gull rule already in `swoop_steal`) and stays. The design wants a toll, not a chase.
  - *Borrowed, DCSS:* choosing a victim by a property, not at random. The rider holding the most food is the pick, with a seeded tie-break.
- **Guaranteed spawns.**
  - *Borrowed, SPD* `levels/SewerLevel.createMobs`: `Ghost.Quest.spawn` runs outside the random mob budget of `RegularLevel.createMobs`.
  - *Borrowed, Brogue CE* `Architect.c` `buildAMachine` with `MF_GENERATE_HORDE`: machine hordes are excluded from `populateMonsters`'s random count.
  - Ours: chance-1.0 rules are placed first and never count against the rolled cap.
  - *Rejected, DCSS* `place_monster`'s hard monster ceiling: a guarantee that a cap can refuse is no guarantee.
- **Don't Starve Together** (added by the owner on 2026-11-14). It is closed source, so these come from the dontstarve.wiki.gg pages named below, read on 2026-11-14. Only ideas are taken: no code, data, numbers, text or art. None of it is a clearly better rule than the owner's decisions, so nothing below changes them.
  - **Birds that land and scatter** (wiki "Crow", "Puffin"). A bird flies in, pecks for a moment and flies off; a player or creature coming close scares it away.
    - *Borrowed:* a visit with an arrival, a short stay and a departure. That is `ambient`'s `ARRIVE` → `STAY` → `LEAVE`, with the optional stay time `circle_time_s.x`.
    - *Rejected for crossing birds:* scattering when a player comes near. On a 4×2-tile raft every rider is always near, so the songbird and the booby would leave at once. The BESTIARY has them ride along and leave for a squall or noise instead.
    - An island ambient (the pelican at a cove) could use a proximity flee later as a data counter, with no machine change.
  - **The parrot companion** (wiki "Polly Roger's Hat"). The parrot flies to its wearer, follows them, fetches loose items into their inventory, can be killed, and comes back the next day.
    - *Borrowed:* a bird that belongs to one player, comes back to them on its own, and needs no orders. This is the galleguito's rider, and its solo shoo where it circles and lands on the same head.
    - *Rejected:* fetching items, and health or death. Fetching would make the gull a survival lever, which the BESTIARY forbids, and the galleguito has no health.
  - **Creatures that steal** (wiki "Splumonkey", "Powder Monkey", "Krampus").
    - Splumonkeys take loose items and container contents. Powder Monkeys knock items out of a player's inventory on sight. Krampus empties everything on screen and flees into his sack. Killing any of them returns what it stole.
    - *Rejected:* whole-pack theft, fleeing after a theft, and getting items back by killing the thief. The galleguito charges a toll, one held snack at most once a minute; it stays and cannot be killed.
    - *Borrowed:* the wiki's advice against Powder Monkeys is to keep common stacks in the first slots, so the inventory order decides what is exposed. Our theft from the first FOOD slot only is the same idea, and a player can choose what they expose.
    - *Borrowed:* Powder Monkeys leave alone players who carry the right pass. That is our `ITEM_CARRIED` → `NEGATE` immunity, the Pluma de galleguito.
  - **Catcoons** (wiki "Catcoon"). Food or toys make one follow a player for up to a day, and a befriended one coughs up gifts on a timer.
    - *Rejected:* befriending, feeding and gifts. The gull is a passenger, not a pet, and gifts would be a survival lever.

**D2. `CrossingCreatures`: the roll lives beside the crossing, not in it.**
- The new file is `game/scripts/crossing/crossing_creatures.gd`, a `Node` child of the crossing on the host. `GameShell._on_route_started` calls `CrossingCreatures.attach(crossing, island.layout.chain_family, band)` right after `Crossing.launch`; on a client it returns null.
- **Its dice are its own.** They are seeded from the run seed, the crossing's number and the node name, so the shell's `_crossing_rng` is never drawn from. Every plan, this crossing's and the next ones', is the same with or without creatures.
- A static `roll(creatures, family, band, phase, weather_id, rng, cap, record)` touches only `rng` and `record`.
  - The node passes the session's creature catalog in id-as-text order.
  - It keeps each CROSSING or BOTH rule that matches: chain families (empty = any), distance bands, phases, `weather_ids` and `excluded_weather_ids`. Chain ids are not checked: the crossing knows the departing family, not the chain.
  - It skips creatures whose `max_per_run` the run record has reached, and counts each one it places in the record.
  - It returns the chance-1.0 rules first and then at most `cap` of the others that pass `rng.randf() < chance`, in id order.
  - One rule places one creature per roll.
- The node then places each creature through `session.spawn_creature`, at the sea's north edge, so clients and late joiners get them like the crossing shark.
- It marks each one `passing` (see D8), gives it a crossing world (D3), and sets its `nest` to its station by the deck (D6).
- On `crossing.ended`, and on `_exit_tree`, it frees its creatures on the host, so the spawner removes them everywhere.
- *Why not inside `Crossing.launch`?* The family is the shell's, the crossing file is shared with `vessel-car-board`, and the plan's RNG order must not move ("Same seed, same plan").
- *Alternative:* a `CREATURE` beat in the plan. Rejected: it changes `CrossingBeat` and snapshot serialisation, and a creature that is there all crossing is not an event.
- The cap is `CrossingTuning.max_rolled_creatures`, set to 2 in `crossing_tuning.tres`. The tuning script has no defaults.

**D3. `CreatureWorld` learns the crossing and the run.**
- The new fields are `crossing: Crossing` (null on an island) and `record: RunRecord`, which defaults to a fresh one so rigs without a session still work. The spawner and `CrossingCreatures` set the session's.
- With a crossing, `players()` is its living riders' bodies, and `terrain` is its sea.
- New reads:
  - `rider_state(body)`, `deck_center()` and `deck_rect()`.
  - `peer_of(body)`, through the session.
  - `run_seed()`, from `session.world_state`, 0 if absent.
  - `day()`, from `WeatherManager.sky.clock`.
- `carries_negator(data, body)` is true when `body` carries an item named by an `ITEM_CARRIED` → `NEGATE` counter of `data`. `take_held` stays as it is; both thieves ask `carries_negator` first.

**D4. `RunRecord` on the session.**
- The new file is `game/scripts/run/run_record.gd`, a `RefCounted`. It holds:
  - `flags: Dictionary[StringName, bool]`;
  - `creature_counts: Dictionary[StringName, int]`;
  - `claims: Dictionary[String, int]`, which maps a claim key to the day it was last claimed.
- It is host-only and never sent to clients: flags are read by host-run endings, and limits are checked where effects apply.
- `CoopSession` gets one line: `var run_record: RunRecord = RunRecord.new()`. A session lives exactly one run, so a new run starts empty.
- `claim(key, limit, day) -> bool` answers whether an effect may fire:
  - `NONE` always fires;
  - `ONCE_PER_RUN` fires the first time;
  - `ONCE_PER_DAY` fires when the last claim was on another day;
  - `ONCE_PER_READER` is treated as once per run per player.
- *Alternative:* `GameState.run`. Rejected: an autoload outlives the run and the tests, so it needs a reset hook that does not exist yet.
- *Alternative:* `IslandTravel`. Rejected: crossing rigs have no travel node.

**D5. Sightings.**
- The new file is `game/scripts/ai/sightings.gd` (static). `Sightings.see(creature, world)` runs when a brain reaches its sighting moment: ambient on reaching its station, perch-ride on its first landing.
  - On a crossing, every living rider sees it.
  - On an island, every player within `sight_radius_tiles` sees it. An island ambient checks each tick while it stays.
- For each player not yet in the creature's `seen_by`, it walks `sighting_effects` by index.
  - The claim key is `"<creature id>#<index>@<player key>"`, and the player key is the body's instance id. A rejoined player reclaims the same body (coop-reconnect), so a rejoin never pays twice.
  - If `record.claim(...)` allows, it calls `EffectApplier.apply(effect, body, body)`.
- `EffectApplier` gains `SET_FLAG` and `CLEAR_FLAG`, which write `CoopSession.of(actor).run_record`. With no session they do nothing. Effects stay in one interpreter.

**D6. `ambient.gd`.**
- **States:** `ARRIVE` → `STAY` → `LEAVE`.
- **Station:** always the creature's `nest`.
  - On a crossing, `CrossingCreatures` sets it to a slot by the deck. Air and vessel domains sit on the deck's corners, in slots 0–3 by the creature's place in the roll. Water domains sit 2 tiles off its side.
  - On an island, its spawn spot.
- `ARRIVE` flies or swims to the station at its speed, then calls `Sightings.see`.
- `STAY` keeps station (a crossing station moves with nothing, since the vessel never moves on screen) and checks:
  - a `CONDITION_HOLDS` counter with response `FLEE` or `REMOVE` whose conditions hold for any player (`ConditionCheck`, so `WEATHER_IS squall` works today);
  - its stay time `circle_time_s.x` (0 means until the crossing ends).
- `LEAVE` heads for the nearest sea edge and frees itself when it gets there, or after 5 s.
- It has no shoo, no strike and no theft.
- NOISE counters are inert because there is no noise bus yet; when the bus lands, a NOISE `FLEE` counter makes the machine leave, with no data change.

**D7. `perch_ride.gd`.**
- **States:** `CIRCLE` → `PERCH`, `HOP`, `HOVER`.
- `CIRCLE` loops the deck for `circle_time_s.x`, then picks and lands.
- **Pick:**
  - Candidates are the riders aboard or tied. If one is excluded, use the rest; if none is left, use the excluded one.
  - The pick is the most `inventory.count_tag(FOOD)`. Ties are broken by an RNG seeded from `hash([run_seed, crossing.serial])` over the tied riders in `crossing.peers()` order.
- `PERCH`:
  - Position = the rider's position, and `creature.perch_peer` = the rider's peer.
  - On first landing, `Sightings.see`.
  - The rider in the water → `HOVER` over them until they are aboard, then `PERCH` again.
  - The rider dead or gone → pick again.
- **Shoo** (the `INTERACT` counter, reach `radius_tiles`):
  - With another candidate → `HOP` to the pick excluding the current rider (flies there at its speed, then `PERCH`).
  - Otherwise → `HOVER` for the counter's `duration_s` (5 s), circling the rider, then `PERCH` on the same rider.
- **Theft clock:**
  - `_since_land_s` starts at the first landing.
  - At each multiple of `steal_interval_s` (60 s), if the state is `PERCH`, the rider is not swimming and `carries_negator` is false, it rolls `steal_chance` (0.5) with `world.rng`. On success it calls `world.take_held(rider)` once.
  - A roll that falls in another state is skipped, not delayed. The gull never leaves after a theft (`flees_after_steal` is false in its data).
  - On a 60–120 s crossing that is at most two thefts.
- It never calls `hit_vessel`, `bite_swimmer` or anything that touches speed, drift or the plan.
- `interact_priority()` returns −1, so the tie-down, climb and pull points (priority 0) win whenever they are in reach.

**D8. Perch sync and drawing.**
- `Creature` gets `var perch_peer: int = 0`, replicated like `state_id` (spawn and always), and `var passing: bool` (host only). `is_passing()` = `passing or lifetime_s >= 0`.
- `perch_peer` is the rider's peer only while the machine is in `PERCH`, and 0 in `CIRCLE`, `HOP` and `HOVER`. A flying gull is drawn at its synced position like any creature.
- `Creature._ready` sets `interactable.priority = brain.interact_priority()`. The base brain returns 1, the scene's current value, so existing creatures are unchanged.
- `CreatureLook.step` handles `perch_peer != 0` when the session has that body:
  - It sets its global position to the body's plus `PERCH_SORT_PX`, so it sorts over the rider.
  - It puts the sprite's feet on the body's head (`BodyLook.head_y()`), with no shadow.
  - It faces with the rider's `PlayerLook.facing.dir`, and plays its idle frames however the rider moves.
- A client therefore draws the gull on its own predicted body, with no 10 Hz trail. The host's synced `position` stays for the reach check and for peers without that body yet.
- `CreatureLook` runs at `process_priority` 1, after the players. A client moves a remote player's drawn body (`PlayerNet`) and turns its look (`PlayerLook`) in their `_process`, and the session lists `Entities` before `Players`. Without this, a gull riding another player would trail them by one frame. The manual two-process run found this.
- After a rejoin, the host writes the rider's new peer to `perch_peer` on the next tick.

**D9. Fixtures.**
- `game/tests/fixtures/content/creatures/` holds `galleguito_prueba.tres` (PERCH_RIDE), `pajarito_prueba.tres` and `pajaro_bobo_prueba.tres` (AMBIENT), with the BESTIARY numbers and the seagull's frames.
- Tests point `session.creature_catalog` at that root, or call `roll` with it, as `test_creature_art` does.
- The feather tests duplicate `seagull.tres` in code and add the counter. A fixture `ItemData` for the feather is registered in the inventory.

**D10. Manual two-process run.**
- `game/tests/manual/perch_ride_run.tscn` (script `perch_ride_run.gd`), run with `-- --mode=host` and `-- --mode=client`. It is a scene, not a `-s` script, so it runs after the autoloads exist. Both default to UDP port 7786 (seven sessions share this machine and would collide on 7777), and `--port=<n>` overrides it. Each process builds a session and the sandbar, as the net tests do, with the fixture catalog.
- The host launches a crossing for its own player and attaches the crossing creatures with the FINAL family. This is the test hook that stands in for a final island.
- The client joins mid-crossing. It checks that the galleguito is drawn on the host player's head while the host walks, and prints `PERCHRUN PASS|FAIL`.

## Risks / Trade-offs

- **[Risk]** A rider can never shoo the gull while standing on the tie-down point, because priority −1 loses to it. → They step off the point. The gull only costs morale-neutral snacks, and the alternative is losing a tie-down in a squall.
- **[Risk]** `count_tag(FOOD)` counts every food in the inventory, while theft takes only the held slot. → This matches "the player holding the most food items" in `docs/BESTIARY.md`. Taking from the held slot keeps the never-from-inventory rule.
- **[Risk]** No real run meets the galleguito until a FINAL island exists. → Fixtures and the manual hook exercise it; `TASKS.md` records the gap.
- **[Risk]** A crossing that starts while a joiner is mid-join could spawn its creatures before that peer has the crossing. → The entity spawner replicates to the joiner when its join is answered, as it does the shark. The look waits for the rider's body and draws at the synced position until then.
- **[Trade-off]** The roll reads phase and weather once, at launch: a squall that begins mid-crossing never brings a squall-only creature. The booby's squall *leave* is checked every tick.

## Migration Plan

- `PERCH_RIDE` is appended, so no saved enum integer shifts.
- `max_rolled_creatures` is added to `crossing_tuning.tres` in the same commit as the script field.
- No save data exists yet. Rollback is reverting the PR; creature files without crossing rules are unaffected.

## Open Questions

- Whether island spawns should also honour `max_per_run` (no island creature uses it today).
