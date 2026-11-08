## 1. Statuses on every peer

- [x] 1.1 Write `test_status_flags.gd` (offline, 1 player) and `test_status_net.gd` (ENet) (RED) and verify they fail:
  - offline: bits and `statuses_changed` per change; `NONE` and out-of-range values ignored; a solo shark bite still bleeds;
  - ENet: a bitten client sees its own bleeding and its clearing; a late joiner sees the host's bleeding.
- [x] 1.2 Replace `SurvivalMeters.statuses` with `status_flags` (bit per status, `statuses_changed` from its setter) and add it to the player's replication config, and verify 1.1 passes and the meters, condition, creature and crossing suites stay green.
- [x] 1.3 Verify the import, the smoke run and GUT pass, and a 300-frame run is clean.

## Workflow follow-up

- If the owner says yes to the HUD tag: add the red "Sangrando" tag under the local player's bars (a test with 1 player offline, and one where a client's tag follows the host), then update proposal.md and this file.
- Review with the ECC reviewers and fix what survives verification.
- Add the `status-sync` line to `TASKS.md` and a Done entry.
- Open the PR against `main`, get CI green and tell the top session (it merges). Rebase if the coast cay lands first.
