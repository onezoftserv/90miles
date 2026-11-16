# Design

## Context

See proposal.md "Why" for the motivation and the owner decisions. This section covers only what exists in the code today (main at 9b90289, surveyed on 2026-11-14) and what the stealth build will add first.

**Capture exists only as data.**
- `PatrolData` (`game/scripts/data/patrol_data.gd`) already has chase, squad and capture fields that nothing reads:
  - `chase_speed_mult`, `chase_speed_ref`;
  - `squad_creature_id`, `squad_size`, `search_duration_s`, `search_order`;
  - `capture_touch_s`, `free_guard_radius_tiles`, `captive_hold_s`;
  - `capture_dialogue_id`, `commander_npc_id`.
- `CreatureData.Behavior.SEARCH_CAPTURE` and `PATROL_ROUTE` exist with no brain files. `CreatureBrain.for_behavior` loads `game/scripts/ai/<behavior>.gd`.
- These enum values exist but are not interpreted:
  - `EffectData.Kind`: `TAKE_ITEMS_WITH_CAPABILITY` (commented "fire sources = LIGHT_FIRE"), `TAKE_ALL_ITEMS`, `TRAVEL_NEXT_ISLAND`, `TRAVEL_PREVIOUS_ISLAND`, `PLAY_DIALOGUE` and `ALERT_PATROL`;
  - `ConditionData.Kind.BACKGROUND_PRESENT`, which falls through to false in `condition_check.gd`;
  - `METER_AT_LEAST`, which is evaluated for the ACTOR scope only.
- `DialogueData` / `DialogueStateData` already model a scene as data:
  - entries keyed by state with conditions and a priority, where the highest passing entry wins;
  - lines, `on_enter_effects` and `next_state`.

  The `DialogueStateData` comment names "the la_captura check" as the use of `on_enter_effects`. No dialogue player or panel exists. Lines reach the screen only as speech bubbles (`CoopSession.show_bubble`) and the sign note panel.
- There is no NPC file, no background file, no per-player background field, and no ending logic. `DialogueService` is a stub.

**Players.**
- `PlayerBody` has `downed`, `left_island` and `pinned`, and `SurvivalMeters` has `downed`, `last_stand` and `dead`.
- `IslandArrival.hold(body)` hides a body and turns its collision off. `IslandArrival.land(body, at, ground)` puts it back, and this is how riders wait on the next shore.
- `DragHandle.dragger` is any `Node2D`, and `_dragged_step` moves the body at `DRAG_SPEED` (2 tiles/s), stopping 0.5 tiles short.
- `net_downed` and `net_dropped` replicate through the body's StateSync. `left_island` and `pinned` are set on every peer from the same events.
- `CoopSession._acting_body` gates intents on the meters' `downed`, `last_stand` and `dead` and on `has_left`.
- Speeds (`movement_model.gd`): walk 4, run 6, crouch 2, swim 3 and drag 2 tiles/s; a dive lasts at most 5 s.

**Inventory.** `Inventory` has `remove_id`, `take_tag`, `count_tag` and `capability_slot` (the first match only). Nothing removes every item with a capability. `lighter.tres` is the only item with `LIGHT_FIRE`, and `dry_grass` is TINDER and FUEL. `ItemTag.KEEPSAKE` exists, but no keepsake item does.

**Travel.**
- `IslandTravel` keeps the current island and `islands_reached`, which `_load` increments unless the layout is off-graph. It has no history.
- `travel(next_id)` is host-only and accepts any layout id. Clients follow through `CoopSession.travel_to`.
- `_load` frees the level, keeps only `SESSION_NODES`, builds the island from its layout, lands the players with their health and energy, and beaches the raft.
- `sandbar.next_island` is the coast cay. The coast cay names no next island, so `check()` returns OVER there.
- The run seed is `world_state["run_seed"]`. Islands are three handmade layouts, so rebuilding one from the run seed means reloading its layout. `SecretPlan.roll` is not called in a real run: no secret piece is placed anywhere yet, and there is no ledger.

**The crossing** has no final-crossing notion: `Crossing.launch` always gets `DistanceBand.COAST`. The run ends through each peer's `GameShell._check_run_over()` and the run summary.

**What the stealth build adds** (the `guardacostas-stealth` change, being built in another session; this change builds after it merges):
- `patrol_boat.tres` and the `PATROL_ROUTE` brain, with states `AWAY`, `HORIZON`, `LAP`, `ALERT_LOCK` and `ALERT_SEARCH`;
- `PatrolLoop`, `Searchlight`, `SpotMeter`, `PatrolTriggers` and `HiddenRules` in `game/scripts/stealth/`;
- the `WorldEvents` bus;
- `PlayerNet.net_spot`;
- the open-eye mark;
- `Creature.patrol_alerted(cause, position)` on the host;
- a patrol roll drawn from the run seed and the island id;
- spot meters that fill inside "any lit cone", with the spot credited to the cone that lit the player.

### The search, simulated

The search was measured with a throwaway script over the two handmade layouts. The script lives in the session scratchpad, not the repo. For each island it ran 200 trials:
- three soldiers start at the landing cell nearest the east side's middle;
- soldier 0 walks to a random last-known position; the other two, and soldier 0 once it arrives, walk between random land cells;
- paths are 8-connected over land, and soldiers walk at 3 tiles/s for 150 s, which is the 180 s search minus landing and walking;
- day sight is a 6-tile, 120° cone along the walking direction, with the spot meter (fill 1, drain 0.5, spot at 2 s).

"Hiding cells" are scrub, mangrove and roofed cells.

| | Sandbar (991 land) | Coast cay (1,021 land) |
| --- | --- | --- |
| Hiding cells | 96 | 44 (15 in the post) |
| A still, hidden player found, if a soldier passing within 1 tile finds them (decision 5b) | 72% of cells on average; 5 cells at 25% or less | 73%; no cell at 25% or less |
| Same, passing over the very cell | 36% | 26% |
| A still player in the open, spotted by day sight within 150 s | 66% of trials (median 40 s) | 54% (median 35 s) |
| A still, hidden player more than 2 tiles from every searched point (decision 5a) | never found, by rule | never found, by rule |

The 5a row holds by rule; the simulation did not measure it. Whether a spotted player can reach such a place depends on where the last known position falls. Under decision 5a it is where the player was last seen: where they hid, or where they left sight. A second throwaway script measured, for every land cell taken as that position, how far it is to cover more than 2 tiles away. It also counted the hiding cells from which a crouching player can slip more than 2 tiles away while still hidden, inside a connected patch.

| | Sandbar | Coast cay |
| --- | --- | --- |
| Hiding patches (largest) | 26 (12, 11, 8 cells) | 30 (the post's 15; the rest are single cells) |
| Steps from a last-known position to cover more than 2 tiles away | median 3, 90th percentile 6, max 8 | median 3, 90th percentile 7, max 13 |
| Hiding cells you can crouch away from while still hidden | 62 of 96 | 15 of 44 (only the post) |

So on the sandbar a spotted player can dive into a scrub patch and crouch through it. On the coast cay that works only in the post. Elsewhere they must first leave sight (the light's 10 tiles, or a soldier's 6) and then take cover a few steps on. The searchlight's lock breaking where they hide is what makes "hide on the spot" fail.

With a stumble rule, hiding is a coin flip at best, which takes away the solo player's main way through. With point searches only, hiding works, but moving off the last-seen spot and away from the fire is the skill. A player who stays in the open is caught about as often as the searchlight catches one in a lap.

## Goals / Non-Goals

**Goals:**
- Every response rule a lone offline player can read and survive, with a capture that is a setback, not a death.
- The host decides everything from the state it owns, and clients only draw and ask.
- Pure helpers (the chase, the squad plan, the capture rules and the outcome) that GUT can test with no scene and no network.
- The scene, its lines, its check and its outcomes are data in `beat_la_captura.tres`, so Marisol's release, Caridad's letter and Rodríguez's trust later become higher-priority entries, not code.
- One router that every future capture calls: the cutter on the first crossing, and the final crossing's patrol.

**Non-Goals:**
- Combat, struggling free, or bribes.
- Line of sight for soldiers. Cover is the hidden states, as for the searchlight.
- A dialogue system for other NPCs: no choices, portraits or voice clips.
- Backgrounds, endings, the final crossing, branching run structure, or generated islands.

## Decisions

### 1. The response hangs off the stealth slice's alert

The stealth brain's alert stays the entry point. This change adds two exits to it and one state machine beside it:
- **Water spot:** a spot whose cause is water or sight on a swimmer moves the boat to a new `CHASE` state (decision 3).
- **Land alert:** an alert whose cause is on land, raised while the island has no squad ashore, moves the boat to `DOCKED`, and the boat's `SquadPlan` lands the squad (decisions 4 and 6).
- Otherwise the stealth alert runs unchanged. That covers a second boat while a squad is ashore, and a chase that broke at sea.

Brain states stay append-only after the stealth ones, because `state_id` is synced: `CHASE` and `DOCKED`.

In both new states the boat's clock stays paused, as an alert pauses it, and the boat resumes its lap where it stopped. `patrol_alerted` still fires once per alert.

*Alternatives:* a separate squad manager node per island, rejected because the boat already owns the squad's data, the alert's position and its sync. An `ALERT_PATROL` effect for the alert itself is left for set pieces (the almendrón's start, the wall), which call the same entry point.

### 2. Whole-party capture and its router

`CaptureRules` (`game/scripts/stealth/capture_rules.gd`) is pure and covers three things.

**Who is free.** A player is free when all of these hold:
- living;
- connected (`is_dropped` false);
- standing (no downed, last stand or dead);
- not a captive and not taken.

A rider in a crossing or waiting on the next shore counts as free.

**When it checks.** The host checks after every capture, death, removal, departure and downed change.

**The result:**
- no free player and at least one captive or taken player is a whole-party capture;
- a squad leaving with captives while someone is free means those captives are taken (decision 7).

`CaptureOutcome.resolve(context)` is the one router:
- An island, or a crossing that is not the final one, plays the scene (decision 9).
- The final crossing ends the run with `devuelto` and rolls no check. Nothing here builds that ending, so the branch emits `run_devuelto` for the final-crossing work to connect. A pure test proves the branch skips the scene and the check.

*Alternatives:* counting only the players on the island as the party. Rejected, because a rider waiting on the next shore would be taken back to the previous island while the session's one live island is the current one.

### 3. The chase at sea

`BoatChase` (`game/scripts/stealth/boat_chase.gd`) is pure. It takes the boat's position, the target's position and movement, and the water grid (`CreatureNav.water` over DEEP cells), and it returns the next waypoint and whether the haul has completed.
- The speed is `chase_speed_mult` (2) × the base swim speed (3), with `chase_speed_ref` = SWIMMER.
- The haul counts while the target is within `haul_tiles` (1) and resets when they leave it, which is the same rule as the soldiers' touch.
- The chase breaks when the target dives (stealth SUBMERGED), stands on a non-DEEP cell, or gets more than `chase_break_tiles` (10) away. The boat then runs the stealth search round the last position for 20 s.
- If the target stands on land, the cause becomes a land alert at that cell and decision 1's landing follows.

A hauled swimmer is a captive aboard. They are held like a dinghy captive, but at the boat (decision 6), and they cannot be freed.

The boat never enters shallows (its domain is DEEP), so the shallows are the swimmer's refuge. On the sandbar a swimmer spotted 6 tiles out has about 4 s: the boat closes at 3 tiles/s relative, then hauls for 2 s.

### 4. The landing and the dinghy

On a land alert:
1. The boat stops where it is and goes to `DOCKED`.
2. The landing cell is the BEACH cell nearest the boat in a straight line, or the nearest land cell if the island has no beach on that side.
3. The dinghy rows from the boat to the landing at `landing_speed_tiles_s` (2) and beaches there. That takes 2–4 s on both islands, since the loop runs 4 tiles off the hull.
4. Three soldiers spawn on the host through `session.spawn_creature` on the landing cell's free neighbours.

The squad's clock starts when the dinghy beaches.

The dinghy is not an entity. It is part of the boat's synced state:
- `squad_state` (NONE, ROWING_IN, ASHORE, ROWING_OUT);
- `landing`, the cell;
- `dinghy_t`, from 0 to 1, advanced by every peer between syncs as the stealth slice does with `route_t`.

The patrol look draws the dinghy from that state. While docked, the boat's light (at night) runs the stealth search sweep round the squad's current last known position. Its water trigger stays on, and a spot updates the last known position instead of starting a chase.

### 5. Soldiers see through the spot meter

The soldier's brain is `game/scripts/ai/search_capture.gd`, for `SEARCH_CAPTURE`. Each soldier is a sight source for the stealth `SpotMeter`, beside the boats' cones.
- By day: a cone of `soldier_day_sight_deg` (120) and `soldier_day_sight_tiles` (6) along the soldier's facing.
- At night: `soldier_night_sight_deg` (60) and `soldier_night_sight_tiles` (5), a flashlight.
- The rules are the same as the searchlight's: no occlusion, and `HiddenRules` hides.
- In weather that disables `SIGHT`, no soldier sees anyone.
- A spot credited to a soldier makes it `CHASE` that player at `soldier_chase_tiles_s` (5) while they stay unhidden within its sight length.
- When the chase breaks, the soldier's last known position becomes a point the soldier searches itself. That position is where it last saw the player: the cell where they hid, or where they left its sight length.

The capture touch mirrors `NightThief._pinch`. Time accumulates while the chased or found player is within `capture_touch_tiles` (1), it resets when contact breaks, and at `capture_touch_s` (2) the player is captured. Downed and dropped bodies are never targets.

*Alternatives:*
- Stumbling onto hidden players (owner decision 5b), measured above at 72–73%.
- The Bush Hat rule (5c), where hiding never shakes a pursuer. It is DST's, and it makes a chased solo player's only way out a 6-against-5 footrace.

### 6. The squad plan

`SquadPlan` (`game/scripts/stealth/squad_plan.gd`) is pure, owned by the docked boat's brain, and stepped on the host.

**Points.** The plan builds them at landing:
1. every lit fire on the island (from `WorldEvents.smoke_sources()`), nearest the landing first;
2. the alert's position as the last known position, for a sight, water or noise cause.

**Taking points.** Each soldier not escorting takes the first point nobody has taken. A soldier with no point walks a random walk.

**The random walk.** Targets are reachable land cells drawn from a stream seeded with the run seed, the island id and the boat's `alert_serial`. The stream is host-only, but stable for a test. This follows Brogue's waypoint wander rather than DCSS's 6-tile jitter.

**Searching a point.** On arrival a soldier stands for `point_search_s` (3) and finds any hidden player within `point_search_tiles` (2): that player is spotted at once and chased.

**The last known position.** While a spotted player stays visible to the boat's lock or a soldier's chase, their position is tracked. When they hide, or leave the lock's 10 tiles or the soldier's sight length, the position at that moment becomes the last known position. A new one replaces the old, and the new point goes to the nearest soldier that is not escorting or chasing.

**Leaving.** The squad leaves:
- when `search_duration_s` (180) has passed since beaching and at least `capture_grace_s` (60) since its latest capture;
- at once when no free player is on the island;
- at once when a squall brings `patrols_in_port`.

Soldiers walk back to the dinghy, the give-up line plays, the dinghy rows out with its captives, the soldiers despawn, and the boat resumes its lap.

### 7. Captives and the taken

**The captive state.** A captured player gets `PlayerBody.captive` (host-owned, replicated as `PlayerNet.net_captive`).
- `_acting_body` refuses every intent from a captive except quick chat.
- The soldier becomes the body's `DragHandle.dragger`, so the captive is led at drag speed (2 tiles/s) to the landing, and the soldier walks at that speed while escorting.
- At the landing the body is pinned on the landing cell, "in the dinghy", and the soldier returns to its plan.
- A hauled swimmer is pinned at the boat's position, aboard, and is not interactable.

**Freeing.** Each captive's body carries an `Interactable` ("Soltar", hold 1 s).
- It runs through the existing interact intent (the intent RPC's interact flag and the host's interaction hold), so no new client message is added. That keeps it clear of `intent-delivery` (PR #55), which reshapes the intent RPC.
- The host checks reach, and checks that no soldier is within `free_guard_radius_tiles` (3) at the start and on every tick of the hold. The hold follows the `RescuePoint` and `InteractionHold` precedent.
- A freed captive stands on the landing cell, or where they are if freed on the walk.
- On the walk the escorting soldier is always within 1 tile, so in this slice a rescue happens in the dinghy. The rule is written for any guard distance, so that a later decoy that pulls the escort away (`DECOY`) makes a walk rescue possible with no rule change.

**Taken.** When the squad leaves while someone is free, each captive is taken (owner decision 8):
- `IslandArrival.hold(body)` hides them;
- their meters freeze, as a waiting rider's do;
- their inventory is emptied except KEEPSAKE-tagged items;
- their SECRET-tagged items are laid on the landing cell through `SecretRules`, as a leaver's are;
- they get `PlayerBody.taken` (replicated).

`IslandTravel.check()` counts a taken player as gone from the island, like a rider. The next `_load` lands them with everyone else.

A whole-party capture includes the taken. They are in the scene, and they go wherever it sends the party.

**Bodies at a whole-party capture.** The downed and dropped bodies on the island are held too (owner decision 9).
- After the scene, a downed player stands at 30 health (the `REVIVE` effect's value).
- A dropped body lands still dropped, with its remaining hold. Their identity can still reclaim it.

**During the scene,** every player in the run is held out of play.

### 8. Island history

`IslandHistory` (`game/scripts/run/island_history.gd`) is pure and owned by `IslandTravel`. It is a list of `{layout_id, index, off_graph}` entries, appended in `_load`.
- `previous()` is the last on-graph entry before the current one with a lower index. On index 1 it is the current island.
- `islands_reached` becomes the highest index in the history, so a restart, or arriving again on an island already reached, adds nothing. The secret-cay guard in `_load` stays.

The travel message already carries the layout id. It now also carries the index, so each client's summary counts the same islands.

A restart is `travel(previous_id)` with:
- every player in the scene as an arrival;
- landing cells from `IslandArrival.landing_positions`, within 5 tiles;
- `raft_integrity` 0, so nothing is beached.

The island is rebuilt from its layout and the run seed through the normal path: its pick-ups, palms, creatures, the patrol roll from the run seed and the island, and its fixed contents.

A release is `travel(layout.next_island)` the same way. When the current layout names no next island, the release returns OVER through the same path a route off that island takes, so the run summary shows.

The secret-piece ledger has nothing to record yet, because no real run places a piece. When the later work places pieces, it writes them to `IslandHistory`'s run state, and `_load` reads it (main spec "Previous island after capture").

*Alternatives:* keeping the history in `RunRecord`, rejected because `RunRecord` is host-only and never sent, and clients need the index for the summary.

### 9. The outcome is data, run by a small scene runner

`beat_la_captura.tres` is a `DialogueData` of kind STORY_BEAT, owned by `rodriguez.tres` (`NpcData`, MAJOR, handwritten). The flow runs open → act → plea → outcome, and each state's entries are picked by priority and conditions:

| State | Entries (highest priority first) | `next_state` / effects |
| --- | --- | --- |
| `open` | again + plural; again; plural; singular | `act` |
| `act` | the formal act | `plea` |
| `plea` | Médico; Maestro; empty (nobody passes) | `outcome` |
| `outcome` | release; car return; return | effects below |

**The gates:**
- "again" is `FLAG_SET captura_previa`.
- "plural" is `PLAYERS_AT_LEAST 2`, counted over the scene's party.
- A plea entry is gated on the persuasion condition with that background, and the speaker is the one who passes. On a tie, the higher morale speaks, then the earlier join.
- The persuasion condition is `ANY_PLAYER` over the scene's party, wrapping `ALL_OF`:
  - `ANY_OF`: `BACKGROUND_PRESENT maestro` or `BACKGROUND_PRESENT medico`;
  - `METER_AT_LEAST morale 60`.

**The outcome effects:**
- **release:** gated on the persuasion condition. `SET_FLAG captura_previa`, then `TRAVEL_NEXT_ISLAND`.
- **car return:** gated on `FLAG_SET almendron_a_bordo` (escape-routes "Almendrón capture"). `SET_FLAG almendron_hundido`, then the return's effects.
- **return:** `SET_FLAG captura_previa`, `TAKE_ITEMS_WITH_CAPABILITY LIGHT_FIRE` on the party (KEEPSAKE-tagged items are skipped), then `TRAVEL_PREVIOUS_ISLAND`.

**Code this needs:**
- `condition_check.gd`:
  - `ANY_PLAYER` on a node: true when some player in the scope passes every child as the ACTOR;
  - `BACKGROUND_PRESENT`, read from a new `PlayerBody.background_id`, empty until the backgrounds change;
  - `METER_AT_LEAST` per actor, already built.
- `effect_applier.gd` and `inventory.gd`: the item removal and the two travels, routed to `IslandTravel`.

**The stub backgrounds.** `maestro.tres` and `medico.tres` are stub `BackgroundData` files: id, names, descriptions and their skill, with no starting items. They exist so the content check resolves the references. content-batch-9 fills them.

**The scene runner** (`CaptureScene`, a host-side node under the session, kept across a travel):
1. It resolves the states.
2. For each line it sends `scene_line(serial, speaker_id, line_id)` as a reliable RPC to every peer.
3. Each line is held for its reveal time (40 chars/s) plus 2 s.
4. At the end it applies the outcome's effects.

The host may skip a line, which in solo means the player. Clients cannot skip, so the line never diverges between peers. A joiner gets the current line in its join extras.

**The panel** (`game/scenes/ui/scene_panel.gd`) draws the speaker's name and the revealed text in the HUD, as the sign note panel does, on every peer.

*Alternatives:* owner decisions 11b and 11c. A hard-coded check in code was rejected, because Marisol, the letter and trust would each need a script edit.

### 10. Rodríguez's lines (drafts for the owner's voice pass)

Rodríguez reads the act in formal Spanish and speaks Baracoa Spanish in person (`docs/CHARACTERS.md` "Voice"). The satire targets paperwork and quotas, never a real person. The players' pleas use Cuban speech too. Each line has a singular and a plural form, and the plural forms are shown here.

- **open:** "No me miren así. Yo también tengo que llenar la planilla: tres copias, y no hay papel carbón." / "¿Saben cuántos he saca'o del agua este mes? Ni yo. La cifra la ponen allá arriba."
- **open, again:** "¿Ustedes otra vez? Mira, yo no estoy pa' esto. Ya los tengo en el acta de la semana pasada."
- **act** (formal): "Acta de interceptación número cuatrocientos doce. Nombre, municipio de residencia y motivo de la salida ilegal del territorio nacional."
- **plea, Maestro:** "Capitán, con esta corriente usted sabe dónde termina un bote sin rumbo. Si nos devuelve, mañana nos saca del agua otra vez, y esa cifra no se la cuadra nadie."
- **plea, Médico:** "Capitán, el muchacho de la proa tiene fiebre desde que subimos. Déjeme verlo, y usted no nos vio."
- **release:**
  - "Bueno. Aquí no ha pasa'o na'. El acta dice 'sector sin novedad'."
  - "Los dejo en el próximo cayo. Y si alguien pregunta, yo 'taba mirando pa'l otro la'o."
  - formal: "Se cierra el acta por no localizarse a los interceptados."
- **return:**
  - "Lo siento, de verdad. Las cifras son las cifras. Pa'trás, pa'l cayo de antes. Y den gracias que no es pa' Mariel."
  - formal: "Se procede a la devolución al punto de partida. Se decomisan los medios de ignición."
- **car return** (before the return's lines): "El carro ese lo hundimos, como manda el reglamento. Me dolió más que a ustedes." / formal: "Se hace constar el hundimiento del vehículo utilizado como embarcación."

The English lines keep *planilla*, *acta*, *cayo* and *Mariel*.

### 11. The squad's calls (drafts)

The squad is on duty, so its calls are official and formal (CLAUDE.md "Writing"). They are the `PatrolData` lists `squad_land_lines_es/en`, `squad_spot_lines_es/en` and `squad_leave_lines_es/en`, picked by a synced serial as the loudhailer's are.
- **landing:** "¡Tropas Guardafronteras! Todo el mundo quieto donde está." / "Se procede a la inspección del cayo. Colaboren con la autoridad."
- **spot:** "¡Alto! Ciudadano, deténgase."
- **leaving:** "Sector sin novedad. Regresamos a la embarcación."

The crew's off-duty chatter in Cuban speech can come with the voice pass.

### 12. Fade with distance is a third spawn rule

`patrol_boat.tres` gains a rule for the families MANGROVE, REEF, ROCK and LIGHTHOUSE:
- `count` (1, 2), like the coast rule;
- `chance` 0.3.

It is rolled from the stealth slice's run-seed patrol stream, so a restarted island rolls the same. No rule names STORM or SHIPWRECK. The final family gets no island rule: the final crossing's patrol is crossing work.

A fixture layout of family REEF tests the odds over 1,000 seeds and the repeat.

### 13. Network

The host decides everything:
- the chase, every touch and capture;
- each free, checked for reach and guard radius;
- the whole-party test, the check and the travel.

**What is synced:**
- **Bodies:** `PlayerNet.net_captive` and `net_taken`, spawn and always-replicate, like `net_downed`.
- **The boat:** `squad_state`, `landing`, `dinghy_t` and `squad_serial` (for the calls), added to the stealth slice's patrol sync.
- **Soldiers:** ordinary creatures (position, facing, `state_id`), so a joiner gets them in the spawn packet.
- **The scene:** `scene_line` RPCs, plus the current line in the join extras.

**No new client intent.** Freeing is an ordinary interact hold on the captive's `Interactable`, which the host checks (§7).

**A late joiner:**
- While the squad is ashore, the joiner gets the soldiers, the dinghy and the captive flags.
- During the scene, the joiner is held out of play, sees the current line, and lands with the party.

**A captive client that drops** keeps the captive flag on its dropped body, and so is not free. If it rejoins within its hold, it takes the captive body back.

### 14. Cues

Everything here is drawn on the client and never changes the simulation:
- **The rope mark** (7×5): `BodyMarks` draws it beside the hidden and open-eye marks, for `net_captive` or a hauled captive.
- **The open eye:** the stealth slice draws it from `net_spot`, so it already fills under a soldier's sight.
- **The prompt:** "[E] Soltar" is the captive's `Interactable` prompt. The host-side guard rule is mirrored on the client, so the prompt hides while a soldier is within 3 tiles. The host still decides.
- **The calls:** each shows in a speech bubble over a soldier for 3 s.
- **Text:** all HUD text lives in `hud_text.tres`.

The placeholder soldier is a recoloured MetroCity body until the art pass. The dinghy is a placeholder hull.

### 15. Data

New `PatrolData` fields (defaults in `patrol_boat.tres`):
- **Chase:** `haul_tiles` (1), `haul_s` (2), `chase_break_tiles` (10). `chase_speed_mult` is 2 with `chase_speed_ref` = SWIMMER.
- **Squad:**
  - `landing_speed_tiles_s` (2), `point_search_s` (3), `point_search_tiles` (2), `capture_grace_s` (60);
  - `soldier_day_sight_deg` (120), `soldier_day_sight_tiles` (6), `soldier_night_sight_deg` (60), `soldier_night_sight_tiles` (5), `soldier_chase_tiles_s` (5);
  - `capture_touch_tiles` (1), `free_hold_s` (1);
  - the three call lists in Spanish and English.

Existing fields take their values:
- `squad_creature_id` `shore_soldier`, `squad_size` 3, `search_duration_s` 180, `search_order` [FIRE, LAST_KNOWN_POSITION, RANDOM_WALK];
- `capture_touch_s` 2, `free_guard_radius_tiles` 3;
- `capture_dialogue_id` `beat_la_captura`, `commander_npc_id` `rodriguez`.

`captive_hold_s` stays unused under decision 7a. Its comment says so, and it is kept because enum and field removal is avoided in saved data.

`shore_soldier.tres` is a `CreatureData`:
- category HUMAN, domains [LAND], behavior SEARCH_CAPTURE;
- `speed_tiles_s` 3, health 0, senses [SIGHT];
- no spawn rules, since only a squad spawns it.

The content validator checks a PATROL creature with a squad:
- the squad creature exists and has `SEARCH_CAPTURE`;
- the squad size is at least 1;
- the touch and the free radius are positive;
- each call list is non-empty in both languages;
- the scene and the commander exist.

### 16. Solo

One offline player is the server, so the boat, the plan, the soldiers, the rules, the scene and the travel all run on that machine. A solo player's first capture is a whole-party capture (decision 2), so no solo path ever waits on a rescue. The solo tests drive the body by its input actions only, as `test_inventory_hud_solo_run.gd` does.

## Reference games (ideas and structure only; nothing copied or translated)

Brogue CE is under `reference/BrogueCE/src/brogue/` (its blueprint and horde tables are in `src/variants/GlobalsBrogue.c`). SPD is under `reference/shattered-pixel-dungeon/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/`. DCSS is under `reference/crawl/crawl-ref/source/`. Line numbers are approximate, and every function named here was found by grep on 2026-11-14.

### Brogue CE

- **Borrowed: a hunter that loses you goes to where it last saw you, then wanders** (`Monsters.c` `updateMonsterState` ~1711, `wanderToward` ~1701, the stored last-seen spot). This became the squad's last-known-position point.
- **Borrowed: wandering between chosen waypoints, not jitter** (`chooseNewWanderDestination` ~1223, `isValidWanderDestination` ~1199). The squad's random walk picks whole land cells to walk to.
- **Borrowed: the alarm marks a place everyone heads for** (`Items.c` `aggravateMonsters` ~3362). The fire that raised the smoke alert is the first point searched.
- **Borrowed: captives held by guards who stay near and mill about** (the `MB_CAPTIVE` flag in `Rogue.h` ~2134; captive hordes in `spawnHorde` ~861; captors keeping close in `monstersTurn` ~3541–3590). Freeing needs the guards more than 3 tiles away. A soldier escorting a captive stays on them, so a rescue waits for the soldier to go back to searching.
- **Borrowed: freeing costs time** (`Movement.c` `freeCaptive` ~529, after the bump in `playerMoves`). It became a 1 s hold that a returning guard cancels. *Rejected:* the confirm prompt, because the game is real time.
- **Borrowed: a guarded prison you reach by sneaking** (the "Vampire lair" and kennel blueprints in `GlobalsBrogue.c` ~241–265). It became the dinghy on the beach.
- **Borrowed: a leader and followers sharing one alert** (`spawnMinions` ~696, `demoteMonsterFromLeadership`). The boat owns the squad's plan and its last known position. *Rejected:* the tight follower leash (`monstersTurn` ~3581), because three soldiers on a leash search like one. The leash is kept only for the escort.
- **Borrowed: fast only in its element** (the eel, water-only, which goes back to wandering when you leave the water: `monstersTurn` ~3514). The boat is fast but deep-water only, and land turns its chase into a landing.
- **Borrowed: being held ends when contact breaks** (seizing: `Combat.c` `attack` ~1068, `Movement.c` `playerMoves` ~1019–1044). The 2 s touch resets. *Rejected:* "struggling does nothing" on its own; running away is the way out.
- **Rejected: always-hunting monsters that path straight to you** (`monstersTurn` ~3452). Omniscient soldiers would leave hiding no point.
- **Rejected: items floating away in deep water** (`Time.c` `applyGradualTileEffectsToCreature` ~477). It would be a separate swimming rule, and harsh on solo play.

### Shattered Pixel Dungeon

- **Borrowed: hunt to the last cell, show "lost", then wander** (`actors/mobs/Mob.java` `Hunting.act` ~1362, `showLost` ~1382, `handleUnreachableTarget` ~1424). A soldier's broken chase becomes a point it searches, and the squad's leaving call is the visible give-up.
- **Borrowed: cones that decide noticing** (the stealth vault guards near `setupStealthGameplayWanderPositions` ~1595). These are the soldiers' day and night cones.
- **Borrowed: a non-lethal setback that rebuilds the level from its seed** (`scenes/InterlevelScene.java` `resurrect` ~749; `levels/Level.java` `getItemsToPreserveFromSealedResurrect` ~661). The previous island is rebuilt from the run seed, and the party keeps its pack.
- **Borrowed, for later: stash and return** (`items/quest/EscapeCrystal.java` `storeHeroBelongings` ~300, `restoreHeroBelongings`). Taken fire sources could be held on Rodríguez's boat and won back in "the patrol that stops" set piece. Not in this change.
- **Rejected: the guard's chain pull** (`actors/mobs/Guard.java` `pullEnemy` ~123, `chainsUsed` ~46). A ranged yank would feel unfair under network interpolation. Its idea of a slowed captive is kept as the escort pace.

### DCSS

- **Borrowed: a memory that drains, then a give-up** (`mon-behv.cc` `foe_memory` ~665–693 in `handle_behaviour`). The squad's 180 s search is one fixed memory for the whole crew. Memory by intelligence was not needed.
- **Borrowed: pacified monsters walk to the exit and vanish** (`mon-behv.cc` `make_mons_leave_level` ~1550). Leaving soldiers walk back to the dinghy and row out.
- **Borrowed: "return to where you came from"** (`abyss.cc` `banished` ~407, whose exits lead back to the level you came from; `god-abil.cc` `okawaru_end_duel` ~6690, which restores what you had on entry). The restart is the previous island, and meters carry on.
- **Borrowed: one verdict binds the band** (`attitude-change.cc` `gozag_check_bribe` ~317). Rodríguez's decision covers the whole party.
- **Borrowed: yield, not death** (`god-companions.cc` `win_apostle_challenge` ~605). A capture is a setback, not a death.
- **Rejected: struggling free with rising odds** (`traps.cc` `player::struggle_against_net` ~1102; `player.cc` `player::attempt_escape` ~8704). It is a good solo tool, but a solo capture ends the island at once (the main spec's "never held on the dock"), so there is nothing to struggle out of.
- **Rejected: a random target within 6 tiles** (`mon-movetarget.cc` `set_random_target`). It is jittery, so Brogue's waypoints were used instead.

### Don't Starve Together (proprietary; dontstarve.wiki.gg only)

- **Borrowed: raiders who do not fight, take their haul to their boat and sail off** (*Pirate Raid*). This is the squad: no combat, captives carried to the dinghy, a rescue at the boat. Its bribe-to-leave is kept for later, as Rodríguez's trust.
- **Borrowed: a soft setback that keeps the pack** (*Drowning*: you wash up nearby and lose some items). Our restart is the targeted version: only fire sources go.
- **Borrowed: a visible give-up** (*Guides/Mob Killing Guide*, via `docs/REFERENCE_DST.md` "Leashing and aggro"). The 180 s search is a leash in data, and the soldiers call it out and walk back.
- **Borrowed: lines that change on a repeat meeting** (`docs/REFERENCE_DST.md` "Lore in fragments"). This is the second-capture opening.
- **Considered, kept as an option: hiding never shakes an active pursuer** (*Bush Hat/DST*). It is owner decision 5c.
- **Borrowed: a view for those out of play** (*Ghost Characters*). Taken captives wait like riders, and `dead-spectate`'s watching view fits them.
- **Rejected: dropping everything on death** (*Death/DST*). Capture keeps the pack except fire.

## Risks / Trade-offs

- **[Every land alert brings soldiers.]** Every day fire within 6 tiles of the sea is seen, so a careless day fire costs a squad. → It is owner decision 3. Its 20 s horizon warning is the time to put the fire out, and the squad is survivable by moving off and hiding. The numbers are data.
- **[Persuasion cannot pass until backgrounds exist.]** → It is owner decision 2, stated in the proposal. The tests pin the passing path with a fixture background, so it works the day backgrounds ship.
- **[Point searches make hiding strong.]** → It is owner decision 5, with the simulated numbers. The search point, the radius and the 3 s are data. Task 6.3 pins the simulated outcomes in a test, so a retune is a deliberate test edit.
- **[It builds on a change still being built.]** The stealth build is editing `creature.gd`, `patrol_data.gd`, `player_net.gd`, `coop_session.gd`, `body_marks.gd` and the patrol brain now. → Build only after it merges (task 0.2), re-read those files, and keep the hand-over note in the shared folder current.
- **[Archive order.]** `openspec validate --strict` passes, but archive refuses this change's Alert delta until `guardacostas-stealth` is archived. → See Workflow follow-up.
- **[Taken captives can wait a long time.]** → `dead-spectate`'s watching view (PR #52) is the natural screen. Until it merges, the taken player sees the waiting line riders see.
- **[A dropped body taken along.]** → It keeps its hold timer, so it still dies after 90 s if not reclaimed, as everywhere else.
- **[The scene pauses the live island.]** Every player is held, and creatures keep running. → Creatures ignore held bodies (`CreatureWorld.players()` gains the held filter). The scene lasts about 30 s.

## Migration Plan

Nothing to migrate. Every new field has a default. Islands without a patrol never land a squad. To roll back, revert the change. The new content files are `shore_soldier.tres`, `rodriguez.tres`, `beat_la_captura.tres` and the two stub backgrounds.

## Open Questions

- The lines and the English translations wait for the owner's voice pass, which cannot change the specs.
- The soldier's and the dinghy's sprites, and Rodríguez's portrait if the full dialogue UI later wants one, wait for the art pass (`docs/ASSETS.md`).

## Changes from the build plan

Recorded while building. Each entry says what moved and why.

- **Task 0.2, the names as merged.** The build branches from main 8edc5ab, which holds the stealth build (PR #62, merged at e175e1a). These names differ from this design:
  - The spot meters are stepped by `PatrolWatch` (`game/scripts/ai/patrol_watch.gd`, owned by the island's spawner as `spawner.watch`), not by `SpotMeter`. So a soldier is a sight source of the watch, beside the boats (§5).
  - `CreatureNav.water(margin)` holds deep and shallow cells, so the chase tests for DEEP itself (§3).
  - The patrol look is `PatrolLook` (`game/scenes/creatures/patrol_look.gd`), and a client's loop and light come from `PatrolView` (`game/scripts/stealth/patrol_view.gd`). The dinghy is drawn there (§4).
  - `ConditionCheck` interprets no `FLAG_SET`, and its `PLAYERS_AT_LEAST` counts every body in the tree, not the scene's party. Group 3 builds both, because §9's "again" and "plural" gates need them.
  - `travel_to` checked an island with `ContentCatalog.has_entry`, which reads only the catalog folder, so it refused a fixture island placed in `GameState.content`'s cache. It now asks `get_entry`, as the travel itself does. `has_entry` is unchanged, because `test_vessel_car_board_data.gd` holds that the folder never lists a fixture.
  - Everything else matches: the `PatrolRoute` states, `Creature.patrol_alerted`, `WorldEvents.smoke_sources()`, `PlayerNet.net_spot`, `IslandArrival.hold`, `land` and `landing_positions`, `DragHandle.dragger`, `CoopSession._acting_body` and `BodyMarks`.
- **Group 1, the defaults.** The new `PatrolData` fields default to §15's numbers. The squad stays off until a patrol names a squad creature and a size (`has_squad()`), so a patrol kind with no squad, such as the `patrol_test` fixture, keeps the stealth slice's plain alert. `chase_speed_tiles_s(own)` is `chase_speed_mult` times the base swim speed for `SWIMMER`, or times the boat's own speed otherwise.
- **Group 1, the content check.** `ContentValidator._check_squad(catalog, where, data)` holds a patrol that names a squad to §15's rules. A missing id is left to the reference check, so it is never reported twice. The broken squads live in `tests/fixtures/squad_broken/`, with a soldier, a commander and a scene of their own, so the stealth slice's `patrol_broken` catalog and its exact count stay as they were.
- **Group 1, the soldier has no frames.** `CreatureArt.frames_problems` skips a `SEARCH_CAPTURE` creature with no `sprite_frames`, as it already skips the patrol boat. The soldier look draws a placeholder body until the art pass.
- **Group 1, `la_captura`.** `beat_la_captura.tres` was written by a one-off script, so its nested conditions save in valid resource syntax. The singular and plural forms of a line sit in one state entry, each line gated on `PLAYERS_AT_LEAST 2` (or its negation) over the scene's party; only `open` uses separate entries, as the §9 table has it. The formal lines' ids end in `_acta`, and a test holds them to formal Spanish. The singular forms of §10's lines, and the Médico's singular plea, are new drafts for the voice pass. `rodriguez.tres` names the beat as its `dialogue_id`, and it has no `ai_profile_path`, because v1 is handwritten only.
- **Group 1, the fixtures.** `FixtureIslands` (`game/tests/helpers/fixture_islands.gd`) puts the five tiny islands into `GameState.content`'s cache by id, as `FixtureRoutes` does for routes. `chain_b` holds a driftwood pick-up, a shipped item, so the fixture catalog's check skips that one reference. `FixtureBackgrounds.give(body, id)` sets `PlayerBody.background_id`, which task 3.2 names. The field was added in group 1, because the fixture needs it. `foto_test` (KEEPSAKE) stands in for the Foto de la familia. `squad_test` is a copy of the patrol boat with no spawn rules, a 2-soldier squad of `soldier_test` and a 120 s search. It names the shipped scene and commander.
- **Group 2, the history's API.** `IslandHistory` (`game/scripts/run/island_history.gd`) has `arrive(id, index, off_graph)`, `current_id()`, `current_index()`, `next_index(off_graph)`, `previous_entry()`, `previous()`, `previous_index()` and `reached()`. An off-graph cay keeps the index of the island it was reached from. `IslandTravel.setup` records the starting island as index 1, and `_load` records every island after it.
- **Group 2, the index in the travel message.** `CoopSession.travel_to(layout_id, arrivals, raft_integrity, index = 0)`: 0, from an older caller such as a test or the manual runs, means the next index. `island_travel_requested` carries the index, and a host message is bounded to 999. `islands_reached` is the larger of its own value and `history.reached()`, so a joiner keeps the host's number from its world state.
- **Group 2, restart and release.** `IslandTravel.previous()`, `restart()` and `release()` are host-only. Both moves send the arrivals with no cell, so `_land` puts the players on the landing cells in peer order, with a raft integrity of 0. A release from an island that names no next one calls the new `CoopSession.end_off_the_chain` RPC. Every peer then emits `off_the_chain_requested`, and `IslandTravel.end_off_the_chain()` holds every living player as a waiting rider, so `check()` answers OVER. It also emits `left_the_chain`, which the shell connects to `_check_run_over`, so the summary shows.
- **Group 2, island 1's landing cells.** The sandbar's landing cells are its four start spots, up to 40 tiles apart, so a restart of island 1 puts each player back where the run began. The 5-tile rule holds on every island a release lands on: the coast cay and the fixture chain, which the test checks.
- **Group 2, a fix to the stealth slice: the event bus survived no travel.** `IslandTravel._clear_level` freed every session child outside `SESSION_NODES`, the `WorldEvents` bus included. The next island's spawner then took a freed bus, which was an error on every travel with creatures, and no patrol heard smoke or noise after it. `&"WorldEvents"` is now one of the `SESSION_NODES`. `test_capture_travel_solo.gd` found it, and it checks the bus after a restart.
- **Group 3, a party for conditions.** `ConditionCheck.holds`, `all_hold` and `first_failing` take an optional `party: Array[PlayerBody]`. A node scoped `ANY_PLAYER` holds when some standing member of the party passes it as the ACTOR. "Standing" means not downed, in a last stand or dead (`can_speak`), after §9's "a captured, standing player". `passing_players(condition, party)` lists those members, which is how the scene picks the plea's speaker. With no party, `ANY_PLAYER` reads the actor's session. `PLAYERS_AT_LEAST` counts the party when there is one, and the tree otherwise, as before.
- **Group 3, two more kinds.** `BACKGROUND_PRESENT` reads `PlayerBody.background_id`; scoped `PARTY`, with a party, it looks through the party. `FLAG_SET` reads the session's `RunRecord` and is false outside a session. §9 needs it for "again" and the car gate, and nothing interpreted it.
- **Group 3, the effects.** `Inventory.take_capability(capability, keep_tag)` removes every item with the capability except those with the tag. `TAKE_ITEMS_WITH_CAPABILITY` keeps KEEPSAKE items, and with target `PARTY` or `ALL_PLAYERS` it takes from every player in the session. The two travels emit `CoopSession.party_travel_requested(onward)` on the host, and `IslandTravel` connects to it. Calling `IslandTravel` from `effect_applier.gd` made a load cycle: the class preloads the island scene, whose scenes use the effects. That broke every island scene's load, so the signal stands between them. `IslandTravel.of(session)` finds a session's keeper for code that may name the class.
- **Group 4, the chase's API.** `BoatChase` (`game/scripts/stealth/boat_chase.gd`) is pure. `step(boat, target, target_terrain, submerged, delta, is_deep)` returns the boat's next position in tiles and an `Outcome`: CHASING, HAULED, DIVED, SHALLOWS, LANDED or LOST. `move_toward` is the deep-water-only step, which the brain also uses to head back. A patrol chases when `can_chase`: a chase speed above 0 (`chase_speed_tiles_s`) and a haul time above 0. The shipped boat chases at 6 tiles/s.
- **Group 4, the brain.** `CHASE` (5) and `DOCKED` (6) are appended to the states. `PatrolView` and `PatrolLook` now read `PatrolRoute.is_alert_state` and `is_in_sight_state`, so a client draws a chasing or docked boat from its synced position, and the loudhailer calls an alert line.
  - A spot by sight or by the water rule of a swimmer standing in deep water starts the chase (`_respond`); anyone else is locked as before.
  - Shallows are water, so a swimmer there is locked by the stealth rules and never chased.
  - In `CHASE` the boat ignores smoke, noise and other water spots. It reports a second player's spot once, as a lock does, and aims its light at the swimmer.
  - A haul puts the swimmer in `aboard`; group 7 makes them a captive, and the water rule and the boat skip them. Until group 7's squad, a landing is the plain search, and every other break is the plain search round where the swimmer was.
  - While it searches, the boat heads back to its loop pose at 3 tiles/s (`RETURN_SPEED_TILES_S`) through deep water, so it resumes its lap where it stopped instead of jumping there.
- **Group 4, tests changed in the stealth suite.**
  - `test_patrol_route.gd`: the states test lists `CHASE` and `DOCKED`. "A swimmer 5 tiles away is spotted at once" now expects a chase instead of a lock, with the swimmer placed seaward of the boat so they stand in deep water. New tests there cover the haul after closing in, a dive and the shallows breaking the chase, the boat back on its loop after the search, and a patrol with no chase speed that still locks.
  - `test_patrol_solo.gd`'s water case is unchanged: it checks only the one `water` alert, which the chase still reports.
  - `test_patrol_cues.gd`'s loudhailer test spotted the host's player where it spawned, at (0, 0), which is deep water. It now puts that player on the sandbar's solo spawn first, so the spot is a lock as the test means.
- **Group 5, the sight source.** `SightCone` (`game/scripts/stealth/sight_cone.gd`, beside `searchlight.gd`) is pure. `for_soldier(patrol, phase)` gives the day cone, or the flashlight in the phases the patrol's searchlight is on (night), so the dark phases follow the same data as the light. `sees(point, eye, facing)` and `chase_holds(point, eye, hidden, disabled_senses)` take tiles; a chase ignores the cone's width, because the soldier runs facing the player. `PatrolWatch` gained `soldiers`, beside `boats`. A soldier's cone counts as a lit cone unless the weather disables sight. The meter takes the nearest source's numbers (a soldier reads its boat's `PatrolData`), and a spot goes to the nearest source that saw the player: `PatrolRoute.spot` or `SearchCapture.spot`.
- **Group 5, the soldier's brain starts here.** `game/scripts/ai/search_capture.gd` (`SearchCapture`) appears in group 5 with its sight (`sees`), its spot (`can_target` refuses downed, dropped and dead bodies) and the chase and its break. Where the soldier last saw the player becomes `lost_at`. Group 7 fills in the rest. Its states are `SEARCH`, `POINT_SEARCH`, `WALK`, `CHASE`, `ESCORT` and `RETURN`, append-only because `state_id` is synced.
- **Group 6, the plan's API.** `SquadPlan` (`game/scripts/stealth/squad_plan.gd`) is pure, and cells are island cells.
  - Building: `build(patrol, landing, fires, last_known, walk_cells, seed)`.
  - The landing and the row: `landing_cell(boat, cells)` and `row_time_s(boat, landing, speed)`.
  - Points: `take_point(soldier)`, `point_of`, `searched`, `drop_point`, `set_last_known(cell, free_soldiers)` (which returns the soldier sent) and `last_known()`. Two fires as far from the landing go in reading order.
  - The search and the walk: `finds(cell, player)` and `next_walk_cell()`.
  - Leaving: `advance`, `note_capture`, `time_is_up()` and `should_leave(free_on_island, squall)`.
  - The landing keeps to a beach unless the nearest land is more than 6 tiles nearer (`BEACH_DETOUR_TILES`), which reads design §4's "if the island has no beach on that side".
- **Group 6, the coverage, measured with the real plan.** `test_squad_search_coverage.gd` runs the built plan, the soldiers' day cone and the shared spot meter over 100 seeded runs per island. Three soldiers land at the beach nearest the boat's east-most loop pose, take the last known position and walk the land grid's paths at 3 tiles/s for 150 s. A still player in the open is spotted in **50%** of runs on the sandbar and **52%** on the coast cay. The throwaway model said 66% and 54%; it walked 8-connected paths from a fixed east landing, while the real soldiers walk the 4-connected land grid. The test pins 50% and 52% within ±10 points. By rule, it also checks two things:
  - A hidden player more than 2 tiles from the last known position is never found.
  - From each island's solo landing, the steps to cover more than 2 tiles away have a median of 3 and a maximum of 8 on the sandbar and 13 on the coast cay, exactly design.md's figures.

  It takes about 7 s, over the 2 s mark, because it steps 2 × 100 runs × 1,500 ticks × 3 soldiers.
- **Group 7, the docked boat.**
  - A land alert is a smoke cause, or a sight, water or noise cause whose cell is not water.
  - Shallows are water, so a swimmer spotted there gets the stealth lock and no squad. A swimmer who comes ashore during a chase does bring the squad (`_came_ashore`).
  - `_dock` stops the boat, picks the landing and starts the row (`Squad`: NONE, ROWING_IN, ASHORE, ROWING_OUT).
  - `_beach` builds the plan from the lit fires and the alert's position, then spawns `squad_size` soldiers on the landing and its free land neighbours.
  - When the plan says to leave, the soldiers walk back. `_row_out` despawns them and emits `rowed_out(captives)`, and the boat resumes its lap.
  - While docked, the light follows a visible player within its range. When it loses them, that cell becomes the plan's last known position, held until the beaching if the dinghy is still rowing.
  - A second boat's sighting moves the squad's last known position (`sighted`).
  - A squall runs the leaving first and sends the boat out of sight only after that.
- **Group 7, the creature's synced fields.** `Creature` gains `squad_state`, `landing`, `dinghy_t`, `squad_serial` and `squad_call` (`PatrolRoute.Call`: LAND, SPOT or LEAVE). Group 10 adds them to the sync. `PatrolRoute.captured(body)` and `rowed_out(captives)` are for group 8.
- **Group 7, the world's spawner.** `CreatureWorld` gains `spawner` (a Callable), `can_spawn()`, `spawn_creature(data, at)`, `creature_data(id)`, `watch`, `island_id`, `island_run_seed` and `catalog`. `run_seed()` answers the island's seed off a crossing. `CreatureSpawner.setup` sets them, and its `_spawn_squad_member` goes through `session.spawn_creature`, so every client sees the soldiers. A world with no spawner, such as a bare test rig, lands no squad. A squad's random walk is seeded with `hash([run seed, island id, alert_serial])`.
- **Group 7, the soldier.**
  - `SearchCapture` walks at its data's speed (3 tiles/s), chases at `soldier_chase_tiles_s` and escorts at the drag speed (2 tiles/s). Its captive follows by the drag handle's dragger, and on arrival `PatrolRoute.seat` puts them on the landing cell.
  - A broken chase gives `PatrolRoute.soldier_lost`, which makes the last-seen cell the plan's last known position, assigned to that soldier.
  - A point search finds the first hidden target within 2 tiles when its 3 s end.
  - When the squad leaves, every soldier turns to `RETURN`, and `is_back()` says it stands at the dinghy.
- **Group 7, the captive body.**
  - `PlayerBody` gains `captive` and `captive_aboard`, and `set_captive(value, by, aboard)`, `seat_captive(at)` and `can_be_freed()`.
  - `advance` treats a captive like a downed body: no interaction, and the dragged step behind its soldier, or standing still with no dragger.
  - `_acting_body` refuses a captive. Quick chat never asks `_acting_body`, so it still works.
  - A hauled swimmer is `captive_aboard`, and the boat carries them at its position.
  - `CaptureRules` (`game/scripts/stealth/capture_rules.gd`) starts here with `capture` and `release`. It is named `release` because `free` is `Object`'s. Group 8 adds the rest.
- **Group 7, freeing.** `FreeHandle` (`game/scripts/interaction/free_handle.gd`) is a child of every player body in `player.tscn`. Its prompt, `free_captive`, reads "Soltar a" / "Free" and names the captive, as the drag prompt does.
  - It is offered while its body can be freed and no soldier stands within the guard radius. A soldier is a member of the `shore_soldiers` group, which a `SEARCH_CAPTURE` creature joins in `Creature._ready`, so the handle never names the creature class.
  - It is refreshed every physics frame on every peer, and from the captive's own step on the host. So a soldier coming back cancels a hold in the same tick: `InteractionHold` resets on a disabled target.
  - The host frees the captive on use, after checking the rule again.
  - The picker's reach of 1 tile is what keeps a hold from afar from freeing anyone.
- **Group 7, tests changed in the stealth suite.**
  - `test_patrol_route.gd` is unchanged: its bare world has no spawner, so its land alerts stay plain, which is the "patrol with no squad" case.
  - `test_patrol_solo.gd`: `_frame` steps the soldiers too. "Spotted on open sand… resumes its lap" now follows the modified Alert's "Solo player spotted, hides and gets away":
    - the scrub it picks belongs to a patch that runs on more than 2 tiles;
    - the player crouch-walks through that patch, hidden;
    - the boat docks, and the squad searches and leaves without finding them;
    - the boat resumes its lap from where it stopped, at least 180 s later.

    "A beach fire alerts once per lap" is unchanged; its squad now lands and leaves within the frames it already runs.
  - `test_patrol_cues.gd`: both loudhailer tests clear the world's spawner, so their boats run the plain alert whose lines they check.
  - `test_patrol_net.gd`: the client test expects `DOCKED`.
  - `test_hud_text.gd`: the prompt ids include `free_captive`.
  - The modified Alert's "A smoke alert by day" is `test_capture_solo.gd`'s day-fire test.
- **Group 8, the rules.** `CaptureRules` is pure over `Member` snapshots. `is_free`, `free_count`, `is_whole_party`, `taken_on_leaving(captive_count, members)` and `members_of(session)` decide, and the host applies the results with `capture`, `release` and `take(session, body, landing_px)`.
  - `take` first lays the body's secret items on the landing through `SecretRules.lay_down_for_leaver`, while the body is still on the island. It then empties every slot that is not a keepsake, sets `PlayerBody.taken`, and holds the body as a waiting rider.
  - `IslandArrival.land` clears `taken`, so a taken captive lands with the party as a rider does.
  - `CaptureOutcome.resolve(final_crossing)` is the router: SCENE or DEVUELTO. `checks_persuasion` is false for DEVUELTO.
- **Group 8, the keeper.** `CaptureScene` (`game/scripts/stealth/capture_scene.gd`) is the session's capture keeper and, from group 9, the scene's runner. It is a child that `CoopSession._ready` adds as `capture`, one of `IslandTravel.SESSION_NODES`, so it survives a travel and its RPCs reach the same node on every peer.
  - It checks for a whole-party capture, deferred, after every capture, death, downed, last-stand, removal and drop.
  - `IslandTravel.check()` asks `holds_travel()` first: true while the scene plays, and on the host while the whole party is caught, before the scene begins. A taken captive is held, so `check()` already counts them as gone, as it counts a rider.
  - The spawner connects each boat's `captured` and `rowed_out` to the keeper. `rowed_out` carries the landing in pixels.
  - A boat that leaves sight (AWAY, or a squall) with captives aboard hands them to the keeper the same way. Their secret items go on the land nearest the boat. Until then they ride aboard, never freeable.
  - After taking captives, the keeper emits the new `CoopSession.capture_state_changed`, and `IslandTravel` checks the party again. The keeper never names `IslandTravel`, because `creature_spawner.gd` names the keeper and the island scene loads the spawner, so a direct reference would close the load cycle that group 3 found.
  - The final-crossing seam is `CaptureScene.in_final_crossing`, a Callable that answers false today. The DEVUELTO branch emits `run_devuelto`.
- **Group 8, creatures ignore held bodies.** `CreatureWorld.players()` now leaves out bodies held out of play: a waiting rider, a taken captive, or a player in the scene. This is design.md's "The scene pauses the live island" risk.
