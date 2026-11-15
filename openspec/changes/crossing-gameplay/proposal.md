# Proposal

## Why

The owner played the game on 2026-11-14 and said the part on the raft is boring. Measurements on `main` at cb7834f bear this out (design.md "Baseline"):

- **No events at all in about a third of crossings.** Across 10,000 rolled coast raft plans, a crossing lasts 75 s on average and 31.9 % of plans hold no event.
- **At most one meaningful choice.** The rock (−40) and the shark pass (−20) land in a single 0.1 s tick with no telegraph and no counter. The only choice is tying down for a squall, which 16 % of plans hold, and it costs nothing. That leaves 84 % of crossings with no decision at all.
- **Little to do and nothing on screen.** Items are refused at sea, coast crossings have no steering, and no crossing HUD shows progress or the raft's integrity.

The outcome is rolled, not played. The run's tension is meant to peak on the crossing (GAME_DESIGN §8, §18), so the crossing needs things the riders do.

## What Changes

Every beat of the crossing gets three parts: a **telegraph** with a lead time, a **counter window**, and a **resolve**. The host still rolls the plan once, the plan stays seed-stable, and every new state reaches clients and late joiners.

- **Paddling.** The deck gets two paddle points, one on the west edge and one on the east edge. A rider holding interact on one slides the vessel toward that side, in tiles relative to the line it sails. When nobody paddles, the current pulls it back to the line. This lateral position is how riders dodge; it is not the Gulf Stream's drift, and coast drift stays 0.
- **Hazards that scroll in.**
  - Rocks (−40) and debris (−10, which also opens a leak) come down a lane from the sea's north edge, 5 s before they reach the deck.
  - They hit only when their lane overlaps the vessel. A raft that does nothing sits on the line, so a rock in line hits it as today.
  - A swimmer in a hazard's lane is cut: −15 health and bleeding.
- **Leaks.** A leak drains integrity until a rider holds interact on it for 2 s.
- **The shark is telegraphed.** Its fin circles one side of the vessel for 5 s before it strikes. A rider aboard who holds interact on it for 1 s makes it leave without biting. A tired or bleeding swimmer can climb aboard during those 5 s.
- **Flotsam.** Coconuts, driftwood, rope and planks drift by in lanes, often beside a hazard. A rider grabs one at the deck edge as it passes, or a swimmer grabs it by touching it. A plank is lashed on at once (+10 integrity); everything else goes into the grabber's inventory.
- **A squall that costs something.**
  - The 60 s warning and the tie-down stay.
  - After the hit, 15 s of rain halve paddling, and no new beat arrives during them.
  - The plan puts a hazard in the 10 s before the hit, so tying down early costs a dodge.
- **A pacing budget.**
  - The plan places a beat every 6–9 s solo, a little denser for each extra rider, between a 6 s calm start and the arrival.
  - Arrival is a reef line with one gap to steer through.
  - No more than 9 s pass without something to decide, except during the squall's rain.
- **A crossing HUD**, drawn client-side: a progress strip from island to island, the vessel's integrity, and short Cuban-Spanish warning lines (squall countdown, fin, leak).
- **Every route.**
  - The car plays like the raft.
  - Boards move as one row, and each hit still goes round-robin through the boards (owner, vessel-car-board Q2).
  - Swimmers dodge by swimming.
- **Hand-written plans in the old form behave exactly as today when riders do nothing.** A `[time, kind]` beat means lane 0, so the existing crossing tests and scenarios stay valid.

Not in this change, each a named follow-up:
- `crossing-encounters`: a run deck of mid-crossing encounters, such as dolphins, a turtle in a net and another raft in trouble.
- `crossing-fishing`: a fishing line for the Pescador.
- Gulf Stream heading and drift on mid and far crossings.
- Water aboard and bailing, if the owner picks it (Q3).
- Items at sea (Q5).

## Solo

Every job (paddle, plug, grab, shoo, tie down, climb back) is one rider's verb, so one rider does all of them in turn. The plan's base density is the solo one. Each extra rider makes the plan about 10 % denser, so co-op splits the jobs instead of having to handle more threats. Every requirement has a 1-player scenario. The tests include a scripted solo rider who dodges, plugs and shoos through rolled plans, and an idle solo rider who shows that doing nothing costs integrity.

## Owner decisions

These are open and listed in design.md "Open questions", with the recommended option first. The specs below follow the recommended options and change if the owner picks otherwise.

## Capabilities

### New Capabilities

None. Everything here belongs to the existing crossing and creatures-ai capabilities.

### Modified Capabilities

- `crossing`:
  - Requirements rewritten: Threat plan (a paced plan with lanes), Raft integrity on the crossing (hits only on overlap; debris and leaks), Shark pass event (telegraph and shoo), Squall line on the crossing (the rain window), Steering and current and Coast drift (paddling is not drift), Board hits (overlap with the row of boards, round-robin kept) and Joining during a crossing (the new state).
  - Requirements added: Paddling, Scrolling hazards, Leaks, Flotsam, Crossing pacing, Crossing HUD and telegraphs, and Crossing play state on every peer.
- `creatures-ai`: Crossing reef shark (it appears at the warning, circles the side it will strike, and is shooed off before the strike) and Every peer sees the crossing shark (a shooed shark leaves every screen).

## Impact

- **Code:**
  - `game/scripts/crossing/`: `crossing_plan.gd` becomes the paced roll; `crossing_beat.gd` gains lane and side; `crossing_tuning.gd` and `.tres` gain the new numbers; `creature_threats.gd` and `scripted_threats.gd` take the telegraphed shark; `crossing_snapshot.gd` and `crossing_result.gd` change.
  - New in the same folder: `crossing_steer.gd` (paddling) and `crossing_leaks.gd`.
  - `game/scenes/crossing/`: `crossing.gd` changes, plus new drawing and HUD nodes; `rescue_point.gd` gains the PADDLE, PLUG, GRAB and SHOO kinds.
- **Data:** new tuning fields only, at the root of `game/resources/`. The flotsam table is part of the crossing tuning. No new content folder, no new autoload.
- **Tests:** about 20 crossing test files keep passing unchanged because of the old-form rule. New 1-player, host-plus-client and late-join tests, plus a plan-statistics test for the pacing budget.
- **Docs:** GAME_DESIGN.md §8 (the crossing) and BESTIARY.md (the reef shark's crossing tell).
- **Sibling seams:**
  - damage-feedback owns the HUD hurt cues. This change adds its own crossing HUD node and touches no file damage-feedback edits.
  - guardacostas-stealth adds no hiding at sea, and the searchlight beat stays with the cutter boss.
