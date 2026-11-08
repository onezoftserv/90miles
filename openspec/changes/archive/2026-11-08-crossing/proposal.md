# Proposal

## Why

escape-routes ends the run the moment a route starts (`CrossingStub`). Milestone B needs the real crossing: the 60-120 s scrolling-sea scene where the run's tension peaks (`docs/GAME_DESIGN.md` §8).

## What Changes

- A `Crossing` scene, entered on every peer by a started route's riders: a vertically scrolling sea, the vessel (the launched raft, or the swimmers themselves) and an ordered plan of events rolled once on the host from the route's risk profile, the distance band and the weather. Every number is data (`crossing_tuning.tres`).
- Raft integrity on the crossing: starts at the launched raft's value (100), squall -30 (times the route's squall factor), shark -20, rock -40. At 0 the raft breaks and everyone falls in.
- The squall reuses weather-daynight's 60 s warning and `HorizonLine`. Riders tie down (hold 1 s on the lashing) or are thrown in; no chance roll.
- Falling in costs 10 energy. In the water every second costs 3 energy times the route's swim drain factor; at 0 energy a swimmer floats and drowns at 10 health a second. A teammate pulls a swimmer aboard (hold 2 s); a lone player climbs aboard alone (hold 3 s within 1 tile of an intact raft's edge).
- The shark pass and the rock sit behind a replaceable `CrossingThreats` hook, which creatures-ai will swap for a reef shark.
- The crossing ends after its length with a `CrossingResult` (integrity, broken, drift 0, each rider's state) and an `ArrivalStub` that takes the riders out of play, replacing `CrossingStub`. The run ends as before once every player has left or died.
- `PlayerBody` gains `pinned` (a tied rider cannot move) and `swim_energy_factor` (0 in the crossing, which pays its own pace drain). `Interactable.usable_by` lets the picker skip a point that belongs to someone else.
- Data: raft `duration_s` 60-90 s; binoculars-and-swim `duration_s` 60-60 s and `swim_drain_multiplier` 0.4.
- **Out:** searchlights and the cutter, the tiger shark, the lighthouse beam, the Miami fisherman, car and board vessels, arrival on the next island, steering and the Gulf Stream (coast drift is recorded as 0), item loss in water, the run summary screen, the reef shark creature.

Capabilities: `crossing` (ADDED requirements only) and `escape-routes` (MODIFIED "Leaving before the crossing exists").

## Solo

One offline player launches the raft, crosses alone, ties down, is thrown in, climbs back in 3 s and finishes, or swims the whole 60 s and ends at energy 28 (`test_crossing_solo.gd`, `test_crossing_rescue.gd`). Nothing needs a teammate: pulling is the co-op shortcut, climbing is the solo way.

## Ordering

`escape-routes` is archived, so its "Leaving before the crossing exists" block is MODIFIED here from `openspec/specs/escape-routes/spec.md`. balsero-lore's crossing MODIFIED requirements (Crossing scene, Vessel integrity, Arrival) are not touched.

## Confirmed by the owner (2026-11-06)

- A squall throws **every** rider who is not tied down into the water; there is no chance roll. Tying down is a 1 s hold during the warning.
- Swimmers lose energy every second they are in the water; at 0 energy they drown at -10 health/s; the binoculars swim route drains at 0.4x (a solo swimmer at 100 ends a 60 s crossing with 28).
- Falling in costs 10 energy; a raft crossing lasts 60-90 s and the swim 60 s; the coast shark-pass chance is 0.5 and the rock chance 0.25; steering is not built and coast drift is 0.

## Provisional (the plan's other choices)

The owner confirmed these too, as they stand, on 2026-11-08.

- The squall's own roll on a crossing long enough for its warning (60 s plus a 10 s margin), and a running squall hitting 10 s into the crossing.
- Events never fall in the first or last 10 s; at most one shark pass and one rock per coast crossing.
- Hold times other than the rescue ones (tie-down 1 s is the owner's; pull 2 s and climb 3 s come from the spec); reach 1 tile.
- Scroll speed 2 tiles/s times the route's speed factor (visual only), the sea size (24x22 tiles) and deck size (4x2 tiles), the sea's place far from the island (y = -4096 px) and one crossing per departure, side by side.
- Deck cells are `BEACH` terrain (no new terrain value); a swimmer standing on the deck is moved to the nearest edge; riders are kept inside the sea.
- Drowning lives in the crossing, not in player-movement; a life vest and the movement rule's ownership are follow-ups.
- The events class is named `CrossingBeat` because `ChainData` already has a `CrossingEvent` enum.
- The sea is drawn in code (scrolling lines), not with the `sea.gdshader`; the vessel is drawn by the crossing, not a separate scene.
- Starting integrity is read from the launched `Raft` before the sandbar frees it, with the route's `vessel_integrity` as the fallback.
