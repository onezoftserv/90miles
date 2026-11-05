# Design

## Context

`player-movement` left a `PlayerBody` that applies `MovementModel` to a `MoveIntent` every physics frame, a `PlayerInput` that builds the intent from the input map, and a camera and input enabled on `local_player and is_multiplayer_authority()`. `NetManager` is an empty autoload. There is no island, inventory, weather or lobby yet. See proposal.md for why and for the provisional decisions; see the spec delta for the required behavior.

A spike on Godot 4.7.2 confirmed the test harness this design depends on: two `SceneMultiplayer` branches in one process (`SceneTree.set_multiplayer(api, branch_path)`) connect over ENet on localhost in about 3 frames; `create_server(0)` binds a free port, read back with `host.get_local_port()`; a `MultiplayerSpawner` with a `spawn_function`, a host-pinned `MultiplayerSynchronizer` and `rpc_id(1, ...)` with sender ids all work across the branches; the host calling its own `call_local` RPC sees sender id 1. Closing a peer while its synchronizers are still in the tree logs engine errors, so the session subtree is freed before its peer is closed.

## Goals / Non-Goals

**Goals:** two to four players on one island with the host authoritative; a client's own player responds on the frame it presses a key; every spec scenario has a GUT test with exact numbers; the RPC rules hold for every handler.

**Non-Goals:** lobby, title or join menus beyond a dev panel (review item 23); inventories, item pick-up effects, creatures or NPC scenes (the entity spawner is ready for them); applying the difficulty numbers to an island (island-generation does that); reconnect reclaim and player identity (decision 3); host migration; voice clips (decision 8); visual smoothing of corrections (decision 7); save-and-quit (decision 11).

## Decisions

### A session scene owns the networking, not the autoload
`CoopSession` (`scenes/net/coop_session.tscn`, script beside it) holds `Players` and its `PlayerSpawner`, `Entities` and its `EntitySpawner`, the RPC handlers, the disconnect timers and the per-peer rate limiters. It uses only `multiplayer` (the API its branch resolves), never `get_tree().get_multiplayer()`. A level instances it, sets `terrain`, `spawn_points` and `world_state`, then calls `start()` once the peer is in place.

`NetPeers` (`scripts/net/net_peers.gd`, static) is the only place that names ENet: `create_server(port)` and `create_client(address, port)` (review item 40: Steam relay or WebRTC replace these two), plus `DEFAULT_PORT` and `MAX_PLAYERS`, which cannot live in the autoload because core-services forbids constants in service scripts. `NetManager` stays thin: `host()`, `join()`, `start_solo()` and `leave()` set the default API's peer from `NetPeers`, turn `server_relay` off and emit `hosted`, `joined`, `join_failed` and `host_lost`.

Alternative: all logic in `NetManager`. Rejected: one autoload means one multiplayer API, so a host and a client cannot run in one test process, and autoloads are meant to stay thin.

### Authority: the body belongs to its peer, its state to the host
The spawn function runs on every peer and, before the body enters the tree, sets `body.set_multiplayer_authority(peer_id)` and then the body's `StateSync` synchronizer back to authority 1. So `is_multiplayer_authority()` keeps meaning "this is my player" and `player.gd`'s camera and input logic needs no change, while replicated state flows only host → clients. Offline everything is peer 1, as before.

Alternative: every body under authority 1 with a separate "mine" flag. Rejected: it changes the camera rule in `player.gd` (which `survival-meters` is also editing) for no gain.

### Three roles per body
`PlayerNet` (child node of `player.tscn`, `scripts/net/player_net.gd`) is inert until the session attaches it, so the movement playground and the player-movement tests behave as before. Its role comes from `PlayerNet.role_for(is_server, local_peer_id, owner_peer_id)`:
- **HOST** (on the host, every body): drains the intents the session queued for this body and steps the body once per intent; writes the shadow fields the synchronizer sends.
- **PREDICTED** (on a client, its own body): steps the body from local input every frame, without interactions, and reconciles when host state arrives.
- **REMOTE** (on a client, other bodies): never simulates; draws the body from interpolated host states.

`PlayerBody` gains `auto_advance` (false once attached) and `advance(delta, with_interaction = true)`, which is the old `_physics_process` body. The body still never reads `Input`.

### Intents carry their own time step, and the host steps each one
Every physics frame on the owning peer, `PlayerInput` (priority −10) sets `body.intent`; `PlayerNet` (priority −5) numbers it, stores it with its delta in a `PredictionBuffer` (clients only) and calls `session.rpc_id(1, "submit_intent", seq, direction, run, crouch, interact, delta)`. The handler is `@rpc("any_peer", "call_local", "unreliable_ordered")`; it returns unless `multiplayer.is_server()`, takes the body from `get_remote_sender_id()` (never from an argument), checks the payload (finite direction of length ≤ 1, delta in (0, 0.1] s, seq newer than the last), applies the rate limits and queues the intent on that body. The host's own body goes through the same handler: its local `rpc_id(1, ...)` call runs synchronously with sender id 1, so solo, host and client share one path.

The HOST role drains up to 8 queued intents per physics frame, each as `body.intent = it; body.advance(it.delta)`, and records the last seq as acknowledged. A downed body ignores intents (it still acknowledges them) and advances once per host frame so it can be dragged.

Why the client's delta: the host then steps the client's body exactly as the client predicted it (same start state, same intents, same deltas), so prediction and host agree to the bit unless the host's world really differs (a current, a wall, a drag). Alternative: the host steps each body once per host frame with the newest intent; rejected because every difference between client and host frame timing becomes a correction.

### Host state as shadow fields at 20 Hz
`StateSync` (`MultiplayerSynchronizer`, `replication_interval` 0.05 s, mode ALWAYS so the newest unreliable packet wins, every field also sent at spawn) replicates `PlayerNet` shadow fields, never `position` itself: `net_position`, `net_energy`, `net_ack_seq`, `net_model_state` (the dive bookkeeping), `net_movement`, `net_stealth`, `net_downed`. On `synchronized`:
- **PREDICTED, not downed:** drop buffered intents up to `net_ack_seq`, set position, energy and model state to the host's, then replay the remaining buffered intents with `advance(delta, false)`. Corrections snap (proposal decision 7).
- **REMOTE, or PREDICTED while downed:** push `(local receive time, net_position)` into a `SnapshotInterpolator` and apply the downed, movement and stealth fields. A downed own player sends no intents.

`SnapshotInterpolator` keeps the last 8 states and samples linearly at `now − 0.1 s`, clamping to the oldest and newest (no extrapolation). It uses local receive times, not host timestamps: on a LAN the jitter is a few ms, and host timestamps need clock-offset estimation that can wait until internet play shows a need.

`MovementModel` gains `get_state() -> PackedFloat32Array` and `set_state()` for its dive fields, so a replay starts from the host's dive state. `Vector2` is 32-bit on both sides and floats travel as 64-bit, so a replay with no real correction reproduces the host's numbers exactly; a test asserts equality, not closeness.

### Rate limits are token buckets on the host's clock
`RateLimiter` (pure: `capacity`, `refill_per_s`, `try_take(amount, now_s) -> bool`) backs three buckets per peer (`PeerLimits`): intent count (30, 90/s), simulated time (0.25 s, 1 s/s; the amount is the intent's delta but at least one 1/60 s frame, so tiny claimed steps cannot buy extra interaction presses) and quick chat (3, one per 2 s). The host's own player, which is the solo player, skips the two intent buckets: it is trusted, and limiting it could only drop a solo player's input after a long frame. The session reads time through a `clock` callable (default `Time.get_ticks_usec() / 1e6`) that tests replace. Over-limit messages are dropped without a log line, so a flooding client cannot flood the host's log through the script either.

### Disconnects and the host-lost screen
On `peer_disconnected` the host calls `set_downed(true)` on that peer's body (it does not redefine downed; `survival-meters` owns it), drops its buckets and starts a 90 s countdown advanced in the session's `_physics_process`. At 0 the session emits `player_removed(peer_id, last_position)` (where `crafting-inventory` will drop the inventory) and frees the body; the spawner removes it on every client. A reconnecting client is a new peer id and gets a new body (proposal decision 3).

On a client, `server_disconnected` makes the session free its players and entities and emit `host_lost`; the level shows `scenes/ui/host_lost_screen.tscn` ("Se perdió la conexión con el anfitrión", a "Volver" button). `NetManager` also returns the default API to the offline peer.

### Spawning, joining, the player cap
The host spawns its own body at `start()` and one per `peer_connected`, at `spawn_points[join_index % size]`, through `PlayerSpawner.spawn({peer, position})`. The spawner replays existing bodies to late joiners. `EntitySpawner` uses scenes that levels register with `add_spawnable_scene` on every peer (creatures, items and NPCs later). Right after spawning a joiner, the host sends `receive_world_state(world_state)` (`@rpc("authority", "call_remote", "reliable")`); the client checks the types of `island_seed`, `weather` and `time_of_day_s` and emits `world_state_received`. ENet's server is created with 3 clients; the session also disconnects any peer beyond four connected players. A dropped player's body waits out its 90 s but does not count toward the cap, so a reconnect (a new peer) fits. Peers that connected before `start()` are added at `start()`.

Solo needs nothing else: `start()` on the offline peer spawns the host's own player at once, its intents take the same `rpc_id(1, ...)` path (a synchronous local call), and it is stepped on the same frame.

### Quick chat
Phrases are the lines of state `quick_chat` in `game/resources/dialogue/quick_chat.tres` (`DialogueData`, kind QUICK_CHAT), in wheel order, ids `quick_chat_<phrase>`. `QuickChatWheel` (`scenes/ui/`) is shown while `quick_chat` (Q, gamepad right shoulder) is held; the slot comes from the mouse offset from the wheel's center or the right stick: 8 sectors of 45° clockwise from north, with a dead zone (`slot_for(direction)` is pure). Releasing over a slot calls `session.rpc_id(1, "request_quick_chat", slot)` (`any_peer`, `call_local`, reliable): the host checks the sender's body, the index and the bucket, then calls `show_quick_chat(peer_id, slot)` (`authority`, `call_local`, reliable) on everyone. Each peer adds a `SpeechBubble` over that body for 2.5 s with the line in the current locale (Spanish first) and plays `res://assets/audio/voice/<line id>.ogg` from the bubble if the file exists. No autoload changes.

### Difficulty scaling and the solo pause
`DifficultyScaling.for_players(n)` (pure) gives `resource_multiplier = 0.8^(n−1)` and `extra_patrols = ⌊n/2⌋`, with n at least 1. `CoopSession.island_difficulty(alive)` counts the session's players that are connected (not in the disconnect countdown) and alive. By default `CoopSession.is_alive()` reads `SurvivalMeters.dead`, which survival-meters adds; until then every connected player counts as alive. Tests pass their own `alive` callable for the "3 of 4 dead" case. Nothing calls `island_difficulty()` yet: island-generation and guardacostas-stealth read it when an island is set up.

`CoopSession.can_pause()` is true only on the offline peer with one player. `set_paused(true)` sets `SceneTree.paused`, which stops every node that inherits the tree's pause: players, meters, creatures, patrols, and the WeatherManager clock and weather. `PauseMenu` (`scenes/ui/pause_menu.tscn`, `PROCESS_MODE_ALWAYS`) opens on the `pause` action (Esc, gamepad Start), shows "Pausa" and "Seguir", and refuses to open in co-op. Pausing the tree is enough because no gameplay node opts out of the pause; anything added later that must run while paused (menus) sets its own process mode.

### Co-op dev playground
`scenes/dev/coop_playground.tscn` reuses the movement playground's terrain, holds a `CoopSession`, and starts from command-line user arguments (`-- --host[=port]`, `-- --join=address[:port]`, `-- --solo`) or a small Host/Join panel. Hosting over the internet needs UDP 7777 forwarded by hand (no UPnP, proposal decision 4); the panel says so. The main scene never hosts on its own, so the headless 300-frame run opens no socket.

### Tests
Pure GUT tests for `RateLimiter`, `PredictionBuffer`, `SnapshotInterpolator`, `PlayerNet.role_for`, `QuickChatWheel.slot_for`, the model state round trip and the phrase file. Integration tests use `tests/helpers/net_harness.gd`: one branch per peer, each with its own `SceneMultiplayer` (relay off) and a `CoopSession` at the same relative path, ENet on port 0, `wait_until` for connections, and a teardown that frees the sessions, then closes the peers, then detaches the APIs. Bodies in the tests have `PlayerInput` disabled and get intents set directly. The 90 s countdown is advanced by calling the session's `_physics_process` with explicit deltas, never by waiting.

## Risks / Trade-offs

- [All branches of an in-process test share one physics world, the `Input` singleton and the `interactable` group] → players never collide with each other (layer 2, mask 1), tests disable `PlayerInput`, and test interactables live only in the host branch.
- [Closing a peer with live synchronizers logs engine errors, which fail GUT and CI] → the harness frees sessions first; the host-lost path frees the client's spawned nodes on `server_disconnected`, and a test checks that path logs no engine error.
- [Unreliable intents can be lost] → the host never applies a lost intent and the next acknowledgement corrects the client; sending the last few intents redundantly can be added if play shows rubber-banding.
- [Clock drift between client and host slowly drains the 0.25 s simulated-time slack] → about 50 ppm on common hardware takes over an hour to drain it, and the cost is one dropped intent and a small correction.
- [Corrections snap and receive-time interpolation jitters over the internet] → both are isolated in `PlayerNet` and `SnapshotInterpolator`; smoothing and host timestamps can be added there.
- [A malicious client can still make the host's engine log errors (RPCs with wrong argument types, to host-only methods or to unknown paths), send large packets, or hold a slot by staying connected and idle] → these happen below the script, before any limit runs; for v1 (join by IP with friends) they are accepted. A per-peer violation count with a kick, an idle kick and a join handshake (SceneMultiplayer `auth_callback`) are the follow-ups if public hosting ever happens.
- [`survival-meters` is editing `player.gd`, `player.tscn` and `SurvivalMeters` at the same time] → this change only adds `advance()`/`auto_advance` and two child nodes, uses `set_downed()` as it is, and the shared notes folder lists the files and the synchronizer layout so meters are added to the same `StateSync`.
- [`game/resources/` appears for the first time, so the content validator checks real data in the smoke run] → `DialogueData` needs no name, and the file is checked by the smoke run and a unit test.

## Migration Plan

No saved data or deployed services. Rollback is a revert of the change's commits.
