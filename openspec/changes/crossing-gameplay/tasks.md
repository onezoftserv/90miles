# Tasks

These tasks follow the recommended answer to every question in design.md "Owner decisions". If the owner picks otherwise, update them before the build starts.

**Three PRs:**
- groups 1–4: plan, paddling, hazards, director;
- groups 5–6: leaks, flotsam;
- groups 7–9: shark, HUD, integration.

**Every group ends with all of these clean:**
- the import (`godot --headless --path game --import`, twice on a fresh checkout);
- the smoke run (`-s res://tests/smoke.gd`);
- GUT (`-s res://addons/gut/gut_cmdln.gd -gexit`);
- a 300-frame windowed run (`--quit-after 300`) with no `ERROR:` line.

**Test rules:**
- Each group adds at least one test with exactly 1 player, offline.
- Each group that sends state adds a host-plus-client test (`NetHarness`).
- Hand-written plans use `CrossingRig`.

## 1. Plan form and tuning

- [ ] 1.1 Write the tests first, in `test_crossing_plan.gd` and a new `test_crossing_beat_lanes.gd`:
  - `[time, kind]` and `[time, kind, lane, extra]` round-trip;
  - `from_array` refuses a lane outside −10..10, a side other than 0 or 1, a flotsam index outside the table, and an unknown kind;
  - an old-form rock rides lane 0 and a shark pass with no side comes from the west.

  See them fail.
- [ ] 1.2 Append `DEBRIS` and `FLOTSAM` to `CrossingBeat.Kind`. Add `lane: int` and `extra: int` with defaults 0, and make `to_array` and `from_array` emit and accept the two forms. Verify that the new tests and every existing crossing test pass unchanged.
- [ ] 1.3 Add the new numbers to `CrossingTuning` and `crossing_tuning.tres`, with no script defaults (as now):
  - lead times: hazard 5 s, shark 5 s;
  - paddling: speed 1.5 and 2.25 tiles/s, pull-back 0.5, limit 6;
  - widths: rock 2, debris 1, vessel 4;
  - hits and repairs: debris hit 5, leak drain 0.5, plug hold 2, max leaks 3, plank 10;
  - holds and reach: grab hold 0.3, shoo hold 1, reach 1;
  - cuts: rock 15 with bleeding, debris 5;
  - squall blow: 15 s, paddle factor 0.5;
  - interaction priorities: shoo 4, pull 3, grab 2, plug 1, paddle, lash and climb 0 (perched creature stays −1);
  - pacing: start 6–9, target gap 7.5, max 9, min 3, rider factor 0.9, reef offset 4, reef half-gap 5;
  - weights by band (coast: rock 0.12, debris 0.20, flotsam 0.68) and the flotsam table (design.md D7).

  Verify that a GUT test loads the `.tres` and reads every field, and that the content validator passes over `res://resources/`.

## 2. Paddling (crossing "Paddling", "Jobs aboard", "Coast drift", "Steering and current")

- [ ] 2.1 Write `test_crossing_paddle.gd` first:
  - solo 2 s east then 2 s released (3, then 2);
  - two paddlers on one side (4.5);
  - paddles on both sides (0);
  - the limit (6);
  - a tied rider and a swimmer cannot paddle;
  - in the squall's blow (1.5 for 2 s);
  - the result's drift stays 0.

  See it fail.
- [ ] 2.2 Add `crossing_steer.gd` (host position and velocity from active paddlers, pull-back, limit, blow factor) and `RescuePoint` kind PADDLE (hold 0; `use` starts paddling for that rider and `release` stops it), one on each deck edge and on each side of each board, enabled for riders aboard and untied. Prompt id `paddle` ("Remar") is appended to `hud_text.tres`. Set the PULL point's priority to 3 (crossing "Which job a press takes"). Verify that `test_crossing_paddle.gd`, `test_crossing_prompt.gd`, `test_crossing_rescue.gd`, the perched-gull tests and the board tests pass, plus a new solo test where a press at the west edge with the paddle and the lashing both in reach ties down at the centre and paddles at the edge.
- [ ] 2.3 Sync the position: add it to `receive_state`, add an unreliable `receive_steer` at up to 10 Hz while the velocity is non-zero, have clients extrapolate the position and advance `elapsed_s` locally between resyncs, and add a required snapshot key "steer". Update the hand-built snapshot dicts in `test_crossing_snapshot.gd`, `test_crossing_join.gd`, `test_crossing_board_state.gd` and `test_game_shell.gd` for the new key. Verify these in `test_crossing_paddle_net.gd`:
  - a client paddles and the host moves the raft;
  - both peers show 3 tiles east;
  - a joiner mid-paddle shows the host's position;
  - a snapshot without "steer" is refused;
  - solo offline sends nothing.

## 3. Scrolling hazards (crossing "Scrolling hazards", "Hazards and swimmers", "Board hits")

- [ ] 3.1 Write `test_crossing_hazards.gd` first:
  - solo idle takes a rock in line (60);
  - solo dodges by paddling 27–30 s (100);
  - a rock in lane 4 passes (100);
  - debris in lane 1 (95);
  - a solo swimmer is cut by a rock (85 and bleeding) or swims clear;
  - a rock beside the row of boards misses;
  - a rock on the row goes round the boards as in "Hits go round the boards".

  See it fail.
- [ ] 3.2 Resolve ROCK and DEBRIS by overlap at the beat's time in `CreatureThreats` and `ScriptedThreats`, through `hit_vessel`. Test swimmers every tick against the hazard's moving rect, once each. Verify that `test_crossing_hazards.gd` and every existing rock scenario pass (`test_crossing_squall.gd`, `test_crossing_board.gd`, `test_crossing_car.gd`).
- [ ] 3.3 Add `CrossingHazards` (Node2D, z −30) to `crossing.tscn`. It draws rocks and debris from the plan, the elapsed time and the position, with placeholder sprites kitbashed from tracked packs, and credits are updated if a new source file is copied. Verify that a GUT art test sees a lane-2 rock at the north edge at time − 5 s on the host and on a client, and that `test_crossing_art.gd` passes.
- [ ] 3.4 Update GAME_DESIGN.md §8 for debris and the swimmer's cuts, and BESTIARY.md "Reef shark" for coral cuts at sea. Verify that the doc lines match the spec numbers.

## 4. The director (crossing "Threat plan", "Crossing pacing")

- [ ] 4.1 Write `test_crossing_pacing.gd` first. Over 2,000 seeds each for 1 and 4 riders:
  - the first beat falls between 6 and 9 s;
  - the reef line is at L − 4;
  - gaps are between 3 and 9·0.9^(n−1) s, except across a squall's blow;
  - the blow is empty of rolled beats, with a hazard in the 10 s before a hit at 16 s or later;
  - a carried squall at 4 s pushes the first rolled beat past 19 s;
  - the reef line stays at L − 4 inside a blow, and a solo rider tied for the squall still makes the gap at half speed;
  - the same seed gives the same plan.

  See it fail.
- [ ] 4.2 Rewrite `CrossingPlan.roll(route, band, sky, rng, tuning, riders)` as design.md D8. `GameShell._on_route_started` passes the rider count. Verify that `test_crossing_pacing.gd` passes and that `test_crossing_plan.gd`'s rolled-plan cases are updated to the new rule, and nothing else.
- [ ] 4.3 Add a statistics test, `test_crossing_balance.gd`, with an idle solo rider and a scripted attentive solo rider (it paddles out of each hazard's lane, plugs, shoos and ties down 2 s before the hit) over 500 rolled 75 s coast raft plans. Verify that the idle average left is 20–40 (the design's Monte Carlo predicts 33.5, with 27 % broken) and the attentive average is 70 or more. Tune only the `.tres` weights to get there, and record the measured numbers in design.md.
- [ ] 4.4 Update GAME_DESIGN.md §8 with the pacing budget and the reef line. Open the first PR (groups 1–4) after a solo windowed crossing from the sandbar runs clean through the Godot MCP.

## 5. Leaks (crossing "Leaks", "Raft integrity on the crossing")

- [ ] 5.1 Write `test_crossing_leaks.gd` first:
  - unplugged (90 at 30 s);
  - solo plugs 22–24 s (93);
  - letting go early does not plug;
  - a fourth hole opens nothing;
  - a leak breaks a raft at 3 in 6 s;
  - a board rider plugs their own board (54).

  See it fail.
- [ ] 5.2 Add `crossing_leaks.gd` (spots on the hit half, drain per tick, at most 3) and `RescuePoint` kind PLUG, with prompt id `plug` ("Tapar") appended to `hud_text.tres`. Draw leak spurts in `CrossingHazards`. Verify `test_crossing_leaks.gd`.
- [ ] 5.3 Sync leaks in `receive_state`, with a required snapshot key "leaks". Verify these in `test_crossing_leaks_net.gd`:
  - a client plugs and both peers show it plugged;
  - a joiner sees an open leak drain;
  - solo offline sends nothing.

## 6. Flotsam (crossing "Flotsam")

- [ ] 6.1 Write `test_crossing_flotsam.gd` first:
  - solo grabs a coconut in lane 3;
  - rope in lane 6 passes;
  - a plank brings 70 to 80, and 95 to 100;
  - a full inventory leaves driftwood in the sea;
  - a swimmer touches rope;
  - two riders reach for one coconut (host and client, the first completed hold wins).

  See it fail.
- [ ] 6.2 Add `RescuePoint` kind GRAB, which follows the piece on every peer, plus touch pickup for swimmers on the host, the host's inventory add, and the plank's repair through the vessel's integrity. The prompt id `grab` ("Agarrar") names the piece. Draw pieces in `CrossingHazards`. Verify `test_crossing_flotsam.gd`, and that `test_use_on_crossing.gd` still refuses item uses at sea.
- [ ] 6.3 Sync the taken pieces (beat index to peer) in `receive_state`, with a required snapshot key "taken". Verify that a joiner does not see a taken coconut, in `test_crossing_flotsam_net.gd`.
- [ ] 6.4 Update GAME_DESIGN.md §8 for leaks, planks and flotsam. Open the second PR (groups 5–6) after a solo windowed crossing runs clean.

## 7. Shark telegraph and shoo (crossing "Shark pass event", "Shooing the shark"; creatures-ai "Crossing reef shark", "Every peer sees the crossing shark")

- [ ] 7.1 Write `test_crossing_shoo.gd` first:
  - the fin is at the east edge at 25 s;
  - solo shoos 27–28 s (100);
  - too late at 29.5 s (80);
  - a tired solo swimmer climbs out 25–28 s (raft 80, nobody bitten);
  - a teammate saves a tired swimmer;
  - a shooed shark is gone by 28 s;
  - a shark pass at 3 s spawns with a 3 s lead.

  See it fail.
- [ ] 7.2 Add `CrossingThreats.warn(beat, crossing)` (no-op base), called by the crossing at the beat's time − lead. `CreatureThreats.warn` spawns the reef shark 1 tile off the named side (beside the board next in turn on a board route) and keeps it there until the strike. Add `RescuePoint` kind SHOO, which follows the fin, with prompt id `shoo` ("Espantar"). At the strike the shark moves beside its victim or the hit deck, so `test_crossing_creature_shark.gd`'s "beside the bitten swimmer" check still holds; update any check on the shark's spawn time to the warning. Verify that `test_crossing_shoo.gd`, `test_crossing_creature_shark.gd`, `test_crossing_shark.gd`, `test_crossing_shark_dump.gd` and `test_crossing_shark_net.gd` pass, plus a solo test where a press with the fin and a leak both in reach shoos first.
- [ ] 7.3 Sync the shooed passes, with a required snapshot key "shooed". A joiner past a warning spawns nothing new: the host's shark is already in the entity spawner. Verify these in `test_crossing_shoo_net.gd`:
  - a client shoos and the shark leaves both screens;
  - a joiner during the circle sees the fin;
  - solo offline sends nothing.
- [ ] 7.4 Update BESTIARY.md "Reef shark" with the crossing tell and the shoo. Verify that the doc lines match the spec.

## 8. Crossing HUD and lines (crossing "Crossing HUD and telegraphs")

- [ ] 8.1 Write `test_crossing_hud.gd` first:
  - solo at 30 s of a 60 s crossing: the strip is half and "70/100";
  - the squall lines at 40 s and 60 s for a hit at 70 s;
  - the fin line names the side;
  - the leak line;
  - a client draws from the received state.

  See it fail.
- [ ] 8.2 Add `CrossingHud` (a CanvasLayer child of the crossing, on every peer) and `game/resources/crossing_text.tres` with the draft lines (design.md D11), both Spanish and English. The HUD reads the crossing only and edits no file of damage-feedback's. Verify `test_crossing_hud.gd`, and that `test_input_map_hud.gd` and `test_meters_hud.gd` pass.

## 9. Integration

- [ ] 9.1 Add the manual run `game/tests/manual/crossing_gameplay_run.gd`: a host and a client as two processes on UDP 7794, riding a raft through a hand-written plan with every beat kind. The client paddles, plugs, grabs and shoos, and a third process joins at 40 s. Run it twice. Verify that it exits 0 both times with no `ERROR:` line, and that the joiner's position, leaks, taken pieces and shark match the host's.
- [ ] 9.2 Play one solo sandbar-to-coast-cay raft crossing windowed through the Godot MCP and log the second-by-second timeline as the baseline did. Verify that no gap without a decision exceeds 9 s outside the squall's blow and that the run reads clean. Add the timeline to design.md beside the baseline.
- [ ] 9.3 Tick this change in `TASKS.md` and add the follow-ups below it: `crossing-encounters`, `crossing-fishing` and items at sea, if the owner chose to keep them. Verify that `openspec validate crossing-gameplay --strict` passes.

## Workflow follow-up

- Archive with `/opsx:archive` after the owner reviews the build and every PR is merged.
- Write the sibling notes file's final "files touched" list for the sessions that rebase after this change.
