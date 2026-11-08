## 1. Change and specs
- [ ] 1.1 Write proposal.md, design.md (decisions and the reference-games table) and the three spec deltas; `openspec validate run-end --type change --strict` and `openspec validate --all` pass

## 2. Cause of death (survival-meters "Cause of death", "Cause ids")
- [ ] 2.1 Write test_death_cause.gd (RED) and add `SurvivalMeters:death_cause` to SHADOW_FIELDS in test_player_state_sync.gd
- [ ] 2.2 Add DeathCause; SurvivalMeters.harm, death_cause and the down cause; StateSync order (death_cause before dead)
- [ ] 2.3 Crossing drowning and bite, CreatureWorld strike and pinch, NightThief and CreatureThreats name their causes (GREEN)

## 3. Removed cause and run seed (coop-networking "Removed player's cause")
- [ ] 3.1 Write test_death_cause_net.gd and the coast-cay joiner test (RED)
- [ ] 3.2 CoopSession removed causes (record_removed, receive_lobby), WORLD_STATE_TYPES run_seed and islands; IslandTravel.islands_reached (GREEN)

## 4. Death one-liners (endings-progression "Death one-liners", "One-liner picked by the run seed")
- [ ] 4.1 Write test_death_lines.gd (RED)
- [ ] 4.2 Write death_one_liners.tres (20 draft lines) and DeathLines (GREEN)

## 5. Run summary (endings-progression "Cause of death on the run summary", "Run summary totals")
- [ ] 5.1 Write test_run_summary.gd (RED)
- [ ] 5.2 RunSummary, SummaryRow, the wider SummaryScreen, GameShell seed_source and _check_run_over; the HUD goes when the summary shows (GREEN)

## 6. Restart (endings-progression "Restart from the summary", "A fresh run starts clean")
- [ ] 6.1 Write test_run_restart.gd (RED)
- [ ] 6.2 "Otra vez" in solo, co-op shows only "Volver al inicio", a client keeps its summary when the host leaves, _end_run clears the pause (GREEN)

## 7. Proof and checks
- [ ] 7.1 Show the new tests failing on the old code once (git apply -R), then passing
- [ ] 7.2 The four Godot checks and both openspec validations pass with no ERROR lines
- [ ] 7.3 TASKS.md ticked with a Done entry and the follow-ups; CONTENT_MANIFEST note
