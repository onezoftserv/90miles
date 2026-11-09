## 1. The shark on every peer

- [x] 1.1 Write the tests (RED) and verify they fail:
  - `test_crossing_creature_shark.gd` (offline, 1 player): the shark is a passing reef shark under the session's `Entities`, freed after its circle; the island spawner's `creatures()` skips it (it drives phase despawns and the fire halving).
  - `test_crossing_shark_net.gd` (ENet): a client and a client that joins during the circle see it; it's gone on both when the host's circle ends.
- [x] 1.2 Add `Crossing.session()`, `Creature.is_passing()`, the skip in `CreatureSpawner.creatures()`, and the spawn through `CoopSession.spawn_creature` in `CreatureThreats._show_shark`, and verify 1.1 passes and the creature and crossing suites stay green.
- [x] 1.3 Verify the import, the smoke run and GUT pass, and a 300-frame run is clean.

## Workflow follow-up

- Review with the ECC reviewers and fix what survives verification.
- Add the `crossing-shark-sync` line to `TASKS.md` and a Done entry.
- Open the PR against `main`, get CI green, and tell the top session (it merges). Rebase if the coast cay lands first.
