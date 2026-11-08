## Why

During a crossing, only the host sees the reef shark. `CreatureThreats._show_shark` adds the shark as a plain child of the host's `Crossing`, outside the session's entity spawner. A client's player is bitten by a shark it never sees, and a late joiner can't see it either. Island creatures don't have this problem: the host spawns them through the session's entity spawner, which shows them on every peer (`creatures-ai` "Host-run creatures"). Found while building `crossing-late-join`; the user queued it (2026-11-08).

## What Changes

- **The crossing's shark is spawned through the session's entity spawner.** Every peer sees it beside its victim (or the vessel) with the host's position and state, and a peer that joins during the circle sees it too. Only the host times its circle: freeing it there removes it everywhere.
- **The crossing's shark is a passing creature, not one of the island's.** A creature with a lifetime (`Creature.is_passing()`) is skipped by the island's creature spawner. So no phase change despawns it early, a fire never counts it as fire-shy, and it never stands in for an island shark.
- **Unchanged:** the shark pass's choice and numbers (`bite_swimmer`, `hit_vessel`), its circle time (6 s, the low end of `reef_shark.tres`'s range, as today), and solo play. One player offline spawns and frees the same shark on the offline peer.

## Confirmed by the owner (2026-11-08)

- Build it ("Yes, queue both (Recommended)"): every peer, and a late joiner, sees the crossing's reef shark, which passes through the session's entity spawner and is not one of the island's creatures. No numbers changed, so nothing else was asked.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `creatures-ai`: "Crossing reef shark" now says every peer sees the shark and it is not one of the island's creatures.

## Impact

- **Code:**
  - `game/scripts/crossing/creature_threats.gd`: spawn through the session.
  - `game/scenes/crossing/crossing.gd`: a `session()` accessor.
  - `game/scenes/creatures/creature.gd`: `is_passing()`.
  - `game/scripts/ai/creature_spawner.gd`: `creatures()` skips passing creatures.
- **Network:** no new RPC. The existing entity spawner and each creature's synchronizer carry it.
- **Tests:**
  - `test_crossing_creature_shark.gd` (offline, 1 player) finds the shark in the session's entities, and the island spawner skips it.
  - A new `test_crossing_shark_net.gd` (ENet, `NetHarness`) checks that a client and a late joiner see the shark and lose it when its circle ends.
