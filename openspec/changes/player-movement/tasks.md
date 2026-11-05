# Tasks

## 1. Rules (tests first)

- [x] 1.1 Add GUT tests for every player-movement scenario against `MovementModel` (running on sand, crouching in brush, crawling at zero energy, exhausted swimmer, diving, same intent same result) and verify they fail before the model exists
- [x] 1.2 Add `MoveIntent`, `TerrainQuery`, `GridTerrain` and `MovementModel` and verify the tests from 1.1 pass
- [x] 1.3 Add `SurvivalMeters` with energy only and verify spending, clamping at 0 and the change signal in a unit test

## 2. Player body

- [x] 2.1 Add `PlayerBody` (`scenes/player/player.tscn`) applying the model with 16 px tiles, and verify an integration test that steps the body for 10 s of running on sand ends 60 tiles away with energy 45
- [x] 2.2 Add `PlayerInput` and the named input actions in `project.godot`, and verify a test that a full right stick or D key gives an east intent of strength 1
- [x] 2.3 Add the local-only `Camera2D` and the committed 16×16 placeholder sprite with its license, and verify the smoke run passes with no dependency on git-ignored assets

## 3. Interaction

- [x] 3.1 Add `Interactable`, `InteractionPicker` and `InteractionHold` and verify tests for nearest-within-1-tile, instant use, a 2 s hold, and release-cancels
- [x] 3.2 Add the `DragHandle` on downed players and verify a test that a held drag moves the downed player at 2 tiles/s until released

## 4. Playground and checks

- [ ] 4.1 Add `scenes/dev/movement_playground.tscn` (land, brush, shallow and deep water drawn without textures, one interactable, two players) and verify it loads in the smoke run
- [ ] 4.2 Verify the import, smoke run, GUT and a 300-frame game run all pass with zero error lines

## Workflow follow-up

- Review with the ECC reviewers and fix what survives verification.
- Archive the change after the user confirms the provisional decisions in proposal.md.
