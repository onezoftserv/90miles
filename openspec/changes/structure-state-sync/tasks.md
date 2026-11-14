# Tasks

## 1. Fire and rain catcher on every peer

- [x] 1.1 Tests first, in a new `game/tests/unit/test_structure_sync_net.gd` (NetHarness, a bench at the same path on every peer, as in `test_build_site_net.gd`):
  - A connected client sees the host's new fire lit from the first frame its copy exists.
  - It sees the fire put out on the host, then a second fire burnt out (`advance` past `fire_burn_s`). Each time: `lit` is false, the fire is not in `PlayerBody.FIRE_GROUP`, its interactable is off and its look shows `out`.
  - It sees the catcher fill in a squall on the host (`cups` 1, look `water`), then empty when the host's player takes the cup (`cups` 0, look `empty`).
  - A late joiner gets a fire put out before it came, out, and a filled catcher holding 1 cup.
  - A client that puts out its own copy changes neither the host's fire nor another client's.
  - Then see them fail.
  - Done 2026-11-14: 5 tests. Before the fix, 4 failed (put out and burnt out, fill and empty, late joiner). The first-frame-lit and own-copy tests passed before too and stay as guards on D4's ordering.
- [x] 1.2 Tests first, offline with 1 player, in a new `game/tests/unit/test_structure_sync.gd`. Setting `Fire.lit` false, then true, before and after `_ready`, moves the fire out of and back into the lit fires and toggles its interactable, with no morale event. Then see it fail.
  - Done 2026-11-14: 2 tests. The after-ready one failed before the setter; the before-ready one passed before too and stays as a guard.
- [x] 1.3 Implement design D3 and D4:
  - The `Fire.lit` setter, with `_ready`, `_burn` and `put_out` going through it.
  - `Fire.attach_sync` and `RainCatcher.attach_sync`.
  - `SitePlacer.make_structure` attaches the sync and applies the payload's `lit` on the host too.
  - Verify: 1.1 and 1.2 pass, and so do `test_build_site_net.gd`, `test_structure_looks.gd`, `test_art_sim_invariance.gd` and the crafting tests ("One fire, once": morale +5 once).
  - Done 2026-11-14: `SitePlacer.state_sync` builds the synchronizer (spawn, on change) and `make_structure` calls `attach_sync`. `from_payload` lost its `on_host` parameter (one call in `coop_session.gd`).
- [x] 1.4 Import (twice), smoke run and GUT pass, with no engine error lines.
  - Done 2026-11-14: second import 0 `ERROR` lines; smoke "10 frames, 0 problem(s)"; GUT 175 scripts, 1550 of 1550.
  - The log's 6 `ERROR` lines are the baseline's own: three refused forged RPCs and the content validator's broken fixture, each asserted by its test.

## 2. Palms on every peer

- [ ] 2.1 Tests first, offline with 1 player, in `test_structure_sync.gd`:
  - The solo scenario on the real sandbar: climb a palm from 2 to 1, take a cup the catcher filled in a squall, and put the fire out. The `PalmSync` in the session has `sent_count` 0.
  - Clamping on a client-side `PalmSync`, called directly: a count of 9 shows the layout's 2 and −1 shows 0. A `receive_counts` of the wrong size and an index out of range change nothing.
  - Then see them fail.
- [ ] 2.2 Tests first, in `test_structure_sync_net.gd`, on the real `SandbarIsland` (the `test_crossing_join.gd` rig):
  - A connected client's palm goes from 2 to 1 and draws 1 when the host's player climbs it.
  - A late joiner gets a palm the host climbed before it came.
  - A rejoined client (the reclaim path, `PlayerIdentity`) gets a palm the host climbed while it was away.
  - A forged `receive_count` from a client changes no peer's palm, and the host's engine refuses the call (`assert_engine_error("not allowed")`).
  - Then see them fail.
- [ ] 2.3 Implement design D5 and D6:
  - `Palm.coconuts_changed`, emitted from the `coconuts` setter.
  - `SandbarIsland.palms`, with `furnish` adding `PalmSync`.
  - The new `game/scripts/net/palm_sync.gd`.
  - `CoopSession.join_state_sent`, emitted at the end of `request_join` beside `send_progress`.
  - Verify: 2.1 and 2.2 pass, and so do `test_coop_session_net.gd`, `test_coop_reconnect*.gd`, `test_crossing_join.gd`, `test_draw_order.gd`, `test_creature_art.gd` and `test_coast_cay_layout.gd`.
- [ ] 2.4 Import (twice), smoke run and GUT pass, with no engine error lines.

## 3. Joiners on later islands, and the raft

- [ ] 3.1 Tests in `test_structure_sync_net.gd`, written and run before any fix they need:
  - A joiner on the coast cay: the host's party travels (`IslandTravel` on every peer), the host's player climbs a coast cay palm, then a client joins. It builds the coast cay and its palm has the host's count.
  - The raft on the real island with a real route start (design D2). A joiner before the launch has the `Raft` and no `RaftSite`. A joiner during the crossing has an unbuilt `RaftSite` with nothing deposited and no `Raft`, as the host has.
  - Verify: they pass, with no error lines.
- [ ] 3.2 Import (twice), smoke run and GUT pass. `openspec validate structure-state-sync --strict` passes.

## 4. Host and client run

- [ ] 4.1 Run a host and a client locally (two processes, the playthrough harness `tests/manual/art_pass_run.gd` or the game through the shell):
  - The client watches the host climb a palm, put out a fire and fill and empty the catcher.
  - Then a second client joins late and sees the same.
  - The client checks compare each value with the host's, not only error lines.
  - Record the result and any finding here.
  - Verify: every check passes, with zero error lines in each log.
- [ ] 4.2 Update `TASKS.md`: a dated "Done" entry with the GUT count, and drop "palm, rain-catcher and fire state sent to clients" from the open follow-ups. Note in `art-pass/design.md`'s D18 risk note and in art-pass-followups' "Still open" that this change closes them. Verify: the files say so.

## Workflow follow-up

- Open the PR into `main` (one capability, conventional commits), then report its link to the coordinating session.
- Archive the change after the owner's review, syncing the `coop-networking` delta into `openspec/specs/`.
