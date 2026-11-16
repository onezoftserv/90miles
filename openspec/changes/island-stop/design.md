# Design

## Context

See proposal.md "Why" for the motivation. This section covers what the code does today (`main` at 8edc5ab).

- **The beached raft.** `Raft` (`game/scenes/structures/raft.gd`) holds `recipe_id` and an `integrity` float. It has one `Interactable` that launches on a 1 s hold through `IslandRoutes.start_for`.
- **Integrity on departure and arrival.**
  - `IslandRoutes` stores the departing vessel's integrity per route (`departure_integrity`).
  - `CrossingResult` records the integrity and whether the raft broke.
  - `IslandTravel._beached_integrity()` reduces the results to one float, the sturdiest intact raft. That float travels in `travel_to` and in the join extras (`"raft"`), and the next island beaches a raft with it.
- **Data with no content yet.**
  - `RecipeData.OutputKind` already has `VESSEL_UPGRADE` (a bonus to max integrity, with `requires_upgrade_ids`) and `VESSEL_REPAIR` (`integrity_delta` restored).
  - `ModifierData` already has `VESSEL_MAX_INTEGRITY`, `VESSEL_SQUALL_DAMAGE` and `VESSEL_LEAK_RATE`, with scope VESSEL and context ABOARD_VESSEL.
  - No recipe uses any of these.
- **Shared builds.** A `BuildSite` already takes deposits from anyone, shares progress, works only while someone works and every input is in, and applies the Mecánico multiplier.
- **Shade.** `GridTerrain.is_shaded(cell)` feeds the player's meter context (`player.gd`, `context.shaded`), so thirst's sun factor and heat already follow shade wherever a terrain marks it.
- **Island counts.**

| Island | Driftwood | Rope | Inner tubes | Other |
| --- | --- | --- | --- | --- |
| Sandbar | 8 | 3 | 2 | 1 tarp, 3 jugs, 3 dry grass |
| Coast cay | 8 | 4 | 2 | 4 nails, 2 jugs, 2 dry grass, a lighter |

  Beach driftwood comes back after a squall on both islands.
  - **Sandbar:** the raft (6, 2, 3) leaves the tarp and 2 driftwood.
  - **Coast cay, reached by raft:** everything is spare.
  - **Coast cay, reached with a broken raft:** a new raft leaves 2 driftwood, 1 rope and the 4 nails.
- **crossing-gameplay** (approved on 2026-11-15, being built in three PRs) adds:
  - paddling, rocks and debris in lanes, leaks and the reef line;
  - planks that lash on for +10, up to the vessel's maximum;
  - four required snapshot keys.

## Diagnosis

### What one crossing costs the rider

The figures are for a solo rider aboard a 75 s crossing, from `survival_tuning.tres` and `weather/calm.tres`.

| Meter | Cost | Notes |
| --- | --- | --- |
| Thirst, by day | 15 | 7.5 in shade |
| Thirst, at night | 3.75 | |
| Hunger | 3.75 | |
| Energy | 0 | Aboard, unless the rider falls in (−10, then 3/s in the water) |
| Heat, at midday in calm | Sunstroke at 66.7 s | Rises at 1.5/s. Not lethal: speed −40 % until heat is back under 60 |
| Morale | −10 per squall, −6.25 alone at night | |

Three crossings back to back by day cost 45 thirst and 11 hunger and nothing else. No meter stops a rider who arrives fed and watered.

### What a raft survives with no stop

**Method.** The crossing-gameplay director, rerolled 20,000 times, with a rider who handles each beat with chance p:
- p = 0: idle.
- p = 0.5: half.
- p = 0.85: attentive, an estimate.
- p = 0.95: expert.

"Handles a beat" means the rider dodges a rock or debris in its lane, threads the reef gap, shoos the fin and grabs a plank. A plugged leak costs 1.5. The 90–120 s legs use the coast weights, because the mid weights do not exist. Scripts and logs are in the shared notes folder, `island-stop-baseline/`, and are not committed.

The skill model is an assumption, not a measurement.

The table gives, for each crossing (leg), the share of rafts still intact and the mean integrity they have left.

| Rider | Leg 1 (75 s) | Leg 2 (75 s) | Leg 3 (75 s) |
| --- | --- | --- | --- |
| Idle | 72.9 %, 46 left | 21.3 %, 30 left | 3.8 %, 23 left |
| Half | 97.2 %, 71 | 82.1 %, 54 | 60.8 %, 45 |
| Attentive | 99.8 %, 86 | 98.0 %, 76 | 94.6 %, 69 |
| Expert | 100 %, 90 | 99.7 %, 83 | 99.0 %, 79 |

A coast leg (60–90 s) followed by two 90–120 s legs gives nearly the same figures.

### What a stop on the coast cay buys for the next 75 s crossing

Here the first leg is a 60–90 s coast crossing from the sandbar, so the rafts that arrive intact come in a little higher than after the 75 s leg above: 48 rather than 46 for idle, 89 rather than 86 for attentive. The defensas column uses a factor of 0.5; see Q3 for 0.75.

| Rider (arrives with) | Relaunch at once | Two mends (+40) | Mended to 100 | 100 + clavazón | + clavazón + defensas (×0.5) |
| --- | --- | --- | --- | --- | --- |
| Idle (48) | 31 % intact | 59 % | 73 % | 85 % | 97 % |
| Half (73) | 85 % | 96 % | 97 % | 99 % | 100 % |
| Attentive (89) | 98.7 %, 78 left | 99.8 %, 85 | 99.9 %, 86 | 100 %, 106 | 100 %, 109 |

On a 90–120 s next crossing, idle goes from 17 % at once to 83 % fully fitted.

### Beaching wear, if the owner wants every island to cost a stop (Q1(b))

The idea: each arrival costs the beached raft 15, whatever the rider did, and the party never stops to mend. The table gives the share still intact on each island's beach and the mean integrity there.

| Rider | Island 2 | Island 3 | Island 4 | Island 5 |
| --- | --- | --- | --- | --- |
| Attentive, no wear | 99.9 %, 86 | 98.3 %, 76 | 94.6 %, 69 | 89.5 %, 64 |
| Attentive, wear 15 | 99.7 %, 71 | 92.0 %, 53 | 76.3 %, 41 | 54.3 %, 34 |
| Expert, wear 15 | 100 %, 75 | 97.7 %, 59 | 90.0 %, 47 | 74.6 %, 40 |

With wear, an attentive rider has to mend about once per island, and an expert every second or third island.

### Reading

- Raft damage already makes careless riders stop: an idle relaunch is a coin toss at best.
- **The attentive rider loses almost nothing by diving.** In the owner's own case, the coast cay to island 3, a stop lifts that rider's next crossing from 98.7 % intact to 100 %, and the coast cay has no tarp for a toldo. With option (a), a skilled rider can skip every island by design. Only Q1(b) bites at full integrity.
- The skill-independent costs are the midday sun and the thirst clock, and both are fixed by the stop: shade, coconuts and the lagoon.
- The design therefore keeps diving legal and makes the stop pay twice:
  - in safety now, through the mend;
  - in a better raft for every later crossing, through the fittings, including the toldo that takes the sun off.
- The pull that would hold a skilled player on every island is in the full design but not built: companions (the endings count who you brought), found texts and NPCs. Until they exist, Q1(b) is the one lever that makes a good player stop now.

## Options weighed

Each option from the brief, with its solo path and the verdict.

1. **A beached raft needs repairs before it can sail.**
   - *As a hard gate* ("below 50, mend first"): a solo player on the final sandbar (6 driftwood, no rope) or on an island already stripped could be stranded, so a waiver rule would be needed. Offered as Q1(d), not recommended.
   - *As beaching wear* (each arrival costs 15, then mend): the one lever that bites at full integrity, with numbers above. It never strands anyone, because there is no gate. It changes crossing "Arrival" ("beached with its remaining integrity" and its scenarios), which balsero-lore also modifies, plus every arrival test. Offered as Q1(b).
   - *As the mend with no gate:* recommended (D1, D2). Solo: one player mends alone.
2. **Relaunch costs a supplies check** (water and food aboard).
   - Items are refused at sea (inventory-hud D11, which the owner kept on 2026-11-15, crossing-gameplay Q5). A stowed larder that the raft hands out works around that rule in spirit.
   - Mid and far crossings with the Gulf Stream are not built, so the "longer, harsher next crossing" has no numbers yet.
   - Rejected for now. It can be revisited with the far chains.
3. **The coast guard patrol can spot a launch.**
   - guardacostas-stealth "Triggers" could take a launch as a noise event (radius 8 or more near the shore), but the riders leave the island at once and nothing chases a raft at sea until the cutter boss (guardacostas-capture, "The cutter on the first crossing").
   - It applies on coast chains only, so it cannot be the answer.
   - Deferred to the cutter boss, recorded as Q8(b).
4. **The next island's arrival is harder without preparation.**
   - This arrives with the generator, with no rule. The reef (`reef_traps`) has a seep of 2 cups a dawn and coconuts on only about half of the reefs.
   - A diver who skips the coast cay's lagoon and palms lands thirsty on the thinnest water so far.
   - No requirement here.
5. **Resting or morale needs that only an island fixes.**
   - Energy comes back only from meals and sleep, and sleep is not wired: `SurvivalMeters.sleep_night()` is called only by tests. Energy also matters only to swimmers.
   - A real "night ashore" (sleep in a shelter: +50 energy, maybe health through DST's "sleep heals for hunger") is a survival-meters and weather slice of its own.
   - Proposed as the follow-up `night-ashore`, Q8(a).
6. **Leave the raft intact, but make the island's resources plainly worth the time.**
   - This is the heart of the recommendation: the fittings (D3) turn each island's leftovers into a better raft.
   - Solo: every input sits on the islands for one player.

## Goals / Non-Goals

**Goals:**
- Every island stop can make the raft safer (the mend) or better (a fitting), with materials the island holds, for one player.
- No rule can strand a lone player. Diving stays a choice whose price shows on the prompt.
- The raft's state (integrity, maximum, fittings, open job) is host-decided and the same on every peer and every joiner, and it rides through the crossing to the next beach.

**Non-Goals:**
- Raft stowage, items at sea, sleep, morale costs per crossing, the patrol seeing a launch, a forced wait such as tides, and new island content. See "Options weighed" and the follow-ups.
- The boat, car and board routes. Only a raft takes fittings.

## Decisions

### D1. Diving stays legal; no gate
An intact raft can still launch at once. The prompt shows the raft's state and warns below half its maximum (inventory-hud "The raft's prompt shows its state"), but never refuses a launch.

**Why:** SPD, Brogue and DCSS all allow the dive and price it in missed loot. A gate needs a waiver for every thin island (the final sandbar, a stripped coast cay, a party scaled to ×0.8), and every waiver is a solo trap waiting to be found.

**Said plainly:** with this decision, a skilled rider can skip every island today. The stop's later pull, companions, texts and NPCs, is not built yet.

*Alternatives:*
- Q1(b), beaching wear of 15 per arrival. It bites at full skill and modifies crossing "Arrival".
- Q1(c), re-lash before relaunch.
- Q1(d), a seaworthy line at 50.

### D2. The mend
`raft_mend.tres` (`VESSEL_REPAIR`) takes 1 driftwood and 1 rope and 10 s of work (Building, ×2 for a Mecánico), and gives `integrity_delta` 20, never above the maximum.

**Why these numbers:**
- Driftwood and rope is GAME_DESIGN §6's own promise.
- +20 is twice a sea plank, because the island pays in walking.
- An idle arrival (about 48) needs two mends, 2 of each, to reach the high 80s. The coast cay holds 8 and 4, and the sea's flotsam brings more.
- A mend never competes with a new raft: rebuilding is 11 items for 100, mending is 2 items for 20.

*Alternatives:*
- 2 driftwood and 1 rope for +30 (Q2(b)): rope-light, but it costs the coast cay a fire.
- Driftwood only (Q2(c)): it makes rope worthless on the stop.

### D3. Fittings are vessel-upgrade recipes with vessel modifiers
A `VESSEL_UPGRADE`'s `integrity_delta` already means "bonus to max integrity" (`recipe_data.gd`). This change adds one rule to it: the same amount is added to the raft's integrity when the fitting is done, so a fitting never makes a raft look more worn. That is the whole of the clavazón.

For effects other than the maximum, `RecipeData` gains `vessel_modifiers: Array[ModifierData]`, applied with scope VESSEL. `ModifierData.Stat` gains two values, appended to the end of the enum so existing values keep their numbers:
- `VESSEL_HAZARD_DAMAGE`: multiplies a rock's or a debris's integrity loss.
- `VESSEL_DECK_SHADE`: SET 1 marks the deck as shade.

`VESSEL_MAX_INTEGRITY` is left for keepsakes such as the *Nudo del pescador*. The three fittings:

| Id | Name | Inputs | Work | Effect |
| --- | --- | --- | --- | --- |
| `raft_clavazon` | Clavazón | 4 nails | 20 s | `integrity_delta` 20 (maximum and integrity) |
| `raft_defensas` | Defensas | 1 inner tube, 1 rope | 10 s | `VESSEL_HAZARD_DAMAGE` MULTIPLY 0.75 |
| `raft_toldo` | Toldo | 1 tarp, 2 driftwood | 15 s | `VESSEL_DECK_SHADE` SET 1 |

**Station.** The four vessel recipes, the mend included, set `station = NONE` and `build_site = false`, so the workbench list never shows them (the default station is WORKBENCH). The raft list picks them by output kind (`VESSEL_REPAIR`, `VESSEL_UPGRADE`).

**Why defensas at 0.75 and not 0.5.** crossing-gameplay's difficulty target, approved on 2026-11-15 (its Q8(a)), is "idle about 30 left" on a bare raft. Fittings keep an idle rider much safer, and the factor sets how much.

Idle 75 s crossing, from a raft mended to 100 (with the clavazón, 120):

| Raft | Intact | Mean left, broken counted as 0 |
| --- | --- | --- |
| Bare | 74 % | 34 |
| Defensas ×0.75 | 83 % | 39 |
| Clavazón | 86 % | 50 |
| Clavazón and defensas ×0.75 | 93 % | 57 |
| Clavazón and defensas ×0.5 | 98 % | 66 |

At 0.75 an idle rider still loses about 63 of 120, close to the bare raft's 66, so paying attention matters as much as before. At 0.5 the loss drops to 54. Q3 lets the owner choose.

Each fitting goes on a raft once. `requires_upgrade_ids` stays free for later chains, such as a mast before a sail.

The inputs follow ITEMS.md: nails "reinforce raft"; the tire is the "raft fender", but no island holds a tire, so the inner tube stands in now and a tire version is a later data file (Q7). The tarp and its 2 driftwood are exactly the sandbar's leftovers once the raft is built. The 4 nails are exactly the coast cay's.

*Alternatives:*
- Defensas through `VESSEL_SQUALL_DAMAGE`. Rejected: a squall is not a collision.
- A fitting class of its own. Rejected: recipes already carry inputs, time, skill and the content check.

### D4. A raft job is a build site that lives on the raft
Choosing a mend or a fitting opens one job on the raft. It reuses the build-site deposit, progress and work logic, so co-op pooling, the Mecánico multiplier, the "Falta:" lines and late-join state all come for free.

- There is one job at a time, so two players can never race two half-built fittings.
- A launch ends an open job and hands each deposit back to the player who made it, or drops it on the raft's cell when that inventory is full. Never deleting a player's things is a DST lesson.

### D5. Two points on the raft
- The launch stays where it is: a 1 s hold, the prompt "Zarpar en la balsa", and every existing launch test unchanged.
- A second interactable, the work point, sits on the raft's land-side neighbour cell: the neighbour that is land and has the most land in its 3×3 (south, east, west, north on a tie). Every peer computes it from the same terrain, so it lands on the same cell everywhere with nothing sent (built in PR 1, `Raft.work_offset`).
  - With no job open, a press opens the raft list.
  - With a job open, it works like a build site.
- The picker takes the nearest point, as with any two interactables.

*Alternative (Q4(b)):* one raft list with "Zarpar" as its first row. This makes launching two presses, and it changes the prompt scenario in inventory-hud "Prompt verbs and targets".

### D6. One beached-raft state instead of a float
A small record, `{integrity, max, fittings}`, replaces the float in:
- `IslandRoutes` (departure);
- `CrossingResult`;
- `_beached_integrity()`, which becomes `_beached_raft()` and keeps the sturdiest raft by integrity, with its own fittings;
- `travel_to`;
- the join extras;
- the crossing snapshot, as a new required key `"raft"`, added after crossing-gameplay's four keys so that the hand-built snapshot dictionaries in the tests change only once.

A broken raft yields no record. Peers of different builds are not supported, as before.

### D7. The toldo works through shade
When the vessel has `VESSEL_DECK_SHADE`, the crossing marks its deck cells as shaded on its `GridTerrain`. The meters then read shade aboard exactly as they do under the hut, so survival-meters needs no delta. A rider in the water is off the deck and follows the swimming rules. A tarp over the deck is drawn client-side and changes nothing in the simulation.

### D8. Defensas in the hit
In the crossing's hit resolution, a rock or debris that overlaps the vessel (crossing-gameplay "Scrolling hazards") takes `VESSEL_HAZARD_DAMAGE` times its loss. The leak still opens, and squalls and sharks are untouched. On `main` before crossing-gameplay, only the rock exists and the same multiplier applies.

### D9. HUD and text
- **Prompt ids**, appended to `hud_text.tres`:
  - `raft_work`: "Arreglar", label "la balsa" ("[E] Arreglar la balsa");
  - `raft_job`: "Trabajar en", target the recipe's name ("[E] Trabajar en Remiendo");
  - the state line "Balsa %d/%d";
  - the fittings' names on a line of their own, joined by " · ", because the prompt's line holds 30 glyphs and "Balsa 90/120 · Clavazón · Toldo" would not fit;
  - the warning line;
  - two refusal reasons, "La balsa está entera." and "La balsa ya lo tiene."
- **The raft list** is the crafting-list panel with a raft source, at the same place (4,162 to 244,302), with the state line, and the fittings' line when there are fittings, as its head.
- **Drafts for the owner's voice pass:**
  - Warning: "Así no llegas ni a la esquina." (30 glyphs, the prompt line's width)
  - Remiendo: "Un palo y una soga donde más hace falta."
  - Clavazón: "Cuatro clavos y la balsa deja de crujir."
  - Defensas: "Una cámara amarrada al borde, pa' que la piedra rebote."
  - Toldo: "Una lona arriba y el sol se queda afuera."
- The refusal reasons are menu text, so they stay in standard Spanish.

### D10. Build order
1. **PR 1, the mend** (built 2026-11-15): the recipe, the raft's work point, the raft list and prompts, the job, the raft's state pushed to clients and asked for by joiners, and a raft beached on the coast cay with its integrity. It does not depend on crossing-gameplay.
   - The record of D6 moved to PR 2. In PR 1 the maximum is always the recipe's 100, so the float `travel_to` already carries is enough, and `island_travel.gd` stays untouched while capture-build edits it.
2. **PR 2, the fittings:** the three recipes, the modifiers, the crossing effects (maximum, defensas, toldo), the record `{integrity, max, fittings}` of D6 and the snapshot key. It goes after crossing-gameplay's three PRs.
3. **PR 3, the docs:** GAME_DESIGN §6 and §8, ITEMS.md, TASKS.md.

### D11. The crafter's background-skill rule (a decision made in PR 1)
The mend's "twice as fast for a Mecánico" needed a rule nothing had built: the raft recipe already carried `skill_speed_multiplier` 2.0 and escape-routes "Shared crafting" promised the Mecánico's 2×, but no code read either.
- **The rule:** `Crafter.recipe_time` divides the recipe's time by its `skill_speed_multiplier` when the player's background (`BackgroundData.skills`) has the recipe's skill.
- **Its reach:** this is outside the proposal's Impact list. It also applies to the raft build. It is dormant today: no player is given a background yet, and only the Maestro and the Médico ship.
- **Stacking it decides:** a carried fast tool replaces the time outright and the skill does not divide it further. How the pliers' ×1.5 stacks with the Mecánico stays data-model question 32, for the equipment change.

## Reference games

**Shattered Pixel Dungeon**
- *Borrowed:* `Dungeon.java` `LimitedDrops` with `posNeeded()` and `souNeeded()`, used by `levels/Level.java` `create()`. Every regular floor places a food item and its share of a fixed run-wide budget of strength potions and upgrade scrolls. Taking the stairs at once is legal, but it forfeits that floor's share of the power curve. Our fittings are that share: each island's leftovers make one, and they compound on later crossings.
- *Rejected:* the run-wide counters that guarantee a total across a set of floors. Our first islands are handmade with fixed counts, so the guarantee is the layout itself. For generated chains, see "Open Questions".
- *Read:* `actors/buffs/Hunger.java` and `actors/buffs/Regeneration.java`. The food clock is SPD's push off a floor, and regeneration stops while starving. Our thirst already pushes, so no new clock is added. Rest is the `night-ashore` follow-up.

**Brogue CE**
- *Borrowed:* `Items.c` `populateItems()` paces food so a steady explorer does not starve (more on deeper levels, which take longer) and meters enchantment, life and strength through `rogue.meteredItems`. The "search vs dive" tension follows from it: time on a level costs food and buys items. Our version: time on an island costs thirst and patrol exposure, and buys mends and fittings.
- *Borrowed:* `Time.c` `manualSearch()`, a deliberate multi-turn search whose last turn finds more. A longer stop finds more: the coast cay's buried rope cache and the far observation post's nails are the patient player's finds.
- *Rejected:* hidden secret doors. Our POIs are visible, apart from the rope cache, which needs Navigation 1 or more.

**DCSS**
- *Read, pushes the other way:* `zot.cc` `incr_zot_clock()` and `decr_zot_clock()`, called from `files.cc` when a level is first created. Time spent in a branch accrues toward a penalty, and each new floor buys time back, so lingering is punished and diving never is.
- *Rejected:* any extra anti-linger clock. We already have one in thirst, the patrol every 3 minutes and squalls. The missing piece is the pull toward stopping, not the push away from it.

**Don't Starve Together** (`docs/REFERENCE_DST.md` "crossing and escape-routes", "crafting-inventory and inventory-hud"; wiki pages named)
- **Leak, Boat Patch.**
  - *Borrowed:* patching and hull repair are separate jobs. Our sea plank and leak plug (crossing-gameplay) are the patches. The mend ashore is the hull repair, which the Leak page lists as boards and logs.
  - Whether boards also close a leak is [unverified], and we do not rely on it.
- **Durability.** *Borrowed:* "damage soaked" as the raft's wear type, and our note's "only the raft gets repair recipes". Hand tools stay unrepairable.
- **Sea Stack.** *Borrowed:* bumpers soften collisions, which is the defensas. Our note already suggested a lashed bumper at the raft site.
- **Boat, Floating Platform.**
  - *Borrowed:* parts added to a built boat after launch-readiness, which become our fittings.
  - *Rejected:* placing them as kits on deck tiles. A fitting is a recipe on the raft, with no placement.
  - *Rejected here:* the grass raft's constant sinking.
- **Seasons/DST.**
  - *Borrowed:* a mild opening, then harsher stages that reward preparation. Fittings bought on the coast islands pay on the mid and far crossings.
  - *Rejected:* the calendar.
- **Regrowth.** *Borrowed:* islands stay mostly finite so their pressure pushes players on. We do not add regrowth to make stopping pay. The island stays finite, and the pull is what its leftovers make.
- **Health.** *Deferred:* "sleep heals but costs hunger" goes to `night-ashore`.
- **Drowning.** Not used: our fall-in rules stay.

## Owner decisions (answered 2026-11-15: option (a) on all eight)

The owner answered in option dialogs relayed by the coordinating session:
- **Q1:** (a), "Allowed; stopping pays". There is no gate. The owner saw the note that a skilled rider can still skip islands until companions, texts and NPCs exist.
- **Q2–Q8:** "Accept all recommended", so (a) on each:
  - a mend is 1 driftwood + 1 rope for +20 in 10 s;
  - all three fittings, with the defensas at ×0.75;
  - a work point opens the raft's list, and launching stays a 1 s hold;
  - the sandbar keeps its one tarp;
  - fittings are lost when the raft breaks;
  - the defensas use an inner tube and a rope;
  - the next follow-up is `night-ashore`, then the patrol spotting a launch.

This approves building PR 1 (the mend) now, and PR 2 (the fittings) after crossing-gameplay's PRs merge. The options stay listed for the record. The specs follow (a) on every question. Two dialogs:

### Dialog 1: the core

1. **Can an intact raft still sail on at once?**
   a. *Recommended:* yes, by design. No gate: the mend and the fittings are the reasons to stay, and the prompt shows the raft's state, with a warning below half. Said plainly: a skilled rider can skip every island until companions, texts and NPCs give islands more pull. In the owner's coast cay case, a stop lifts an attentive rider from 98.7 % to 100 % intact. Solo: nothing can strand one player.
   b. Beaching wear. Each arrival costs the beached raft 15, whatever the rider did, so an attentive rider mends about once per island and an expert every second or third: without mending, island 3 is reached at about 53 and island 5 at about 34, 54 % intact. No gate, so solo-safe. It modifies crossing "Arrival" (which balsero-lore also modifies) and the arrival tests.
   c. Re-lash first. Every beached raft needs 1 rope and 10 s before it can launch again: a short forced stop, waived on an island with no rope left so a solo player is never stuck. Flotsam rope makes it cheap for a good rider.
   d. A seaworthy line. Below 50 the raft cannot launch until mended to 50, waived where the island holds no driftwood or rope (the final sandbar, a stripped cay). It does not bind a rider who arrives above 50.
2. **What a mend costs.**
   a. *Recommended:* 1 driftwood and 1 rope for +20, 10 s (5 s for a Mecánico).
   b. 2 driftwood and 1 rope for +30, 20 s. Uses less rope, but costs the coast cay its fire.
   c. Driftwood only: 1 for +10, 5 s.
3. **Fittings in this change**, against crossing-gameplay's approved target (idle about 30 left on a bare raft; here a bare idle raft keeps 34, 74 % intact).
   a. *Recommended:* all three, defensas at ×0.75. Clavazón (4 nails: +20 to the maximum and to integrity), defensas (tube and rope: rocks and debris do three quarters) and toldo (tarp and 2 driftwood: the deck is shade). An idle rider on a fully fitted raft keeps 57, 93 % intact, losing about what a bare raft loses. All are buildable by one player from the sandbar and coast cay.
   b. All three, defensas at ×0.5: idle fully fitted keeps 66, 98 % intact, so attention matters less.
   c. Clavazón only: data plus the maximum, no new crossing rule. Idle keeps 50, 86 % intact.
   d. None now: the mend only, fittings later.
4. **How a player works on the raft.**
   a. *Recommended:* a work point on the raft's land side opens the raft's list of mends and fittings, like the bench's list, and a chosen job takes deposits and work like a build site. Launching stays a 1 s hold on the raft.
   b. One list: E on the raft opens a list with "Zarpar" first, then mends and fittings. Launching becomes two presses.

### Dialog 2: rules and follow-ups

5. **The sandbar's one tarp.** After the raft, the sandbar holds exactly the tarp and 2 driftwood: one toldo. The rain catcher needs the same tarp and 4 driftwood.
   a. *Recommended:* keep one tarp. Rain on the sandbar or shade at sea is a real choice.
   b. Add a second tarp to the hut. This changes the sandbar's fixed counts.
6. **When a fitted raft breaks.**
   a. *Recommended:* the fittings are lost with it, and the next raft starts bare.
   b. They wash ashore: each fitting's main item (nails, tube, tarp) lands beside the next island's raft site.
7. **The defensas' input.**
   a. *Recommended:* an inner tube and a rope now, and a tire version later as a second data file once tires spawn.
   b. A tire only (ITEMS.md's raft fender), so the defensas wait for tire spawns.
8. **Which follow-up next.**
   a. *Recommended:* `night-ashore`: sleep in a shelter at night (+50 energy, wiring `sleep_night()`), the long stop. Then the patrol seeing a launch, with the cutter boss.
   b. The patrol seeing a launch first: a launch in the searchlight or within earshot alerts, though nothing chases at sea until the cutter boss.
   c. Neither: playtest the stop first.

## Risks / Trade-offs

- [An attentive diver still dives] → Accepted and measured: diving is the skill reward, and its price is the fittings' margin on harsher legs. Companions, texts and NPCs (later changes) add more reasons to stay.
- [Fittings make crossings too easy] → At ×0.75, an idle rider on a fully fitted raft keeps 57 of 120 (93 % intact) and loses about what a bare raft loses (D3). Fittings cost a stop and materials, the owner picks the factor in Q3, and the factors are data if the playtest disagrees.
- [Two interactables on a small raft] → The work point sits on the land-side neighbour cell, and the picker takes the nearest. Tests cover both prompts from each side.
- [Collisions with work in flight] →
  - crossing-gameplay touches the crossing's hit code and the snapshot, so PR 2 waits for it.
  - guardacostas-capture touches `island_travel.gd`, so rebase onto it.
  - balsero-lore modifies "Arrival", and this change only adds requirements.
  - hud-window-kit restyles HUD panels. The raft list reuses the crafting-list panel, so it is restyled with it.
- [The sturdiest-raft rule drops a weaker raft's fittings] → Accepted. It is the existing rule, and a scenario states it.

## Migration Plan

The data is additive, and the beached-raft record replaces a float in a host-to-client message, a join extra and the crossing snapshot. Peers of different builds are unsupported, as before. Rollback is reverting the PRs. Tuning lives in the four recipe files.

## Open Questions

- The final Spanish lines and recipe descriptions wait for the owner's voice pass (drafts in D9).
- The look of the toldo, the defensas and the clavazón on the raft frame is kitbashed from the tracked packs, and a proper pass belongs with the art review.
- Whether each generated chain must guarantee one fitting's inputs, as SPD's limited drops guarantee a share per floor, is for the next chain template in island-generation. It does not change these specs.
