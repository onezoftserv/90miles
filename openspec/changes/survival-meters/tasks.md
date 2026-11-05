# Tasks

## 1. Six meters and the tuning file

- [x] 1.1 Add GUT tests for a fresh player (thirst, hunger, energy, morale, health 100; heat 0), clamping and `meter_changed` for all six meters, the shipped tuning holding every number in the spec, and the existing energy API; verify the new ones fail (RED)
- [x] 1.2 Add `SurvivalTuning` with `game/resources/survival_tuning.tres` and extend `SurvivalMeters` to six properties and signals; verify the 1.1 tests and the existing energy tests pass, and the import, smoke run and GUT pass (GREEN)

## 2. Drains, restores and states

- [x] 2.1 Add GUT tests stepping `tick` with a context for the thirst scenarios (working in the sun, swimming does not add the sun, a day in the shade, dry, seawater), hunger (crafting doubles hunger, starving caps energy), heat (midday sun, scorching calm, sunstroke lingers, night resets heat), energy (a meal, a night's sleep) and morale (ally dies, alone at night, company, a fire ends the hallucinations); verify they fail (RED)
- [x] 2.2 Add `MeterContext`, `SurvivalRules`, `MeterOverTime`, `tick`, the event methods and the sunstroke and hallucinating states; verify the 2.1 tests pass, and the import, smoke run and GUT pass (GREEN)

## 3. Health and downed state

- [x] 3.1 Add GUT tests for poison (90 after 15 s, 80 after 30 s), nobody comes (dead after 90 s), solo (dead at once), revive (health 30 and thirst +25 with 40 s left, refused when not downed), thirst still draining while downed, and dead meters not ticking; verify they fail (RED)
- [x] 3.2 Add the downed timer, `revive`, `solo` and `died` to `SurvivalMeters`; verify the 3.1 tests pass, and the import, smoke run and GUT pass (GREEN)

## 4. Player body

- [ ] 4.1 Add GUT tests: a body on land in a midday climate loses thirst at 0.2/s; a swimming body uses ×3; a body on a shaded cell gets no sun; a teammate within 5 tiles restores morale; sunstroke slows walking to 2.4 tiles/s; running out of energy at the body level; meters going down puts the body down with its drag handle enabled, and a death keeps it down with the handle disabled; a body that is not the host does not advance its meters; verify they fail (RED)
- [ ] 4.2 Add `TerrainQuery.is_shaded` with a shaded set in `GridTerrain`, `ClimateState`, the optional `speed_factor` in `MovementModel.step`, and the host-only meters tick and downed wiring in `PlayerBody`; verify the 4.1 tests and all player-movement tests pass, and the import, smoke run and GUT pass (GREEN)

## 5. HUD

- [ ] 5.1 Add GUT tests: the HUD scene has six bars labelled Sed, Hambre, Calor, Energía, Ánimo, Salud in the committed font; bars follow the meters (thirst 40 shows 40 of 100); heat 75 fills three quarters; values set directly on the node, as a synchronizer would, show up; only the bound player's sunstroke shows the blur; rebinding stops following the old node; verify they fail (RED)
- [ ] 5.2 Add `scenes/ui/meter_bar.tscn`, `scenes/ui/meters_hud.tscn` and the blur shader; verify the 5.1 tests pass, and the import, smoke run and GUT pass (GREEN)
- [ ] 5.3 Add the HUD, a shaded hut and a midday climate to the movement playground; verify the smoke run loads it and a windowed screenshot at 640×360 shows six readable bars

## 6. Docs and integration

- [ ] 6.1 Update `docs/GAME_DESIGN.md` §4 (numbers, heat row, morale below 20, health drains) and §5 (the clock) to match the spec; verify every number there matches `survival_tuning.tres`
- [ ] 6.2 Verify the import, smoke run, GUT and a 300-frame game run all pass with zero `ERROR:` or `SCRIPT ERROR:` lines, including resources in use at exit
- [ ] 6.3 Tick the `survival-meters` line in `TASKS.md` §3 and add a Done entry naming the provisional numbers; verify `openspec validate survival-meters --type change --strict` passes

## Workflow follow-up

- The "Pescador eats raw fish" scenario is item data (the raw fish's poison effect carries a background condition) and is tested by crafting-inventory, which interprets item effects; the revive scenario is tested here at the meter level (revive plus the cup's +25 thirst).
- Review with the ECC reviewers and fix what survives verification.
- Rebase on `main`, open the PR, and wait for CI to pass.
- Archive the change after the PR review; the provisional numbers stay listed in proposal.md for the user to confirm.
