## Context

- **What exists:**
  - `coop-networking` gives a host-authoritative session. `CoopSession` maps peer ids to `PlayerBody` nodes spawned through a `MultiplayerSpawner` whose spawn data is `{peer, position}`.
  - A dropped client's body is set downed and counted down from 90 s (`_dropped`), then removed (`player_removed`).
  - `ui-shell` added a lobby phase and the join request `request_join(name)`, accepted once per peer, which fills `roster` (peer → name).
  - In the run phase, a peer spawns on connect, before its join request arrives.
- **What a body's network identity is:** `PlayerNet.attach(peer, role, send)` sets the body's multiplayer authority to its peer, keeps `StateSync` with the host, and picks the role. HOST on the host; PREDICTED for a client's own body; REMOTE for the others.
  - `PlayerBody._ready()` enables the camera and keyboard input once, for the local authority.
  - The host's `PlayerNet` refuses intents whose sequence number is not newer than the last one it queued.
- **Godot gives a reconnecting client a new peer id.** Nothing today links the new peer to the old body.
- **Not on `main` yet:** player inventories (`crafting-inventory`) and the endings and Experiencia systems (`GameState` is a stub).
- **Other branches:** `weather-daynight` and `crafting-inventory` also edit `coop_session.gd`, so this change keeps its edits there small and puts the new logic in its own files.
- **Not archived:** `ui-shell`. Its delta also modifies "Host and join" and "Intents reach only the host…", so this change touches neither and adds its own requirements instead.

## Goals / Non-Goals

**Goals:**
- A client that drops and joins again within 90 s, from the same install, gets the same body back: the node and everything on it.
- No client can take another player's body.
- A silent peer cannot hold a slot.
- Removed players count as dead in the run summary, and there is one record for endings and Experiencia to read.
- Solo is unchanged and stays closed.

**Non-Goals:**
- Host migration, or rejoining a host that restarted.
- Encrypting the transport.
- A "full" refusal reason: ENet refuses a fourth client before the session sees it.
- Reclaiming in the lobby: nothing is in the world yet, so a lobby rejoin is just a new join.

## Decisions

### Identity: a random id and secret per install, checked by the host

- `PlayerIdentity` (`scripts/net/player_identity.gd`) holds `id` (32 hex characters) and `secret` (64 hex characters). It makes them from `Crypto.generate_random_bytes`, checks their form, and hashes the secret with SHA-256.
- `GameSettings` keeps them under `[player] id` and `secret`. A missing or malformed pair is replaced by a new one, and the shell saves it at once so the id is stable from the first launch. `load_from` never writes files.
- `IdentityRegistry` (`scripts/net/identity_registry.gd`) is the host's map for a run: id → (current peer, secret hash). `claim(id, secret, peer, is_dropped)` returns NEW, RECLAIM or TAKEOVER (both with the old peer), or GUEST.
  - An unknown id is NEW, registered to the new peer.
  - A known id with the matching secret is RECLAIM when its player dropped, and TAKEOVER when its old connection is still open.
  - GUEST is not registered: a wrong secret, a malformed or empty id, or the host's own id.
  - The host `reserve()`s its own identity at start, even if a client got there first.
- **TAKEOVER** covers a client that crashed and joins again before the host's ENet times out the dead connection (several seconds).
  - The host closes the old connection with `SceneMultiplayer.disconnect_peer()`. That forgets the peer at once, so nothing more is sent to a closing connection; it emits no signal.
  - The host then handles it as a drop, and reclaims.
  - Two clients from one install would take each other over, so give them separate settings files.
- **Why a new player instead of a refusal:** a host and a client launched from one install share `user://settings.cfg` and so the id. Refusing would break the two-process checks this repo relies on, and "cannot take their body" is met either way.
- **Ids never leave the host.** The roster stays peer → name. The secret is only compared as a hash, and it travels in plain text over ENet like the rest of the session (accepted for v1).

### Reclaim re-binds the same node; it does not respawn a copy

A copy would have to list every component's state (meters, timed effects, the inventory that `crafting-inventory` is adding, later stealth and status) and would silently miss the next one. Re-binding keeps the whole body by construction.

On the host, `request_join` with RECLAIM:
1. Moves the body from the old peer to the new one in the session's maps: bodies, roster (the name carries over), rate limits. Clears the old peer's countdown.
2. Calls `PlayerBody.rebind(new_peer, role, send)`. That runs `PlayerNet.rebind()`, which re-attaches and resets the intent queue, the sequence numbers, the acknowledgement, the prediction buffer and the interpolator, so the new client's intents (from sequence 1) are taken. It then runs `refresh_local()` (camera and keyboard for the local authority).
3. Stands the body up unless its meters are downed, in last stand or dead.
4. Sends `rebind_player(old, new)` to every client, which does the same mapping and re-attach with its own role. The rejoined client's copy becomes PREDICTED, with its camera and input on.
5. Sends `receive_lobby` to the rejoiner. That arrives after the rebind, so the shell's run HUD binds to the right local body.

Further details:
- **Later joiners:** the spawner replays the original spawn data `{peer: old}`, so a client that joins later first maps the body under its old peer. `receive_lobby` therefore also carries the owner map (spawn peer → current peer) for re-bound bodies, and the joiner re-binds them. Spawns are sent on connect, before any reply to the join request, on the same reliable path.
- **Node name:** the body keeps its original name (the peer it first spawned under). Nothing reads a peer from a node name. `_on_body_exiting` now forgets a body by value, not by the peer it was bound to.
- **HUD:** `CoopSession.player_rebound(old, new, body)` lets `RunHud` drop the name tag and bind the meters when the re-bound body becomes the local player. Other players' tags stay on the same node and are renamed through `roster_updated`.

### Spawning moves from connect to the join request (run phase)

- In the run phase the host spawns, or reclaims, when the join request arrives. Until then the peer has no body.
- Each connected peer gets a 10 s countdown (`_awaiting`, counted down next to `_dropped`). A peer that has not sent its request when the countdown ends is disconnected.
- A request that arrives before the host's `start()` (a peer that connected early) is recorded, and the player spawns at `start()`.
- `begin_run()` spawns the host, then identified peers in roster order. A connected peer that has not identified spawns when its request arrives.
- The world state goes to a joiner after its body is spawned or reclaimed, as before.

### Removed players are a run record

- `CoopSession` keeps the names of players removed after their 90 s, in removal order: `removed_names()`.
- `GameShell._check_run_over` adds them to the summary as dead. A run whose remaining players are all dead ends with them listed.
- The endings and Experiencia changes read the same record: a removed player is not a survivor and earns no more points.

### Tests

- **Identity, offline:** form, hashing, and that the id persists.
- **Registry claims, offline:** new, reclaim, id in use, wrong secret, anonymous.
- **Over ENet with NetHarness clients that carry an identity:**
  - drop and rejoin within 90 s gets the same body, meters and position, and others see it as the rejoiner's;
  - a rejoin after removal is a new player;
  - someone else's id cannot take the body;
  - an id in use joins as a new player;
  - a silent peer is disconnected after 10 s (driven through `_physics_process` with a large step, like the drop countdown);
  - a late joiner sees the reclaimed body under its new owner.
- **Solo, offline:** the run spawns at once, opens no port and refuses nobody, because nobody can connect.
- **Shell:** removed players appear as "Murió".
- **Manual:** a two-process host and client through the shell, where the client quits and a second client process with the same settings file rejoins.

## Risks / Trade-offs

- **The rebind touches `PlayerNet` and `PlayerBody`, which run every frame.** → `rebind()` is a separate entry point that resets state. `attach()` keeps its current behaviour for spawning, and the existing PlayerNet suites must stay green.
- **Moving spawning to the join request changes timing for every co-op test.** → NetHarness clients already send their request when their session starts, and the join helpers wait for bodies on both sides. A request before `start()` is kept.
- **Same-install two-process runs can never reclaim** (the host holds the id). → Accepted: the manual rejoin check runs the rejoining client with its own settings file.
- **Conflicts with `weather-daynight` and `crafting-inventory`** in `coop_session.gd`. → Keep edits there small, put the logic in the new files, and rebase on `main` before the PR opens.
