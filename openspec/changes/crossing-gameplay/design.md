# Design

## Context

See proposal.md "Why". The crossing (`game/scenes/crossing/crossing.gd`) is host-owned. The host rolls a `CrossingPlan` of `CrossingBeat`s (`[time, kind]`: SQUALL_WARN, SQUALL, SHARK_PASS, ROCK), fires each beat at its time through `_fire` and the `CrossingThreats` hook (`CreatureThreats` spawns the reef shark), ticks riders (fall in, swim drain, drown) and ends with a `CrossingResult`. Clients get the plan (`receive_plan`), rider states and integrity (`receive_state`, on change and every 1 s) and the result. Joiners get a `CrossingSnapshot`, which requires every one of its `KEYS`.

The sea is a 24×22-tile `GridTerrain`. The deck is a fixed 4×2-tile rect at its centre, filled as BEACH cells. Board routes use a row of 1×2 boards 3 tiles apart. `CrossingCreatures` (creature-perch-ride), `CrossingDeck`, `CrossingBoards` and `CrossingSea` read `deck_rect`, `deck_center`, `sea_rect`, `serial` and `scroll_px`, and those must stay stable.

Riders act only through the interact intent on Interactables: `RescuePoint` LASH, CLIMB and PULL. `InteractionHold` calls `use(by)` when the hold time is reached and `release(by)` when the button comes up, and `DragHandle` already uses that pair for a hold that lasts while held. Items are refused at sea: inventory-hud D11, the owner's choice of 2026-11-08, enforced by the host's `_acting_body` and the HUD's `UsePlan.actor_reason`.

## Baseline (measured on `main` at cb7834f, 2026-11-14)

**Method.** A scratch GUT script drove a real solo game shell: build the sandbar raft, launch it, then step `Crossing.advance`, `PlayerBody.advance`, the meters and the sky by hand in 0.1 s steps, logging every second and every change. The same script rolled 10,000 plans with `CrossingPlan.roll` for the raft route on the coast band. The script and its logs are in the shared notes folder, `crossing-gameplay-baseline/`. They are not committed.

**What a coast raft crossing holds** (10,000 plans; calm sky, no squall pending or running on launch; the squall's own chance is the same in every phase with today's two weather states, weights 3 and 1):

| Measure | Value |
| --- | --- |
| Length | 60–90 s, mean 75.0 s |
| Hits in the plan: 0 / 1 / 2 / 3 | 31.9 % / 47.6 % / 18.6 % / 1.9 % |
| Shark pass / rock / own squall per crossing | 0.50 / 0.24 / 0.16 |
| Expected integrity lost | 24.6 (0.16×30 + 0.50×20 + 0.24×40), which matches GAME_DESIGN §6's "about 25 % per crossing" |

A squall warned on the island adds a squall that follows the riders. That is not counted above.

**Second by second.** Every real run looked like this. The run below is seed 123: 88.4 s, launched at dawn, idle rider.

| Time | On screen | What the rider can do | Does any choice change the outcome? |
| --- | --- | --- | --- |
| 0–51.3 s | Sea scrolling, raft whole, no HUD for time or integrity | Walk the 4×2 deck; tie or untie (1 s hold, useless with no squall); step off (−10 energy, then −3/s) and climb back (3 s) | No |
| 51.4 s | The rock lands in one 0.1 s tick: −40, raft drawn worn | Nothing: no warning, no counter | No |
| 51.5–88.4 s | As before, raft worn at 60 | As before | No |

The other runs:
- Seed 1: one shark pass at 35.4 s, −20. A reef shark appears at the moment of the bite, circles and leaves.
- Seeds 7 and 42: no events at all.
- Seed 99: a shark pass at 31.7 s.
- A hand-written "busy" plan (squall warned at 5 s, shark at 30 s, rock at 50 s, squall at 65 s): the rider tied down at 6 s and then stood pinned for 74 s while integrity went 100 → 80 → 40 → 10. The single input of the crossing was at 5 s.

**Decisions per crossing.** In about 84 % of crossings (no squall) there is none. In about 16 % there is exactly one: tying down at some moment in a 60 s window, and tying down costs nothing. The rock and the shark have no telegraph and no counter, and being aboard is all that ever matters. Dead time is the whole crossing apart from about 1 s.

**Other routes, from the code.**
- *Co-op raft:* the plan ignores the number of riders. The only extra verb is pulling a swimmer (2 s), and there is nobody to pull unless a rider skipped the tie-down or stepped off.
- *Boards and car:* fixtures only (`game/tests/fixtures/routes/`). No real island offers them yet. A board has no lashing, so a squall means only climbing back.
- *Binoculars and swim:* 60 s with no vessel. A rock hits nothing, and a shark pass bites only a bleeding swimmer or one below 20 energy. Moving changes nothing, because the drain is the same moving or not. The swimmer ends at energy 28 having made no decision.

**Sun aboard.** It is real, but nothing can be done about it. Launched at 11:00 in the default calm weather (heat ×2), the rider's heat rose 0 → 45 at 30 s and reached 100 (sunstroke) at about 67 s, and thirst fell 18 over 89 s. The deck has no shade, and items are refused at sea. The only counter that exists is to jump in, since water cools, which nobody would guess and which costs energy. At dawn, heat stayed 0. The first attempt read heat 0 at noon because the shell resets the clock to dawn at launch, a harness artifact found and corrected.

**Creatures.** No real island's crossing rolls a creature: the galleguito needs the FINAL chain family, which no island has. The only crossing creature is the shark, and it shows at the bite.

**HUD.** The crossing shows no clock, no progress and no integrity number. The only feedback is the raft frame (whole, worn, breaking) and the squall's horizon line.

## Goals / Non-Goals

**Goals:**
- A decision at least every 9 s solo, each with a readable tell 4–5 s ahead, a counter one rider can do, and a cost to doing it: leaving the line, leaving another job, or staying untied.
- An idle rider does clearly worse than an attentive one. Targets on a 75 s solo coast raft crossing: idle about 20–40 integrity left, attentive 70 or more. The targets are checked by a plan-statistics test.
- The old plan form keeps its outcome when riders are idle, so existing tests and scenarios stand.
- Everything is host-decided, seed-stable, sent to clients, and restored for joiners.

**Non-Goals:**
- Encounters (dolphins, a turtle in a net, another raft), fishing, the Gulf Stream heading and drift, the cutter's searchlight, hiding at sea, and items at sea. See "Owner decisions" and the follow-ups in proposal.md.
- New art packs. Hazards, flotsam, fins and leaks start as kitbashed placeholders from the packs already tracked, drawn client-side.

## Decisions

### D1. Extend the beat, don't simulate the sea
Every beat keeps its plan time as the moment it resolves (the hit, the strike, the pass) and gains a lead (its telegraph) and a counter window. This keeps the one host roll, the 0.1 s `due()` firing, seed stability and `Crossing.restore` without replaying, and keeps clients drawing everything as a pure function of the plan, the elapsed time and the vessel's lateral position.

*Alternatives:*
- Spawn hazards as networked entities through the session spawner. Rejected: every rock would cost a spawn, a despawn and late-join bookkeeping, for something the plan already determines.
- Physics collisions between moving hazards and a moving raft. Rejected: they are not deterministic across peers.

### D2. Paddling moves a number, not the deck
The vessel's lateral position is one host float in tiles. Paddle points add speed and the pull-back draws it to 0. The deck, the riders and the sea grid never move; hazards and flotsam are drawn at `lane − position`, so the world slides past the fixed raft.

This keeps `deck_rect`, `CrossingCreatures` stations, climb and pull reach, and client prediction of each rider's own body (no moving platform under a predicted player) unchanged. Swimmers already "keep pace" in the raft's frame (crossing "Falling in"), so a hazard's place beside a swimmer also follows the position.

On a swimmers' route the position is always 0, and swimmers dodge by swimming. Paddle points are `RescuePoint` kind PADDLE, with hold time 0, which uses on press and stops on `release`, like `DragHandle`.

*Alternatives:*
- Move the deck cells and the riders. Rejected: it breaks prediction and every reader of `deck_rect`.
- Steer with movement keys at a helm spot. Rejected: the DST Steering Wheel lesson, since a manned wheel pins the one solo rider. Offered as Q2(c) anyway.

### D3. The pull-back makes idle equal today
The current pulls a vessel nobody paddles back to the line, at 0.5 tiles/s. So an idle raft is always on lane 0, and an old-form beat (no lane, so lane 0) hits it exactly as today.

The pull-back also makes a dodge a commitment: you paddle out, the rock passes, and you drift back over about 6 s, in time for the next beat. Holding a position off the line, for flotsam, means paddling.

### D4. Hits by overlap at the beat's time
At its time, a rock or debris hits when `|lane − position| < vessel_half + hazard_half`. The halves are 2 for the raft and the car, half the row's span for boards, 1 for a rock and 0.5 for debris. A miss passes harmlessly. Swimmers are tested every tick against the hazard's moving rect, once per hazard each.

On boards, a hit on the row still goes to the next intact board in rider order (the owner's vessel-car-board Q2). The fin of a board shark shows beside the board that is next in turn at the warning.

### D5. Leaks drain integrity directly (DST Leak)
Debris opens a leak on the hit half of the deck: −0.5/s until plugged by a 2 s hold, at most 3 open leaks. Plug points are `RescuePoint` kind PLUG on deck tiles.

A separate "water aboard" meter with bailing was weighed and kept as Q3(b). It is more balsero, but it adds a second gauge and a second job to a 75 s scene.

### D6. Shark: warn, circle, strike or be shooed
`CrossingThreats` gains `warn(beat, crossing)`, called at the beat's time − 5 s (the base class does nothing). `CreatureThreats.warn` spawns the reef shark 1 tile off the named side and keeps it circling there. At the strike, `resolve` runs today's choice (the swimmer first, then the vessel −20, with a dump on routes that dump), unless the beat was shooed.

Shooing is a `RescuePoint` kind SHOO that follows the fin: a 1 s hold by a rider aboard. A shooed shark is freed at once; the spawner takes it off every peer. A pass that fires with no lead, because it is in the first 5 s, or a plan restored past its warning, spawns the shark at the restored point.

### D7. Flotsam is loot or a plank, through interact only
A FLOTSAM beat's extra field indexes the tuning's flotsam table:

| Piece | Weight | Kind |
| --- | --- | --- |
| `coco` | 3 | item |
| `driftwood` | 3 | item |
| `rope` | 2 | item |
| `plastic_jug` | 1 | item |
| `cloth` | 1 | item |
| `inner_tube` | 0.5 | item |
| plank | 2 | lashed at once |

An item goes to the taker through the host's inventory add, so nothing breaks the owner's "no items at sea" rule (D11): items are taken, not used. A plank is lashed at once, +10 integrity, an interact-only repair.

Grab points are `RescuePoint` kind GRAB and follow the piece on every peer. The host decides with its own copy, using the usual reach plus slack.

### D8. The plan director
`CrossingPlan.roll(route, band, sky, rng, tuning, riders)`:
1. Length and squall as today.
2. The shark pass by the band's chance, as today.
3. `t1 = 6 + U(0, 3)` s, and the reef line at `L − 4` s.
4. `n = ceil((L − 4 − t1) / (7.5·d))` gaps, where `d = 0.9^(riders − 1)`. Times are spread evenly, then jittered by up to ±1.5·d s, with at least 3 s and at most 9·d s between neighbours.
5. Slots inside a squall's blow (hit to hit + 15 s) are dropped, and the next slot is pulled back to at most 9·d s after the blow ends. A rock or debris is placed at `hit − U(4, 8)` s when the hit is at 16 s or later. The blow beats the calm start and the first-beat window: a squall carried from the island to hit at 4 s pushes the first rolled beat past 19 s. The blow never moves the reef line. A rolled squall hits between 60 s and L − 10 s, so on a 70–79 s crossing the reef line always arrives in the blow, and half-speed paddling still covers 3.75 tiles in its 5 s lead, more than the 3 tiles to the farthest gap.
6. The shark takes one random slot. Every other slot draws from the band's weights, coast for now: rock 0.12, debris 0.20, flotsam 0.68, each threat weight times the route's threat factor.
7. Lanes: rocks and debris U{−4..4}, flotsam U{±2..±5}, often the slot next to a hazard's lane so that going for it risks the hazard. The reef gap g is U{−3..3}.

**Pacing budget** (solo, with co-op at 4 riders in brackets):

| Length | Calm start | Beats before the reef line | Mean gap | Max gap |
| --- | --- | --- | --- | --- |
| 60 s | 6–9 s | about 7 (10) | about 7 s (5 s) | 9 s (6.6 s) |
| 75 s | 6–9 s | about 9 (12) | about 7 s (5 s) | 9 s (6.6 s) |
| 90 s | 6–9 s | about 11 (15) | about 7 s (5 s) | 9 s (6.6 s) |
| 120 s (mid/far, later) | 6–9 s | about 15 (20) | about 7 s (5 s) | 9 s (6.6 s) |

**Expected loss** at 75 s, solo, before tuning:
- Idle: rocks 1.0 × 5/9 × 40 ≈ 23; debris 1.7 × 5/9 × (5 + 0.5 × ~35 s) ≈ 21; shark 0.5 × 20 = 10; squall 0.16 × 30 ≈ 5; reef line 2/7 × 40 ≈ 11. That totals about 70, so about 30 left.
- Attentive: squall plus a few seconds of leaks, about 10. That leaves about 90.

A Monte Carlo of this director (20,000 plans, script in the shared notes folder's `crossing-gameplay-baseline/mc_director.py.txt`) gives these idle results:

| Riders | 60 s: mean left / broken | 75 s: mean left / broken | 90 s: mean left / broken |
| --- | --- | --- | --- |
| 1 | 48.5 / 12.6 % | 33.5 / 26.7 % | 25.8 / 38.9 % |
| 4 | 40.2 / 20.5 % | 25.0 / 39.5 % | 16.5 / 55.8 % |

An idle co-op party does worse, because it gets more beats; it also has more hands. The attentive figure is still an estimate. The tasks check both against rolled plans in the game and tune the `.tres` weights.

### D9. The squall's blow and the cost of tying down
For 15 s after the hit (the blow; the squall weather itself rains for its whole 120 s) paddling is halved (`squall_blow_s`, `blow_paddle_factor`). Jobs aboard need an untied rider (crossing "Jobs aboard"). The director's pre-hit hazard makes tying down early cost a dodge. Today's "tie early, wait" stays possible, but it now costs integrity.

### D10. The wire and the snapshot
- **Plan.** `CrossingBeat` serialises as `[time, kind]` or `[time, kind, lane, extra]`. `from_array` accepts both, checks that `lane` is in −10..10 and that `extra` is a side (0 or 1) or a valid flotsam index, and refuses anything else. New kinds DEBRIS and FLOTSAM are appended to the enum, so existing ints keep their meaning.
- **State.** `receive_state` gains the position, the paddle velocity, the open leaks (spot and opening time), the flotsam taken (beat index → peer) and the passes shooed. A small unreliable `receive_steer(position, velocity, time)` goes at up to 10 Hz while the velocity is non-zero. Clients extrapolate the position by velocity between messages.
- **Clock.** Clients also advance `elapsed_s` locally between resyncs. Today it moves only on receipt, every 1 s, which would make hazards stutter.
- **Snapshot.** `CrossingSnapshot.KEYS` gains "steer", "leaks", "taken" and "shooed". A snapshot without them is refused, as for "boards".
- **Result.** Unchanged.

### D11. HUD and lines
A `CrossingHud` CanvasLayer child of the crossing, created on every peer, draws the progress strip, the integrity (for example "Balsa 70/100") and the lines. A `CrossingHazards` Node2D at z −30, between the sea at −40 and the deck at −20, draws rocks, debris, flotsam and leak spurts. Both only read the crossing, like `CrossingDeck`.

Prompt verbs (Remar, Tapar, Agarrar, Espantar) go in `hud_text.tres` by prompt id, as every Interactable's do. The warning lines are drafts in a new `game/resources/crossing_text.tres`, at the resources root so the validator does not take it for a content folder, and they wait for the owner's voice pass:
- "La raya negra viene pa'cá."
- "¡Amárrate, que ahí viene!"
- "¡Aleta! Por la izquierda." and "¡Aleta! Por la derecha."
- "¡Un hueco! Tápalo."

### D12. Swimmers' route
Same plan rules, position fixed at 0. Rocks and debris cut swimmers (−15 and bleeding, −5), which makes a cut swimmer a shark's preferred prey. Flotsam is taken by touch. The reef line is a gap to swim through. Shooing needs a rider aboard, so a lone swimmer's counters are swimming clear and keeping energy above 20.

### D13. One button, several jobs
A rider at a deck edge can be within 1 tile of a paddle point, a fin, a passing piece, a leak and the lashing. `InteractionPicker.pick` takes the highest `priority`, then the nearest. The crossing sets these priorities:

| Point | Priority |
| --- | --- |
| SHOO | 4 |
| PULL | 3, raised from 0 |
| GRAB | 2 |
| PLUG | 1 |
| PADDLE, LASH, CLIMB | 0 |
| A perched creature's shoo | −1, unchanged |

The most urgent and shortest-lived job wins: a fin strikes in 5 s, a swimmer may drown, flotsam passes in about 1 s, and a leak waits. Paddling is the default. The order keeps creatures-ai "Perched creature never hides the rescue points". The crossing reef shark's own creature interactable (brain priority 1) is disabled while the SHOO point exists.

*Alternatives:*
- Separate buttons. Rejected: there is no free gamepad face button, and the HUD prompt names what E will do.
- Nearest only. Rejected: a paddle at the edge would always steal the shoo.

## Specs touched without a delta

- **inventory-hud "Prompt text".** Prompts are data by prompt id, so new ids (`paddle`, `plug`, `grab`, `shoo`) are appended to `hud_text.tres` with no rule change.
- **art-pass "Crossing look".** It says the sea lies under everything and the deck above the sea and under the riders. Hazards and flotsam drawn between them (z −30) keep both rules.
- **ui-shell "HUD layout".** It puts the day phase top-centre with the sign note under it. The crossing strip takes the sign note's place, since no sign opens at sea, and crossing "Crossing HUD and telegraphs" states that placement. If the owner wants ui-shell to own it, a one-line delta is added at archive. The damage-feedback session may edit "HUD layout" too, so the coordinator is asked to relay.
- **creatures-ai "Perched creature never hides the rescue points".** It still holds (D13).

## Reference games

**Shattered Pixel Dungeon**
- *Borrowed:* `levels/Level.java` `create()` rolls a level "feeling" (water, grass, dark and others, 50 % of levels). One cheap rolled twist on a standard layout is how our director varies crossings: weights and lanes per slot, with the reef line as the fixed climax.
- *Borrowed for the follow-up `crossing-encounters`:* `levels/rooms/special/SpecialRoom.java` `initForRun()` / `useType()` keeps a run-wide shuffled list of special rooms and moves a used one to the back, so the same encounter does not come twice in a row.
- *Rejected:* SPD's level-sized challenge length. Our crossing is a 60–120 s gauntlet, not a floor.

**Brogue CE**
- *Read, and rejected for now:* `Time.c` `applyGradualTileEffectsToCreature()`: a player in deep water has a 50 % chance per turn of an unequipped pack item floating away ("floats away in the current"), and `updateEnvironment()` moves items lying on water. It would punish falling in harder, but it fights our 3 s climb-back and the items-refused rule, so it waits for a later look at falling in.
- *Borrowed:* the drifting-items idea, turned around, as flotsam that drifts past.

**DCSS**
- *Borrowed:* `dat/dlua/lm_tmsg.lua` `TimedMessaging` and `time_messages()` give a timed portal warnings at shrinking intervals, worded by how near the player is. Our squall line at 60 s, plus lines at 30 s and 10 s, follows that.
- *Borrowed:* `dat/dlua/lm_timed.lua` `TimedMarker:new()` and `start_short()` give a timed portal a random duration that drops to a much shorter one once the player has seen it. A seen opportunity must be taken now, which is how flotsam works: it shows 5 s out and is gone once it passes. The crossing's own clock stays fixed, as our spec already has it.

**Don't Starve Together** (`docs/REFERENCE_DST.md` "crossing and escape-routes"; wiki pages named):
- **Leak, Boat Patch.** *Borrowed:* a hit that keeps draining until a rider plugs it, as the solo rider's job, with the hold well under any warning. *Rejected for now:* patch items, because of D11.
- **Kelp Patch.** *Rejected for now:* a temporary plug.
- **Oar.** *Borrowed:* rowing in the direction you choose, slower than any sail. *Rejected:* cooldown penalties. A hold is simpler for 1–4 players on one deck.
- **Mast.** *Rejected:* mast stacking and the timed furl. The furl belongs to the cutter's searchlight later.
- **Steering Wheel.** *Rejected:* a manned wheel that pins a rider (D2). Navigation and Maestro stay passive drift cancels.
- **Anchor.** *Rejected:* nothing on a fixed-length crossing needs to hold a position.
- **Sea Stack.** *Borrowed:* obstacles the sea brings in, steered around, as our rocks and the reef line. *Later:* a tire-bumper upgrade.
- **Waves.** *Borrowed:* "push, not damage" for any later swell. The **Rogue_Wave** page returned 404, so a rogue wave is unverified and not used.
- **Boat Fragment.** *Borrowed:* sea debris you break for a board, as the plank lashed on. The **Flotsam** page describes the base game and Reign of Giants, not DST, so only the idea of wreck flotsam you snag is taken, with no numbers.
- **Sea Fishing Rod, Ocean Fishes.** *Deferred:* fishing to `crossing-fishing` (Q6).
- **Malbatross.** *Rejected:* a damage race does not fit 60–120 s.
- **Pirate Raid.** *Rejected:* boarding fights.
- **Falling overboard ("Drowning").** *Kept:* ours stays deadly, with no teleport to shore.
- **Crew roles on one boat** (Boat, Floating Platform). *Borrowed:* jobs live at places on the deck (paddles at the edges, leaks on tiles, the lashing in the middle), so roles come from where you stand and nothing is assigned. One rider walks between them.
- **Biggest lessons.** "Warn before you hurt" and "threats commit, then quit" are the frame for D1 and D6. "Every co-op rule has a solo path; solo gets the base amount" is D8's rider factor.

**What our own docs promise**
- GAME_DESIGN §8: sharks follow blood, the squall forces a tie-down, the searchlight comes later, and the Gulf Stream applies on mid and far crossings.
- BESTIARY: the reef shark circles for 6–10 s and a coral cut makes a swimmer bleed. Waterspout ("steer perpendicular"), sargassum ("pole through"), jellyfish ("steer around") and the remora are later hazards that reuse D2 and D4 as data.
- LORE: bailing, paddling, sun and thirst.
- ISLANDS: "The bale", 5 % of crossings, and "The floating cooler" are candidates for `crossing-encounters`.

## Owner decisions (open; the specs follow the recommended option)

1. **Scope of this change.**
   a. *Recommended:* the core slice. Paddling, rocks, debris and leaks, the shark's telegraph and shoo, flotsam, the squall's blow, the pacing director and the crossing HUD, built in three PRs: (1) director, paddling and rocks; (2) leaks and flotsam; (3) shark, HUD and lines. Encounters, fishing and items at sea are follow-ups.
   b. A smaller first change: paddling, rocks, the director and the HUD only. Leaks, flotsam and the shark go in a second change.
   c. Everything at once, including an encounter deck of three (dolphins, a turtle in a net, another raft).
2. **How paddling feels.**
   a. *Recommended:* hold interact at a paddle point on the side you want to go toward. The current pulls the raft back to the line when nobody paddles.
   b. The same, but the raft stays where you leave it, with no pull-back. Idle no longer equals today, and flotsam is easier to reach.
   c. A helm spot at the stern, steered with the movement keys. It pins one rider.
3. **Leaks.**
   a. *Recommended:* debris opens a leak that drains 0.5 integrity/s until someone holds interact on it for 2 s.
   b. Water aboard: leaks and rain fill a gauge drawn on the raft, riders bail it at a bail spot, and above half it drains integrity and slows paddling.
   c. No leaks: debris is just −5.
4. **The shark's counter.**
   a. *Recommended:* the fin circles one side for 5 s, and a 1 s hold on it shoos it off. A tired swimmer can climb aboard in those 5 s.
   b. A telegraph only, with no shoo: the fin warns, and only climbing aboard helps.
   c. Shooing needs a held item (a spear or oar). That needs Q5(b).
5. **Items at sea** (inventory-hud D11, refused since 2026-11-08).
   a. *Recommended:* keep refusing. Flotsam goes to the inventory for the next island, and planks repair on the grab.
   b. Allow eating, drinking and bandaging aboard, but not crafting or placing. This adds an inventory-hud delta, and a grabbed coconut can be drunk at midday.
6. **Follow-ups to queue.**
   a. *Recommended:* `crossing-encounters` next (dolphins, a turtle in a net, another raft in trouble, from a run deck), then `crossing-fishing`.
   b. Fishing first.
   c. Neither for now; playtest the core first.
7. **Pacing density.**
   a. *Recommended:* a beat every 6–9 s solo (mean about 7.5 s), 10 % denser per extra rider, the reef line last.
   b. Calmer: every 8–12 s, with no co-op scaling.
   c. Busier: every 5–7 s.
8. **Difficulty target** (75 s solo coast raft).
   a. *Recommended:* idle arrives with about 20–40 integrity and attentive with 70 or more.
   b. Gentler: idle about today's 75, and attention earns loot only.
   c. Harsher: idle usually breaks the raft.
9. **Rocks cut swimmers, the binoculars route included** (a default baked into the specs).
   a. *Recommended:* yes, −15 and bleeding, dodged by swimming.
   b. No: hazards ignore swimmers.
10. **The reef line ends every crossing.**
   a. *Recommended:* yes. Idle passes it 5 times in 7.
   b. Only on half of crossings.
   c. No reef line.
11. **How much flotsam.** At 75 s solo there are about 6 pieces, about 1 of them a plank, against islands whose counts the owner fixed.
   a. *Recommended:* about 6, most of them off the line.
   b. About 3, with the flotsam weight halved.
   c. Planks only, so nothing goes into the inventory.
12. **A pulled swimmer outranks other jobs** (D13).
   a. *Recommended:* yes, only shooing the fin ranks above pulling.
   b. Keep PULL at the paddles' rank, so the nearest wins.

## Risks / Trade-offs

- [Holding E to paddle is tiring] → The hold is short: a dodge is 2–3 s. If playtests say otherwise, Q2(c) or a toggle stays open.
- [A client's flotsam grab misses because of latency] → The host uses reach plus the usual slack. Pieces stay grabbable about 1 s, and the hold is 0.3 s.
- [Hazards stutter on clients] → Clients advance elapsed time locally and extrapolate the position (D10). The 1 s resync corrects any drift.
- [Too punishing for a first run] → The idle target keeps a raft that does nothing alive 20–40 integrity on average. The weights live in `crossing_tuning.tres`, and a stats test watches them.
- [Existing crossing tests] → The old-form rule, the pull-back and idle riders keep every outcome check. Some tests still change:
  - `test_crossing_plan.gd`, because rolled plans change;
  - the four tests that build snapshot dicts by hand, for the new required keys;
  - shark tests that check when the shark appears, because the fin comes 5 s early.

  Raising PULL's priority (D13) could change a pick in a test whose rider stands near both a swimmer and the lashing, so `test_crossing_rescue.gd` is rerun in group 2.
- [damage-feedback edits the HUD at the same time] → This change adds its own `CrossingHud` node and edits only `hud_text.tres` among shared HUD data, by appending prompt ids. The seam is noted in the shared notes.
- [Deck crowding with 4 riders on 4×2 tiles] → The picker takes the nearest enabled point. Paddles, leaks and the lashing sit on different tiles.

## Migration Plan

The plan form is backward compatible (D10). The snapshot gains required keys, and peers of different builds are not supported, as before. Rollback means reverting the PRs. Tuning is data only.

## Open Questions

- The final Spanish lines and prompt verbs wait for the owner's voice pass (drafts in D11).
- The placeholder art for rocks, debris, flotsam, fins and leaks is kitbashed from tracked packs. A proper pass belongs with the art review.
- The tuning weights are provisional until the Milestone B playtest.
