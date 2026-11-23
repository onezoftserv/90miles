# Proposal

## Why

The Fable review of 2026-11-22 (priority 1; findings G1, G2, G7, G9, G10, G13) found the loop has no pressure. A scripted solo bot won the whole run in 4:14:
- it never ate, drank, crafted, hid or met a patrol;
- it left the sandbar at 08:50 on day 1, before the first midday;
- the raft build was 60 s of standing still at no cost.

So night, the patrol, thirst, Energía and Ánimo never matter, and the best content in the build (searchlight, shore squad, *La captura*, night, bleeding) is never met in normal play.

On 2026-11-23 the owner chose the review's option (a): a staged raft build that costs energy and thirst, launching in view of a patrol counts as being spotted, and a retune so that a first-time solo player sees thirst under 50, one midday and one night before launch. Two more decisions came with it: heat at sea is capped below sunstroke until the toldo ships, and run 1 gets a short last stand.

## What Changes

**The budget behind the design** (design.md "Diagnosis"). Soft costs alone cannot make island 1 cost a day for a player who knows the island:
- Energy refills only from meals (+10) and sleep. Sleep is not wired: `SurvivalMeters.sleep_night()` has no caller.
- The sandbar's 10 coconuts are worth +100 energy.
- So any energy price is paid in coconuts, not in time. An all-knowing bot under the staged build alone still leaves at about 3–4 minutes, before night (night starts 7:00 real).
- Only a rule tied to the clock guarantees the night. The recommended one is below, and the owner's alternatives are in design.md "Open decisions".

The changes:
- **Staged raft build.** The raft is built in four stages, each with its own inputs and 30 s of work (120 s in all, 60 s for a Mecánico):
  1. "Amarrar las cámaras": 2 inner tubes, 1 rope.
  2. "Armar el piso": 4 driftwood, 1 rope.
  3. "Amarrar la baranda": 2 driftwood, 1 rope.
  4. "Apretar los nudos": no inputs.

  The totals stay 6 driftwood, 2 tubes and 3 rope, so the sandbar's counts and the mends are untouched.
  - A stage can start once the inputs it and the stages before it need are in, so building and gathering interleave, and in co-op one player can gather while another builds.
  - Work advances only while a worker *holds* interact on the site. Letting go keeps the progress.
  - Each second of raft work costs the worker 1 energy (GAME_DESIGN §4 "building 1/s", wired for the first time) and 0.25 thirst on top of the normal drain. A worker with no energy cannot work.
  - All of it is data on the recipe: new `BuildStageData` stages and per-second work costs. A recipe without stages (fire, rain catcher, mends) works as before.
- **Launch in view of a patrol is a spot** (recommended reading of "in view"):
  - By day, dawn and dusk (every phase in which the boat's searchlight is off), every launch of a vessel route from an island whose patrol boats are out is seen. "De día la guardia ve el mar entero."
  - At night, a launch is seen only while a boat's searchlight lights the starter.
  - A squall (patrols in port) or a weather that blinds sight hides any launch. An island with no patrol never sees one.
  - A seen launch does not start: nothing is spent and the raft stays on the beach. The boat raises a land alert on the starter (cause `launch`), so the shore squad lands and searches as for any spot.
  - The raft's launch prompt warns while a launch would be seen.
  - The effect: every player leaves a patrolled island at night or in a squall, as the balseros did.
- **Heat at sea capped.** A rider aboard a vessel in a crossing never gains heat past 59, so no rider is sunstruck at sea and one who boards sunstruck clears it. The island-stop toldo replaces the cap when it ships.
- **Short last stand.** A player with no living teammate gets a 12 s last stand on land before their Experiencia bonuses (was 0 s), so a solo player on run 1 can drink a coconut or a cup to get up. At sea the window stays the bonuses alone, since nothing can be used there. **BREAKING** for every scenario that times a solo death on land.
- **The measured bot.** A 1-player bot run, with its policy written before tuning, sails the real sandbar to coast cay path. It must see midday and thirst under 50 on the sandbar and launch after 20:00. Host-plus-client tests and a two-process run on UDP 7799 cover the staged build and the spotted launch.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `crafting-inventory`: "Shared builds" gains stages, held work and per-second work costs.
- `escape-routes`: "Raft build site" and "Sandbar routes as data" become the four-stage raft; "Starting a route" refuses a launch a patrol sees.
- `guardacostas-stealth`: a new requirement, "Launch in view", for when a patrol sees a launch and what follows.
- `survival-meters`: "Energy" and "Thirst" add the work costs; "Heat" gets the sea cap; "Health and downed state", "Solo last stand", "Free revive", "Cause of death" and "Cause ids" move to the 12 s base on land.
- `endings-progression`: "Solo last stand from Experiencia" gets the 12 s base.
- `inventory-hud`: "Build site prompt" shows the stage; a new requirement adds the patrol warning on the launch prompt.

## Impact

- **Data:**
  - `game/resources/recipes/raft.tres` gets stages and work costs.
  - `survival_tuning.tres`: `solo_last_stand_s` 12 and `sea_heat_cap` 59.
  - `hud_text.tres` gets the stage and warning lines.
- **Code:**
  - `RecipeData` and a new `BuildStageData`;
  - `BuildSite` (stage boundaries derived from the synced progress, so no new network state);
  - `Crafter` (held work, costs, the energy gate);
  - `MeterContext`, `SurvivalRules.next_heat` and `SurvivalMeters._on_health_empty`;
  - `PlayerBody` (one at-sea flag);
  - a one-line set in `Crossing._bind_body` and a reset in `island_arrival.gd`;
  - `IslandRoutes.start_for` and `PatrolRoute` (a `sees_launch` query and the `launch` cause);
  - the prompt in `interact_prompt.gd`;
  - the content validator's stage checks.
- **Docs:** GAME_DESIGN §4 (Energy, Thirst, Heat, last stand), §6 (raft stages), §9 (launch rule) and §14 (12 s base), and TASKS.md.
- **Seams:**
  - HUD clarity's objective row reads `BuildSite.missing_items()`, `progress()` and `inputs_complete()`; they keep their meaning.
  - Island-stop's toldo scenario "without the toldo" changes once the cap ships.
  - The crossing-gameplay rebase touches `crossing.gd`; this change adds one line there.
