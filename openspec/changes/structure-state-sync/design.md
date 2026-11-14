# Design

## Context

What reaches a client today:

- **Build sites.** A synced site (the level's `RaftSite`, or one placed at a bench) pushes its deposits and progress (`BuildSite.receive_state`). A client asks for the live state when it is ready and again when the world state arrives (`CoopSession.receive_world_state`, `request_site_state`). The host answers a level site it already built as built (`_built_sites`, `receive_site_built`).
- **Raft.** `SandbarIsland._on_route_started` runs on every peer (IslandRoutes emits `route_started` on clients from `receive_departure`), so the raft goes and a fresh `RaftSite` takes its place everywhere. A beached raft's integrity reaches every peer through `travel_to`, and a joiner gets it through the world state's `raft` key (`IslandTravel._join_extras`, `follow`).
- **Spawned structures.** A fire or rain catcher built from a bench site is spawned once by the entity spawner (`CoopSession.spawn_structure`). Its payload says `lit: true`, and `SitePlacer.make_structure` applies that only on a client (`and not on_host`). The host lights its own copy afterwards through `on_built`.

What never reaches a client:

- `Palm.coconuts`. It changes only on the host, in `_on_interacted`. Palms are built by `SandbarIsland._ready` under `Palms` in the island, which is the session's sibling and not its child. Their names are engine-made (`@Palm@N`), so they differ between peers.
- `Fire.lit`. Put out on the host by the interaction, or by `advance` once it has burnt out. A late joiner's copy is built from the old payload, so it arrives lit.
- `RainCatcher.cups`. Filled and taken only on the host.

Every look (`StructureLook.step`) reads its structure's fields each frame (art-pass T8), so a field that holds the host's value draws the host's frame.

Test topology (`NetHarness`): each peer has its own branch with its own `SceneMultiplayer` and a `Session`. The net tests that use an island add it as a child of the GUT test, outside every branch. The whole tree has one `Palms` group, spread over every branch's island.

## Goals / Non-Goals

**Goals:**
- A client's palms, fires and rain catchers hold the host's values, live and after a join or rejoin, on any island.
- The raft and site behaviour that already works stays guarded by a test on the real island and the real route start.

**Non-Goals:**
- Changing what a structure does: no palm regrowth, no disabling a bare palm or an empty catcher (a separate `TASKS.md` follow-up).
- Moving build sites or the raft onto the new paths. Their existing sync works and has tests.
- The ENet throttle on `submit_intent` and other `coop-networking` follow-ups.

## Decisions

### D1. Reference games: a newcomer gets the whole state once, the rest get changes

- **Borrowed, DCSS, `crawl-ref/source/tileweb.cc`.**
  - When a spectator joins (`"spectator_joined"`), `TilesFramework::_send_everything()` runs. Through `_send_map(true)` it sends the full map to the new spectator only.
  - `_send_map(false)` sends everyone else only the dirty cells.
  - Here, a joiner gets the full palm counts once, after its island has loaded. Players already in the run get each change as it happens.
  - A spectator in DCSS is the closest thing those games have to a late joiner.
- **Borrowed, Shattered Pixel Dungeon, `actors/blobs/Blob.java` (`storeInBundle`, `restoreFromBundle`) and `items/Heap.java`.**
  - A level object stores only its mutable fields: a blob stores its `cur` volumes, trimmed to the cells in use.
  - Here, the island's fixed part (the grid, the palms and their places) is rebuilt from the layout on every peer. Only the mutable fields travel: coconuts left, `lit`, `cups`.
- **Rejected, Brogue CE, `src/brogue/RogueMain.c`, `startLevel()`.**
  - On returning to a level, Brogue catches it up. It runs `updateEnvironment()` once per turn of `timeAway`, which is measured from `levels[n].awaySince` and capped at 100 turns.
  - A client here never simulates structures. The host's state is live and authoritative, so a joiner takes the host's values rather than catching up locally.
- **Rejected, DCSS, `crawl-ref/source/tags.cc` (versioned marshalling).** Nothing here is saved or read back across versions. A message is between two builds of the same game.
- **Borrowed, Don't Starve Together (closed source; ideas only, from the dontstarve.wiki.gg "Dedicated Server" guide and DST's known replica model).**
  - The server runs the game logic and holds the world, also when a player hosts from the game's menu. Fire pits, crock pots and farm plots change only there. Clients, joiners included, see replicas of that state through network variables, and never run it themselves.
  - Here the host is that server: palms, fires and catchers change only on the host, and clients and joiners show its values. A solo player is their own host, as a DST game hosted from the menu is its own server.
  - Rejected: DST's shards, one server process per world (the forest and the caves) running side by side. Here one island is live at a time. The island the party leaves is freed, so a joiner gets only the current island's state.
- No code, data or text is copied.

### D2. The raft and build sites: no change, a regression test

- The "unconfirmed" note in art-pass's workflow follow-up described a joiner during the crossing. On the host at that moment, the sandbar had a fresh, empty `RaftSite` and the raft was at sea. The joiner showed exactly that.
- `test_build_site_net.gd` covers it only with a hand-made launch, so a new test runs the real `SandbarIsland` with a real route start (the `test_crossing_join.gd` rig).
  - A joiner during the crossing gets an unbuilt site with nothing deposited and no `Raft`.
  - A joiner before the launch gets the `Raft` and no site.
- A beached raft's integrity is not added to any new message: `travel_to` and the world state already carry it.

### D3. Fire and rain catcher: a synchronizer attached at spawn

- `SitePlacer.make_structure` calls `attach_sync()` on the structure it makes, when the structure has one, as `CoopSession._make_creature` does for creatures (`Creature.attach_sync`).
  - `Fire.attach_sync` replicates `.:lit`.
  - `RainCatcher.attach_sync` replicates `.:cups`.
  - Both use spawn on and `REPLICATION_MODE_ON_CHANGE`, which sends reliably when the value changes.
- The host is the synchronizer's authority. The engine drops a sync packet from any other peer, and a client's own change to its copy is never sent.
- A late joiner gets the current values with the spawn (the spawner sends the synchronizer's spawn state), so a fire that went out arrives out.
- **Why attached in code, not in `fire.tscn`:**
  - Fires and catchers made outside the spawner (solo dev scenes, tests that add one on one peer) would carry a synchronizer with no spawn. The host would then sync it to clients that have no such node, and those clients log engine errors.
  - Only spawned structures need it.
- *Alternative:* one RPC channel for palms, fires and catchers. Rejected:
  - The spawner already delivers spawned nodes to late joiners with their synchronizer state.
  - The project rule is that state syncs through `MultiplayerSynchronizer`.
  - The authority check is the engine's.

### D4. `Fire.lit` takes effect wherever it is set

- `lit` gets a setter. Once the fire is ready, the setter puts the fire in or out of `PlayerBody.FIRE_GROUP` and sets `interactable.enabled`. `_ready` applies the same.
- So a value set by the synchronizer, before or after `_ready`, gives the client a lit fire, a lit-fires member and an "[E] Apagar" prompt, or none of the three.
- `_burn()` and `put_out()` keep their jobs on the host: `burn_left_s`, and `light()`'s morale event. They set `lit`; the setter does the rest.
- **The host's spawned fire is lit before its spawn is sent.**
  - `make_structure` applies the payload's `lit` on the host too (`and not on_host` goes), so the spawn state the engine captures says `lit: true`.
  - `on_built` → `light()` still gives the fire-lit morale exactly once ("One fire, once").
  - The first test written is a connected client that must see the fire lit from its first frame, so this ordering is checked, not assumed.
- The payload's `lit` stays: it is what lights the host's copy before the spawn is captured.

### D5. Palms: a `PalmSync` the island adds to the session

- `SandbarIsland` keeps its palms in layout order (`palms: Array[Palm]`). `furnish` adds a `PalmSync` named `PalmSync` to the session and hands it those palms and the layout's starting counts (`built.palm_coconuts`).
- It is island furniture: `IslandTravel._clear_level` frees it with the bench and routes, and the next island's `furnish` adds a new one at the same path. `SESSION_NODES` is not edited.
- `Palm.coconuts` gets a setter that emits `coconuts_changed(count)` when the value changes.
- **Host, live:** on a palm's `coconuts_changed`, `receive_count.rpc_id(peer, index, count)` goes to every connected peer that has a player in the session.
  - A peer still in the lobby, or not yet admitted, gets nothing. It gets the full counts when it is admitted.
- **Host, joiner:** on the session's `join_state_sent(peer)` (D6), `receive_counts.rpc_id(peer, counts)` sends every palm's count, in order, as a `PackedInt32Array`.
- **Client:** both RPCs are `authority`, and each returns unless the sender is `HOST_ID`.
  - `receive_count` needs an index in range.
  - `receive_counts` needs exactly as many counts as the island has palms. A different size means another island, and the message is dropped.
  - Each count is clamped to 0 up to that palm's layout count; counts only go down today.
  - The look follows on its next frame.
- **Why an index:** the island is built from the same layout on every peer, so the order under `Palms` is the same everywhere. Palm names are engine-made and differ.
- **Why not a synchronizer on each palm:**
  - Palms are not in the session. In every `NetHarness` rig the island is outside the branch's multiplayer root, so a palm has no peer to sync with.
  - A group lookup would find every branch's palms.
  - The island is rebuilt on travel, and a static synchronizer would then point at freed nodes.
- **Solo:** `PalmSync` is there (the same code). `multiplayer.get_peers()` is empty, so it sends nothing. `sent_count` stays 0, and the solo test reads it.

### D6. One host signal in `CoopSession`, after the world state

- **Added:** `signal join_state_sent(peer_id: int)` ("Host: a joiner or a rejoined player was sent the world state and its lobby reply; anything it must hear after its island loads goes now").
- **Emitted** at the end of `request_join`, beside the existing `send_progress(sender)` and under the same condition (run started, in the run, the sender has a body).
  - On both the admit and the reclaim path, `receive_world_state` is sent before that point.
  - On the client, `follow` → `_load` rebuilds the island inside `receive_world_state`. A message sent later on the same reliable channel arrives after the new `PalmSync` exists.
- **Not covered:** `begin_run`'s admissions from the lobby, which do not go through `request_join`. Nobody has spawned in the lobby, so no palm has changed. This is the same choice `send_progress` made.
- *Alternatives:*
  - Defer the push from `player_spawned` and `player_rebound`, with no edit to `coop_session.gd`. Rejected: both fire before the world state is sent, so this relies on the same-frame ordering, and they also fire for the host's own player.
  - The client asks after `world_state_received`. Rejected: that spends the client's action budget (`PeerLimits.allow_action`, which site asks already use) and adds a request path to rate-limit.
- The edit is three lines, local to `request_join` and the signal list. The sibling `_dropped` work (`CoopSession._dropped`) touches neither.

### D7. Tests

- **`test_structure_sync.gd`** (offline, 1 player):
  - The solo scenario on the real sandbar.
  - The fire setter: `lit` false then true moves the fire out of and back into the lit fires and toggles its interactable, before and after `_ready`, with no morale event from the setter.
  - Palm clamping: a count above the layout's or below 0, a wrong-size `receive_counts`, an index out of range.
- **`test_structure_sync_net.gd`** (ENet, `NetHarness`):
  - A connected client sees a new fire lit from its first frame.
  - It sees a palm climbed, a fire put out and burnt out (no "[E] Apagar" prompt, not a lit fire), and the catcher fill and empty, each look's frame included.
  - A late joiner sees all three. A rejoiner sees a palm climbed while it was away.
  - A joiner on the coast cay gets that island's counts (the `test_crossing_join.gd` rig and `IslandTravel`).
  - Forged messages change nothing, and the host's engine refuses the non-authority call.
  - The two raft cases of D2 run on the real island with a real route start.

## Risks / Trade-offs

- [The engine captures a spawned node's synchronizer state when it becomes ready, before `on_built` lights the fire] → D4 lights the host's copy from the payload first. The connected-client test is written and run first.
- [ON_CHANGE deltas go out on the next network frame] → a client shows a change one frame or so after the host. That is the same order of delay as the creatures' 0.1 s sync. Tests wait for it.
- [A palm message reaching a client mid-travel] → `travel_to` and the RPCs share the reliable channel, so they arrive in the order sent. A `receive_counts` for the wrong island has the wrong size and is dropped.
- [A merge conflict with the sibling session's `coop_session.gd` work] → the edit is three lines in `request_join` and the signal list. It is rebased on `main` before the PR.
- [Synchronizers on spawned structures log engine errors when a peer closes under them] → `NetHarness.teardown` frees sessions before closing peers, as it already does for players and creatures.

## Settled

- The owner answered the three decisions on 2026-11-14 through the coordinating session, picking each recommendation:
  - D2: test only, with no raft or site code change.
  - D3 and D5: split by node, with a synchronizer for the fire and the rain catcher and `PalmSync` with index-keyed host RPCs for palms.
  - D6: the `join_state_sent(peer)` signal in `coop_session.gd`.
