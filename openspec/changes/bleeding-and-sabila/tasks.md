# Tasks

Every group is test-first: write its tests, watch them fail for the right reason, then build until they pass. Every group ends with these commands passing (on a fresh checkout, run the import twice):

- `godot --headless --path game --import`
- `godot --headless --path game -s res://tests/smoke.gd`
- `godot --headless --path game -s res://addons/gut/gut_cmdln.gd -gexit`

A group may run only its own scripts with `-gdir=res://tests/unit -gselect=<name>`. The full suite runs in 5.1 and 5.3.

## 0. Decisions and base

- [x] 0.1 Record the owner's answers to Q1–Q4 in design.md. "Owner decisions (asked 2026-11-15, pending)" becomes "Owner decisions", with the date. Adjust the specs, D1–D6 and these tasks to any answer other than the recommended one. Verify that `openspec validate bleeding-and-sabila --strict` passes. Done: A on all four (2026-11-15), so no spec changed.
- [x] 0.2 Base the branch on `origin/main` with PR #65 (`damage-feedback`) in it. If #65 has not merged, stack on `claude/damage-feedback-1cc261` and say so in the PR. Then:
  - re-read `use_outcome.gd`, `item_user.gd`, `effect_applier.gd`, `survival_meters.gd`, `use_plan.gd` and `aloe.tres` as merged, and note any drift in design.md;
  - verify the three commands pass on the untouched branch.

  Done: #65 merged into main at 3b5f9b1 and the branch is rebased on it; no drift in `survival_meters.gd` or `use_plan.gd`. The second import printed 0 error lines.

## 1. Bleeding drains and ends on its own (survival-meters)

- [x] 1.1 Write `game/tests/unit/test_bleeding.gd`, plain `SurvivalMeters` with the real tuning, failing first. It covers:
  - 30 s of bleeding at 100 takes 3;
  - at 2 health, 60 s leaves 1 and no last stand, death or cause;
  - 120 s ends it, and health is 88 and stays there;
  - a second `set_status(BLEEDING, true)` at 100 s still bleeds at +119 s and has stopped at +121 s, with one drain, not two;
  - `set_status(BLEEDING, false)` stops the drain and the count;
  - a downed meter at 0 takes nothing;
  - a revive at 30 keeps bleeding and keeps its time left;
  - `statuses_changed` fires once when the time runs out;
  - other statuses (POISON set by hand) have no timer and no drain.
- [x] 1.2 Add the `Statuses` group to `survival_tuning.gd` (`bleeding_health_per_s`, `bleeding_s`, `bleeding_floor`, with no defaults) and the values 0.1, 120 and 1 to `survival_tuning.tres`. Verify that `test_survival_tuning` (or the tuning load test) still passes.
- [x] 1.3 Add the host-only time left and the drain to `SurvivalMeters` (design D1, D3). Verify that `test_bleeding.gd` passes:
  - `set_status` starts, restarts or clears the count;
  - `tick` drains, then counts down, and ends the status at 0;
  - the drain does not touch `_last_harm`.
- [x] 1.4 Write the 1-player wiring test `test_bleeding_solo.gd`, through a real body in a 1-player `CoopSession`:
  - a reef shark's strike (`CreatureWorld.strike`) is 75 at once and 74 after 10 s more;
  - the "Sangrando" tag hides when the bleeding ends at 120 s;
  - an arrival rider waiting out of play for 60 s keeps the time left it had.

  Done, plus a case in `test_escape_routes_solo`: binoculars-and-swim starts once the bleeding has ended. Both fail against the old `survival_meters.gd`.
- [x] 1.5 Give the shark tests that read health a little after a strike a tolerance for the drain since (design D7): `test_patrol_circle_strike`, `test_crossing_shark` and `test_crossing_creature_shark`. Verify that those scripts pass and that each one still fails when the strike is removed. Done: no change needed. Their rigs never tick the player's meters (design D7), and all four scripts, `test_death_cause` included, pass unchanged.
- [x] 1.6 Update the docs. Verify each by reading it back.
  - `docs/GAME_DESIGN.md` §4: in the Health row, "Drains from" gains "bleeding (0.1/s for 120 s after the latest wound, never the last point)", and "Restored by" names sábila's 5.
  - `docs/BESTIARY.md`: the reef shark section defines "bleeding" once, with a pointer to §4.
  - `TASKS.md`: the `item-effects-runtime` line says data-model-questions 22 is answered for bleeding by this change; the "bleeding cause" line (70) says bleeding never kills.

## 2. Sábila heals and goes to whoever needs it (crafting-inventory, inventory-hud)

- [x] 2.1 Write `test_sabila.gd`, failing first. It covers:
  - solo at 70 with sunburn and bleeding: both gone, 75, leaf gone (keep `test_coast_cay_solo`'s aloe test and add the health check there);
  - solo at 90 not bleeding: 95, leaf gone;
  - solo at full health not bleeding: refused with `NOTHING_TO_DO` and the leaf stays (#65's rule, kept true with the heal);
  - a use on a teammate within reach: their bleeding stops and they gain 5, and the user's meters are unchanged;
  - a teammate 3 tiles away: refused `OUT_OF_REACH` by `UsePlan.actor_reason`, and nothing changes.
- [x] 2.2 Add `METER_ADD` health +5 on the use target to `aloe.tres` after the cures, and the new Spanish and English descriptions (design D4). Verify that `test_sabila.gd`, `test_coast_cay_solo`, the content validator and `test_effect_line` (#65's effect words) pass. Done. #65's tests that expected sábila to read as cures only now expect the heal: `test_effect_line` ("Cura quemadura y sangrado · Salud +5 (+0 útil)" at full health), `test_wasted_uses` and `test_damage_feedback_solo` (the reason is "'Tás entero."; "No hay na' que curar." stays covered by a two-cure use). No HUD code changed.
- [x] 2.3 Write the `UsePlan` tests in `test_use_plan_cure.gd`, failing first:
  - a non-bleeding holder 0.5 tiles from a bleeding teammate aims at them, and `item_line_text` gives "Sábila · [F] Untar: <name>";
  - a bleeding holder aims at themself;
  - a teammate 3 tiles away is not aimed at;
  - a downed bleeding teammate is not a cure target, and a revive still wins with a cup;
  - a dead teammate or one waiting out of play is skipped;
  - a rain cup next to a standing thirsty teammate goes on the holder;
  - with no session (solo), the plan is always the holder.
- [x] 2.4 Add the cure step to `UsePlan.choose` after the revive branches (design D5). Verify that the 2.3 tests and the existing `test_use_plan*`, `test_inventory_strip*` and `test_use_button_solo` pass.
- [x] 2.5 Update the docs. Verify each by reading it back.
  - `docs/ITEMS.md`: the Sábila row reads "Stops bleeding and heals 5; soothes sunburn once it exists".
  - `TASKS.md`: a line under the current milestone for sunburn (a source from heat, an effect on heat, a HUD tag; data stays in `aloe.tres`), and HUD follow-ups for the status time-left bar (Brogue's progress bars, DCSS's HP-bar preview, SPD's incoming-damage bar).

## 3. Host and client

- [x] 3.1 Write `test_bleeding_net.gd`, host plus client in one process, as the other `_net` tests do:
  - the host's shark strikes the client's player, and the client sees the bleeding start and, 120 s later on the host, end;
  - the player's synchronizer lists the same property paths as before;
  - a late joiner sees an ongoing bleed;
  - the host's player treats the client's bleeding player with sábila from 0.5 tiles (the client sees bleeding end and +5);
  - a client's sábila use aimed at a far teammate changes nothing.

  Done: 6 tests, passing twice in a row. The host body's bleeding is shortened to 1 s through a duplicated tuning so the end is seen in real time. The synchronizer's exact path list stays pinned by `test_player_state_sync`.
- [ ] 3.2 Write `game/tests/manual/bleeding_run.gd`, a two-process run on UDP 7795 modelled on the other `*_run.gd` scripts. The host and the client each print pass or fail lines for:
  - the client sees itself bleed, then stop at 120 s;
  - the client treats the host's bleeding player;
  - the client's own health falls by the drain.

  Run it 3 times, with 0 engine error lines.

## 4. Solo stays winnable

- [x] 4.1 Add a solo end-to-end test to `test_bleeding_solo.gd`:
  - a 1-player run, offline, at 30 health is struck in deep water (5 left);
  - the player swims to the shallows and waits;
  - the player is alive at 1 health or more when the bleeding ends, and is no longer a shark target.

  A second case: a solo player bleeding on the sandbar, with no aloe, can start binoculars-and-swim once the bleeding ends.

  Done in `test_bleeding_solo` (the swimmer at 30 ends at 1 health, alive, and a shark circles them and leaves) and in `test_escape_routes_solo`. Both fail against the old meters.

## 5. Finish

- [ ] 5.1 Run the import twice (the second must print 0 error lines), the smoke run and the full GUT suite, all clean. Record the counts in the PR.
- [ ] 5.2 Run `tests/manual/bleeding_run.gd` as two processes on UDP 7795, 3 times. Record the host and client pass counts in the PR.
- [ ] 5.3 Run `openspec validate bleeding-and-sabila --strict`, and tick `TASKS.md`'s line for this change.

## Workflow follow-up

- Open a PR into `main` with the owner's answers, the counts and the follow-ups, and send the coordinator the link once CI is green.
- Archive the change after the owner plays it.
