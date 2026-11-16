# Proposal

## Why

On 2026-11-14 the owner asked: "can i go from island 2 to island 3 as soon as i get there if i sail on the raft?"

**The answer today.** There is no island 3 yet. The coast cay names no next island, so launching the beached raft there ends the run with the summary (crossing "Arrival", scenario "A beached raft launches again"). The generator that builds island 3 is gated on the Milestone A/B playtest, and the owner chose to keep runs ending on the coast cay until the run structure exists (island-generator decision 2). Once island 3 exists, the answer is yes: an intact raft beached on any island can launch again at once, and no rule asks the party to stay.

**Why nothing makes them stay** (numbers in design.md "Diagnosis"):
- **The raft has no life on land.** A beached raft keeps its integrity, and nothing ashore mends it or makes it better. `RecipeData` already has the `VESSEL_REPAIR` and `VESSEL_UPGRADE` kinds, and GAME_DESIGN §6, crafting-inventory "Durability" and ITEMS.md all promise repair and a reinforced raft, but no recipe exists.
- **Little of what an island holds is needed for the next crossing.**
  - Aboard, a 75 s crossing by day costs about 15 thirst and 4 hunger, and no energy unless the rider falls in.
  - Items are refused at sea (the owner kept that rule on 2026-11-15, crossing-gameplay Q5).
  - The next island has its own coconuts.
- **Leaving early loses nothing that lasts.** Experiencia gives a point per island reached, not per island used.
- **Raft damage stops only careless riders.** With crossing-gameplay (being built now), simulated with an assumed rider skill model:
  - An idle rider's raft breaks on 27 % of 75 s crossings, and the rest arrive with about 46. Relaunched at once, under a third of those reach the next island intact.
  - An attentive rider arrives with about 86–89 and can chain three crossings on one raft with 95 % intact and about 70 left.
  - In the owner's own case, the coast cay to island 3, a stop lifts an attentive rider's next crossing from 98.7 % intact to 100 %, and the coast cay holds no tarp. So a fix built only on raft damage changes almost nothing for a good player.

## What Changes

The design is **"Parar paga" (stopping pays)**. Sailing on at once stays legal, as diving down stairs stays legal in Shattered Pixel Dungeon, Brogue and DCSS. The stop is where the raft is mended and fitted out from what the island holds, and the fittings stay on the raft for every later crossing.

Said plainly: with the recommended option, a skilled rider can still skip every island until companions, texts and NPCs give islands more pull. The owner's Q1 offers the one lever that bites at full skill, **beaching wear** (each arrival costs the beached raft 15, so even an expert mends every second or third island). It is not recommended here because it changes crossing "Arrival", which balsero-lore also modifies, and every arrival test.

- **Mending ashore.**
  - A built raft (beached after a crossing, or built and not yet launched) can be mended: 1 driftwood and 1 rope give +20 integrity after 10 s of work, or 5 s for a Mecánico, never above the raft's maximum. The mend repeats.
  - It is a shared job on the raft: anyone deposits, work advances while someone works.
  - Data: `game/resources/recipes/raft_mend.tres` (`VESSEL_REPAIR`).
- **Raft fittings** (`VESSEL_UPGRADE` recipes, one of each per raft). Each stays on the raft while it is intact, through the crossing and the beaching on the next island, and is lost when the raft breaks:
  - *Clavazón* (4 nails, ITEMS.md "reinforce raft"): +20 to the maximum and +20 now. The coast cay's observation post holds exactly 4 nails.
  - *Defensas* (1 inner tube and 1 rope, ITEMS.md "raft fender"): rocks and debris that hit, including the reef line, do three quarters of their damage. That keeps an idle rider's loss near crossing-gameplay's approved target (design.md D3).
  - *Toldo* (1 tarp and 2 driftwood): the deck is shade for riders aboard, so the sun factor on thirst stops and heat falls. Without it, a midday crossing brings sunstroke at about 67 s whatever the rider does.
- **The raft shows its state.**
  - The raft's prompt adds its integrity, its maximum and its fittings, and a warning line below half its maximum.
  - A work point on the raft's land side opens the raft's list of mends and fittings, built like the workbench list.
  - Launching stays a 1 s hold on its sea side, so "Zarpar en la balsa" is unchanged.
- **No new gate.** A hard rule such as "below 50 the raft cannot sail" could strand a solo player on the final sandbar (6 driftwood and no rope) or on any island already stripped bare. That rule is offered to the owner as an option, with a waiver, and is not recommended.

These options were weighed and left out (design.md "Options weighed"):
- **A supplies check at launch (water and food aboard):** it works around the owner's "no items at sea" rule.
- **The patrol seeing a launch:** it applies on coast chains only, and nothing chases a raft at sea until the cutter boss.
- **A rest or morale need:** sleep is not wired (`SurvivalMeters.sleep_night()` is called only from tests). This is the follow-up `night-ashore`.
- **"The next island punishes the unprepared":** the reef's thin water arrives with the generator and needs no rule.

## Solo

Every job is one player's:
- One player deposits a mend's or a fitting's inputs, works it alone and launches.
- Every input of the three fittings and of a mend is on the sandbar or the coast cay for one player who arrives by raft:
  - the sandbar's tarp and the 2 driftwood the raft leaves, for the toldo;
  - the coast cay's 4 nails, 2 inner tubes, 4 rope and 8 driftwood, for the clavazón, the defensas and two mends.
- With no gate, no island can strand a lone player.
- Every requirement has a 1-player, offline scenario. The tests sail the real sandbar to coast cay path alone.

## Owner decisions

Answered on 2026-11-15:
- Q1: the owner chose (a), "Allowed; stopping pays", after seeing that a skilled rider can still skip islands.
- Q2–Q8: the owner accepted the recommended option (a) on each.

Details are in design.md "Owner decisions". The specs follow those answers. PR 1 (the mend) is approved to build now, and PR 2 (the fittings) after crossing-gameplay's PRs merge.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `escape-routes`, all ADDED:
  - Mending a built raft
  - Raft fittings
  - Raft jobs are shared
  - A launch ends an unfinished job
  - The raft's state on every peer
- `crossing`:
  - ADDED: Raft maximum and fittings at sea, Defensas at sea, Toldo at sea, and Fittings ride with the raft.
  - MODIFIED: Vessel look on the crossing (the share is of the vessel's maximum, which a fitted raft raises). No in-flight change modifies it.
  - Not touched: "Raft integrity on the crossing", "Arrival" and "Joining during a crossing", which crossing-gameplay and balsero-lore already modify.
- `inventory-hud`, all ADDED:
  - The raft's prompt shows its state
  - Raft work list
  - Raft jobs in the prompt

## Impact

- **Data.** New files:
  - `game/resources/recipes/raft_mend.tres`, `raft_clavazon.tres`, `raft_defensas.tres` and `raft_toldo.tres`.
  - `RecipeData` gains `vessel_modifiers: Array[ModifierData]` (scope VESSEL). A `VESSEL_UPGRADE`'s existing `integrity_delta` (the bonus to the maximum) carries the clavazón.
  - `ModifierData.Stat` gains `VESSEL_HAZARD_DAMAGE` and `VESSEL_DECK_SHADE`, appended to the end of the enum.
  - The four vessel recipes set `station = NONE`, so the workbench list never shows them.
  - New prompt ids are appended to `hud_text.tres`.
- **Code:**
  - `game/scenes/structures/raft.gd` and `.tscn`: a maximum, fittings, a work point and a job.
  - `game/scripts/routes/island_routes.gd`: the departure state carries the maximum and fittings.
  - `game/scripts/levels/island_travel.gd`: `_beached_integrity()` becomes a beached-raft state with integrity, maximum and fittings, sent in `travel_to` and in the join extras.
  - `game/scenes/crossing/crossing.gd`, `crossing_result.gd` and `crossing_snapshot.gd`.
  - The HUD's prompt and list code.
- **Tests:** new 1-player tests (mend, each fitting, fittings carried to the coast cay, a broken raft's fittings lost) and host-plus-client and late-join tests. The crafting-inventory test "A solo player crafts every recipe" learns that a vessel recipe is crafted at a raft.
- **Docs:**
  - GAME_DESIGN §6 "Durability" and "Crafting": the mend's numbers and the fittings.
  - GAME_DESIGN §8: the toldo and the defensas at sea.
  - ITEMS.md: the uses of nails, tarp, inner tube and tire.
- **Sequencing:**
  - The crossing parts build after crossing-gameplay's three PRs, which add debris, leaks, planks and four required snapshot keys.
  - `island_travel.gd` is also touched by guardacostas-capture (the restart), so this change rebases onto it.
  - balsero-lore modifies crossing "Arrival", and this change does not.
  - The mending slice (escape-routes and inventory-hud) does not depend on crossing-gameplay and can go first.
