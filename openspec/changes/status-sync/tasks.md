## 1. Statuses on every peer

- [x] 1.1 Write `test_status_flags.gd` (offline, 1 player) and `test_status_net.gd` (ENet) (RED) and verify they fail:
  - offline: bits and `statuses_changed` per change; `NONE` and out-of-range values ignored; a solo shark bite still bleeds;
  - ENet: a bitten client sees its own bleeding and its clearing; a late joiner sees the host's bleeding.
- [x] 1.2 Replace `SurvivalMeters.statuses` with `status_flags` (bit per status, `statuses_changed` from its setter) and add it to the player's replication config, and verify 1.1 passes and the meters, condition, creature and crossing suites stay green.
- [x] 1.3 Verify the import, the smoke run and GUT pass, and a 300-frame run is clean.

## 2. The bleeding tag (the owner said yes, 2026-11-08)

- [x] 2.1 Write the tag tests (RED) and verify they fail: `test_meters_hud.gd` (1 player, offline: shown only while bleeding, at bind, red under the bars in the pixel font, the panel still fits, unbinding stops it) and the client's tag following the host in `test_status_net.gd`.
- [x] 2.2 Add the hidden red "Sangrando" `Label` under the bars in `meters_hud.tscn` and `bleeding_tag()` / `statuses_changed` in `MetersHud`, and verify 2.1 passes.
- [x] 2.3 Verify the import, the smoke run and GUT pass, and a 300-frame run is clean.

## Workflow follow-up

- Review with the ECC reviewers and fix what survives verification.
- Add the `status-sync` line to `TASKS.md` and a Done entry.
- Open the PR against `main`, get CI green and tell the top session (it merges). Rebase if the coast cay lands first.
