# Proposal

## Why

Milestone A is "two players on a handmade island" (`TASKS.md` §3). `player-movement` gave a body driven by `MoveIntent`s; nothing yet connects two machines. Every later system (meters, inventory, creatures, weather) keeps its state on the host and reaches clients through this layer, so the session, the sync model and the RPC rules have to exist, with tests, before those systems are built on top.

## What Changes

- **Host and join.** A player hosts on a port (default 7777) and up to three others join by IP over ENet. Solo runs the same session code on Godot's offline peer, so no port is opened. `NetManager` creates the transport behind one factory (ENet now; Steam relay or WebRTC later replace only the factory, review item 40) and reports hosting, joining and losing the host.
- **A session node, not autoload logic.** A `CoopSession` scene holds the players, the spawners and the RPC handlers and uses only the multiplayer API of its own branch. This is what lets tests run a host and clients in one process, and it keeps `NetManager` thin (no new autoload).
- **Spawning.** The host spawns one player per peer through `MultiplayerSpawner`, at the level's beach spawn points. An entity spawner is ready for creatures, items and NPCs to register their scenes. Late joiners receive everything already spawned, plus a world-state message (island seed, weather, time of day) from the host.
- **Host authority with prediction (decided 2026-11-05, `CLAUDE.md` "Movement sync").** The host simulates every player from intents. Each client predicts its own player from its own intents and, when the host's state arrives (20 Hz, `MultiplayerSynchronizer`), resets to it and replays the intents the host has not processed yet. Other players are interpolated 100 ms behind the newest snapshot. Interactions (pick up, drag, timed holds) run only on the host.
- **RPC rules (review item 17).** Clients send intents only to the host (`rpc_id(1, ...)`). Every intent handler returns unless it runs on the host. The acting player comes from the sender's peer id, never from an argument. Host-to-client calls are authority-only, client-to-client relay is off, and each peer has rate limits on intents and quick chat.
- **Disconnects.** A client that drops leaves its player downed in the world for 90 s, after which the player is removed and the host announces the removal (inventory drop hooks in there once `crafting-inventory` exists). If the host drops, the session ends and clients see a "host lost" screen.
- **Quick chat.** A radial wheel (hold the new `quick_chat` action) with the 8 phrases; the host validates the pick and every player sees the phrase as a speech bubble over the speaker. Phrases are content: `game/resources/dialogue/quick_chat.tres` (a `DialogueData` of kind QUICK_CHAT), so changing a phrase needs no script edit.
- **A co-op dev playground** (`scenes/dev/coop_playground.tscn`): the movement playground's terrain with a session, hosting or joining from command-line arguments or a small panel, for the "run host and client locally" check in `CLAUDE.md`.

**Provisional decisions to confirm** (each is a constant or a small, isolated piece of code; none blocks changing it later):

1. **Split parties (review item 16): one live level per session in v1.** Everyone who is not on the current island waits (the crossing and escape-routes changes decide what waiting looks like). This change keeps players and entities under one level node, so several level containers with per-peer visibility remain possible later. **Question:** keep "one live level" for v1, or plan for simultaneous split play now?
2. **Difficulty scaling is not implemented here.** It has no consumer until `island-generation` and `guardacostas-stealth`, and review item 27 says ×0.8 per extra player makes co-op harder than solo. The requirement stays in the spec as it is. **Question:** keep ×0.8 per extra player, or switch to the review's per-head scaling? Also, "+1 patrol per 2 players" can be read as ⌊n/2⌋ (2 players → +1) or ⌊(n−1)/2⌋ (2 players → +0); both give +1 for 3 players.
3. **Reconnects (review item 40): a client that reconnects is a new player.** Its old body stays downed until the 90 s removal; there is no stable player id yet. **Question:** add a join handshake with a stable player id so a reconnect within 90 s reclaims the body? And does a removed player count as dead for endings and Experiencia? (Undecided: the removal is only announced.)
4. **Platforms (review item 40): Windows and Linux desktop.** ENet does not exist on Web, so the web-export rationale in the project-skeleton design no longer holds. No UPnP: the host forwards UDP 7777 by hand (documented in the playground and the design).
5. **Solo uses Godot's offline peer**, not an ENet server with joining refused, so solo never opens a socket or triggers a firewall prompt.
6. **Rate limits:** intents at most 90 per second with a burst of 30, and at most 1 s of simulated time per real second with 0.25 s of slack (an intent's own time step is capped at 0.1 s); quick chat at most 3 in a burst, then one every 2 s. Excess messages are dropped silently.
7. **Prediction snaps.** A correction moves the client's player straight to the corrected position (no visual smoothing); remote players are drawn 100 ms behind the newest snapshot.
8. **Voice clips for quick chat arrive with Milestone G.** The bubble shows now; the clip plays when a file exists for the phrase's line id, and nothing plays until then. The spec delta says so.
9. **Quick-chat English lines** keep the slang: "¡Dale!", "Water!", "Not that way!", "Shark!", "Patrol!", "Help!", "Food here!", "¡Vámonos!". `content-batch-10` may rewrite them; this change only needs the file to exist.
10. **World state on join** is a small dictionary (`island_seed`, `weather`, `time_of_day_s`) filled by the level. The dev playground sends fixed dev values until `island-generation` and `weather-daynight` own them.
11. **No pause in co-op** (review item 24 stays open): this change adds no pause, save or resume rule.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `coop-networking`: "Host and join" adds the offline solo path, the four-player cap and the world-state message on join. "Host authority" adds client prediction with reconciliation and interpolation of other players. "Disconnect handling" makes the removal an announcement other systems hook into and keeps the "host lost" screen. "Quick chat" makes phrases content, validated by the host, with voice clips deferred. One requirement is added: intent RPC rules with per-peer rate limits.

## Impact

- New: `game/scenes/net/coop_session.tscn` (+ script), `game/scripts/net/` (player net component, prediction buffer, snapshot interpolator, rate limiter, quick-chat phrases), `game/scenes/ui/` (quick-chat wheel, speech bubble, host-lost screen), `game/scenes/dev/coop_playground.tscn`, `game/resources/dialogue/quick_chat.tres` (the first content file, so the content validator now checks real data).
- Changed: `NetManager` (filled in: host, join, leave, peer factory, signals), `scenes/player/player.gd` (one step function the network can call; camera and input logic unchanged), `scenes/player/player.tscn` (net component and synchronizer), `MovementModel` (save and restore dive state for replays), `project.godot` (`quick_chat` input action).
- Tests: GUT unit tests for the pure parts; integration tests that run a host and one or two clients over ENet on localhost in one process.
- No new autoload; the core-services set is unchanged.
