## Context

- `CreatureThreats._show_shark` (creatures-ai) makes a `Creature` with a lifetime and adds it under the host's `Crossing`. Nothing replicates it, so clients never see it.
- Island creatures come from `CoopSession.spawn_creature`, through the session's `EntitySpawner` under `Entities`.
  - Each peer's `_spawn_entity` builds the same `Creature` and attaches a synchronizer for position, facing and state.
  - A client never runs one (`Creature.advance` returns there).
  - Freeing it on the host despawns it everywhere, and a late joiner gets it in the spawner's replay (`creatures-ai` "Late joiner sees the creatures").
- The crossing's node sits at the session's origin, and its sea is in session coordinates, so a position on the crossing is the same under `Entities`.
- `CreatureSpawner.creatures()` lists every `Creature` under `Entities`. It drives phase despawns and the fire halving.

## Goals / Non-Goals

**Goals:**
- Every peer sees the crossing's shark for exactly its circle, including a peer that joins during it.
- The island's spawner never treats it as one of its own.

**Non-Goals:**
- A shark that moves or circles on screen. It still stands beside its victim for its circle time, as today.
- Changing any shark number.
- Other crossing creatures (tiger shark, cutter): later, through the same path.

## Decisions

### Reference games

- **Borrowed from DCSS, `crawl-ref/source/tileweb.cc`, `TilesFramework::_send_monster()`.**
  - The server sends each monster with a stable `client_id` and its cell as part of the map state.
  - Web clients and spectators draw only what arrives.
  - A newly joined spectator gets every monster in the full map (`_send_map(true)`).
  - Here, the shark is one more replicated creature with a stable node name. It reaches a late joiner through the spawner's replay.
- **Borrowed from Shattered Pixel Dungeon, `scenes/GameScene.java`, `add(Mob)`.** Adding a mob to `Dungeon.level.mobs` and creating its sprite (`addMobSprite`) are one call, so what exists is what shows. Here, `CoopSession.spawn_creature` both creates the shark on the host and shows it everywhere. There is no separate "visual only" path.
- **Rejected from Brogue CE, `src/brogue/Combat.c`, `flashMonster()`.**
  - It sets a display-only flag on a creature, which the next redraw picks up and nobody else ever learns about.
  - A display-only "shark here" message would miss a joiner.
  - It would also leave each client to time and free a node it doesn't own.

### Spawn through the session; the host times the circle

- `CreatureThreats._show_shark` calls `crossing.session().spawn_creature(data, at)` and sets the returned shark's `lifetime_s` to the circle time on the host.
  - The host's `Creature.advance` counts it down and frees it, and the spawner removes it on every client.
  - No spawn-data field and no RPC are needed. Clients never run creatures, so their copy needs no lifetime.
- `Crossing.session()` exposes the crossing's session for its threats, so `CreatureThreats` doesn't have to guess it from the tree.
- **Alternatives rejected:**
  - A crossing RPC `receive_shark(at, seconds)`: a client-side node with its own timer, invisible to joiners. That is Brogue's flash, above.
  - A spawner inside each `Crossing`: a spawn would reach peers that don't have the crossing yet, which `crossing-late-join` just removed.

### A passing creature is not the island's

- `Creature.is_passing()` is true when it has a lifetime: it leaves by itself.
- `CreatureSpawner.creatures()` skips passing creatures. So phase despawns, the fire halving and anything that counts the island's creatures ignore the crossing's shark.
- **Why not a separate parent node:** `Entities` is the one spawn path every peer has from the start. A second spawner would need its own path in `coop_session.tscn` and its own late-join replay. That is more surface for the same result.

### Tests

- **Offline, 1 player (`test_crossing_creature_shark.gd`):**
  - The shark pass puts one passing reef shark under the session's `Entities` beside the bitten swimmer, freed after its circle.
  - The island spawner's `creatures()` doesn't list it, and a phase change doesn't remove it.
- **ENet (`test_crossing_shark_net.gd`, `NetHarness`):**
  - A host and a client on a raft crossing, the client in the water at energy 15.
  - The host's shark pass shows a reef shark on the client beside the client's player.
  - A client that joins during the circle sees it.
  - When the host's circle ends, it is gone on both clients.

## Risks / Trade-offs

- **[Spawn order]** The shark spawns on clients on the spawner's path, independently of the crossing's own messages. → Nothing on the client links the two: the shark is drawn in session coordinates, and the bite arrives through the meters as before.
- **[Island counts]** Something outside `creatures()` could still walk `Entities` and meet the shark. → Today `creatures()` is the only reader; the requirement says the island ignores passing creatures, so a future reader must use it.
