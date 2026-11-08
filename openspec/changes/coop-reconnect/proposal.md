## Why

A client that drops today comes back as a stranger. Its old player lies downed for 90 s and is then removed, and the reconnecting client gets a new player with fresh meters at the spawn point. A one-second network blip costs a co-op player their place, their meters and (once players carry them) their items. A run is also confused about who is gone: the run summary forgets removed players, and nothing tells endings or Experiencia that they are dead.

The user asked for this change to follow `ui-shell` (2026-11-05). It builds on the join request that `ui-shell` added, which carries a player's name once per peer.

## What Changes

- **A stable player id per install.**
  - Each install keeps a random player id and a separate secret in `user://settings.cfg`, made on first launch.
  - The join request now carries them.
  - The host keeps, for the run, which id belongs to which player and a hash of its secret. Ids and secrets never go to other clients.
- **A rejoin within the 90 s reclaims the player.** A client that drops and joins again with the same id and secret before its 90 s are up takes back the same body: the node itself, with its position, meters and everything it carries.
  - The body stands up again unless its meters had it downed.
  - Everyone else sees the same body come back under its new peer id.
- **Back before the host noticed:** a client that crashed and joins again while the host still holds its dead connection takes over. The host closes the old connection and the player takes back its body.
- **Taking someone else's player is impossible.**
  - A wrong secret, no id at all, or the host's own id never reclaims anything: that client joins as a new player.
  - The host's id joins as a new player, not refused, so a host and a client from the same install keep working (they share a settings file, so they share an id).
- **Joiners spawn when their join request arrives**, not on connect, so the host can match the id first.
  - A peer that connects but sends no join request within 10 s is disconnected and frees its slot.
  - The host's "Empezar viaje" spawns only identified peers.
- **A player removed after the 90 s counts as dead for the run.**
  - The session keeps who was removed, and the run summary lists them as "Murió".
  - They are not survivors for endings and earn no further Experiencia. Both systems are still stubs and will read this record.
- **Solo is unchanged.** It opens no port, so a solo run stays closed to joiners, and nothing here applies with one player. A test keeps that.

**Decisions (made here, to confirm):**
1. **A failed claim joins as a new player rather than being refused.** This covers a wrong secret, no id at all, and the host's own id. Refusing would break running a host and a client from one install, which every two-process check in this repo does. Two clients from one install would take each other over; give them separate settings files.
2. **The secret travels in plain text over ENet**, like everything else in the session. Someone on the same network could read it. Encrypting the transport (DTLS) is out of scope.
3. **The reclaimed body keeps its node name** (the peer id it first spawned under). Code that needs a body's peer asks the session (`CoopSession.peer_of`), never the node name; the escape-route and crossing code do so since the merges, and their records kept by peer (route departures, crossing riders) follow `player_rebound`.
4. **Join timeout of 10 s** for a connected peer to identify.

**Left out:** host migration, rejoining after the host restarts, encrypting the transport, a "full" reason on refusal (ENet's three-client cap refuses a fourth client before the session sees it), and showing a crossing in progress to a client that joins or rejoins during it (the host keeps the rider; the joiner's screen has no crossing until it ends).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `coop-networking`:
  - "Disconnect handling" changes: a rejoin within 90 s reclaims the player, and a removed player counts as dead.
  - ADDED "Player identity": a stable id and secret per install, kept by the host and never shared.
  - ADDED "Reclaiming a player": a player's id and secret reclaim its body (dropped, or a connection the host has not noticed is dead); anything else joins as a new player.
  - ADDED "Join request": players spawn on the join request, and a silent peer times out.

## Impact

- **New:**
  - `game/scripts/net/player_identity.gd` (id and secret: make, check, hash)
  - `game/scripts/net/identity_registry.gd` (the host's id → player map for a run)
- **Changed:**
  - `CoopSession`: the join request carries id and secret; spawning moves to the join request; rebind on reclaim; join timeout; removed players are kept.
  - `PlayerNet`: `rebind()` resets its intent queue and prediction.
  - `PlayerBody`: `refresh_local()` after a rebind.
  - `GameSettings`: `[player] id` and `secret`.
  - `GameShell`: passes the identity and folds removed players into the summary.
  - `RunHud`: follows a rebind.
- **Tests:**
  - GUT over ENet: rejoin within 90 s gets the same body back; a rejoin after removal is a new player; someone else's id cannot take a body; a silent peer times out; a late joiner sees a reclaimed body under its new owner.
  - GUT, offline: the solo run stays closed; removed players appear as "Murió" in the summary.
  - A two-process rejoin through the shell.
