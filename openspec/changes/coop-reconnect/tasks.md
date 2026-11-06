## 1. Identity

- [x] 1.1 Add `PlayerIdentity` (make, check form, hash) and `[player] id` / `secret` in `GameSettings`, saved by the shell when new, and verify GUT tests for "the id is kept", "a malformed id is replaced" and "load_from writes nothing"
- [x] 1.2 Add `IdentityRegistry` (new, reclaim, id in use, wrong secret, anonymous) and verify its offline GUT tests
- [x] 1.3 Verify the import, smoke run and GUT pass

## 2. Join request and rejoin

- [x] 2.1 Carry the identity in `request_join`, spawn on the request in the run phase, keep a request that arrives before `start()`, add the 10 s join timeout, and verify GUT tests for "a peer that never asks to join" and "solo spawns at once" (1 player, offline)
- [x] 2.2 Add `PlayerNet.rebind()`, `PlayerBody.rebind()` / `refresh_local()`, the `rebind_player` RPC, the owner map in `receive_lobby` and `player_rebound`, and verify GUT tests for "rejoin within 90 s", "someone else's id", "an id already in use" and "a late joiner sees the reclaimed body"
- [x] 2.3 Verify the existing co-op suites (net, disconnect, lobby, meters, quick chat, rate limits, player net) still pass, and that the import, smoke run and GUT pass

## 3. Removed players and the shell

- [x] 3.1 Keep removed players in `CoopSession`, list them as "Murió" in the run summary, and verify GUT tests for "rejoin after removal" and "removed player in the summary"
- [x] 3.2 Pass the settings identity to the session in `GameShell`, follow `player_rebound` in `RunHud`, and verify a shell GUT test with 1 player offline
- [ ] 3.3 Verify the import, smoke run, GUT and a two-process host and client rejoin through the shell pass with zero error lines

## Workflow follow-up

- Review with the ECC reviewers and fix what survives verification.
- Add the coop-reconnect line to `TASKS.md` and a Done entry.
- Rebase on `main`, open the PR against `main` and get CI green; the user's other session merges it.
