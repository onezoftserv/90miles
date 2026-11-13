# Tasks

## 1. Interact priority (gull shoo over palm climb)

- [ ] 1.1 Tests first in `test_interaction_picker.gd` (or the picker's existing test file): a higher priority within reach beats a nearer base one; equal priorities keep nearest-wins; a higher priority out of reach loses. Seen failing, then passing.
- [ ] 1.2 Add `priority` to `Interactable`, use it in `InteractionPicker.pick`, set it on `creature.tscn`'s Interactable. Verify: 1.1 passes and the existing picker and prompt tests still pass.
- [ ] 1.3 1-player test: a solo sandbar run with a perched gull at a nest palm; the player at the trunk's foot sees "[E] Espantar …", a press makes the gull flee, and holding E afterwards climbs the palm and adds a coconut. Verify: the test passes.
- [ ] 1.4 Import (twice), smoke run and GUT pass.

## 2. The sign's verb

- [ ] 2.1 Test first: a coast cay sign's prompt reads "[E] Mirar" (Spanish) and "[E] Look" (English); add `look_sign` to `test_hud_text.gd`'s prompt ids. Seen failing, then passing.
- [ ] 2.2 Add the verb to `hud_text.tres` and set `prompt_id` in `IslandSign`. Verify: 2.1 passes. Import (twice), smoke run and GUT pass.

## 3. The playthrough harness

- [ ] 3.1 Night foam check allows for the tint (design D4). Verify: re-run the check on the art-pass run's day and night captures' logic in a solo run; cell (47, 19) passes and the day counts are unchanged.
- [ ] 3.2 The gull check needs the shoo shown: E at the palm makes the gull flee, then the climb gives a coconut. Verify: PASS in the solo run.
- [ ] 3.3 Host and client modes play the structures and the route to the coast cay (design D5), with one client riding through and one rejoining mid-crossing. Verify: a host with two clients, every check PASS or a written finding, zero error lines in the three logs.
- [ ] 3.4 Run solo (windowed) and host plus two clients (headless); look at the captures. Tick art-pass 4.6 note, 6.5, 8.5 and 10.3 in `openspec/changes/art-pass/tasks.md` with dated notes, or leave a clause unticked with its finding. Update `TASKS.md`.
- [ ] 3.5 Import (twice), smoke run, GUT, `openspec validate art-pass-followups --strict` pass.

## Workflow follow-up

- Archive after the owner's review, together with or after `art-pass`.
- Still open, outside this change: structure-state sync to late joiners, ENet throttle on `submit_intent`, the shoo prompt's height (art-pass K9), the sign bubble's readability at 1× over sand.
