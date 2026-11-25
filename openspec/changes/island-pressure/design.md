# Design

## Context

### What the review found (copied, since the review lives in a temporary folder)

From the Fable review of main `8c58c16` (2026-11-22), `FABLE_REVIEW.md` and its bot log `playthrough.md`:

- **Priority 1, "Make island 1 cost a day".** "Root cause: it decides whether night, patrol, thirst, Energía and Ánimo ever matter." Evidence: the raft was built at 1:24, before 09:00 on day 1, and the run ended at 4:14, "Días 1". The review's fix: split the raft build into 3–4 staged holds that cost Energía and thirst (GAME_DESIGN already says 1/s), make launching in view of the patrol a spot, retune so a first-time solo player sees thirst under 50, one midday and one night before launch, and give run 1 a 10–15 s last stand.
- **G1 (+G13), high.** Survival never engages; the run is over before midday of day 1. Fix: the island costs a day by rule; wire Energía costs. (H13/G13: Energía and Ánimo never move.)
- **G2, high.** The raft build is 60 s of standing still at no cost. Fix: staged holds with a cost; a job for player 2.
- **G7, high.** Patrol, squad and capture are never met in normal play. Fix: a launch-in-view spot; daytime sight on open beach.
- **G9, medium.** Calor sits at 100 for 46 s at sea with no counter, and the blur hides hazards. Fix: tarp as shade, or cap heat at sea.
- **G10, medium.** Solo: instant death on run 1; thirst kills in 50 s. Fix: a short last stand; a warning step.

From the bot log (run 2, solo, real shell, no hooks):
- **Times.** Gathering took 24 s: 11 pick-ups, all on the sandbar within a 24 s walk. Then the bot stood at the site for 60 s; the work advanced with no button held, one percent every 0.6 s. The raft launched at 1:25 (08:50).
- **Meters.** At 1:00 they read 100/94/95/0/100/100 (Salud/Sed/Hambre/Calor/Energía/Ánimo). At the end: thirst 58, hunger 85, health 100, energy 99. Nothing was eaten or drunk.
- **Patrol.** The boat was in its 20 s horizon warning at spawn and never came near the player.
- **Heat.** It climbed from Mediodía on: 49 at the cay landing (2:33), 90 at 3:00, 100 by 3:28, 19 s into crossing 2, with the whole view blurred for the rest of the crossing.
- **Dead time.** About 175 of 254 s held no meaningful choice (raft work 60 s, crossing gaps 91.8 s, long walks).

### What the code says today

- **Build site.** `BuildSite.work(fraction)` advances one shared `_progress` once `inputs_complete()`. `Crafter._advance_site` works it every host frame while the player stays within `HOLD_REACH_PX`. No button is held and nothing is paid; `MeterContext.crafting` only doubles hunger.
- **Energy.** It is spent only by movement (`PlayerBody.advance`: run 0.5/s, swim, dive) and the crossing's swim drain. `SurvivalMeters.sleep_night()` has no caller (`night-ashore` is island-stop's follow-up). So the only refill is a meal, +10.
- **The patrol.** One boat on the sandbar (`patrol_boat.tres`):
  - period 180 s: 20 s on the horizon, a 100 s lap, then away;
  - searchlight only in `NIGHT`: a 60° cone, 10 tiles, sweeping a 120° arc round the island's centroid.
  - `PatrolRoute.spot()` ignores a boat that is not in sight.
  - An alert whose cause is on land docks the boat and lands the squad (`_lands_squad`, `_dock`).
- **Weather.** Calm 3 : squall 1, rolled at each phase start; a squall lasts 120 s after a 60 s warning, and patrols stay in port.
- **Last stand.** `survival_tuning.tres` `solo_last_stand_s = 0`: a player with no living teammate dies at once on run 1. A coconut already revives (crafting-inventory "Fresh-water revives"), so a last stand would let a carrier of a coconut and a knife get up.
- **At sea.** A rider's body uses the crossing's sea `TerrainQuery`, whose deck is `BEACH`. So aboard in the day phase is "direct sun", and heat rises at midday.

## Diagnosis: why soft costs cannot buy a night

Night starts at 20:00, 7:00 real; midday runs 2:00–5:00 real.

**Energy on the sandbar by day:**

| Source | Energy |
|---|---|
| Start | 100 |
| 10 coconuts as meals (needs the hut's knife, 40 uses) | +100 |
| 10 climbs, one coconut each (−5 each) | −50 |
| **Total by day** | **≈150** (≈140 without the 2 coconuts on the gulls’ nest palms) |

Corrected while building: the first draft counted one climb per palm (−30, ≈170). A climb gives one coconut, so each coconut climbed for nets +5. The build’s 120 leaves a solo builder about 20–30 energy for the night and the crossing.

Nothing refills on a clock: sleep is not wired.

**Demand:** the raft at 1/s is 120 for the proposed 4 × 30 s (60 for a Mecánico), plus running at 0.5/s.

**So an energy price is paid in coconuts, not in time.** Earliest launch for the review's all-knowing bot (estimates, before tuning):

| Rule set | Earliest launch (real) | Midday? | Night? |
|---|---|---|---|
| Today | 1:25 | no | no |
| Staged build and costs only | ≈2:40 (gather 0:24, 120 s holds, 1 palm and 2 coconuts) | yes (barely) | no |
| + launch seen only while a boat is in sight (lap or alert) | ≈2:40–4:20 (waits for one away window) | yes | no |
| + launch seen whenever a boat is out by day (recommended) | 7:00 (20:00), or a squall's window | yes | yes |

**Thirst by 20:00** for a solo builder who never drinks: 6 at dawn, about 54 over the day at half sun, plus 30 for the build. That is about 90 drained, so thirst ends near 10.

**Coconuts cover it.** Each coconut eaten for energy also gives +15 thirst. A builder who eats 2–3 for energy reaches night near 40–55, and must drink about once more if they idle in the sun. "Thirst under 50 before launch" holds for any player who builds alone.

**Squall windows.** A squall rolled at the day-phase start (25 %) comes at 2:00–6:00 real and is a launch window by the recommended rule. Launching into it means a squall at sea (−30, riders thrown unless tied). The acceptance bot runs with calm weather; the squall launch is a deliberate gamble, not the normal path.

## Goals / Non-Goals

**Goals:**
- Island 1 costs a day for everyone: midday on land, thirst under 50, the launch at night or in a storm. The patrol, the searchlight and the squad are met in normal play.
- The raft build costs energy and thirst and gives co-op a split: one gathers, one builds.
- Nobody is sunstruck at sea until the toldo exists.
- Run 1 solo can survive one mistake on land (a 12 s window to drink).
- Everything stays solo-winnable, offline, with numbers in `.tres`.

**Non-Goals:**
- **Sleep** (`night-ashore`), **daytime sight on the open beach** (G7's second half) and **a cutter at sea** after a seen launch.
- **The Calor HUD row and the clock**: the HUD-clarity session owns them. This change only adds prompt lines.
- **New pick-ups or a reshaped sandbar.** The island's counts stay; only the raft's recipe changes shape.
- **Crossing pacing** (crossing-gameplay groups 5–8) and **the toldo** (island-stop PR 2).

## Decisions

### D1. Stages are data on the recipe; the stage is derived from progress
- **`BuildStageData`** is a new `Resource`, not content: `name_es`, `name_en`, `inputs: Dictionary[StringName, int]` and `time_s`.
- **`RecipeData`** gains three fields:
  - `stages: Array[BuildStageData]` (empty means not staged);
  - `work_energy_per_s` and `work_thirst_per_s` (default 0).
- **The content check** requires, for a staged recipe:
  - stage inputs that sum to the recipe's inputs;
  - no tag inputs;
  - stage times that sum to `time_s`, each above 0.
- **The stage comes from the synced progress.** Stage k ends at the boundary b_k = Σ_{i≤k} t_i / T. The stage being worked is the first whose boundary lies above the progress (with an epsilon).
- **Work stops at a stage whose inputs are missing.** `BuildSite.work()` caps the progress at the boundary of the last stage whose cumulative inputs are in.
- **Deposits are unchanged.** `deposit()` still takes any recipe input up to the totals.
- **What stays the same:**
  - `missing_items()`, `inputs_complete()` and `progress()` keep their meaning (whole recipe), for the HUD-clarity objective row.
  - New helpers carry the stage: `stage_index()`, `stage_missing_items()`, `stage_progress()`, `work_limit()`.
  - No new network state: `receive_state`, the join path, `RaftJob` and `send_state_to` are untouched.

**Rejected alternatives:**
- **Four chained build sites:** they break "one site per raft" at a fixed path, the level's synced site and the island-stop work point.
- **A synced stage index:** a second source of truth that can disagree with progress.
- **Per-stage deposits:** they would refuse driftwood picked up early, and refusing a carried input reads as a bug.

### D2. Held work for staged recipes
- **How a hold works.** In `Crafter._advance_site`, a staged recipe advances only while the body's host-side intent has `interact_held`. Letting go cancels the crafter's hold, and the site keeps its progress. The next press goes through `BuildSite._on_interacted` (deposit and `start_work`) as today.
- **Two holders.** Each holder calls `work()` with their own fraction, so two holders are 2× (escape-routes "Shared crafting" already sums workers).
- **Unstaged recipes** (fire, catcher, mends) keep "in reach works it", so their tests and the island-stop job rules do not move.

Rejected: holding for every build site. It would change the fire, the catcher and the mend for no review finding.

### D3. Work costs and slow work at 0 energy
- **What a worker pays.** Each host frame, a worker on a recipe with a cost pays `work_energy_per_s × delta` through `spend_energy` and `work_thirst_per_s × delta` off thirst. The skill factor speeds the stage, not the rate, so a Mecánico pays half per stage.
- **Slow work at 0 energy** (owner Q4 (a), 2026-11-24; this replaced a gate that stopped all work and could strand a solo player, see "Stress runs"). With `work_energy_per_s > 0` and energy at 0, a hold works at `RecipeData.exhausted_work_factor` (the raft's 0.25). Each second held still pays `work_thirst_per_s`; no energy is spent. The prompt says "Sin fuerzas: come algo." The worker gets out at the price of time and thirst: the last 20 s of a raft take 80 s of holding.
- **Numbers:**
  - energy 1/s: GAME_DESIGN §4 already says "building 1/s"; the owner pointed at it.
  - thirst +0.25/s: a 30 s stage costs 7.5, about half a coconut, so the build's 30 thirst is felt.

Rejected:
- **A lump per stage:** the price is no longer tied to the time worked, and two workers would each pay the whole lump.
- **A thirst ×2 work factor:** it compounds with the sun factor into 0.4/s and hides the cost in the sun rules.

### D4. "In view": by day the guard sees the whole sea; at night only the light
- **The route flag.** `RouteData.seen_at_launch: bool`: the raft true, binoculars-and-swim false (a swimmer stays under the water rule).
- **The query.** A pure query, `LaunchSight.seen_by(boats, phase, weather, point_px)`, is used by both the host's `IslandRoutes.start_for` and the HUD prompt. It returns the first boat (by member index) that sees the point:
  - **Never seen:** in a squall (`patrols_in_port`), when the weather disables `SIGHT`, or on an island with no boat.
  - **Seen by every boat on the island:** in a phase that is not in the boat's `searchlight_phases`, whatever its loop state, since by day the guard watches the whole sea.
  - **Night:** seen only by a boat whose light covers the starter (`light_on` and the cone, the test `PatrolRoute.lights()` already does).
- **It runs on clients too.** The inputs (phase, weather, each boat's `state_id`, `light_on`, `beam` and position) are already synced, so a client computes the same warning.

**Why this reading of "in view".** The review asked that a first-time player see a night before launch. The diagnosis shows that only a clock-bound rule makes that true for a player who knows the island. The rule makes the patrol the reason to wait, as for the historical balseros, who left at night, and it puts the searchlight in normal play (G7).

**Alternatives** (owner decision Q1 chose this rule over both):
- **Seen only while a boat is in sight.** Soft; a knowing player leaves at about 3–4 minutes.
- **Pull sleep forward from `night-ashore`** and price the build above a day's food. This needs a sleep rule, outside this change's scope.

### D5. A seen launch is a land alert, and the launch is refused
- **What `start_for` does.** It checks the requirements, then `LaunchSight`. On a sighting it returns false with nothing spent and calls `PatrolRoute.launch_seen(body)`.
- **A boat on its lap or alerting** responds as to a spot on land, through `_respond(&"launch", body)`.
- **A boat away or on the horizon** is first put on its lap at the loop point nearest the starter: its clock is set to that lap time and it enters `LAP`. It then responds. The dinghy therefore rows from a point within the loop's offshore distance, not from off the map.
- **The cause `launch`** is on land, so `_lands_squad` docks the boat when it has a squad and none is ashore.
- **What the player meets.** The rest is the existing shore squad: a search of 180 s, the fire first, then the last known position (the raft), then a random walk; capture on a 2 s touch; *La captura*. Solo on island 1, a failed persuasion restarts island 1, regenerated.
- **The raft is lost on a restart.** Its deposits were spent. This is harsh, but it is the existing capture rule. The prompt's warning comes first, so the loss always follows a warned choice.

Rejected:
- **Launch, then a chase at sea:** the cutter boss and crossing searchlights are not built, and crossing.gd is being rebased.
- **A refused launch with no consequence:** the review asks for a spot, and G7 wants the squad met.

### D6. Heat at sea is capped
- **The flag.** `MeterContext.at_sea` is true for a player who left the island by a route (`CoopSession.has_left`, the rule `UsePlan` already refuses item use at sea by). `PlayerBody._meter_context` sets it, and a rider also counts when they walk on a crossing's sea under way in the session (a crossing built without the island's routes, as the test rigs do). For the last stand (D7), `SurvivalMeters.at_sea_source` asks the body at the moment health reaches 0, since a crossing's harm can land between ticks; bare meters in unit tests use the last tick's context. Built when this change was implemented, in place of a `PlayerBody.at_sea` field set in `Crossing._bind_body` and cleared in `island_arrival.gd`: the departures already reset with each island, so no flag can stick on land after a restart or a rematch, and `crossing.gd` (which the crossing-gameplay work owns) is untouched.
- **The cap.** `SurvivalRules.next_heat`: when `SurvivalRules.sea_heat_capped(context, tuning)` holds (`at_sea`, and `sea_heat_cap` not negative), a rise stops at `tuning.sea_heat_cap`, and heat above the cap falls at no less than `heat_fall_per_s` down to it (shade at sea keeps falling past it). That function is the cap's one switch, which the island-stop toldo turns off.
- **Why 59.** It is below where sunstroke ends (60), so nobody is sunstruck at sea, and a rider who boards sunstruck clears it within about 54 s. A cap of 74 would keep the Calor label orange, but a sunstruck boarder would then stay blurred the whole crossing, which is G9 again.
- **The number** lives in `survival_tuning.tres` with the other meter numbers, so `SurvivalRules` stays pure over context and tuning.
- **When the toldo ships** (island-stop PR 2), it makes the deck shade, the cap goes, and island-stop's scenario "The same crossing without the toldo" is reread against whatever rule then holds. This is noted in the shared notes folder for that session.

### D7. A 12 s last stand on land
- `solo_last_stand_s = 12`. `SurvivalMeters._on_health_empty` uses `(0 if at_sea else solo_last_stand_s) + downed_bonus_s`, with `at_sea` from the last tick's context (D6).
- **Same for co-op's last one alive.** `solo` in code already covers them, and GAME_DESIGN treats them alike.
- **None at sea.** Items are refused at sea (crossing-gameplay Q5), so a sea last stand could only delay a death. Keeping it out also keeps the drowning and shark scenarios exact.
- **Why 12.** Drinking takes 2 s (coconut `time_s`), plus finding the slot.
- **Reference.** DCSS's Death's Door lasts about 10–23 turns (`spl-selfench.cc`), the same order.

### D8. Prompt lines
`interact_prompt.gd` builds the lines from `BuildSite`'s stage helpers and the HUD text file:
- the stage line and the "Falta:" lines for the stage;
- the stage bar;
- "Sin fuerzas" when the local player's synced energy is 0 and the recipe costs energy;
- `LaunchSight` for the raft's launch warning.

The words live in `hud_text.tres` and the stage names in the recipe. Players see the HUD-text and stage words in Spanish only (menus and prompts follow the HUD text file). The English stage names exist for data completeness.

### D9. The measured bot: policy written before tuning
A manual script, `tests/manual/island_pressure_run.gd`, boots the real game shell solo, with calm weather pinned (no squall window). It plays with this policy, fixed now so the numbers cannot be tuned to it.

**What it knows:** every pick-up position (as the review's bot did), the site's stages, its own meters, the launch warning the HUD would show, and the crossing plan at sea.

**Order of play:**
1. **Gather** the next missing stage's inputs, the nearest first, and pick up the hut's knife.
2. **Work** by holding the site.
3. **When energy reaches 0**, climb the nearest palm with coconuts (not a gull's nest palm first), eat each at once out of the gulls' sight, and repeat until energy is at least 20 or no palm has coconuts. (Was "at least 40": corrected when building, since a climb gives one coconut for 5 energy; see "Measured run".)
4. **Drink** a coconut whenever thirst drops below 30.
5. **Cool off** at midday: at heat 80 or more, walk to the hut's shade until heat is below 30.
6. **Wait** once the raft is built. If thirst is below 30 or energy below 20, top up first. Then stand in the hut's shade until the launch warning is gone.
7. **Launch.**

**At sea and after:** the review bot's dodge and tie-down rules. On the cay, the same policy (top up, wait for no warning, launch).

**Logged:** a snapshot every 30 s real; the minimum thirst on the sandbar; the phases seen; the launch time; the arrival; the summary.

**What it asserts:**
- midday seen on the sandbar;
- thirst under 50 at some point before the launch;
- the launch after 20:00;
- the player alive to the summary;
- 0 errors logged.

It runs headless with a fixed physics step (`--fixed-fps 60`), faster than real time. The game clock is the game's own. A GUT test covers the same targets with the pure rules: a scripted day of the policy against `SurvivalRules` and the stage costs. It runs in CI in seconds; the manual run is the measurement.

### References (ideas only, nothing copied)

**Shattered Pixel Dungeon:**
- **Borrowed: a warning before harm.** `actors/buffs/Hunger.java`, `Hunger.act()`: a warning at `HUNGRY` (300) comes well before `STARVING` (450), and starving is a slow loss that food still cancels. This is the shape of our last stand: a short window in which the right item saves you.
- **Borrowed: a surcharge on a meter while working.** `actors/hero/Hero.java`: searching charges extra hunger, `TIME_TO_SEARCH` and `HUNGER_FOR_SEARCH` passed to `affectHunger`. This is the shape of the raft's thirst surcharge: working costs more than standing.
- **Borrowed: every level carries what it charges.** `levels/Level.java` `create()`: one food item is guaranteed per floor (`Generator.Category.FOOD`). The sandbar's 10 coconuts cover the build's 120 energy, so the price can be paid on the island that asks it.

**Brogue CE:**
- **Borrowed as a method: the budget view.** `Items.c` `populateItems()` keeps a running food debt (`rogue.foodSpawned` against `POW_FOOD`), so supply tracks how far the player has come. Our Diagnosis table is that view for one island: supply against demand per resource.
- **Rejected: the bare clock as the only pressure.** `Rogue.h` sets `STOMACH_SIZE`, `HUNGER_THRESHOLD`, `WEAK_THRESHOLD` and `FAINT_THRESHOLD`; `Time.c` `printNutritionMessages()` and `playerTurnEnded()`. Brogue's clock presses because every turn spends food and there is always more dungeon. Ours runs in real time on an island already solved, so it presses only when something says to wait. Hence the launch rule.

**DCSS:**
- **Lesson.** `docs/changelog.txt`, 0.26: "Food and hunger are removed", because the clock had become a tax that produced hoarding and dull pacing. Our costs must create decisions (when to work, eat, cool off, launch), not only drain. That is why the costs come with a gate (no energy, no work) and a visible price.
- **Rejected: a debuff after a burst.** `player.cc` `player_end_berserk()`: exhaustion and a slow after berserk. Energy already pays for the work.
- **Borrowed: the size of the window at death's edge.** `spells/spl-selfench.cc`, Death's Door (`DUR_DEATHS_DOOR`, about 10–23 turns). Rejected: its opt-in form; ours is automatic.

**Don't Starve Together** (dontstarve.wiki.gg; `docs/REFERENCE_DST.md`):
- **Day-Night Cycle page. Borrowed, inverted.** In DST the first day is the window to prepare before dark, and night is the danger. Ours keeps the day as the preparation window but makes the night the moment to leave, because the guard sees by day.
- **Crafting page. Rejected for the raft.** DST charges only materials for crafting, no time or meter. Our loop has no other pressure on the build, so the owner chose a price in energy and thirst.
- **Telltale Heart, via REFERENCE_DST.md "Revival by a teammate"** (the page was not fetched). Borrowed: a craft can cost a meter as a visible, named price. The prompt shows what the raft costs before you hold.
- **Charlie/Darkness, via REFERENCE_DST.md "Darkness and the night attacker"** (not fetched). Borrowed: night is where a light decides your fate. For us it is the searchlight's cone at launch.
- **Boat, via REFERENCE_DST.md "Boat building".** Kept: our notes reject placing a vessel piece by piece. The stages are work on one site, and the route still names a finished vessel.
- **Launch detection.** None of the four games has a precedent for a launch seen by a patrol. It is our own rule.

## Risks / Trade-offs

- **Tests that launch by day.** Every existing test that launches a raft by day on an island with a spawned patrol boat would now be refused. → Mitigation: a sweep of the tests that start routes (task 1.1). They set the phase to night or pin a squall, or use islands without creatures. The rule reads only boats that exist, so tests without creatures are untouched.
- **Tests that work the raft site by standing.** → Update them to hold interact, and test the four stages. Fire, catcher and mends are unchanged (D2).
- **The coast cay also costs until dark** when the party lands there by day. → This is intended pressure, but the owner should know. An arrival at night can leave at once (outside the light). It is in the message to the coordinator.
- **A seen launch can cost the raft** (a capture restarts island 1, regenerated). → The warning shows before every seen launch, and hiding from the squad (brush, the hut) still saves the raft.
- **The squall gamble.** It lets a fast player leave by day in about a quarter of runs. → It is the intended trade (a squall at sea). If the owner wants the night guaranteed, squall launches could count as seen too, but that removes the storm option GAME_DESIGN §3 names ("wait for the right weather").
- **Low energy at sea.** A builder who launches at 0 energy and falls in drowns fast. → The bot policy tops up before launch. The Energía bar shows it, and a launch-energy warning belongs with the HUD-clarity work (noted for that session).
- **Seams with other sessions.**
  - HUD clarity reads `BuildSite.missing_items()`, `progress()` and `inputs_complete()`: their meaning stays.
  - The crossing-gameplay rebase owns `crossing.gd`: this change adds one line there.
  - Island-stop PR 2 replaces the sea cap.

  All three are written in the shared notes folder.

## Test sweep (task 0.2, on main 041e711)

Baseline: GUT 2739 of 2739 passing on the rebased branch before any change.

`grep` for tests that start a route (`start_for`, `start_route_for`, `request_route`, a raft's `interacted`) or work a raft site found 25 unit files and 5 manual scripts. What the change did to each:

- **Work the raft by standing (fixed: they now hold interact and pay the work's energy):** `test_raft_site.gd`, `test_escape_routes_solo.gd`, `test_secret_cay_solo.gd`, `test_inventory_hud_solo_run.gd` (it now lets go at energy 10, drinks three carried coconuts from the HUD and goes back to hold E).
- **Read the raft's 60 s (fixed):** `test_route_content.gd` (120 s), and the prompt's raft-site lines in `test_interact_prompt.gd` (stage lines).
- **Launch by day on an island with a spawned patrol boat (fixed: the island's boats are taken away first, since these tests are about the crossing or the relaunch):** `test_coast_cay_solo.gd` (the relaunch from the cay), and `test_crossing_art.gd` and `test_crossing_join.gd`. The last two spawn the sandbar's creatures and never set the clock, so before this change they passed or failed on the clock other tests left behind. The manual runs `capture_crossing.gd`, `capture_crossing_gameplay.gd`, `crossing_gameplay_run.gd` and `island_stop_run.gd` get the same, with a printed hook where the run prints its hooks. `test_inventory_hud_solo_run.gd` waits for the night the warning asks for.
- **A hollow pass (fixed):** `test_crafting_solo.gd` "every recipe completes with one player" still passed for the raft, because letting go ends the work. It now holds interact, pays the energy and checks that the site was built.
- **The prompt's stage lines (fixed):** `test_interact_prompt.gd` and `test_interact_prompt_net.gd` (the client's prompt at 45 of 120 s, and the joiner's first-stage lines).
- **Solo deaths timed at 0 s (fixed for the 12 s last stand):** `test_survival_tuning.gd`, `test_survival_last_stand.gd`, `test_survival_health.gd`, `test_player_meters.gd`, `test_bleeding.gd`, `test_death_cause.gd`, `test_run_summary.gd` and `test_run_restart.gd`. The crossing's drowning and shark bite still kill at once, since the body reports it is at sea.
- **Unchanged and passing:** the other crossing, reconnect, rematch, status, structure-sync, perch-ride, coast-cay and route tests in the grep list. They build the raft with `work(1.0)` on a full site and launch where no boat is yet.
- **Found in passing:** the shell tests failed to load the palm and raft scenes when run first. The cause was this change's own load cycle, `LaunchSight` naming `SandbarIsland`, now removed.

After the merge with main f8a6c75: GUT passes 2957 of 2957, and smoke reports 0 problems.

## Measured run (task 6.2, 2026-11-23)

`tests/manual/island_pressure_run.gd` ran headless with `--fixed-fps 60`, solo, offline, with calm weather pinned and a quiet 75 s crossing plan (a printed hook). It passed 8 of 8 checks with 0 engine or script errors. One policy detail was corrected before the run: D9's "eat until energy is at least 40" became "at least 20". A climb gives one coconut and costs 5 energy, so 40 cannot be reached after a 120-energy build (see the corrected budget table above).

**Timeline:**

| Game time | Clock | What | Sed | Calor | Energía |
|---|---|---|---|---|---|
| 0 s | 06:00 | knife, gather | 100 | 0 | 100 |
| 30 s | 07:00 | stage 1 | 94 | 0 | 89 |
| 120 s | 10:00 | stage 3 | 65 | 0 | 32 |
| 150 s | 11:00 | stage 3, energy runs out | 52 | 45 | 2 |
| 180 s | 12:00 | ate 3 coconuts; cools off in the hut | 90 | 89 | 20 |
| 270 s | 15:00 | stage 4 | 79 | 44 | 16 |
| ≈ 291 s | 15:31 | **raft built** | | | |
| 300 s | 16:00 | top up | 69 | 89 | 0 |
| 330–420 s | 17:00–20:00 | waits in the hut's shade for the night | 98 → 89 | 67 → 0 | 20 |
| ≈ 428 s | **20:15** | **launch** (not seen: night, out of the light) | 89 | 0 | 20 |
| — | 22:44 | lands on the coast cay at night and leaves at once, out of the light | 85 | 0 | 20 |
| 581 s | — | the run summary, alive | | | |

**The targets:**
- midday was seen on the sandbar;
- the lowest thirst on the sandbar was **49.2**;
- the launch came at 20:15;
- the player was alive at the summary;
- 6 coconuts were eaten and 1 was taken by a gull.

The whole run took 9:41, against 4:14 in the review's run.

**The GUT mirror:** `test_island_pressure_day.gd` plays the same policy against the pure rules. It builds the raft at 12:50 and launches at 20:17, with the lowest thirst at 46.8 and 20 energy left.

**Margins worth knowing:**
- The bot's lowest thirst is only just under 50. It is a knowing player that eats for energy, and each coconut also gives +15 thirst. A first-time player who wanders will dip lower.
- A solo builder reaches the night with about 20 energy, and sleep (`night-ashore`) is the follow-up that refills it.

### Stress runs: a solo player can strand (open owner question Q4)

The sandbar holds no other food: coconuts do not regrow, there are no food pick-ups, and crabs only steal. Sleep is not wired. The bot ran three stress variants (printed hooks), each headless on the merged branch:

| Variant | Result |
|---|---|
| `--run` (runs everywhere, 0.5 energy a second) | stranded at 19:17 with 109 of 120 s built: 0 energy, no coconut left (5 eaten, 4 taken by gulls) |
| `--lose=3` (3 coconuts gone at the start, as gulls would take them) | stranded at 18:38 with 110 of 120 s |
| both | stranded at 16:28 with 101 of 120 s |

Stranded means alive, with an almost-built raft and no way to finish it on island 1. The run never ends until thirst kills the player. That broke "solo must be winnable" for any player who is less than careful, so it went to the owner as Q4 before merging, with options:
- **(a)** Work at 0 energy at a quarter speed, paying thirst only (recommended).
- **(b)** Coconuts regrow each dawn.
- **(c)** The raft's work costs 0.75 energy a second.
- **(d)** Pull `night-ashore` sleep forward.

**The owner chose (a) on 2026-11-24.** Its reruns are under "Stress runs after Q4 (a)".

### Stress runs after Q4 (a) (2026-11-24, on main 9f3ec68)

The same four runs, headless, with slow work at 0 energy. None strands: every one launches at night and is alive at the summary, with 0 errors.

| Variant | Slow work from | Raft built | Launch | Lowest thirst on the sandbar | Checks |
|---|---|---|---|---|---|
| baseline | never | 15:31 | 20:15 | 49.2 | 8 of 8 |
| `--run` | never (9 coconuts eaten, 4 taken by gulls) | 20:48 | 20:51 | 51.1 | 7 of 8: thirst stayed above 50 |
| `--lose=3` | 18:38, at 110 of 120 s | 20:48 | 20:51 | 28.8 | 8 of 8 |
| `--run --lose=3` | 16:28, at 101 of 120 s | 19:50 | 21:30 | 36.3 | 8 of 8 |

**The one check missed:** the running variant ate 9 coconuts, so its thirst stayed above 50. That target is a measure of pressure, not of being stranded.

**The price of running dry:** a player who runs out of energy finishes the raft later, then waits out the light, and arrives thirstier.

## Two processes (task 6.3, 2026-11-24, on main f8a6c75)

`tests/manual/island_pressure_coop_run.gd` ran headless on UDP 7799, host first. Host 18 of 18 and client 9 of 9 passed, with 0 errors on either:
- the client's hold finished the first stage alone (30 s, −30 energy) while the host's player was away, and the site waited at its end on both peers;
- both held until the raft was built and shared the last 90 s (host −45, client −60 in all);
- the client's day launch was seen, nobody left, the raft stayed at 100 and both saw the boat dock;
- a squall recalled the squad; then at 22:00 the client's launch, out of the light, carried both to the coast cay.

## Migration Plan

- One PR: data, code, specs, GAME_DESIGN and TASKS.
- Saved data never loses a field: the new recipe fields have defaults, and old `.tres` files load unstaged.
- To roll back, revert the PR. No save format changes.

## Owner decisions (2026-11-23, through the coordinating session)

The owner chose the recommended answer to all three, in option dialogs:
- **Q1 (a). Day launches are seen:** every player leaves a patrolled island at night or in a squall. The owner saw the caveats that this is close to the review's "only at night" option and that the coast cay also costs until dark when the party lands there by day.
- **Q2 (a).** The measured bot sees midday on the sandbar and launches from island 1 at 20:00 or later.
- **Q3 (a).** A 12 s last stand on land for anyone with no living teammate, and none at sea.

The tuning numbers stand as written. Rejected, for the record: (b) seen only while a boat is in sight; (c) sleep pulled forward; 720 s on island 1 or for the whole run; a 15 s window; a last stand for solo runs only.
